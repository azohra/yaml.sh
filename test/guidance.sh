#!/bin/sh
# Guidance documents make checkable claims about the repository. This gate
# fails when a named make target, path, link, version, or provenance claim
# no longer matches reality, so the guidance cannot silently rot.

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

status=0
GUIDANCE='AGENTS.md CLAUDE.md CONTRIBUTING.md VERSIONING.md _static/_www/docs/development.md'

# Every `make target` named in guidance must exist in the Makefile.
for doc in $GUIDANCE; do
    grep -oE 'make [a-z][a-z-]*' "$doc" | sort -u | while IFS= read -r reference; do
        target=${reference#make }
        if ! grep -Eq "^$target:" Makefile; then
            printf 'Stale make target in %s: %s\n' "$doc" "$reference" >&2
            exit 1
        fi
    done || status=1
done

# Every repo path named in backticks must exist; globs must match something.
for doc in $GUIDANCE; do
    grep -o '`[^`]*`' "$doc" | tr -d '`' | sort -u | while IFS= read -r candidate; do
        case "$candidate" in
        /*|-*|*' '*|*'('*|*'$'*|*'='*) continue ;;
        */*|*.md|*.tsv|*.sh|*.awk) ;;
        *) continue ;;
        esac
        # Intentional glob expansion so documented patterns count as matched.
        # shellcheck disable=SC2086
        set -- $candidate
        if [ ! -e "$1" ]; then
            printf 'Stale path in %s: %s\n' "$doc" "$candidate" >&2
            exit 1
        fi
    done || status=1
done

# Local markdown links in root documents must resolve.
for doc in AGENTS.md CLAUDE.md CONTRIBUTING.md VERSIONING.md DESIGN.md README.md; do
    grep -oE '\]\([^)#]+\)' "$doc" | sed 's/^](//; s/)$//' | sort -u | while IFS= read -r link; do
        case "$link" in
        http://*|https://*|mailto:*) continue ;;
        esac
        if [ ! -e "$link" ]; then
            printf 'Broken local link in %s: %s\n' "$doc" "$link" >&2
            exit 1
        fi
    done || status=1
done

# CLAUDE.md must keep importing the shared agent guidance.
if ! grep -q '^@AGENTS.md$' CLAUDE.md; then
    printf '%s\n' 'CLAUDE.md no longer imports AGENTS.md' >&2
    status=1
fi

# The release version must appear everywhere the checklist says it does.
VERSION=$(sed -n 's/^YSH_VERSION=//p' src/ysh.sh | head -n 1)
if [ -z "$VERSION" ]; then
    printf '%s\n' 'src/ysh.sh no longer defines YSH_VERSION' >&2
    status=1
else
    assertions=$(grep -cF "v$VERSION" test/test.sh || :)
    if [ "$assertions" -ne 3 ]; then
        printf 'VERSIONING.md promises three version assertions in test/test.sh; found %s for v%s\n' "$assertions" "$VERSION" >&2
        status=1
    fi
    if ! grep -qF "## [$VERSION]" CHANGELOG.md; then
        printf 'CHANGELOG.md has no entry for the current version %s\n' "$VERSION" >&2
        status=1
    fi
fi

# Every versioned changelog heading needs its compare-link definition.
grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '#[] ' | sort -u | while IFS= read -r entry; do
    if ! grep -q "^\[$entry\]: http" CHANGELOG.md; then
        printf 'CHANGELOG heading %s has no link definition\n' "$entry" >&2
        exit 1
    fi
done || status=1

# The recorded shunit2 provenance must match the vendored copy.
shunit_version=$(sed -n "s/^SHUNIT_VERSION='\(.*\)'\$/\1/p" test/shunit2)
if [ -z "$shunit_version" ] || ! grep -qF "$shunit_version" _static/_www/docs/development.md; then
    printf '%s\n' 'development.md records a stale shunit2 version' >&2
    status=1
fi

# Guidance names this test as the expected mid-development failure.
if ! grep -q 'testReleaseArtifactsStayInSync()' test/test.sh; then
    printf '%s\n' 'Guidance references testReleaseArtifactsStayInSync, which no longer exists' >&2
    status=1
fi

if [ "$status" -ne 0 ]; then
    exit 1
fi
printf '%s\n' 'Guidance: make targets, paths, links, versions, and provenance verified.'
