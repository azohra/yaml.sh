#!/bin/sh

YSH_VERSION=1.7.0

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
      --type              print the selected node type
      --tag               print the selected node tag
      --line              print the selected node source line
      --ast               print the parsed node graph
      --events            print parser-style node events

Documents:
  -d, --document INDEX    select a zero-based YAML document
      --all-documents     evaluate every document in a stream
  -n, --null-input        build output without reading input
  -i, --inplace           update a YAML file in place

Evaluation:
  -e, --exit-status       fail on no result, null, or false
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

ysh_run_awk() {
    YSH_QUERY_TEXT=$YSH_QUERY
    export YSH_QUERY_TEXT
    if [ "$YSH_EVAL_ALL" -eq 1 ] && [ "$#" -gt 0 ]; then
        ysh_awk_program \
            -v output_mode="$YSH_OUTPUT_MODE" \
            -v selected_document="$YSH_DOCUMENT" \
            -v all_documents_mode="$YSH_ALL_DOCUMENTS" \
            -v null_input_mode="$YSH_NULL_INPUT" \
            -v inplace_mode="$YSH_INPLACE" \
            -v exit_status_mode="$YSH_EXIT_STATUS" \
            -v disable_env_ops="$YSH_DISABLE_ENV_OPS" \
            -v input_filename="$YSH_INPUT_FILENAME" \
            -v input_file_index="$YSH_FILE_INDEX" \
            -v combined_files_mode=1 \
            -v eval_all_mode=1 \
            -v max_input_bytes="$YSH_MAX_INPUT_BYTES" \
            -v max_nodes="$YSH_MAX_NODES" \
            -v max_depth="$YSH_MAX_DEPTH" \
            "$@"
    elif [ "$YSH_NULL_INPUT" -eq 1 ]; then
        ysh_awk_program \
            -v output_mode="$YSH_OUTPUT_MODE" \
            -v selected_document="$YSH_DOCUMENT" \
            -v all_documents_mode="$YSH_ALL_DOCUMENTS" \
            -v eval_all_mode="$YSH_EVAL_ALL" \
            -v null_input_mode="$YSH_NULL_INPUT" \
            -v inplace_mode="$YSH_INPLACE" \
            -v exit_status_mode="$YSH_EXIT_STATUS" \
            -v disable_env_ops="$YSH_DISABLE_ENV_OPS" \
            -v input_filename="$YSH_INPUT_FILENAME" \
            -v input_file_index="$YSH_FILE_INDEX" \
            -v max_input_bytes="$YSH_MAX_INPUT_BYTES" \
            -v max_nodes="$YSH_MAX_NODES" \
            -v max_depth="$YSH_MAX_DEPTH" \
            /dev/null
    elif [ -z "$YSH_INPUT_FILE" ] || [ "$YSH_INPUT_FILE" = "-" ]; then
        ysh_awk_program \
            -v output_mode="$YSH_OUTPUT_MODE" \
            -v selected_document="$YSH_DOCUMENT" \
            -v all_documents_mode="$YSH_ALL_DOCUMENTS" \
            -v eval_all_mode="$YSH_EVAL_ALL" \
            -v null_input_mode="$YSH_NULL_INPUT" \
            -v inplace_mode="$YSH_INPLACE" \
            -v exit_status_mode="$YSH_EXIT_STATUS" \
            -v disable_env_ops="$YSH_DISABLE_ENV_OPS" \
            -v input_filename="$YSH_INPUT_FILENAME" \
            -v input_file_index="$YSH_FILE_INDEX" \
            -v max_input_bytes="$YSH_MAX_INPUT_BYTES" \
            -v max_nodes="$YSH_MAX_NODES" \
            -v max_depth="$YSH_MAX_DEPTH" \
            /dev/fd/3 3<&0
    else
        ysh_awk_program \
            -v output_mode="$YSH_OUTPUT_MODE" \
            -v selected_document="$YSH_DOCUMENT" \
            -v all_documents_mode="$YSH_ALL_DOCUMENTS" \
            -v eval_all_mode="$YSH_EVAL_ALL" \
            -v null_input_mode="$YSH_NULL_INPUT" \
            -v inplace_mode="$YSH_INPLACE" \
            -v exit_status_mode="$YSH_EXIT_STATUS" \
            -v disable_env_ops="$YSH_DISABLE_ENV_OPS" \
            -v input_filename="$YSH_INPUT_FILENAME" \
            -v input_file_index="$YSH_FILE_INDEX" \
            -v max_input_bytes="$YSH_MAX_INPUT_BYTES" \
            -v max_nodes="$YSH_MAX_NODES" \
            -v max_depth="$YSH_MAX_DEPTH" \
            "$YSH_INPUT_FILE"
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

ysh_run_inplace() {
    case "$YSH_INPUT_FILE" in
    */*)
        YSH_INPUT_DIR=${YSH_INPUT_FILE%/*}
        YSH_INPUT_NAME=${YSH_INPUT_FILE##*/}
        ;;
    *)
        YSH_INPUT_DIR=.
        YSH_INPUT_NAME=$YSH_INPUT_FILE
        YSH_INPUT_FILE=./$YSH_INPUT_FILE
        ;;
    esac
    if ! YSH_TEMP_FILE=$(umask 077 && mktemp "${YSH_INPUT_DIR}/.${YSH_INPUT_NAME}.ysh.XXXXXX") 2>/dev/null; then
        ysh_error "could not create temporary file beside: $YSH_INPUT_FILE"
        return 1
    fi
    trap 'rm -f "$YSH_TEMP_FILE"' 0
    trap 'exit 1' 1 2 3 15
    if ! cp -p "$YSH_INPUT_FILE" "$YSH_TEMP_FILE"; then
        ysh_error "could not preserve input metadata: $YSH_INPUT_FILE"
        return 1
    fi
    YSH_OUTPUT_MODE=yaml
    if ! ysh_run_awk > "$YSH_TEMP_FILE"; then
        return 1
    fi
    if ! mv -f "$YSH_TEMP_FILE" "$YSH_INPUT_FILE"; then
        ysh_error "could not replace input file: $YSH_INPUT_FILE"
        return 1
    fi
    YSH_TEMP_FILE=
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
    YSH_DISABLE_ENV_OPS=0
    YSH_INPUT_FILENAME=-
    YSH_FILE_INDEX=0
    YSH_INPUT_FILES=
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
        if [ -L "$YSH_INPUT_FILE" ]; then
            ysh_error "--inplace refuses symbolic links"
            return 2
        fi
        if [ -n "$YSH_INPUT_FILES" ]; then
            ysh_error "--inplace accepts exactly one input file"
            return 2
        fi
        ysh_run_inplace
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
