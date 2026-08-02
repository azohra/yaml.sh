#!/bin/sh

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
PUBLISHED=$ROOT/_static/_www/docs
STORY=$ROOT/_static/_www/story
GENERATED=$(mktemp -d "${TMPDIR:-/tmp}/ysh-docs.XXXXXX")
PAGES='getting-started recipes queries documents output yq-compatibility supported_yml security migration internals development versioning'
trap 'rm -rf "$GENERATED"' 0 1 2 3 15

YSH_DOCS_OUTPUT=$GENERATED "$ROOT/build/docs.sh" >/dev/null

cmp "$GENERATED/index.html" "$PUBLISHED/index.html"
cmp "$GENERATED/search-index.json" "$PUBLISHED/search-index.json"
for page in $PAGES; do
    cmp "$GENERATED/$page/index.html" "$PUBLISHED/$page/index.html"
done

VERSION_TEST=$GENERATED/version-test
YSH_DOCS_VERSION=9.9.9 YSH_DOCS_OUTPUT=$VERSION_TEST "$ROOT/build/docs.sh" >/dev/null
if ! grep -Fq 'Install <span>v9.9.9</span>' "$VERSION_TEST/index.html"; then
    printf '%s\n' 'Documentation release text is not generated from the executable version.' >&2
    exit 1
fi
if ! awk -v version=9.9.9 -f "$ROOT/build/docbuilder.awk" "$ROOT/_static/_www/index.html" | grep -Fq 'data-ysh-version>v9.9.9'; then
    printf '%s\n' 'Homepage release text is not generated from the executable version.' >&2
    exit 1
fi
if ! awk -v version=9.9.9 -v sha256=abc123 -f "$ROOT/build/docbuilder.awk" "$ROOT/_static/_www/install" | grep -Fq 'expected_sha256=abc123'; then
    printf '%s\n' 'Installer checksum is not generated from the release artifact.' >&2
    exit 1
fi
if ! awk -v version=9.9.9 -v sha256=abc123 -f "$ROOT/build/docbuilder.awk" "$ROOT/_static/_www/install" | grep -Fq 'releases/download/v9.9.9/ysh'; then
    printf '%s\n' 'Installer download URL is not generated from the release version.' >&2
    exit 1
fi

if ! grep -Fq 'css/style.css?v=4.1' "$ROOT/_static/_www/index.html" ||
    ! grep -Fq 'css/style.css?v=4.1' "$STORY/index.html"; then
    printf '%s\n' 'Homepage and story stylesheet cache keys are not synchronized.' >&2
    exit 1
fi

if grep -En 'docsify|cdn\.jsdelivr|href="#/|theme\.css' "$PUBLISHED"/*.html "$PUBLISHED"/*/index.html >/dev/null; then
    printf '%s\n' 'Generated documentation still references the retired runtime renderer.' >&2
    exit 1
fi

if grep -En 'href="[[:alnum:]_-]+\.md([#"]|$)' "$PUBLISHED"/*.html "$PUBLISHED"/*/index.html >/dev/null; then
    printf '%s\n' 'Generated documentation contains a source Markdown link.' >&2
    exit 1
fi

if ! grep -Eq 'scroll-margin-top: calc\(var\(--header\) \+ 28px\)' "$PUBLISHED/docs.css"; then
    printf '%s\n' 'Documentation headings have lost their sticky-header offset.' >&2
    exit 1
fi

if grep -En 'scroll-behavior:[[:space:]]*smooth' "$PUBLISHED/docs.css" >/dev/null; then
    printf '%s\n' 'Smooth scrolling reintroduced anchor movement.' >&2
    exit 1
fi

for asset in "$ROOT/_static/_www/brand/hero.svg" "$ROOT/_static/_www/og.png" "$STORY/story.css" "$PUBLISHED/docs.css" "$PUBLISHED/docs.js"; do
    if [ ! -s "$asset" ]; then
        printf 'Missing documentation asset: %s\n' "$asset" >&2
        exit 1
    fi
done

LINKS=$GENERATED/.links
for source in "$ROOT/_static/_www/index.html" "$STORY/index.html" "$PUBLISHED"/*.html "$PUBLISHED"/*/index.html; do
    awk -v source="$source" '
    {
        line = $0
        while (match(line, /(href|src)="[^"]+"/)) {
            link = substr(line, RSTART, RLENGTH)
            sub(/^[^=]+="/, "", link)
            sub(/"$/, "", link)
            print source "\t" link
            line = substr(line, RSTART + RLENGTH)
        }
    }
    ' "$source" >> "$LINKS"
done

while IFS="	" read -r source link; do
    case "$link" in
    http://*|https://*|mailto:*|data:*) continue ;;
    esac
    anchor=""
    case "$link" in
    *#*) anchor=${link#*#}; link=${link%%#*} ;;
    esac
    link=${link%%\?*}
    if [ -z "$link" ]; then
        target=$source
    else
        case "$link" in
        /) target=$ROOT/_static/_www/index.html ;;
        /*/) target=$ROOT/_static/_www${link}index.html ;;
        /*) target=$ROOT/_static/_www$link ;;
        *) target=$(dirname "$source")/$link ;;
        esac
    fi
    if [ ! -f "$target" ]; then
        printf 'Broken local link: %s -> %s\n' "$source" "$link" >&2
        exit 1
    fi
    if [ -n "$anchor" ] && ! grep -Fq "id=\"$anchor\"" "$target"; then
        printf 'Broken local anchor: %s -> #%s\n' "$source" "$anchor" >&2
        exit 1
    fi
done < "$LINKS"

if grep -En 'og-v[0-9]|v[0-9]+\.[0-9]+.*(\.png|\.svg)' "$ROOT/README.md" "$ROOT/_static/_www/index.html" "$STORY/index.html" "$PUBLISHED"/*.html "$PUBLISHED"/*/index.html >/dev/null; then
    printf '%s\n' 'A release-specific image reference returned.' >&2
    exit 1
fi

page_count=$(printf '%s\n' "$PAGES" | wc -w | tr -d ' ')
printf 'Static documentation: %s generated pages, local links, stable anchors, evergreen identity.\n' "$((page_count + 1))"
