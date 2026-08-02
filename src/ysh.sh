#!/bin/sh

YSH_VERSION=1.9.0

# Replaced by the build with the embedded AWK engine.
# YSH_AWK_PROGRAM

ysh_error() {
    printf "Error: %s\n" "$*" >&2
}

ysh_usage() {
    cat <<EOF
YAML.sh v${YSH_VERSION}

Usage:
  ysh [options] QUERY [FILE...]
  ysh eval-all [options] QUERY FILE...
  ysh [options] FILE
  command | ysh [options] QUERY

Examples:
  ysh ".server.host" config.yml
  ysh ".services[] | select(.enabled) | .name" config.yml
  ysh -o yaml '.release.channel = "stable"' config.yml
  ysh -i '.services[] | select(.enabled) | .tier = "active"' config.yml
  ysh -n -o yaml '{name: "api", enabled: true}'
  ysh '.services | map(.name) | unique' config.yml
  ysh ".services | length" config.yml
  ysh ".missing // \"fallback\"" config.yml
  ysh ".[\"key.with.dots\"]" config.yml
  printf "%s\\n" "answer: 42" | ysh ".answer"

Output:
  -o, --output FORMAT      value, raw, json, or yaml
  -r, --raw-output        print scalar values without JSON quoting
      --json              emit JSON
  -y, --yaml-output       emit YAML
  -I, --indent N         set YAML indentation from 1 through 9 (default: 2)
      --unwrap-scalar=BOOL
                          unwrap scalar values (default: true)
      --type              print the selected node type
      --tag               print the selected node tag
      --line              print the selected node source line
      --ast               print the parsed node graph
      --events            print parser-style node events

Documents:
  -d, --document INDEX    select a zero-based YAML document
      --all-documents     evaluate every document in a stream
  -n, --null-input        build output without reading input
  -i, --inplace           transactionally update YAML files in place

Evaluation:
  -e, --exit-status       fail on no result, null, or false
      --explain           report selections, mutations, and presentation behavior
      --explain=json      emit one value-free JSON audit record per input
      --security-disable-env-ops
                          disable env(), strenv(), and envsubst

Safety:
      --max-input-bytes N reject larger inputs (default: 16777216)
      --max-nodes N       cap parser and query nodes (default: 100000)
      --max-depth N       cap collection depth (default: 256)

Other:
  -V, --version           print the version
  -h, --help              print this help

QUERY supports yq-style paths, streams, variables, slices, interpolation,
portable regexes, maps, reducers, sorting, arithmetic, construction,
assignment, deletion, and deep merge. Collections emit JSON by default.
Safe in-place edits preserve comments; other edits emit stable YAML.
EOF
}

ysh_set_output_mode() {
    case "$1" in
    value|raw) YSH_OUTPUT_MODE="value" ;;
    json) YSH_OUTPUT_MODE="json" ;;
    yaml|yml) YSH_OUTPUT_MODE="yaml" ;;
    *)
        ysh_error "unsupported output format: $1"
        return 2
        ;;
    esac
}

ysh_invoke_awk() {
    ysh_awk_program \
        -v output_mode="$YSH_OUTPUT_MODE" \
        -v selected_document="$YSH_DOCUMENT" \
        -v all_documents_mode="$YSH_ALL_DOCUMENTS" \
        -v eval_all_mode="$YSH_EVAL_ALL" \
        -v combined_files_mode="$YSH_COMBINED_FILES" \
        -v null_input_mode="$YSH_NULL_INPUT" \
        -v inplace_mode="$YSH_INPLACE" \
        -v exit_status_mode="$YSH_EXIT_STATUS" \
        -v explain_mode="$YSH_EXPLAIN" \
        -v yaml_indent="$YSH_INDENT" \
        -v unwrap_scalar_mode="$YSH_UNWRAP_SCALAR" \
        -v disable_env_ops="$YSH_DISABLE_ENV_OPS" \
        -v input_filename="$YSH_INPUT_FILENAME" \
        -v input_file_index="$YSH_FILE_INDEX" \
        -v max_input_bytes="$YSH_MAX_INPUT_BYTES" \
        -v max_nodes="$YSH_MAX_NODES" \
        -v max_depth="$YSH_MAX_DEPTH" \
        "$@"
}

ysh_run_awk() {
    YSH_QUERY_TEXT=$YSH_QUERY
    export YSH_QUERY_TEXT
    YSH_COMBINED_FILES=0
    if [ "$YSH_EVAL_ALL" -eq 1 ] && [ "$#" -gt 0 ]; then
        YSH_COMBINED_FILES=1
        ysh_invoke_awk "$@"
    elif [ "$YSH_NULL_INPUT" -eq 1 ]; then
        ysh_invoke_awk /dev/null
    elif [ -z "$YSH_INPUT_FILE" ] || [ "$YSH_INPUT_FILE" = "-" ]; then
        ysh_invoke_awk /dev/fd/3 3<&0
    else
        ysh_invoke_awk "$YSH_INPUT_FILE"
    fi
}

ysh_run_files() {
    YSH_FILES_STATUS=0
    YSH_FILE_INDEX=0
    YSH_FILES_EMITTED=0
    YSH_SAVED_IFS=$IFS
    IFS='
'
    set -f
    # Intentional newline-only splitting turns the stored file list back into argv.
    # shellcheck disable=SC2086
    set -- $YSH_INPUT_FILES
    set +f
    IFS=$YSH_SAVED_IFS
    if [ "$YSH_EVAL_ALL" -eq 1 ]; then
        for YSH_INPUT_FILE do
            if [ "$YSH_INPUT_FILE" != "-" ] && [ ! -f "$YSH_INPUT_FILE" ]; then
                ysh_error "input file does not exist: $YSH_INPUT_FILE"
                return 1
            fi
        done
        ysh_run_awk "$@"
        return $?
    fi
    for YSH_INPUT_FILE do
        if [ "$YSH_INPUT_FILE" != "-" ] && [ ! -f "$YSH_INPUT_FILE" ]; then
            ysh_error "input file does not exist: $YSH_INPUT_FILE"
            YSH_FILES_STATUS=1
            YSH_FILE_INDEX=$((YSH_FILE_INDEX + 1))
            continue
        fi
        YSH_INPUT_FILENAME=$YSH_INPUT_FILE
        if [ "$YSH_OUTPUT_MODE" = yaml ] && [ "$YSH_FILES_EMITTED" -gt 0 ]; then
            printf '%s\n' '---'
        fi
        if ! ysh_run_awk; then
            YSH_FILES_STATUS=1
        fi
        YSH_FILES_EMITTED=$((YSH_FILES_EMITTED + 1))
        YSH_FILE_INDEX=$((YSH_FILE_INDEX + 1))
    done
    return "$YSH_FILES_STATUS"
}

ysh_cleanup_transaction() {
    for YSH_CLEANUP_LIST in "$YSH_TRANSACTION_NEW_LIST" "$YSH_TRANSACTION_OLD_LIST"; do
        if [ -n "$YSH_CLEANUP_LIST" ] && [ -f "$YSH_CLEANUP_LIST" ]; then
            while IFS= read -r YSH_CLEANUP_FILE; do
                [ -z "$YSH_CLEANUP_FILE" ] || rm -f "$YSH_CLEANUP_FILE"
            done < "$YSH_CLEANUP_LIST"
        fi
    done
    for YSH_CLEANUP_LIST in "$YSH_TRANSACTION_INPUT_LIST" "$YSH_TRANSACTION_NEW_LIST" "$YSH_TRANSACTION_OLD_LIST" \
        "$YSH_TRANSACTION_REPORT" "$YSH_TRANSACTION_CALL_LOG"; do
        [ -z "$YSH_CLEANUP_LIST" ] || rm -f "$YSH_CLEANUP_LIST"
    done
}

ysh_append_transaction_log() {
    while IFS= read -r YSH_LOG_LINE; do
        printf '%s\n' "$YSH_LOG_LINE" >> "$YSH_TRANSACTION_REPORT"
    done < "$YSH_TRANSACTION_CALL_LOG"
}

ysh_emit_transaction_log() {
    while IFS= read -r YSH_LOG_LINE; do
        printf '%s\n' "$YSH_LOG_LINE" >&2
    done < "$1"
}

ysh_rollback_transaction() {
    YSH_ROLLBACK_STATUS=0
    while IFS= read -r YSH_ROLLBACK_INPUT && IFS= read -r YSH_ROLLBACK_OLD <&4; do
        if [ -n "$YSH_ROLLBACK_OLD" ] && [ -f "$YSH_ROLLBACK_OLD" ]; then
            if ! mv -f "$YSH_ROLLBACK_OLD" "$YSH_ROLLBACK_INPUT"; then
                ysh_error "could not roll back input file: $YSH_ROLLBACK_INPUT"
                YSH_ROLLBACK_STATUS=1
            fi
        fi
    done < "$YSH_TRANSACTION_INPUT_LIST" 4< "$YSH_TRANSACTION_OLD_LIST"
    return "$YSH_ROLLBACK_STATUS"
}

ysh_interrupt_transaction() {
    if [ "${YSH_TRANSACTION_COMMITTING:-0}" -eq 1 ]; then
        ysh_rollback_transaction || :
    fi
    exit 1
}

ysh_run_inplace_transaction() {
    YSH_TRANSACTION_INPUT_LIST=$(mktemp "${TMPDIR:-/tmp}/ysh-inputs.XXXXXX") || return 1
    YSH_TRANSACTION_NEW_LIST=$(mktemp "${TMPDIR:-/tmp}/ysh-new.XXXXXX") || {
        rm -f "$YSH_TRANSACTION_INPUT_LIST"
        return 1
    }
    YSH_TRANSACTION_OLD_LIST=$(mktemp "${TMPDIR:-/tmp}/ysh-old.XXXXXX") || {
        rm -f "$YSH_TRANSACTION_INPUT_LIST" "$YSH_TRANSACTION_NEW_LIST"
        return 1
    }
    YSH_TRANSACTION_REPORT=$(mktemp "${TMPDIR:-/tmp}/ysh-report.XXXXXX") || {
        rm -f "$YSH_TRANSACTION_INPUT_LIST" "$YSH_TRANSACTION_NEW_LIST" "$YSH_TRANSACTION_OLD_LIST"
        return 1
    }
    YSH_TRANSACTION_CALL_LOG=$(mktemp "${TMPDIR:-/tmp}/ysh-call-log.XXXXXX") || {
        rm -f "$YSH_TRANSACTION_INPUT_LIST" "$YSH_TRANSACTION_NEW_LIST" "$YSH_TRANSACTION_OLD_LIST" "$YSH_TRANSACTION_REPORT"
        return 1
    }
    trap 'ysh_cleanup_transaction' 0
    trap 'ysh_interrupt_transaction' 1 2 3 15

    YSH_SAVED_IFS=$IFS
    IFS='
'
    set -f
    # Input filenames are stored one per line; embedded newlines are unsupported.
    # shellcheck disable=SC2086
    set -- $YSH_INPUT_FILES
    set +f
    IFS=$YSH_SAVED_IFS

    YSH_FILE_INDEX=0
    YSH_OUTPUT_MODE=yaml
    for YSH_TRANSACTION_INPUT do
        if [ "$YSH_TRANSACTION_INPUT" = "-" ]; then
            ysh_error "--inplace requires real input files"
            return 2
        fi
        if [ -L "$YSH_TRANSACTION_INPUT" ]; then
            ysh_error "--inplace refuses symbolic links: $YSH_TRANSACTION_INPUT"
            return 2
        fi
        if [ ! -f "$YSH_TRANSACTION_INPUT" ]; then
            ysh_error "input file does not exist: $YSH_TRANSACTION_INPUT"
            return 1
        fi
        case "$YSH_TRANSACTION_INPUT" in
        */*)
            YSH_INPUT_DIR=${YSH_TRANSACTION_INPUT%/*}
            YSH_INPUT_NAME=${YSH_TRANSACTION_INPUT##*/}
            ;;
        *)
            YSH_INPUT_DIR=.
            YSH_INPUT_NAME=$YSH_TRANSACTION_INPUT
            YSH_TRANSACTION_INPUT=./$YSH_TRANSACTION_INPUT
            ;;
        esac
        while IFS= read -r YSH_TRANSACTION_EXISTING; do
            if [ "$YSH_TRANSACTION_EXISTING" = "$YSH_TRANSACTION_INPUT" ]; then
                ysh_error "--inplace received the same input more than once: $YSH_TRANSACTION_INPUT"
                return 2
            fi
        done < "$YSH_TRANSACTION_INPUT_LIST"
        if ! YSH_TRANSACTION_NEW=$(umask 077 && mktemp "${YSH_INPUT_DIR}/.${YSH_INPUT_NAME}.ysh-new.XXXXXX") 2>/dev/null; then
            ysh_error "could not create candidate beside: $YSH_TRANSACTION_INPUT"
            return 1
        fi
        if ! YSH_TRANSACTION_OLD=$(umask 077 && mktemp "${YSH_INPUT_DIR}/.${YSH_INPUT_NAME}.ysh-old.XXXXXX") 2>/dev/null; then
            rm -f "$YSH_TRANSACTION_NEW"
            ysh_error "could not create rollback copy beside: $YSH_TRANSACTION_INPUT"
            return 1
        fi
        printf '%s\n' "$YSH_TRANSACTION_INPUT" >> "$YSH_TRANSACTION_INPUT_LIST"
        printf '%s\n' "$YSH_TRANSACTION_NEW" >> "$YSH_TRANSACTION_NEW_LIST"
        printf '%s\n' "$YSH_TRANSACTION_OLD" >> "$YSH_TRANSACTION_OLD_LIST"
        if ! cp -p "$YSH_TRANSACTION_INPUT" "$YSH_TRANSACTION_NEW" ||
            ! cp -p "$YSH_TRANSACTION_INPUT" "$YSH_TRANSACTION_OLD"; then
            ysh_error "could not preserve input metadata: $YSH_TRANSACTION_INPUT"
            return 1
        fi
        YSH_INPUT_FILE=$YSH_TRANSACTION_INPUT
        YSH_INPUT_FILENAME=$YSH_TRANSACTION_INPUT
        : > "$YSH_TRANSACTION_CALL_LOG"
        if ! ysh_run_awk > "$YSH_TRANSACTION_NEW" 2> "$YSH_TRANSACTION_CALL_LOG"; then
            ysh_emit_transaction_log "$YSH_TRANSACTION_CALL_LOG"
            ysh_error "transaction aborted before writing any files"
            return 1
        fi
        ysh_append_transaction_log
        YSH_FILE_INDEX=$((YSH_FILE_INDEX + 1))
    done

    YSH_TRANSACTION_STATUS=0
    YSH_TRANSACTION_COMMITTING=1
    while IFS= read -r YSH_TRANSACTION_INPUT && IFS= read -r YSH_TRANSACTION_NEW <&4; do
        if ! mv -f "$YSH_TRANSACTION_NEW" "$YSH_TRANSACTION_INPUT"; then
            ysh_error "could not replace input file: $YSH_TRANSACTION_INPUT"
            YSH_TRANSACTION_STATUS=1
            break
        fi
    done < "$YSH_TRANSACTION_INPUT_LIST" 4< "$YSH_TRANSACTION_NEW_LIST"
    if [ "$YSH_TRANSACTION_STATUS" -ne 0 ]; then
        ysh_rollback_transaction || :
        YSH_TRANSACTION_COMMITTING=0
        return 1
    fi

    YSH_TRANSACTION_COMMITTING=0
    ysh_emit_transaction_log "$YSH_TRANSACTION_REPORT"
    ysh_cleanup_transaction
    YSH_TRANSACTION_INPUT_LIST=
    YSH_TRANSACTION_NEW_LIST=
    YSH_TRANSACTION_OLD_LIST=
    YSH_TRANSACTION_REPORT=
    YSH_TRANSACTION_CALL_LOG=
    trap - 0 1 2 3 15
}

ysh_main() {
    YSH_OUTPUT_MODE="value"
    YSH_DOCUMENT=0
    YSH_ALL_DOCUMENTS=0
    YSH_EVAL_ALL=0
    YSH_QUERY=.
    YSH_INPUT_FILE=
    YSH_NULL_INPUT=0
    YSH_INPLACE=0
    YSH_EXIT_STATUS=0
    YSH_EXPLAIN=0
    YSH_INDENT=2
    YSH_UNWRAP_SCALAR=1
    YSH_DISABLE_ENV_OPS=0
    YSH_INPUT_FILENAME=-
    YSH_FILE_INDEX=0
    YSH_INPUT_FILES=
    YSH_TRANSACTION_INPUT_LIST=
    YSH_TRANSACTION_NEW_LIST=
    YSH_TRANSACTION_OLD_LIST=
    YSH_TRANSACTION_REPORT=
    YSH_TRANSACTION_CALL_LOG=
    YSH_MAX_INPUT_BYTES=${YSH_MAX_INPUT_BYTES:-16777216}
    YSH_MAX_NODES=${YSH_MAX_NODES:-100000}
    YSH_MAX_DEPTH=${YSH_MAX_DEPTH:-256}
    YSH_POSITIONAL_COUNT=0
    YSH_POSITIONAL_ONE=
    YSH_POSITIONAL_TWO=
    YSH_POSITIONAL_REST=

    while [ "$#" -gt 0 ]; do
        case "$1" in
        -o|--output|--output-format)
            if [ "$#" -lt 2 ]; then
                ysh_error "$1 requires a format"
                return 2
            fi
            ysh_set_output_mode "$2" || return $?
            shift 2
            ;;
        -o=*|--output=*|--output-format=*)
            ysh_set_output_mode "${1#*=}" || return $?
            shift
            ;;
        -r|--raw-output)
            YSH_OUTPUT_MODE="value"
            shift
            ;;
        --json)
            YSH_OUTPUT_MODE="json"
            shift
            ;;
        -y|--yaml-output)
            YSH_OUTPUT_MODE="yaml"
            shift
            ;;
        -I|--indent)
            if [ "$#" -lt 2 ]; then
                ysh_error "$1 requires an integer from 1 through 9"
                return 2
            fi
            case "$2" in
            [1-9]) YSH_INDENT=$2 ;;
            *)
                ysh_error "$1 requires an integer from 1 through 9"
                return 2
                ;;
            esac
            shift 2
            ;;
        -I[1-9])
            YSH_INDENT=${1#-I}
            shift
            ;;
        -I=*|--indent=*)
            YSH_INDENT=${1#*=}
            case "$YSH_INDENT" in
            [1-9]) ;;
            *)
                ysh_error "--indent requires an integer from 1 through 9"
                return 2
                ;;
            esac
            shift
            ;;
        --unwrap-scalar=*|--unwrapScalar=*)
            case "${1#*=}" in
            true) YSH_UNWRAP_SCALAR=1 ;;
            false) YSH_UNWRAP_SCALAR=0 ;;
            *)
                ysh_error "--unwrap-scalar must be true or false"
                return 2
                ;;
            esac
            shift
            ;;
        --type)
            YSH_OUTPUT_MODE="type"
            shift
            ;;
        --tag)
            YSH_OUTPUT_MODE="tag"
            shift
            ;;
        --line)
            YSH_OUTPUT_MODE="line"
            shift
            ;;
        --ast)
            YSH_OUTPUT_MODE="ast"
            shift
            ;;
        --events)
            YSH_OUTPUT_MODE="events"
            shift
            ;;
        -n|--null-input)
            YSH_NULL_INPUT=1
            shift
            ;;
        -i|--inplace|--in-place)
            YSH_INPLACE=1
            shift
            ;;
        -e|--exit-status)
            YSH_EXIT_STATUS=1
            shift
            ;;
        --explain)
            YSH_EXPLAIN=1
            shift
            ;;
        --explain=json)
            YSH_EXPLAIN=2
            shift
            ;;
        --security-disable-env-ops)
            YSH_DISABLE_ENV_OPS=1
            shift
            ;;
        -d|--document)
            if [ "$#" -lt 2 ]; then
                ysh_error "$1 requires a document index"
                return 2
            fi
            case "$2" in
            ""|*[!0-9]*)
                ysh_error "document index must be a non-negative integer"
                return 2
                ;;
            esac
            YSH_DOCUMENT=$2
            YSH_ALL_DOCUMENTS=0
            shift 2
            ;;
        --all-documents)
            YSH_ALL_DOCUMENTS=1
            shift
            ;;
        --max-input-bytes|--max-nodes|--max-depth)
            if [ "$#" -lt 2 ]; then
                ysh_error "$1 requires a positive integer"
                return 2
            fi
            case "$2" in
            ""|*[!0-9]*|0)
                ysh_error "$1 requires a positive integer"
                return 2
                ;;
            esac
            case "$1" in
            --max-input-bytes) YSH_MAX_INPUT_BYTES=$2 ;;
            --max-nodes) YSH_MAX_NODES=$2 ;;
            --max-depth) YSH_MAX_DEPTH=$2 ;;
            esac
            shift 2
            ;;
        -V|--version)
            printf "v%s\n" "$YSH_VERSION"
            return 0
            ;;
        -h|--help)
            ysh_usage
            return 0
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                YSH_POSITIONAL_COUNT=$((YSH_POSITIONAL_COUNT + 1))
                if [ "$YSH_POSITIONAL_COUNT" -eq 1 ]; then
                    YSH_POSITIONAL_ONE=$1
                elif [ "$YSH_POSITIONAL_COUNT" -eq 2 ]; then
                    YSH_POSITIONAL_TWO=$1
                else
                    if [ -z "$YSH_POSITIONAL_REST" ]; then
                        YSH_POSITIONAL_REST=$1
                    else
                        YSH_POSITIONAL_REST="${YSH_POSITIONAL_REST}
$1"
                    fi
                fi
                shift
            done
            ;;
        -*)
            ysh_error "unknown option: $1"
            return 2
            ;;
        *)
            if [ "$YSH_POSITIONAL_COUNT" -eq 0 ]; then
                case "$1" in
                e|eval)
                    shift
                    continue
                    ;;
                ea|eval-all)
                    YSH_EVAL_ALL=1
                    shift
                    continue
                    ;;
                esac
            fi
            YSH_POSITIONAL_COUNT=$((YSH_POSITIONAL_COUNT + 1))
            if [ "$YSH_POSITIONAL_COUNT" -eq 1 ]; then
                YSH_POSITIONAL_ONE=$1
            elif [ "$YSH_POSITIONAL_COUNT" -eq 2 ]; then
                YSH_POSITIONAL_TWO=$1
            else
                if [ -z "$YSH_POSITIONAL_REST" ]; then
                    YSH_POSITIONAL_REST=$1
                else
                    YSH_POSITIONAL_REST="${YSH_POSITIONAL_REST}
$1"
                fi
            fi
            shift
            ;;
        esac
    done

    if [ "$YSH_POSITIONAL_COUNT" -ge 2 ]; then
        case "$YSH_POSITIONAL_ONE" in
        .*)
            YSH_QUERY=$YSH_POSITIONAL_ONE
            YSH_INPUT_FILE=$YSH_POSITIONAL_TWO
            ;;
        *)
            if [ -f "$YSH_POSITIONAL_ONE" ] && [ "${YSH_POSITIONAL_TWO#.}" != "$YSH_POSITIONAL_TWO" ]; then
                YSH_INPUT_FILE=$YSH_POSITIONAL_ONE
                YSH_QUERY=$YSH_POSITIONAL_TWO
            else
                YSH_QUERY=$YSH_POSITIONAL_ONE
                YSH_INPUT_FILE=$YSH_POSITIONAL_TWO
            fi
            ;;
        esac
    elif [ "$YSH_POSITIONAL_COUNT" -eq 1 ]; then
        if [ -f "$YSH_POSITIONAL_ONE" ] || [ "$YSH_POSITIONAL_ONE" = "-" ]; then
            YSH_INPUT_FILE=$YSH_POSITIONAL_ONE
        else
            case "$YSH_POSITIONAL_ONE" in
            *.yml|*.yaml|*.json) YSH_INPUT_FILE=$YSH_POSITIONAL_ONE ;;
            *) YSH_QUERY=$YSH_POSITIONAL_ONE ;;
            esac
        fi
    fi

    if [ -n "$YSH_INPUT_FILE" ] && [ "$YSH_INPUT_FILE" != "-" ] && [ ! -f "$YSH_INPUT_FILE" ]; then
        ysh_error "input file does not exist: $YSH_INPUT_FILE"
        return 1
    fi
    if [ -n "$YSH_INPUT_FILE" ]; then
        YSH_INPUT_FILENAME=$YSH_INPUT_FILE
    fi

    if [ -n "$YSH_POSITIONAL_REST" ]; then
        if [ -z "$YSH_INPUT_FILE" ]; then
            ysh_error "multiple inputs require an explicit query"
            return 2
        fi
        YSH_INPUT_FILES="${YSH_INPUT_FILE}
${YSH_POSITIONAL_REST}"
    fi

    if [ "$YSH_INPLACE" -eq 1 ]; then
        if [ "$YSH_EVAL_ALL" -eq 1 ]; then
            ysh_error "--inplace cannot be combined with eval-all"
            return 2
        fi
        if [ "$YSH_NULL_INPUT" -eq 1 ]; then
            ysh_error "--inplace cannot be combined with --null-input"
            return 2
        fi
        if [ -z "$YSH_INPUT_FILE" ] || [ "$YSH_INPUT_FILE" = "-" ]; then
            ysh_error "--inplace requires an input file"
            return 2
        fi
        if [ -z "$YSH_INPUT_FILES" ]; then
            YSH_INPUT_FILES=$YSH_INPUT_FILE
        fi
        ysh_run_inplace_transaction
        return $?
    fi

    if [ -n "$YSH_INPUT_FILES" ]; then
        ysh_run_files
        return $?
    fi
    if [ "$YSH_EVAL_ALL" -eq 1 ]; then
        YSH_ALL_DOCUMENTS=0
    fi

    ysh_run_awk
}

if [ "${YSH_LIB:-0}" != 1 ]; then
    ysh_main "$@"
    exit $?
fi
