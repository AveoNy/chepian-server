# Repository Guidelines

- OpenCode runs on Windows and must not run `sudo`, `live-build`, `debootstrap`, QEMU, or Linux build commands there.
- Generate a replacement PNG branding asset only on the Debian builder.
- Branding consists of editable `assets/chepian-apple.svg` and tracked ready-to-build `assets/chepian-splash.png`. The logo must remain an original, symmetric red-and-green apple without a bite.
- Do not use the Apple Inc. logo or download third-party logos.
- Do not modify `/usr/share/live/build`; copy templates only into this repository.
- Do not run destructive disk commands, including partitioning, formatting, or raw-device writes.
- Do not modify files outside this repository.
- Do not add passwords, private keys, tokens, or other secrets.
- Chep doctor collection must remain allowlisted and redact credentials; do not add profiles or bundles in the 0.1.1 Diagnostics release.
- Do not commit ISO files, live-build output, caches, or chroots.
- Do not perform `git commit` or `git push` automatically.
- Run `scripts/check.sh` after changes. After branding changes, perform a full clean ISO rebuild on the Debian builder.
