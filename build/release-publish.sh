#!/usr/bin/env bash
set -euo pipefail
tag=${1:?release: a tag is required}
[[ "$tag" =~ ^v(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$ ]] || exit 1
[ -z "$(git status --porcelain)" ] || { echo 'release: commit changes first' >&2; exit 1; }
git fetch -q origin main
git fetch -q origin "refs/tags/$tag"
[ "$(git rev-parse 'FETCH_HEAD^{commit}')" = "$(git rev-parse HEAD)" ] || { echo 'release: check out the release tag first' >&2; exit 1; }
git merge-base --is-ancestor HEAD origin/main
mise run build:release -- "$tag"
gh release create "$tag" .release/ysh .release/ysh.sha256 \
  --repo azohra/yaml.sh --verify-tag \
  --title "$(cat .release/title.txt)" --notes-file .release/notes.md
