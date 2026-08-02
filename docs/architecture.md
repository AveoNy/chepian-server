# Architecture

Chepian Server is a live-build profile targeting Debian 13 (trixie) on amd64. `auto/config` defines a hybrid ISO image, so the generated image supports both BIOS and UEFI boot paths provided by live-build.

The image is a `live` system and includes the text Debian Installer through `--debian-installer live`. The package list deliberately contains server and console tooling only; it does not include a display server, desktop environment, browser, display manager, or graphical installer.

`config/includes.chroot` supplies image-specific files. The 0.1.1 `chep` dispatcher loads only the needed modules from `/usr/lib/chep`: `common.sh` provides safe output, elevation, temporary-directory, and formatting helpers; `package.sh` provides apt/dpkg commands; and `doctor.sh` provides read-only diagnostics. The chroot hook applies hostname, locale, OS metadata link, and SSH configuration. It enables `ssh.service`, prohibits root SSH login without embedding credentials, and sets `multi-user.target` as the default systemd target.

`chep doctor` reports safe observations for system, CPU, memory, disk, network, services, and security. Its exit status is `0` for OK, `1` for warnings, `2` for failures, and `3` for usage or internal errors. `chep doctor --collect` writes an allowlisted, redacted archive. It excludes `/etc/shadow`, private keys, shell history, full environments, and credentials; key/value lines with password, token, secret, authorization, or API-key names are redacted.

## Boot Branding

`assets/chepian-apple.svg` is the editable branding source. `assets/chepian-splash.png` is the tracked ready-to-build 640x480 rendering. It is an original, symmetric whole apple: green on the left, red on the right, with no bite. It is not the Apple Inc. logo and does not use third-party artwork.

For a normal build, `scripts/prepare-branding.sh` validates the ready PNG with `file`, clears only the generated local bootloader directory, copies the stock live-build templates into it, and replaces `syslinux_common/splash.png`. The process is:

```text
assets/chepian-splash.png
        -> scripts/prepare-branding.sh
        -> config/bootloaders/syslinux_common/splash.png  (BIOS/ISOLINUX)
        -> live-build hybrid ISO
```

The script copies the live-build bootloader templates from `/usr/share/live/build/bootloaders` only into the repository. It removes the local `syslinux_common/splash.svg` so it cannot replace `splash.png`, but does not inspect or require exact boot-menu text. The generated `config/bootloaders/` tree is reproducible, ignored by Git, and is never written to `/usr/share/live/build`. BIOS/ISOLINUX is guaranteed the graphical splash.

Build artifacts are generated only on a Debian builder. Run `make check` and `sudo ./scripts/build.sh`; branding changes require a full clean rebuild. `scripts/build.sh` runs `lb clean --purge`, `lb config`, branding preparation, and `lb build` from the repository root. It validates the expected hybrid ISO and writes a versioned ISO plus SHA-256 checksum. `scripts/clean.sh` delegates cleanup to `lb clean --purge` from that same root.

## Diagnostics Checkpoint

Chepian Server `0.1.1` is a diagnostics checkpoint after 0.1.0. `/usr/bin/chep` is a small dispatcher: it loads `common.sh` for common safety helpers, `package.sh` for apt/dpkg operations, and `doctor.sh` for diagnostics only when needed. `CHEP_LIB_DIR` lets the test suite load these modules from the source tree. Profiles, bundles, offline repositories, and heavyweight orchestration dependencies are intentionally not included.

`chep doctor` performs read-only system, CPU, memory, disk, network, service, and security checks. It returns `0` for OK, `1` for warnings, `2` for failures, and `3` for invalid use or internal errors. Collection is allowlisted and redacts key/value data containing password, passwd, token, secret, authorization, api_key, or apikey. It does not collect shadow content, private keys, shell history, complete environments, or credentials. Profiles and bundles are intentionally out of scope for this release.
