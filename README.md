# Chepian Server

Chepian Server is a minimal, text-only Debian 13 (trixie) live server ISO for amd64 systems. It supports BIOS and UEFI boot, includes the text Debian Installer, and has no graphical environment.

## Defaults

- Version: `0.1.0`
- Live hostname: `chepian`
- Live user: `chep`
- Primary locale: `en_US.UTF-8`
- Additional locale: `ru_RU.UTF-8`
- SSH: installed and enabled; root SSH login is disabled

## Build on Debian 13

Run these commands on a Debian 13 amd64 builder, not on Windows:

```sh
apt-get update
apt-get install -y live-build shellcheck
git clone https://github.com/AveoNy/chepian-server.git
cd chepian-server
make check
sudo make build
```

The build produces `chepian-server-0.1.0-amd64.iso` and its SHA-256 checksum in the repository root.

## Commands

```sh
make help
make check
make configure
sudo make build
sudo make clean
```

`/usr/bin/chep` is a small frontend for `apt-get`, `apt-cache`, and `dpkg-query`. Run `chep help` in the live system for usage.

## Layout

- `auto/`: live-build configuration entry points
- `config/`: packages, image files, and chroot hooks
- `scripts/`: build, cleanup, and validation scripts
- `docs/`: project architecture notes

See [docs/architecture.md](docs/architecture.md) for details.
