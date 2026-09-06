#!/usr/bin/env bash
set -euo pipefail
checksum() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/repo/_static/_www" "$scratch/repo/releases"
cd "$scratch/repo"
printf '#!/bin/sh\nprintf v1.2.3\n' > ysh
chmod +x ysh
printf 'ysh:; @true\n' > Makefile
sha=$(checksum ysh | cut -d' ' -f1)
printf 'release_url=https://github.com/azohra/yaml.sh/releases/download/v1.2.3/ysh\nexpected_sha256=%s\n' "$sha" > _static/_www/install
printf '# YAML.sh v1.2.3 — example\n\nReviewed notes.\n' > releases/v1.2.3.md
bash "$root/build/release-build.sh" v1.2.3
(cd .release && checksum -c ysh.sha256)
cmp ysh .release/ysh
if bash "$root/build/release-build.sh" v1.2.4 >/dev/null 2>&1; then exit 1; fi
printf 'bad checksum\n' >> ysh
if bash "$root/build/release-build.sh" v1.2.3 >/dev/null 2>&1; then exit 1; fi
# A corrupt or missing hosted artifact must stop deployment.
mkdir "$scratch/bin"
cat > "$scratch/bin/curl" <<'CURL'
#!/bin/sh
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then shift; printf bad > "$1"; exit; fi
  shift
done
exit 1
CURL
chmod +x "$scratch/bin/curl"
if PATH="$scratch/bin:$PATH" bash "$root/build/release-consumer.sh" >/dev/null 2>&1; then exit 1; fi
echo 'Release build and installer failure boundaries passed'
