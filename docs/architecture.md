# Architecture

Chepian Server is a live-build profile targeting Debian 13 (trixie) on amd64. `auto/config` defines a hybrid ISO image, so the generated image supports both BIOS and UEFI boot paths provided by live-build.

The image is a `live` system and includes the text Debian Installer through `--debian-installer live`. The package list deliberately contains server and console tooling only; it does not include a display server, desktop environment, browser, display manager, or graphical installer.

`config/includes.chroot` supplies image-specific files. The `chep` command is an argument-safe Bash frontend for package management. The chroot hook applies hostname, locale, OS metadata link, and SSH configuration. It enables `ssh.service` and uses an SSH drop-in to prohibit root login without embedding credentials.

Build artifacts are generated only on a Debian builder. `scripts/build.sh` runs the live-build lifecycle from the repository root, validates the expected hybrid ISO, and writes a versioned ISO plus SHA-256 checksum. `scripts/clean.sh` delegates cleanup to `lb clean --purge` from that same root.
