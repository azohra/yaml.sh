#!/bin/sh

YSH_VERSION=1.0.0

# Replaced by the build with the embedded AWK engine.
YAML_AWK_PARSER=$(cat src/ysh.awk)

ysh_error() {
    printf "Error: %s\n" "$*" >&2
}

ysh_usage() {
    cat <<EOF
YAML.sh v${YSH_VERSION}

Usage:
  ysh [options] QUERY [FILE]
  ysh [options] FILE
  command | ysh [options] QUERY

Examples:
  ysh ".server.host" config.yml
  ysh ".services[0]" config.yml --json
  ysh ".[\"key.with.dots\"]" config.yml
  printf "%s\\n" "answer: 42" | ysh ".answer"

Output:
  -o, --output FORMAT      value, raw, or json
  -r, --raw-output        print scalar values without JSON quoting
      --json              emit JSON
      --type              print the selected node type
      --tag               print the selected node tag
      --line              print the selected node source line
      --ast               print the parsed node graph
      --events            print parser-style node events

Documents:
  -d, --document INDEX    select a zero-based YAML document

Other:
  -V, --version           print the version
  -h, --help              print this help

QUERY uses yq-style paths such as .server.host, .items[0], and
.["key.with.dots"]. Collections are emitted as JSON by default.
EOF
}

ysh_set_output_mode() {
    case "$1" in
    value|raw) YSH_OUTPUT_MODE="value" ;;
    json) YSH_OUTPUT_MODE="json" ;;
    *)
        ysh_error "unsupported output format: $1"
        return 2
        ;;
    esac
}

ysh_run_awk() {
    if [ -z "$YSH_INPUT_FILE" ] || [ "$YSH_INPUT_FILE" = "-" ]; then
        awk \
            -v query="$YSH_QUERY" \
            -v output_mode="$YSH_OUTPUT_MODE" \
            -v selected_document="$YSH_DOCUMENT" \
            "$YAML_AWK_PARSER"
    else
        awk \
            -v query="$YSH_QUERY" \
            -v output_mode="$YSH_OUTPUT_MODE" \
            -v selected_document="$YSH_DOCUMENT" \
            "$YAML_AWK_PARSER" \
            "$YSH_INPUT_FILE"
    fi
}

ysh_main() {
    YSH_OUTPUT_MODE="value"
    YSH_DOCUMENT=0
    YSH_QUERY=.
    YSH_INPUT_FILE=
    YSH_POSITIONAL_COUNT=0
    YSH_POSITIONAL_ONE=
    YSH_POSITIONAL_TWO=

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
                    ysh_error "too many positional arguments"
                    return 2
                fi
                shift
            done
            ;;
        -*)
            ysh_error "unknown option: $1"
            return 2
            ;;
        *)
            YSH_POSITIONAL_COUNT=$((YSH_POSITIONAL_COUNT + 1))
            if [ "$YSH_POSITIONAL_COUNT" -eq 1 ]; then
                YSH_POSITIONAL_ONE=$1
            elif [ "$YSH_POSITIONAL_COUNT" -eq 2 ]; then
                YSH_POSITIONAL_TWO=$1
            else
                ysh_error "too many positional arguments"
                return 2
            fi
            shift
            ;;
        esac
    done

    if [ "$YSH_POSITIONAL_COUNT" -eq 2 ]; then
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
                ysh_error "query must start with ."
                return 2
            fi
            ;;
        esac
    elif [ "$YSH_POSITIONAL_COUNT" -eq 1 ]; then
        case "$YSH_POSITIONAL_ONE" in
        .*) YSH_QUERY=$YSH_POSITIONAL_ONE ;;
        *) YSH_INPUT_FILE=$YSH_POSITIONAL_ONE ;;
        esac
    fi

    if [ -n "$YSH_INPUT_FILE" ] && [ "$YSH_INPUT_FILE" != "-" ] && [ ! -f "$YSH_INPUT_FILE" ]; then
        ysh_error "input file does not exist: $YSH_INPUT_FILE"
        return 1
    fi

    ysh_run_awk
}

if [ "${YSH_LIB:-0}" != 1 ]; then
    ysh_main "$@"
    exit $?
fi
