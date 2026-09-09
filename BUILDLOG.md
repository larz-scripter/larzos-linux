# LarzOS build log

Newest first. Mirrored to <https://larzos.com/larzos-linux/>.

## 2026-09-09 — Phase 0 scaffold

- New repo. The LarzOS effort pivots from the bare-metal kernel to a Linux
  base with Larzscript as the system language (Guix/Nix model).
- `system.lz` schema + `larzos.system(...)` normalizer.
- `larz-system`: `plan` / `apply` / `show` / `modules` / `version`, written
  in Larzscript. Evaluates a spec file in a subprocess, reads it back as
  JSON, diffs it against the live system module by module.
- Seven realization modules: hostname, locale, users, packages, services,
  audio (PipeWire low-latency drop-in), ai (`/etc/larzos/ai.toml`).
- `.lz` package format + `larz-pkg deb` → real `.deb` (verified:
  `larz-ai_0.1.0_all.deb`, `larz-desktop_0.1.0_all.deb` build and pass
  `dpkg-deb -I`).
- Distro packages: `larz-desktop` (metapackage), `larz-ai` (OS AI router
  skeleton + systemd unit), `larzsh` (Larzscript login shell).
- `larz-system plan examples/system.lz` produces a 13-change plan on a
  stock box; `examples/server.lz` a 10-change headless plan.

## 2026-09-09 — Phase 1: apt repo + bootstrap

- `larz-system`: `rollback` (re-apply previous spec, walks back through
  snapshots), `status` (drift check), `history`. Applied specs rotate through
  `/var/lib/larzos/history/` (keep 10).
- `packages/larz-system/` — the engine packaged: CLIs + library tree under
  `/usr/lib/larzos`, `/usr/bin` wrappers, default `/etc/larzos/system.lz`.
  Verified: relative imports resolve from the installed layout, spec-eval
  subprocess inherits the path.
- `packages/larzscript/` — wraps the upstream release binary so
  `apt install larz-desktop` pulls a working runtime (amd64; `LARZOS_ARCH=arm64`
  for the arm64 deb).
- `tools/repo-publish.sh` — builds a signed flat apt repo with
  apt-ftparchive + gpg (ed25519 signing key, no reprepro). Publishes
  `dists/stable`, `pool/main`, `KEY.asc`.
- `tools/install.sh` — `curl -fsSL https://larzos.com/larzos-linux/install.sh | sudo sh`
  adds the repo + key and installs a component.
