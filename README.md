# Chepian Server

> `0.1.1` is the Diagnostics checkpoint after 0.1.0. It remains a minimal server ISO and does not include profiles, bundles, or heavyweight orchestration dependencies.

Chepian Server is a minimal, text-only Debian 13 (trixie) live server ISO for amd64 systems. It supports BIOS and UEFI boot, includes the text Debian Installer, and has no graphical environment.

## Defaults

- Version: `0.1.1`
- Live hostname: `chepian`
- Live user: `chep`
- Primary locale: `en_US.UTF-8`
- Additional locale: `ru_RU.UTF-8`
- SSH: installed and enabled; root SSH login is disabled

## Branding

`assets/chepian-apple.svg` is the editable original branding source. `assets/chepian-splash.png` is the tracked, ready-to-build 640x480 splash image. The image is a minimal, symmetric red-and-green whole apple without a bite, created for Chepian Server. It is not an Apple Inc. logo or a derivative of a third-party trademark.

Normal builds use the ready PNG and do not require `rsvg-convert` or `librsvg2-bin`. After `lb config`, the build copies the stock live-build bootloader templates into the repository, replaces only `syslinux_common/splash.png`, and removes the local `splash.svg`. BIOS/ISOLINUX is guaranteed to use the graphical splash. Generated bootloader files are reproducible and intentionally ignored by Git.

## Build on Debian 13

Run these commands on a Debian 13 amd64 builder, not on Windows:

```sh
sudo apt update
sudo apt install -y live-build shellcheck
git clone https://github.com/AveoNy/chepian-server.git
cd chepian-server
make check
sudo ./scripts/build.sh
```

The build produces `chepian-server-0.1.1-amd64.iso` and its SHA-256 checksum in the repository root.

## Commands

```sh
make help
make check
make branding
make configure
sudo make build
sudo make clean
```

`/usr/bin/chep` is a modular frontend for `apt-get`, `apt-cache`, and `dpkg-query`. For system-changing operations it safely re-executes itself through `sudo`, so `chep install nginx` works for a permitted user. Package installation still always runs with root privileges.

## Doctor

```sh
chep doctor
chep doctor memory
chep doctor security
chep doctor --collect
```

`doctor` reports system, CPU, memory, disk, network, service, and security observations. Exit codes are `0` (OK), `1` (warnings), `2` (failures), and `3` (usage/internal error). `--collect` creates a redacted support archive and never includes shadow files, SSH keys, environment dumps, history, or credentials.

Chep modules are installed below `/usr/lib/chep`: `common.sh`, `package.sh`, and `doctor.sh`. Profiles and bundles are not included in this release.

## Layout

- `auto/`: live-build configuration entry points
- `config/`: packages, image files, and chroot hooks
- `scripts/`: build, cleanup, and validation scripts
- `docs/`: project architecture notes

See [docs/architecture.md](docs/architecture.md) for details.
