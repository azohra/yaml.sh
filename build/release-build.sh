#!/usr/bin/env bash
set -euo pipefail
checksum() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
tag=${1:?release-build: a tag is required}
[[ "$tag" =~ ^v(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$ ]] || exit 1
notes="releases/$tag.md"
[ -s "$notes" ] || { echo "release-build: reviewed notes are missing at $notes" >&2; exit 1; }
head -1 "$notes" | grep -Eq "^# YAML[.]sh $tag .+" || { echo 'release-build: notes need a release title and quip' >&2; exit 1; }
make ysh
[ "$(./ysh --version)" = "$tag" ] || { echo 'release-build: version differs from tag' >&2; exit 1; }
sha=$(checksum ysh | cut -d' ' -f1)
grep -Fxq "release_url=https://github.com/azohra/yaml.sh/releases/download/$tag/ysh" _static/_www/install
grep -Fxq "expected_sha256=$sha" _static/_www/install
rm -rf .release
mkdir .release
cp ysh .release/ysh
printf '%s  ysh\n' "$sha" > .release/ysh.sha256
sed '1d' "$notes" > .release/notes.md
# shellcheck disable=SC2016
printf '\n**Artifact SHA-256:** `%s`\n' "$sha" >> .release/notes.md
head -1 "$notes" | sed 's/^# //' > .release/title.txt
