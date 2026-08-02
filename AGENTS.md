# Repository Guidelines

- Do not run `sudo` on Windows.
- Do not run destructive disk commands, including partitioning, formatting, or raw-device writes.
- Do not modify files outside this repository.
- Do not add passwords, private keys, tokens, or other secrets.
- Do not commit ISO files, live-build output, caches, or chroots.
- Do not perform `git commit` or `git push` automatically.
- Build this project only on a supported Debian builder. Do not run `live-build`, `debootstrap`, or Linux build commands on Windows.
