.PHONY: lint test all install
all: ysh lint test

ysh: src/ysh.sh src/ysh.awk
	@echo "👷 Building"
	@awk -f build/builder.awk src/ysh.sh > ysh
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
