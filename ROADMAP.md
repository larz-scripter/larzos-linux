# LarzOS roadmap

The goal: a Linux distribution whose entire human-facing surface —
configuration, packaging, services, shell, AI — is Larzscript, installable
on real laptops and servers.

Prior work: `github.com/larz-scripter/larzscript` carried a from-scratch
bare-metal kernel (`kernel/`) and a Larzscript userland (`os/`) as far as a
windowed desktop. That proved the language can drive an OS. LarzOS now
takes the practical path: the same Larzscript-everything vision on a Linux
base that boots on today's hardware.

---

## Phase 0 — the language surface  ·  *done*

- [x] `system.lz` schema + `larzos.system(...)` normalizer
- [x] `larz-system plan` / `apply` / `show` / `modules`
- [x] realization modules: hostname, locale, users, packages, services, audio, ai
- [x] `.lz` package definition format + `larz-pkg` → real `.deb`
- [x] distro packages: `larz-desktop`, `larz-ai`, `larzsh`
- [x] `larz-system` `--check` in CI on every push

## Phase 1 — the overlay repo  ·  *in progress*

- [x] signed apt repo (`apt-ftparchive` + gpg, ed25519 key) at `larzos.com/apt`
- [x] `apt install larz-desktop` resolves on a stock Ubuntu box (`apt-get update` verifies clean)
- [x] `larzscript` + `larz-system` packaged; `tools/refresh.sh` republishes
- [x] `system.lz` rollback + `status` + `history` (snapshots in `/var/lib/larzos/history/`)
- [x] bootstrap script: `curl … | sudo sh` → repo key + `apt install`
- [x] arm64 packages (`larzscript` is arch-specific)
- [x] automated repo refresh on tagged release (GitHub Actions → server)
- [x] `larz-system` renders full `spec.units` to `/etc/systemd/system`
- [x] `larz-aid` real HTTP router daemon (`/route` `/chat` `/models` `/health`)
- [x] `larz-system` systemd *drop-ins* (`unit.d/x.conf` paths in `spec.units`)
- [x] `larzsh` `export` / non-interactive `larzsh script.lz` (pipes work via sh)
- [ ] `larzsh` real job control

## Phase 2 — installable images  ·  *in progress*

- [x] Docker image — `ghcr.io/larz-scripter/larzos` (amd64 + arm64), repo + engine preinstalled
- [x] `debootstrap` → rootfs tarball (`tools/build-rootfs.sh`, shared base)
- [x] **WSL image** — `wsl --import larzos-rootfs.tar.gz` (systemd on, `larz` user)
- [x] **live ISO** (`tools/build-iso.sh`, casper) + `larz-install` — a
      Larzscript disk installer, no Calamares
- [ ] boot-test the ISO on real VirtualBox / bare metal; test `larz-install`
- [ ] publish the WSL image to the Microsoft Store
- [ ] arm64 rootfs / ISO (needs `qemu-user-static` on the build host)
- [ ] `larz-aid`: real local model execution (ollama/llama.cpp wrapper)

## Phase 3 — the identity

- [ ] LarzOS branding, Plymouth theme, first-boot `larz-system` wizard
- [ ] pro-audio profile validated against `rtcqs` on real hardware
- [ ] `larzsh` as a login shell people actually keep
- [ ] money-native OS primitives revisited on the Linux base (compute wallet,
      metered execution) — the moat that carried over from the bare-metal work

## Non-goals

- Forking the kernel or a desktop environment. Stay a thin, sustainable
  overlay on an LTS base.
- A second package ecosystem. LarzOS packages are `.deb`; the `.lz`
  definition is just a nicer way to author them.
