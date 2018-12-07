#! /bin/bash
# shellcheck source=/dev/null
YSH_version='0.1.2'

# Will be replaced by builder with minified awk parser program
YAML_AWK_PARSER=$(cat src/ysh.awk)

YSH_parse() {
    awk "${YAML_AWK_PARSER}" "${1}"
}

YSH_query() {
    grep -E "^${2}" <<< "${1}" | sed -E "s/^${2}[\\.=]?//"
}

YSH_safe_query() {
    grep -E "^${2}=\".*\"$" <<< "${1}" | sed -E "s/^${2}=\"//" | sed -E "s/\"$//"
}

YSH_sub() {
    grep -E "^${2}[^=]" <<< "${1}" | sed "s/^$2\\.//"
}

YSH_list() {
    YSH_sub "${1}" "${2}" | grep -E "^\\[[0-9]+\\]"
}

YSH_count() {
    YSH_sub "${1}" "${2}" | grep -oE "^\\[[0-9]+\\]" | uniq | wc -l
}

YSH_index() {
    YSH_query "${1}" "\\[${2}\\]"
}

YSH_safe_index() {
    YSH_safe_query "${1}" "\\[${2}\\]"
}

YSH_safe_index() {
    YSH_safe_query "${1}" "\\[${2}\\]"
}

YSH_tops() {
    sed -E "s/[\\[\\.=].*$//" <<< "${1}" | uniq
}

YSH_next_block() {
    grep -E "^-.*" <<< "${1}" | sed -E "s/^-\\.?//g"
}


YSH_usage() {
    echo ""
    echo "Usage: ysh [flags]"
    echo ""
    echo "flags:"
    echo "  -f, --file        <file_name>    parse file"
    echo "  -T, --transpiled  <file_name>    use pre-transpiled file"
    echo "  -q, --query       <query>        generic query"
    echo "  -Q, --query-val   <query>        safe query. Guarentees a value."
    echo "  -s, --sub         <query>        sub structure. No values."
    echo "  -l, --list        <query>        query for a list"
    echo "  -c, --count       <query>        count length of list element"
    echo "  -i, --index       <i>            array access by index"
    echo "  -I, --index-val   <i>            safe array access by index. Guarentees a value."
    echo "  -t, --tops                       top level children keys of structure"
    echo "  -n, --next                       move to next block"
    echo "  -h, --help                       prints this message"
    echo ""
    echo "And even more at https://docs.yaml.sh"
}

ysh() {
    local YSH_RAW_STRING=""
    while [ $# -gt 0 ] ; do

        case "$1" in
        -v|--version)
            echo "v${YSH_version}" && exit 0
        ;;
        -h|--help)
            YSH_usage
        ;;
        -f|--file)
            YSH_RAW_STRING="$(YSH_parse "${2}")"
            shift
        ;;
        -T|--transpiled)
            YSH_RAW_STRING="${2}"
            shift
        ;;
        -q|--query)
            YSH_RAW_STRING="$(YSH_query "${YSH_RAW_STRING}" "${2}")"
            shift
        ;;
        -Q|--query-val)
            YSH_RAW_STRING="$(YSH_safe_query "${YSH_RAW_STRING}" "${2}")"
            shift
        ;;
        -c|--count)
            YSH_RAW_STRING="$(YSH_count "${YSH_RAW_STRING}" "${2}")"
            shift
        ;;
        -l|--list)
            YSH_RAW_STRING="$(YSH_list "${YSH_RAW_STRING}" "${2}")"
            shift
        ;;
        -i|--index)
            YSH_RAW_STRING="$(YSH_index "${YSH_RAW_STRING}" "${2}")"
            shift
        ;;
        -I|--index-val)
            YSH_RAW_STRING="$(YSH_safe_index "${YSH_RAW_STRING}" "${2}")"
            shift
        ;;
        -s|--sub)
            YSH_RAW_STRING="$(YSH_sub "${YSH_RAW_STRING}" "${2}")"
            shift
        ;;
        -n|--next)
            YSH_RAW_STRING="$(YSH_next_block "${YSH_RAW_STRING}")"
        ;;
        -t|--tops)
            YSH_RAW_STRING="$(YSH_tops "${YSH_RAW_STRING}")"
        ;;
        -*)
            echo "Unknown option: ${1} Refer to -h for help."
            exit 1
        ;;
        *)
            echo "Unknown Ussage!" > /dev/stdout
            exit 1
        ;;
        esac
        shift
        if [[ $# -eq 0 ]]; then echo "${YSH_RAW_STRING}"; fi
    done
}
if [[ YSH_LIB -ne 1 ]]; then 
    if [[ $# -eq 0 ]] ; then YSH_usage; exit 1; fi
    ysh "$@"; 
fi