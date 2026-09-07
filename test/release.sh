#!/usr/bin/env bash
set -euo pipefail
checksum() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
for task in build:release deploy; do
    mise tasks info "$task" --json | node -e '
      let data = "";
      process.stdin.on("data", chunk => data += chunk);
      process.stdin.on("end", () => process.stdout.write(JSON.parse(data).run[0]));
    ' > "$scratch/${task//:/-}.sh"
done
mkdir -p "$scratch/repo/_static/_www"
cd "$scratch/repo"
printf '#!/bin/sh\nprintf v1.2.3\n' > ysh
chmod +x ysh
printf 'ysh:; @true\n' > Makefile
sha=$(checksum ysh | cut -d' ' -f1)
printf 'release_url=https://github.com/azohra/yaml.sh/releases/download/v1.2.3/ysh\nexpected_sha256=%s\n' "$sha" > _static/_www/install
printf '# Changelog\n\n## [1.2.3] - 2026-01-01\n\nRelease notes.\n\n## [1.2.2] - 2025-12-01\nOld notes.\n' > CHANGELOG.md
usage_tag=v1.2.3 bash "$scratch/build-release.sh"
(cd .release && checksum -c ysh.sha256)
cmp ysh .release/ysh
grep -Fxq 'Release notes.' .release/notes.md
if grep -Fq 'Old notes.' .release/notes.md; then exit 1; fi
cp CHANGELOG.md "$scratch/changelog"
printf '# Changelog\n' > CHANGELOG.md
if usage_tag=v1.2.3 bash "$scratch/build-release.sh" >/dev/null 2>&1; then exit 1; fi
cp "$scratch/changelog" CHANGELOG.md
if usage_tag=v1.2.4 bash "$scratch/build-release.sh" >/dev/null 2>&1; then exit 1; fi
printf 'bad checksum\n' >> ysh
if usage_tag=v1.2.3 bash "$scratch/build-release.sh" >/dev/null 2>&1; then exit 1; fi
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
cat > "$scratch/bin/git" <<'GIT'
#!/bin/sh
[ "$1" != rev-parse ] || echo fixture
GIT
printf '#!/bin/sh\nexit 0\n' > "$scratch/bin/mise"
# shellcheck disable=SC2016
printf '#!/bin/sh\ntouch "$DEPLOY_TEST_CALL"\n' > "$scratch/bin/wrangler"
chmod +x "$scratch/bin/"*
export CLOUDFLARE_API_TOKEN=fixture DEPLOY_TEST_CALL="$scratch/deployed"
if PATH="$scratch/bin:$PATH" bash "$scratch/deploy.sh" >/dev/null 2>&1; then exit 1; fi
[ ! -e "$DEPLOY_TEST_CALL" ]
export DEPLOY_TEST_ASSET="$PWD/.release/ysh"
# shellcheck disable=SC2016
sed 's/printf bad > "$1"/cp "$DEPLOY_TEST_ASSET" "$1"/' "$scratch/bin/curl" > "$scratch/curl"
cp "$scratch/curl" "$scratch/bin/curl"
PATH="$scratch/bin:$PATH" bash "$scratch/deploy.sh"
[ -e "$DEPLOY_TEST_CALL" ]
echo 'Release build, changelog selection, and installer failure boundaries passed'
