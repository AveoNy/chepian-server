.DEFAULT_GOAL := help

.PHONY: help check branding branding-regenerate configure build clean

help:
	@printf '%s\n' 'Chepian Server build targets:' \
		'  make check      Validate project files and shell scripts' \
		'  make branding   Prepare bootloader themes from the ready PNG' \
		'  make branding-regenerate  Regenerate the ready PNG from SVG on Debian' \
		'  make configure  Generate live-build configuration' \
		'  make build      Build the ISO (requires root on Debian)' \
		'  make clean      Purge live-build artifacts (requires root on Debian)'

check:
	./scripts/check.sh

branding:
	./scripts/prepare-branding.sh

branding-regenerate:
	./scripts/prepare-branding.sh --regenerate

configure:
	./auto/config

build:
	./scripts/build.sh

clean:
	./scripts/clean.sh
