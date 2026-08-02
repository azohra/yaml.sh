BUILDERS = $(shell find build/*)
INSTALL_DIR=/usr/local/bin

.PHONY: lint test conformance differential all install uninstall docs clean

all: ysh lint test

ysh: src/ysh.sh src/ysh.awk Makefile $(BUILDERS)
	@echo "👷 Building"
	@awk -f build/shbuilder.awk src/ysh.sh > ysh
	@chmod 755 ysh

lint: ysh
	@echo "👖 Linting"
	@shellcheck -e SC2016 ysh test/test.sh test/conformance.sh test/differential.sh _static/_www/install

test: ysh
	@echo "🔬 Testing"
	@./test/test.sh

conformance: ysh
	@echo "🧭 Measuring YAML conformance"
	@./test/conformance.sh

differential: ysh
	@echo "⚖️  Comparing with yq"
	@./test/differential.sh

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
	@awk -v version=$(VERSION) -f build/docbuilder.awk README.md > .tmp_README.md
	@mv .tmp_README.md README.md
	@awk -v version=$(VERSION) -f build/docbuilder.awk _static/_www/install > .tmp_install
	@mv .tmp_install _static/_www/install
	@chmod 755 _static/_www/install

clean:
	@rm -f ysh
