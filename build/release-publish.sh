#!/usr/bin/env bash
set -euo pipefail
checksum() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
tag=${1:?release-publish: a tag is required}
refuse() { echo "release: refusing — $*" >&2; exit 1; }
[ "$(gh repo view --json nameWithOwner --jq .nameWithOwner)" = azohra/yaml.sh ] || refuse 'unexpected repository'
[ -z "$(git status --porcelain)" ] || refuse 'dirty tree'
[ "$(bash build/release-source.sh "$tag")" = "$(git rev-parse HEAD)" ] || refuse 'tag is not HEAD'
[ "$(.release/ysh --version)" = "$tag" ] || refuse 'artifact version differs from tag'
(cd .release && checksum -c ysh.sha256)
assets=(.release/ysh .release/ysh.sha256)
existing_draft=""
release_view_error=$(mktemp)
if existing_draft=$(gh release view "$tag" --json isDraft --jq .isDraft 2>"$release_view_error"); then
  rm -f "$release_view_error"
  [ "$existing_draft" = "true" ] || refuse "release $tag is already published"
else
  if ! grep -Eiq 'not found|HTTP 404|status 404' "$release_view_error"; then
    detail=$(tr '\n' ' ' <"$release_view_error")
    rm -f "$release_view_error"
    refuse "could not inspect release $tag${detail:+: $detail}"
  fi
  rm -f "$release_view_error"
  gh release create "$tag" --draft --notes-file .release/notes.md --title "$(cat .release/title.txt)" --verify-tag
fi
gh release upload "$tag" "${assets[@]}" --clobber
published_assets=$(gh release view "$tag" --json assets --jq '.assets[].name') || refuse "could not read uploaded assets"
for asset in "${assets[@]}"; do
  asset_name=${asset##*/}
  grep -Fxq "$asset_name" <<<"$published_assets" || refuse "release is missing uploaded asset $asset_name"
done
download=$(mktemp -d)
trap 'rm -rf "$download"' EXIT
gh release download "$tag" --pattern ysh --pattern ysh.sha256 --dir "$download"
cmp .release/ysh "$download/ysh"
cmp .release/ysh.sha256 "$download/ysh.sha256"
gh release edit "$tag" --draft=false
published_state=$(gh release view "$tag" --json isDraft --jq .isDraft) || refuse "could not verify published release"
[ "$published_state" = "false" ] || refuse "release $tag is still a draft"
