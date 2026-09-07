#!/usr/bin/env bash
set -euo pipefail
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
for task in build:release build:site changelog release deploy; do
    mise tasks info "$task" --json | node -e '
      let data = "";
      process.stdin.on("data", chunk => data += chunk);
      process.stdin.on("end", () => process.stdout.write(JSON.parse(data).run[0]));
    ' > "$scratch/${task//:/-}.sh"
done
mkdir -p "$scratch/repo/src" "$scratch/repo/build" "$scratch/repo/_static/_www" "$scratch/published"
cp cliff.toml "$scratch/repo/"
cp build/shbuilder.awk build/docbuilder.awk "$scratch/repo/build/"
cp _static/_www/install _static/_www/index.html "$scratch/repo/_static/_www/"
cd "$scratch/repo"
cat > src/ysh.sh <<'SOURCE'
#!/bin/sh
YSH_VERSION=dev
if [ "$1" = --version ]; then printf 'v%s\n' "$YSH_VERSION"; else printf '42\n'; fi
SOURCE
cat > Makefile <<'MAKE'
.PHONY: .release/ysh
.release/ysh:
	@mkdir -p .release
	@awk -v release_version="$(RELEASE_VERSION)" -f build/shbuilder.awk src/ysh.sh > $@
MAKE
# shellcheck disable=SC2016
printf '#!/bin/sh\nmkdir -p "$YSH_DOCS_OUTPUT"\n' > build/docs.sh
chmod +x build/docs.sh
printf '# Changelog\n\n## [1.2.3]\n\nHistorical notes stay intact.\n\n[1.2.3]: https://example.invalid/history\n' > CHANGELOG.md
printf '.release/\n' > .gitignore
git init -q
git config user.name 'Release fixture'
git config user.email 'release@example.invalid'
git config commit.gpgsign false
git add .
git commit -qm 'feat: initial version'
git tag v1.2.3
git remote add origin "$PWD"
make .release/ysh RELEASE_VERSION=1.2.3
cp .release/ysh "$scratch/published/ysh"
(cd "$scratch/published" && shasum -a 256 ysh > ysh.sha256)
printf v1.2.3 > "$scratch/published-tag"
export RELEASE_TASK_FIXTURE="$scratch"
# Invoke the repository's task bodies; replace only external publication.
mise() {
    case "$2" in
        changelog) usage_release="$([ "${4:-}" != --release ] || printf true)" bash "$RELEASE_TASK_FIXTURE/changelog.sh" ;;
        build:release) bash "$RELEASE_TASK_FIXTURE/build-release.sh" ;;
        build:site) usage_tag="$4" usage_assets="$5" bash "$RELEASE_TASK_FIXTURE/build-site.sh" ;;
        *) return 1 ;;
    esac
}
gh() {
    case "$2" in
        view) cat "$RELEASE_TASK_FIXTURE/published-tag" ;;
        download)
            while [ "$1" != --dir ]; do shift; done
            cp "$RELEASE_TASK_FIXTURE/published/"* "$2/" ;;
        create)
            [ "${RELEASE_FAIL_PUBLISH:-false}" != true ] || return 1
            printf '%s\n' "$*" >> "$RELEASE_TASK_FIXTURE/publication"
            cp .release/ysh .release/ysh.sha256 "$RELEASE_TASK_FIXTURE/published/"
            printf '%s' "$3" > "$RELEASE_TASK_FIXTURE/published-tag"
            git tag "$3" ;;
        *) return 1 ;;
    esac
}
wrangler() { printf '%s\n' "$*" >> "$RELEASE_TASK_FIXTURE/deployment"; }
export -f mise gh wrangler
# A website-only change deploys against the existing release, with no release.
git commit --allow-empty -qm 'docs: explain installation' -m 'Example text:

feat: add a hypothetical operator'
git update-ref refs/heads/main HEAD
bash "$scratch/release.sh"
[ ! -e "$scratch/publication" ]
usage_release=true bash "$scratch/changelog.sh" > "$scratch/maintenance-notes"
[ "$(grep -Fc '## [1.2.3]' "$scratch/maintenance-notes")" = 1 ]
grep -Fq '## Unreleased' "$scratch/maintenance-notes"
if bash "$scratch/build-release.sh" >/dev/null 2>&1; then exit 1; fi
usage_dry_run=true bash "$scratch/deploy.sh"
grep -Fq 'releases/download/v1.2.3/ysh' .release/site/install
grep -Fq 'data-ysh-version>v1.2.3' .release/site/index.html
grep -Fq -- '--dry-run' "$scratch/deployment"
[ -z "$(git status --porcelain)" ]
# A release keeps notes concise and links the full reviewed explanation.
git commit --allow-empty -qm 'fix: retain empty values' -m 'Keep empty values in their original positions.'
git update-ref refs/heads/main HEAD
# Used by the release task in a child shell.
# shellcheck disable=SC2329
make() { return 1; }
export -f make
if bash "$scratch/release.sh" >/dev/null 2>&1; then exit 1; fi
unset -f make
[ ! -e "$scratch/publication" ]
usage_dry_run=true bash "$scratch/release.sh"
[ ! -e "$scratch/publication" ]
[ "$(sh .release/ysh --version)" = v1.2.4 ]
grep -Fq 'retain empty values' .release/notes.md
if grep -Fq 'Keep empty values in their original positions.' .release/notes.md; then exit 1; fi
grep -Fq "https://github.com/azohra/yaml.sh/commit/$(git rev-parse HEAD)" .release/notes.md
cp .release/ysh "$scratch/first-ysh"
cp .release/notes.md "$scratch/first-notes"
usage_dry_run=true bash "$scratch/release.sh"
cmp .release/ysh "$scratch/first-ysh"
cmp .release/notes.md "$scratch/first-notes"
[ -z "$(git status --porcelain)" ]
# Publication failure leaves the installer on the last successful release.
if RELEASE_FAIL_PUBLISH=true bash "$scratch/release.sh"; then exit 1; fi
bash "$scratch/deploy.sh"
grep -Fq 'releases/download/v1.2.3/ysh' .release/site/install
bash "$scratch/release.sh"
grep -Fq -- "--target $(git rev-parse HEAD)" "$scratch/publication"
bash "$scratch/build-release.sh"
cmp .release/ysh "$scratch/first-ysh"
cmp .release/notes.md "$scratch/first-notes"
bash "$scratch/deploy.sh"
grep -Fq 'releases/download/v1.2.4/ysh' .release/site/install
# Run the generated installer with a local download stand-in.
curl() { cp "$RELEASE_TASK_FIXTURE/published/ysh" "$4"; }
export -f curl
YSH_INSTALL_DIR="$scratch/installed" bash .release/site/install
cmp "$scratch/installed/ysh" "$scratch/published/ysh"
# Bad published bytes cannot reach a new deployment or replace an installation.
printf broken >> "$scratch/published/ysh"
cp "$scratch/deployment" "$scratch/previous-deployment"
if bash "$scratch/deploy.sh" >/dev/null 2>&1; then exit 1; fi
cmp "$scratch/deployment" "$scratch/previous-deployment"
if YSH_INSTALL_DIR="$scratch/installed" bash .release/site/install >/dev/null 2>&1; then exit 1; fi
cmp "$scratch/installed/ysh" "$scratch/first-ysh"
# Subsequent releases retain generated history as well as the original archive.
git commit --allow-empty -qm 'feat: add a query operator'
[ "$(git cliff --offline --unreleased --bumped-version)" = v1.3.0 ]
bash "$scratch/build-release.sh"
grep -Fq '## [1.2.4]' .release/CHANGELOG.md
grep -Fq 'retain empty values' .release/CHANGELOG.md
grep -Fq 'Historical notes stay intact.' .release/CHANGELOG.md
git commit --allow-empty -qm 'refactor: remove the old argument' -m 'BREAKING CHANGE: use --input instead of --file.'
[ "$(git cliff --offline --unreleased --bumped-version)" = v2.0.0 ]
bash "$scratch/build-release.sh"
grep -Fq 'use --input instead of --file.' .release/notes.md
git tag v2.0.0
git commit --allow-empty -qm 'chore!: remove a supported host'
[ "$(git cliff --offline --unreleased --bumped-version)" = v3.0.0 ]
echo 'Release, website, installer, and failure boundaries passed'
