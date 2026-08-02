#!/bin/sh

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE=$ROOT/_static/_www/docs
DOCS=${YSH_DOCS_OUTPUT:-$SOURCE}
RENDERER=$ROOT/build/docs-page.awk
VERSION=${YSH_DOCS_VERSION:-$(sed -n 's/^YSH_VERSION=//p' "$ROOT/ysh" | head -n 1)}
PAGES='README getting-started recipes queries documents output yq-compatibility supported_yml security migration internals development'

mkdir -p "$DOCS"

description_for() {
    case "$1" in
    README) printf '%s\n' 'Install, query, transform, and understand YAML.sh.' ;;
    getting-started) printf '%s\n' 'Install one file and solve the first YAML task.' ;;
    recipes) printf '%s\n' 'Copyable solutions for configuration work.' ;;
    queries) printf '%s\n' 'Paths, filters, construction, updates, and context.' ;;
    documents) printf '%s\n' 'Work across YAML streams and multiple files.' ;;
    output) printf '%s\n' 'Choose value, JSON, YAML, metadata, AST, or events.' ;;
    yq-compatibility) printf '%s\n' 'The useful overlap with yq and the deliberate boundary.' ;;
    supported_yml) printf '%s\n' 'The exact YAML syntax and behavior covered by tests.' ;;
    security) printf '%s\n' 'Bound hostile input and understand the security model.' ;;
    migration) printf '%s\n' 'Move scripts from the pre-v1 interface.' ;;
    internals) printf '%s\n' 'Follow YAML from source text into the node graph.' ;;
    development) printf '%s\n' 'Build, test, and extend the portable implementation.' ;;
    esac
}

for page in $PAGES; do
    source_file=$SOURCE/$page.md
    if [ "$page" = README ]; then
        slug=index
        output_file=$DOCS/index.html
    else
        slug=$page
        mkdir -p "$DOCS/$slug"
        output_file=$DOCS/$slug/index.html
    fi
    title=$(sed -n 's/^# //p' "$source_file" | head -n 1)
    description=$(description_for "$page")
    awk \
        -v version="$VERSION" \
        -v page_slug="$slug" \
        -v page_title="$title" \
        -v page_description="$description" \
        -f "$RENDERER" "$source_file" > "$output_file"
done

set --
for page in $PAGES; do
    set -- "$@" "$SOURCE/$page.md"
done
awk -f "$ROOT/build/docs-search.awk" "$@" > "$DOCS/search-index.json"

printf 'Generated %s static documentation pages for v%s.\n' "$(printf '%s\n' "$PAGES" | wc -w | tr -d ' ')" "$VERSION"
