#!/bin/sh

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE=$ROOT/_static/_www/docs
GENERATED=$ROOT/.release/site
PUBLISHED=$GENERATED/docs
STORY=$GENERATED/story
LINKS=$(mktemp "${TMPDIR:-/tmp}/ysh-links.XXXXXX")
trap 'rm -f "$LINKS"' 0 1 2 3 15

make -C "$ROOT" build >/dev/null
PAGES=
for page_source in "$SOURCE"/*.md; do
    page=$(basename "$page_source" .md)
    if [ "$page" != README ]; then
        PAGES="$PAGES $page"
        [ -s "$PUBLISHED/$page/index.html" ] || { printf 'Missing generated page: %s\n' "$page" >&2; exit 1; }
    fi
done

node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$PUBLISHED/search-index.json"

if ! awk -v version=9.9.9 -f "$ROOT/build/docbuilder.awk" "$ROOT/_static/_www/index.html" | grep -Fq 'data-ysh-version>v9.9.9'; then
    printf '%s\n' 'Homepage release text is not generated from the published version.' >&2
    exit 1
fi
if ! awk -v version=9.9.9 -v sha256=abc123 -f "$ROOT/build/docbuilder.awk" "$ROOT/_static/_www/install" | grep -Fq 'expected_sha256=abc123'; then
    printf '%s\n' 'Installer checksum is not generated from the release artifact.' >&2
    exit 1
fi
expected_sha256=$(sed -n 's/^expected_sha256=//p' "$ROOT/_static/_www/install")
if ! awk -v version=9.9.9 -f "$ROOT/build/docbuilder.awk" "$ROOT/_static/_www/install" | grep -Fq "expected_sha256=$expected_sha256"; then
    printf '%s\n' 'Ordinary documentation builds rewrite the pinned release checksum.' >&2
    exit 1
fi
release_url=$(sed -n 's/^release_url=//p' "$ROOT/_static/_www/install")
if ! awk -f "$ROOT/build/docbuilder.awk" "$ROOT/_static/_www/install" | grep -Fxq "release_url=$release_url"; then
    printf '%s\n' 'Ordinary documentation builds rewrite the pinned release URL.' >&2
    exit 1
fi
if ! awk -v version=9.9.9 -v sha256=abc123 -f "$ROOT/build/docbuilder.awk" "$ROOT/_static/_www/install" | grep -Fq 'releases/download/v9.9.9/ysh'; then
    printf '%s\n' 'Installer download URL is not generated from the release version.' >&2
    exit 1
fi

CACHE_KEY=$(sed -n 's|.*css/style\.css?\(v=[0-9.][0-9.]*\).*|\1|p' "$ROOT/_static/_www/index.html" | head -n 1)
if [ -z "$CACHE_KEY" ]; then
    printf '%s\n' 'Homepage no longer carries a stylesheet cache key (css/style.css?v=...).' >&2
    exit 1
fi
if ! grep -Fq "css/style.css?$CACHE_KEY" "$STORY/index.html"; then
    printf 'Story stylesheet cache key does not match the homepage key %s.\n' "$CACHE_KEY" >&2
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

# Content tripwires (moved from test/test.sh): retired copy, layouts, and
# release-specific artifacts must not return, and required copy must stay.
if ! grep -Fq 'One POSIX shell file' "$STORY/index.html"; then
    printf '%s\n' 'Story page lost its "One POSIX shell file" framing.' >&2
    exit 1
fi
if grep -Fq 'story-timeline' "$STORY/index.html"; then
    printf '%s\n' 'Story page reintroduced the retired story-timeline layout.' >&2
    exit 1
fi
if grep -Fq 'releases/tag/' "$STORY/index.html"; then
    printf '%s\n' 'Story page links to a release tag again.' >&2
    exit 1
fi
if grep -Fq 'YAML.sh v1.17' "$STORY/index.html"; then
    printf '%s\n' 'Story page hardcodes a release version.' >&2
    exit 1
fi
if grep -Fq 'class="cursor"' "$ROOT/_static/_www/index.html"; then
    printf '%s\n' 'Homepage reintroduced the retired cursor animation.' >&2
    exit 1
fi
if grep -Fq 'A real parser this time' "$ROOT/_static/_www/index.html"; then
    printf '%s\n' 'Homepage reintroduced retired tagline copy.' >&2
    exit 1
fi
if grep -Fq 'transform: rotate(1.25deg)' "$ROOT/_static/_www/css/style.css"; then
    printf '%s\n' 'Stylesheet reintroduced the retired rotated-card transform.' >&2
    exit 1
fi
if ! grep -Fq '/docs/docs.css' "$PUBLISHED/index.html" ||
    ! grep -Fq '/docs/docs.js' "$PUBLISHED/index.html"; then
    printf '%s\n' 'Documentation index lost its generated docs.css or docs.js link.' >&2
    exit 1
fi
if ! grep -Fq 'brand/hero.svg' "$ROOT/README.md"; then
    printf '%s\n' 'README no longer shows the evergreen hero image.' >&2
    exit 1
fi
if ! grep -Fq 'og.png' "$ROOT/_static/_www/index.html"; then
    printf '%s\n' 'Homepage no longer references the social preview image.' >&2
    exit 1
fi
if ! grep -Fq '# Operator reference' "$SOURCE/operators.md" ||
    ! grep -Fq 'array_to_map' "$SOURCE/operators.md" ||
    ! grep -Fq 'split_doc' "$SOURCE/operators.md"; then
    printf '%s\n' 'Operator reference lost its heading or a portable operator entry.' >&2
    exit 1
fi
if grep -Fq 'testExpression' "$SOURCE/operators.md"; then
    printf '%s\n' 'Operator reference leaks internal test function names.' >&2
    exit 1
fi
if ! grep -Fq '# Validate, patch & convert' "$SOURCE/contracts.md"; then
    printf '%s\n' 'Contracts page lost its heading.' >&2
    exit 1
fi
if ! grep -Fq '# YAML support' "$SOURCE/yaml-support.md"; then
    printf '%s\n' 'YAML support page lost its heading.' >&2
    exit 1
fi
if grep -Fq 'Date/time, XML' "$SOURCE/yaml-support.md"; then
    printf '%s\n' 'YAML support page reintroduced retired capability copy.' >&2
    exit 1
fi
OPERATOR_TAB=$(printf '\t')
if ! grep -Fq "operator${OPERATOR_TAB}Array to map${OPERATOR_TAB}supported" "$ROOT/test/operator-manifest.tsv" ||
    ! grep -Fq "operator${OPERATOR_TAB}Split into documents${OPERATOR_TAB}focused" "$ROOT/test/operator-manifest.tsv"; then
    printf '%s\n' 'Operator manifest lost its portable operator rows.' >&2
    exit 1
fi
if grep -Fq '35/35' "$ROOT/_static/_www/index.html" || grep -Fq '35/35' "$ROOT/README.md"; then
    printf '%s\n' 'A retired 35/35 conformance badge returned.' >&2
    exit 1
fi

if ! grep -Fq '<code>|=</code>' "$PUBLISHED/operators/index.html" ||
    grep -Fq '<td>=<code>' "$PUBLISHED/operators/index.html"; then
    printf '%s\n' 'A pipe inside inline code broke a generated documentation table.' >&2
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

for asset in "$ROOT/_static/_www/brand/hero.svg" "$ROOT/_static/_www/brand/og.svg" "$ROOT/_static/_www/og.png" "$STORY/story.css" "$PUBLISHED/docs.css" "$PUBLISHED/docs.js"; do
    if [ ! -s "$asset" ]; then
        printf 'Missing documentation asset: %s\n' "$asset" >&2
        exit 1
    fi
done

for brand_source in "$ROOT/_static/_www/brand/hero.svg" "$ROOT/_static/_www/brand/og.svg"; do
    if ! grep -Fq 'YAML in shell' "$brand_source" || grep -Eqi 'yq energy|v[0-9]+\.[0-9]+' "$brand_source"; then
        printf 'Brand source is stale or release-specific: %s\n' "$brand_source" >&2
        exit 1
    fi
done

for source in "$GENERATED/index.html" "$STORY/index.html" "$PUBLISHED"/*.html "$PUBLISHED"/*/index.html; do
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
        /) target=$GENERATED/index.html ;;
        /*/) target=$GENERATED${link}index.html ;;
        /*) target=$GENERATED$link ;;
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
# The +1 counts the generated landing index page, which is not in $PAGES.
printf 'Static documentation: %s generated pages, local links, stable anchors, evergreen identity.\n' "$((page_count + 1))"
