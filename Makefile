BUILDERS = $(shell find build/*)

.PHONY: lint test all install uninstall docs

all: ysh lint test

ysh: src/ysh.sh src/ysh.awk Makefile $(BUILDERS)
	@echo "👷 Building"
	@awk -f build/shbuilder.awk src/ysh.sh > ysh
	@chmod u+x ysh

lint: ysh
	@echo "👖 Linting"
	@shellcheck -e SC2016 ysh

test: ysh
	@echo "🔬 Testing"
	@./test/test.sh

install: ysh
	@echo "📦 Installing ysh"
	@cp ysh /usr/local/bin/ysh
	@chmod u+x /usr/local/bin/ysh

uninstall:
	@echo "🗑️  Uninstalling ysh"
	@rm /usr/local/bin/ysh

docs: ysh
	@echo "📚 Updating docs"
	$(eval VERSION := $(shell grep "YSH_version=" ysh | sed "s/YSH_version='//" | sed "s/'$$//"))
	@awk -v version=$(VERSION) -f build/docbuilder.awk README.md > .tmp_README.md
	@mv .tmp_README.md README.md
	@awk -v version=$(VERSION) -f build/docbuilder.awk _static/_get/index.html > .tmp_index.html
	@mv .tmp_index.html _static/_get/index.html
