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
- [ ] arm64 packages (`larzscript` is arch-specific)
- [ ] `larz-system` generates real systemd drop-ins, not just enables units
- [ ] automated repo refresh on tagged release (GitHub Actions → server)
- [ ] `larzsh` fleshed out (pipes, redirection, job control)
- [ ] `larz-aid` local socket daemon (currently a routing skeleton)

## Phase 2 — installable images

- [ ] `debootstrap` → rootfs tarball (shared by all delivery forms)
- [ ] **WSL distro** — `wsl --import`, published to the Microsoft Store
- [ ] Docker image for the dev + AI use case
- [ ] live ISO with a Calamares installer that writes the first `system.lz`
- [ ] `larz-aid`: real local model management (ollama/llama.cpp wrapper) + Gateway routing

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
