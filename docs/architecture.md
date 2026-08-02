# Architecture

Chepian Server is a live-build profile targeting Debian 13 (trixie) on amd64. `auto/config` defines a hybrid ISO image, so the generated image supports both BIOS and UEFI boot paths provided by live-build.

The image is a `live` system and includes the text Debian Installer through `--debian-installer live`. The package list deliberately contains server and console tooling only; it does not include a display server, desktop environment, browser, display manager, or graphical installer.

`config/includes.chroot` supplies image-specific files. The `chep` command is an argument-safe Bash frontend for package management. The chroot hook applies hostname, locale, OS metadata link, and SSH configuration. It enables `ssh.service`, prohibits root SSH login without embedding credentials, and sets `multi-user.target` as the default systemd target. The fallback target symlink is only written if `systemctl set-default` cannot do so in the chroot.

## Boot Branding

`assets/chepian-apple.svg` is the editable branding source. `assets/chepian-splash.png` is the tracked ready-to-build 640x480 rendering. It is an original, symmetric whole apple: green on the left, red on the right, with no bite. It is not the Apple Inc. logo and does not use third-party artwork.

For a normal build, `scripts/prepare-branding.sh` validates the ready PNG with `file` and copies it into generated bootloader themes. `rsvg-convert` and `librsvg2-bin` are required only for the explicit `--regenerate` mode. The process is:

```text
assets/chepian-apple.svg --regenerate only--> assets/chepian-splash.png
assets/chepian-splash.png
        -> scripts/prepare-branding.sh
        -> config/bootloaders/isolinux/splash.png  (BIOS/ISOLINUX)
        -> config/bootloaders/grub/splash.png      (UEFI/GRUB)
        -> live-build hybrid ISO
```

The script copies the live-build bootloader templates from `/usr/share/live/build/bootloaders` only into the repository, then replaces product labels while retaining template kernel and initrd commands. It verifies that the ISOLINUX configuration actually contains every Chepian label. It removes a copied `splash.svg` from each generated theme so it cannot replace `splash.png`. The generated `config/bootloaders/` tree is reproducible, ignored by Git, and is never written to `/usr/share/live/build`. BIOS/ISOLINUX is guaranteed the graphical splash. GRUB/UEFI keeps textual branding and bootability even if the installed live-build version has no supported graphical theme directory.

Build artifacts are generated only on a Debian builder. Run `make check` and `sudo ./scripts/build.sh`; branding changes require a full clean rebuild. To regenerate the ready PNG, install `librsvg2-bin` with `sudo apt update` and `sudo apt install -y librsvg2-bin`, then run `make branding-regenerate`. `scripts/build.sh` runs `lb clean`, `lb config`, branding preparation, splash validation, and `lb build` from the repository root. It validates the expected hybrid ISO and writes a versioned ISO plus SHA-256 checksum. `scripts/clean.sh` delegates cleanup to `lb clean --purge` from that same root.
