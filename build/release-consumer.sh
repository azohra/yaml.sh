#!/usr/bin/env bash
set -euo pipefail
checksum() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
installer=_static/_www/install
url=$(sed -n 's/^release_url=//p' "$installer")
expected=$(sed -n 's/^expected_sha256=//p' "$installer")
[[ "$url" =~ ^https://github.com/azohra/yaml[.]sh/releases/download/v[0-9]+[.][0-9]+[.][0-9]+/ysh$ ]] || exit 1
[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || exit 1
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
curl --fail --silent --show-error --location --retry 3 "$url" -o "$scratch/ysh"
actual=$(checksum "$scratch/ysh" | cut -d' ' -f1)
[ "$actual" = "$expected" ] || { echo 'release: installer does not match the published asset' >&2; exit 1; }
echo 'Installer release asset and checksum verified'
