#!/bin/sh

YSH_VERSION=1.3.0

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
  -n, --null-input        build output without reading input
  -i, --inplace           update a YAML file in place

Other:
  -V, --version           print the version
  -h, --help              print this help

QUERY supports yq-style paths, streams, variables, dynamic indexes, maps,
entries, reducers, sorting, strings, arithmetic, construction, assignment,
deletion, and deep merge. Collections emit JSON by default. In-place scalar
updates preserve comments and presentation; structural edits emit stable YAML.
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
    if [ "$YSH_NULL_INPUT" -eq 1 ]; then
        LC_ALL=C awk \
            -v query="$YSH_QUERY" \
            -v output_mode="$YSH_OUTPUT_MODE" \
            -v selected_document="$YSH_DOCUMENT" \
            -v inplace_mode="$YSH_INPLACE" \
            "$YAML_AWK_PARSER" \
            /dev/null
    elif [ -z "$YSH_INPUT_FILE" ] || [ "$YSH_INPUT_FILE" = "-" ]; then
        LC_ALL=C awk \
            -v query="$YSH_QUERY" \
            -v output_mode="$YSH_OUTPUT_MODE" \
            -v selected_document="$YSH_DOCUMENT" \
            -v inplace_mode="$YSH_INPLACE" \
            "$YAML_AWK_PARSER"
    else
        LC_ALL=C awk \
            -v query="$YSH_QUERY" \
            -v output_mode="$YSH_OUTPUT_MODE" \
            -v selected_document="$YSH_DOCUMENT" \
            -v inplace_mode="$YSH_INPLACE" \
            "$YAML_AWK_PARSER" \
            "$YSH_INPUT_FILE"
    fi
}

ysh_run_inplace() {
    YSH_TEMP_FILE=${YSH_INPUT_FILE}.ysh.$$
    if ! (umask 077 && set -C && : > "$YSH_TEMP_FILE") 2>/dev/null; then
        ysh_error "could not create temporary file beside: $YSH_INPUT_FILE"
        return 1
    fi
    trap 'rm -f "$YSH_TEMP_FILE"' 0
    trap 'exit 1' 1 2 3 15
    YSH_OUTPUT_MODE=yaml
    if ! ysh_run_awk > "$YSH_TEMP_FILE"; then
        return 1
    fi
    if ! cp "$YSH_TEMP_FILE" "$YSH_INPUT_FILE"; then
        ysh_error "could not replace input file: $YSH_INPUT_FILE"
        return 1
    fi
    rm -f "$YSH_TEMP_FILE"
    trap - 0 1 2 3 15
}

ysh_main() {
    YSH_OUTPUT_MODE="value"
    YSH_DOCUMENT=0
    YSH_QUERY=.
    YSH_INPUT_FILE=
    YSH_NULL_INPUT=0
    YSH_INPLACE=0
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

    if [ "$YSH_INPLACE" -eq 1 ]; then
        if [ "$YSH_NULL_INPUT" -eq 1 ]; then
            ysh_error "--inplace cannot be combined with --null-input"
            return 2
        fi
        if [ -z "$YSH_INPUT_FILE" ] || [ "$YSH_INPUT_FILE" = "-" ]; then
            ysh_error "--inplace requires an input file"
            return 2
        fi
        ysh_run_inplace
        return $?
    fi

    ysh_run_awk
}

if [ "${YSH_LIB:-0}" != 1 ]; then
    ysh_main "$@"
    exit $?
fi
