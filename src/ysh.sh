#!/usr/bin/env bash
# shellcheck source=/dev/null
YSH_version='0.4.0'

# Replaced by the build with the embedded AWK parser.
YAML_AWK_PARSER=$(cat src/ysh.awk)

YSH_error() {
    printf 'Error: %s\n' "$*" >&2
}

YSH_normalize_query() {
    local query="${1#.}"
    printf '%s\n' "${query}" | sed -e 's/\[/.[/g' -e 's/^\.//' -e 's/\.\././g'
}

# Kept as a library alias for callers that used the original helper.
YSH_escape_query() {
    YSH_normalize_query "${1}"
}

YSH_parse() {
    case "${2:-values}" in
    1|lines) awk -v line_numbers=1 "${YAML_AWK_PARSER}" "${1}" ;;
    types) awk -v value_types=1 "${YAML_AWK_PARSER}" "${1}" ;;
    *) awk "${YAML_AWK_PARSER}" "${1}" ;;
    esac
}

YSH_parse_stdin() {
    case "${1:-values}" in
    1|lines) awk -v line_numbers=1 "${YAML_AWK_PARSER}" ;;
    types) awk -v value_types=1 "${YAML_AWK_PARSER}" ;;
    *) awk "${YAML_AWK_PARSER}" ;;
    esac
}

# Compatibility alias for the misspelled helper in v0.2.x.
YSH_parse_sdin() {
    YSH_parse_stdin "${1:-0}"
}

YSH_query() {
    local data="${1}"
    local query
    local line
    query=$(YSH_normalize_query "${2}")

    while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
        "${query}="*)
            printf '%s\n' "${line#"${query}="}"
            ;;
        "${query}."*)
            printf '%s\n' "${line#"${query}."}"
            ;;
        esac
    done <<< "${data}"
}

YSH_unescape_value() {
    local encoded="${1}"
    local decoded=""
    local char
    local next_char
    local i=0
    local size=${#encoded}

    while [ "${i}" -lt "${size}" ]; do
        char=${encoded:${i}:1}
        if [ "${char}" != "\\" ] || [ $((i + 1)) -ge "${size}" ]; then
            decoded="${decoded}${char}"
            i=$((i + 1))
            continue
        fi

        i=$((i + 1))
        next_char=${encoded:${i}:1}
        case "${next_char}" in
        n) decoded="${decoded}"$'\n' ;;
        r) decoded="${decoded}"$'\r' ;;
        t) decoded="${decoded}"$'\t' ;;
        \\) decoded="${decoded}\\" ;;
        '"') decoded="${decoded}\"" ;;
        *) decoded="${decoded}\\${next_char}" ;;
        esac
        i=$((i + 1))
    done

    printf '%s\n' "${decoded}"
}

YSH_safe_query() {
    local result
    local encoded
    while IFS= read -r result || [ -n "${result}" ]; do
        if [ "${result#\"}" != "${result}" ] && [ "${result%\"}" != "${result}" ]; then
            encoded=${result#\"}
            encoded=${encoded%\"}
            YSH_unescape_value "${encoded}"
        fi
    done < <(YSH_query "${1}" "${2}")
}

YSH_sub() {
    local data="${1}"
    local query
    local line
    query=$(YSH_normalize_query "${2}")

    while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
        "${query}."*) printf '%s\n' "${line#"${query}."}" ;;
        esac
    done <<< "${data}"
}

YSH_list() {
    local line
    while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
        \[[0-9]*\]*) printf '%s\n' "${line}" ;;
        esac
    done < <(YSH_sub "${1}" "${2}")
}

YSH_list_values() {
    local line
    local path
    local index
    local encoded

    while IFS= read -r line || [ -n "${line}" ]; do
        path=${line%%=*}
        case "${path}" in
        \[*\])
            index=${path#\[}
            index=${index%\]}
            case "${index}" in
            ''|*[!0-9]*) continue ;;
            esac
            ;;
        *) continue ;;
        esac

        encoded=${line#*=}
        if [ "${encoded#\"}" != "${encoded}" ] && [ "${encoded%\"}" != "${encoded}" ]; then
            encoded=${encoded#\"}
            encoded=${encoded%\"}
            YSH_unescape_value "${encoded}"
        fi
    done < <(YSH_sub "${1}" "${2}")
}

YSH_count() {
    local line
    local first
    local index
    local seen=$'\n'
    local count=0

    while IFS= read -r line || [ -n "${line}" ]; do
        first=${line%%]*}
        first=${first#\[}
        case "${first}" in
        ''|*[!0-9]*) continue ;;
        esac
        index="[${first}]"
        case "${seen}" in
        *$'\n'"${index}"$'\n'*) ;;
        *)
            seen="${seen}${index}"$'\n'
            count=$((count + 1))
            ;;
        esac
    done < <(YSH_sub "${1}" "${2}")
    printf '%s\n' "${count}"
}

YSH_index() {
    YSH_query "${1}" "[${2}]"
}

YSH_safe_index() {
    YSH_safe_query "${1}" "[${2}]"
}

YSH_tops() {
    local line
    local key
    local seen=$'\n'

    while IFS= read -r line || [ -n "${line}" ]; do
        key=${line%%=*}
        key=${key%%.*}
        case "${seen}" in
        *$'\n'"${key}"$'\n'*) ;;
        *)
            seen="${seen}${key}"$'\n'
            printf '%s\n' "${key}"
            ;;
        esac
    done <<< "${1}"
}

YSH_next_block() {
    local line
    while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
        -*) printf '%s\n' "${line#-}" ;;
        esac
    done <<< "${1}"
}

YSH_line_query() {
    local data="${1}"
    local query
    local line
    local pointer
    local seen=$'\n'
    query=$(YSH_normalize_query "${2}")

    while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
        "${query}="*|"${query}."*)
            pointer=${line##*=}
            case "${seen}" in
            *$'\n'"${pointer}"$'\n'*) ;;
            *)
                seen="${seen}${pointer}"$'\n'
                printf '%s\n' "${pointer}"
                ;;
            esac
            ;;
        esac
    done <<< "${data}"
}

YSH_usage() {
    cat <<'EOF'

Usage: ysh [-f FILE | -T DATA] [queries]

input:
  -f, --file        <file>         parse a YAML file
  -T, --transpiled  <data>         use quoted, pre-transpiled data
                                      (use -T "${data}")

queries:
  -q, --query       <query>        generic, chainable query
  -Q, --query-val   <query>        return a decoded scalar value
  -s, --sub         <query>        return a child structure
  -l, --list        <query>        return a list structure
  -L, --list-val    <query>        return all scalar list values
  -c, --count       <query>        count list elements
  -i, --index       <index>        select a list element
  -I, --index-val   <index>        return a decoded list value
  -p, --line        <query>        return source line number(s)
      --type        <query>        return scalar type(s)
  -t, --tops                       return top-level keys
  -n, --next                       move to the next YAML document
  -v, --version                    print the version
  -h, --help                       print this message

Documentation: https://docs.yaml.azohra.com
EOF
}

YSH_needs_lines() {
    local argument
    for argument in "$@"; do
        case "${argument}" in
        -p|--line) return 0 ;;
        esac
    done
    return 1
}

YSH_needs_types() {
    local argument
    for argument in "$@"; do
        case "${argument}" in
        --type) return 0 ;;
        esac
    done
    return 1
}

ysh() {
    local raw_string=""
    local line_string=""
    local type_string=""
    local stdin_string=""
    local status=0
    local supports_lines=0
    local supports_types=0

    if [ "$#" -eq 0 ]; then
        YSH_usage
        return 1
    fi

    case "${1}" in
    -v|--version)
        printf 'v%s\n' "${YSH_version}"
        return 0
        ;;
    -h|--help)
        YSH_usage
        return 0
        ;;
    -f|--file)
        if [ "$#" -lt 2 ]; then
            YSH_error "${1} requires a file"
            return 2
        fi
        if [ ! -f "${2}" ]; then
            YSH_error "file ${2} does not exist"
            return 1
        fi
        raw_string=$(YSH_parse "${2}")
        status=$?
        if [ "${status}" -ne 0 ]; then
            return "${status}"
        fi
        if YSH_needs_lines "$@"; then
            line_string=$(YSH_parse "${2}" lines) || return $?
            supports_lines=1
        fi
        if YSH_needs_types "$@"; then
            type_string=$(YSH_parse "${2}" types) || return $?
            supports_types=1
        fi
        shift 2
        ;;
    -T|--transpiled)
        if [ "$#" -lt 2 ]; then
            YSH_error "${1} requires one quoted data argument"
            return 2
        fi
        raw_string=${2}
        shift 2
        ;;
    *)
        stdin_string=$(cat)
        raw_string=$(YSH_parse_stdin <<< "${stdin_string}")
        status=$?
        if [ "${status}" -ne 0 ]; then
            return "${status}"
        fi
        if YSH_needs_lines "$@"; then
            line_string=$(YSH_parse_stdin lines <<< "${stdin_string}") || return $?
            supports_lines=1
        fi
        if YSH_needs_types "$@"; then
            type_string=$(YSH_parse_stdin types <<< "${stdin_string}") || return $?
            supports_types=1
        fi
        ;;
    esac

    while [ "$#" -gt 0 ]; do
        case "${1}" in
        -q|--query|-Q|--query-val|-s|--sub|-l|--list|-L|--list-val|-c|--count|-i|--index|-I|--index-val|-p|--line|--type)
            if [ "$#" -lt 2 ]; then
                YSH_error "${1} requires an argument"
                return 2
            fi
            ;;
        esac

        case "${1}" in
        -q|--query) raw_string=$(YSH_query "${raw_string}" "${2}"); shift ;;
        -Q|--query-val) raw_string=$(YSH_safe_query "${raw_string}" "${2}"); shift ;;
        -s|--sub) raw_string=$(YSH_sub "${raw_string}" "${2}"); shift ;;
        -l|--list) raw_string=$(YSH_list "${raw_string}" "${2}"); shift ;;
        -L|--list-val) raw_string=$(YSH_list_values "${raw_string}" "${2}"); shift ;;
        -c|--count) raw_string=$(YSH_count "${raw_string}" "${2}"); shift ;;
        -i|--index) raw_string=$(YSH_index "${raw_string}" "${2}"); shift ;;
        -I|--index-val) raw_string=$(YSH_safe_index "${raw_string}" "${2}"); shift ;;
        -p|--line)
            if [ "${supports_lines}" -ne 1 ]; then
                YSH_error "line queries require YAML input from a file or stdin"
                return 2
            fi
            raw_string=$(YSH_line_query "${line_string}" "${2}")
            shift
            ;;
        --type)
            if [ "${supports_types}" -ne 1 ]; then
                YSH_error "type queries require YAML input from a file or stdin"
                return 2
            fi
            raw_string=$(YSH_line_query "${type_string}" "${2}")
            shift
            ;;
        -n|--next) raw_string=$(YSH_next_block "${raw_string}") ;;
        -t|--tops) raw_string=$(YSH_tops "${raw_string}") ;;
        -h|--help) YSH_usage; return 0 ;;
        -v|--version) printf 'v%s\n' "${YSH_version}"; return 0 ;;
        -*)
            YSH_error "unknown option: ${1}; use --help for usage"
            return 2
            ;;
        *)
            YSH_error "invalid argument: ${1}; transpiled data must be passed as -T \"\${data}\""
            return 2
            ;;
        esac
        shift
    done

    printf '%s\n' "${raw_string}"
}

if [ "${YSH_LIB:-0}" != '1' ]; then
    ysh "$@"
    exit $?
fi
