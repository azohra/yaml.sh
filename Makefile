.PHONY: all perms test build strap docs integrity

all: exec test build docs integrity

exec:
	@chmod u+x *.sh
	@chmod u+x build/*.sh
	@chmod u+x straps/**/*.sh

test:
	@shellcheck ./strapped.sh
	@shellcheck ./straps/**/*.sh
	@shellcheck ./build/*.sh

docs:
	@./build/docs.sh

integrity:
	@./build/integrity.sh

strap:
	@./build/compiler.sh $(yml)
