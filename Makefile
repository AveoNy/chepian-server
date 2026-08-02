.DEFAULT_GOAL := help

.PHONY: help check configure build clean

help:
	@printf '%s\n' 'Chepian Server build targets:' \
		'  make check      Validate project files and shell scripts' \
		'  make configure  Generate live-build configuration' \
		'  make build      Build the ISO (requires root on Debian)' \
		'  make clean      Purge live-build artifacts (requires root on Debian)'

check:
	./scripts/check.sh

configure:
	./auto/config

build:
	./scripts/build.sh

clean:
	./scripts/clean.sh
