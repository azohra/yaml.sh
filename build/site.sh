#!/bin/sh
set -eu

tag=$(sh .release/ysh --version)
[ "$(printf 'answer: 42\n' | sh .release/ysh '.answer')" = 42 ]
if command -v sha256sum >/dev/null 2>&1; then
    (cd .release && sha256sum ysh > ysh.sha256)
else
    (cd .release && shasum -a 256 ysh > ysh.sha256)
fi
sha=$(cut -d' ' -f1 .release/ysh.sha256)
rm -rf .release/site
mkdir -p .release/site
cp -R _static/_www/. .release/site/
YSH_DOCS_OUTPUT="$PWD/.release/site/docs" ./build/docs.sh
find .release/site -name '*.md' -delete
awk -v version="${tag#v}" -v sha256="$sha" -f build/docbuilder.awk _static/_www/install > .release/site/install
awk -v version="${tag#v}" -f build/docbuilder.awk _static/_www/index.html > .release/site/index.html
tar -czf .release/site.tar.gz wrangler.jsonc .release/site
