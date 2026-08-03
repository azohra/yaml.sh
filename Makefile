BUILDERS = $(shell find build/*)
INSTALL_DIR=/usr/local/bin

.PHONY: lint test docs-check operator-manifest conformance toml-conformance schema-conformance json-patch-conformance differential fuzz presentation parser-boundaries adversarial benchmark scale all install uninstall docs clean

all: ysh lint test docs-check

ysh: src/ysh.sh src/ysh.awk src/diff.awk Makefile $(BUILDERS)
	@echo "👷 Building"
	@awk -f build/shbuilder.awk src/ysh.sh > ysh
	@chmod 755 ysh

lint: ysh
	@echo "👖 Linting"
	@shellcheck -e SC2016 ysh build/docs.sh test/docs.sh test/test.sh test/workflows.sh test/operator-manifest.sh test/conformance.sh test/toml-conformance.sh test/schema-conformance.sh test/json-patch-conformance.sh test/toml-test-decoder test/toml-test-encoder test/differential.sh test/generate-yq-corpus.sh test/fuzz.sh test/presentation-matrix.sh test/parser-boundaries.sh test/adversarial.sh test/fault-bin/mv bench/benchmark.sh bench/scale.sh _static/_www/install

test: ysh
	@echo "🔬 Testing"
	@./test/test.sh
	@./test/workflows.sh
	@./test/parser-boundaries.sh

docs-check: ysh
	@echo "📚 Checking static documentation"
	@./test/docs.sh
	@./test/operator-manifest.sh

operator-manifest: ysh
	@echo "🧾 Auditing the operator surface"
	@./test/operator-manifest.sh

conformance: ysh
	@echo "🧭 Measuring YAML conformance"
	@./test/conformance.sh

toml-conformance: ysh
	@echo "🍅 Measuring TOML 1.0 conformance"
	@./test/toml-conformance.sh

schema-conformance: ysh
	@echo "📐 Measuring JSON Schema 2020-12 focused conformance"
	@./test/schema-conformance.sh

json-patch-conformance: ysh
	@echo "🩹 Measuring RFC 6902 conformance"
	@./test/json-patch-conformance.sh

differential: ysh
	@echo "⚖️  Comparing with yq"
	@./test/differential.sh

fuzz: ysh
	@echo "🧬 Running deterministic properties"
	@./test/fuzz.sh

presentation: ysh
	@echo "🎨 Exercising presentation mutations"
	@./test/presentation-matrix.sh

parser-boundaries: ysh
	@echo "🚧 Auditing parser boundaries"
	@./test/parser-boundaries.sh

adversarial: ysh
	@echo "🛡️  Exercising resource limits"
	@./test/adversarial.sh

benchmark: ysh
	@echo "⏱️  Measuring parser and query throughput"
	@./bench/benchmark.sh

scale: ysh
	@echo "📏 Verifying the scale contract"
	@./bench/scale.sh

install: ysh
	@echo "📦 Installing ysh"
	@mkdir -p $(INSTALL_DIR)
	@cp ysh $(INSTALL_DIR)/ysh
	@chmod u+x $(INSTALL_DIR)/ysh

uninstall:
	@echo "🗑️  Uninstalling ysh"
	@rm -f $(INSTALL_DIR)/ysh

docs: ysh
	@echo "📚 Updating docs"
	$(eval VERSION := $(shell sed -n 's/^YSH_VERSION=//p' ysh | head -n 1))
	$(eval RELEASE_SHA256 := $(shell if command -v sha256sum >/dev/null 2>&1; then sha256sum ysh | sed 's/ .*//'; else shasum -a 256 ysh | sed 's/ .*//'; fi))
	@awk -v version=$(VERSION) -f build/docbuilder.awk README.md > .tmp_README.md
	@mv .tmp_README.md README.md
	@awk -v version=$(VERSION) -v sha256=$(RELEASE_SHA256) -f build/docbuilder.awk _static/_www/install > .tmp_install
	@mv .tmp_install _static/_www/install
	@chmod 755 _static/_www/install
	@awk -v version=$(VERSION) -f build/docbuilder.awk _static/_www/index.html > .tmp_index.html
	@mv .tmp_index.html _static/_www/index.html
	@./build/docs.sh

clean:
	@rm -f ysh
