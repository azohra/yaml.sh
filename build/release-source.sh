#!/usr/bin/env bash
set -euo pipefail
tag=${1:?release-source: a tag is required}
[[ "$tag" =~ ^v(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)([.-][0-9A-Za-z.-]+)?$ ]] || { echo 'release-source: invalid release tag' >&2; exit 1; }
git fetch -q origin main
git fetch -q origin "refs/tags/$tag"
sha=$(git rev-parse 'FETCH_HEAD^{commit}')
git merge-base --is-ancestor "$sha" origin/main || { echo 'release-source: tag is outside origin/main' >&2; exit 1; }
[ "$(git rev-parse "refs/tags/$tag")" = "$(git rev-parse FETCH_HEAD)" ] || { echo 'release-source: local and remote tags disagree' >&2; exit 1; }
tag_object=$(git rev-parse "refs/tags/$tag")
[ "$(git cat-file -t "$tag_object")" = tag ] || { echo 'release-source: an annotated signed tag is required' >&2; exit 1; }
verified=$(gh api "repos/azohra/yaml.sh/git/tags/$tag_object" --jq '.verification.verified')
[ "$verified" = true ] || { echo 'release-source: GitHub could not verify the tag signature' >&2; exit 1; }
printf '%s\n' "$sha"
