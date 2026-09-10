# LarzOS build log

Newest first. Mirrored to <https://larzos.com/larzos-linux/>.

## 2026-09-10 - Claude Code, preinstalled

- **`larz code`.** New package `larz-claude-code` puts Anthropic's terminal
  coding agent on the OS. `larz code` (or `larz-code`, or `claude`) starts it
  in the current directory. It ships in the rootfs (so the WSL image, the live
  ISO and the phone all have it) and is pulled by `larz-desktop`.
- **Larzscript is the default language Claude sees.** The package ships
  `/etc/claude-code/CLAUDE.md` at Claude Code's managed-policy path - loaded on
  every session in every repo, and cannot be turned off by user settings - that
  tells Claude "Larzscript is the default language for new code on this system".
  `larz-code` also adds a matching `--append-system-prompt` line
  (`LARZOS_NO_SYSPROMPT=1` to skip).
- The `claude` command itself is installed via npm on configure
  (`larz-claude-code` depends on `nodejs` + `npm`); `larz-code` retries the
  install if it's missing.
- **Auth is the user's.** First run signs in with an Anthropic account, or
  `ANTHROPIC_API_KEY`. `/etc/larzos/claude-code.toml` can name a `base_url` +
  `auth_token` to route Claude Code through the LarzOS Gateway once the
  Gateway exposes an Anthropic-compatible endpoint.
- The minimal container image (`ghcr.io/larz-scripter/larzos`) stays lean —
  `larz install larz-claude-code` adds it there.
- Termux edition: `larz-code` launcher + `larz code` documented; set
  `LARZOS_NO_CLAUDE=1` to skip the bigger nodejs download.

## 2026-09-09 - the larz command grows up (v0.1.6)

- **Money is in the OS.** `lib/larzos/wallet.lz` - the machine has a wallet;
  AI usage, metered packages and API calls go into a receipted, append-only
  ledger, capped by `larz budget` or a `budget` block in system.lz. Verbs:
  `larz wallet | pay | topup | budget | spend`. Providers: local now,
  cryptolarz/larzpay stubbed. New `budget` module.
- **An OS you talk to.** `larz-aid` rewritten to speak OpenAI to
  gateway.larzos.com, route by task, check the `ai` budget before a call and
  meter the cost after. `larz do "<goal>"` proposes commands and (after a
  snapshot) runs them; `larz explain`, `larz why <topic>`, `larz ask`.
- **Configuration generations.** `larz snapshot` / `larz switch <n>` /
  `larz generations` / `larz diff` - `lib/larzos/genlib.lz`.
- **Fleet + sharing.** `larz fleet add|apply|run`; `larz share` /
  `larz adopt <id>` against a new machine hub (`tools/machined.lz`, deployed
  at larzos.com/larzos-linux/m/).
- Docs: larzos.com/larzos-linux/larz/ (full reference) and /different/
  (what makes LarzOS different). man page + bash completion rewritten.
- Note: Larzscript reserves `wallet`/`price`/`to`/`pay`/`require`; aliased the
  wallet import `as wal`.

## 2026-09-09 - it presents as LarzOS; base is Debian

- **Standardized on Debian stable** as the base (was: Ubuntu/casper ISO +
  Debian Termux container). Debian is built to be rebranded and has far fewer
  vendor ad/nag surfaces. `build-rootfs.sh` -> debootstrap trixie;
  `build-iso.sh` -> the Debian live stack (live-boot + live-config), no casper.
- **`larz-branding`** package - the LarzOS identity for every surface a user
  sees: `os-release` / `lsb-release` / `/etc/issue`, the login MOTD (drops the
  base distro's motd.d scripts for one LarzOS banner), GRUB distributor, a
  Plymouth theme, the dpkg vendor, the logo. `larz-rebrand` applies it
  (package postinst) and restores the originals (prerm). Verified on
  debian:trixie: install -> presents as LarzOS; remove -> exact restore.
  A `branding` module in `larz-system` re-asserts it on every apply, so an
  upstream package upgrade that rewrites os-release self-heals.
- **`larz`** - one command for the whole machine: `install`/`remove`/`search`/
  `update`/`upgrade` (over apt), `plan`/`apply`/`rollback`/`status` (over
  larz-system), `ai` (over larz-aid), `doctor`, `rebrand`, `version`. Bash
  completion + man page. Users never type `apt` or `systemctl`.
- `tools/check-branding.sh` - fails a build whose rootfs still presents as the
  base distro; wired into `build-rootfs.sh` and `build-iso.sh`.
- `larz-pkg` / `pkg.lz` gained DEBIAN maintainer-script support (`scripts`
  field). `larz-desktop` depends on `larz-branding` + `larz`.

## 2026-09-09 - lean ISO boots; Termux edition

- **Lean live ISO (128 MB) boots end to end on real VirtualBox 7.2** (PC2):
  GRUB -> kernel 6.8 -> casper overlay root -> autologin to `larzsh`. The prior
  `(initramfs)` drop was `tools/build-iso.sh` writing `BUILD_SYSTEM="LarzOS"`
  into `casper.conf`; casper only sets `MP_QUIET` for `Debian`/`Ubuntu`, so it
  ran `modprobe "" -b overlay` (empty arg -> rc 1 -> panic). Fixed:
  `BUILD_SYSTEM="Ubuntu"` (FLAVOUR stays `LarzOS`).
- Verified in the booted image: `sudo larz-system plan` (8 modules, clean),
  `larz-aid route --task coding` -> gateway, `larz-install` present. Only
  failed unit is `casper-md5check` (stale checksum on a stripped ISO -
  cosmetic).
- Published ISO `sha256 55a2ae70...`; `larzos.com/larzos-linux/larzos-live-amd64.iso`.
- `tools/termux-install.sh` - LarzOS on an unrooted Android phone via Termux.
  The static `aarch64` larzscript trips Android's seccomp filter (SIGSYS /
  "Bad system call" - glibc reaches for `faccessat2`/`statx`), so the installer
  drops LarzOS into a `proot-distro` Debian arm64 container: adds the apt repo,
  installs `larzscript` + `larz-system` + `larz-ai` + `larzsh`, and puts thin
  Termux launchers (`larz-system`, `larz-aid`, `larzos`) on `PATH` that bind
  `~/.config/larzos` to the container's `/etc/larzos`. `plan`/`show`/`modules`
  and the AI router work; `apply` converges packages + files but not systemd
  services. One-liner: `curl -fsSL https://larzos.com/larzos-linux/termux.sh | sh`.

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

## 2026-09-09 — Phase 1 cont.: unit generation + arm64

- New `systemd` module: `spec.units` renders straight to
  `/etc/systemd/system/*` (sections → `key=value`, lists → repeated lines,
  bools → yes/no) + `daemon-reload` on change. `examples/system.lz` now
  declares a `larz-reconcile.timer` that re-applies the spec nightly — the
  machine self-heals toward its declaration, no hand-written `.service`.
- `services` module already handles `foo.timer` names.
- `repo-publish.sh`: pool is cumulative — arm64 debs built on another host
  sit alongside amd64 without being clobbered by an amd64-only rebuild.
- arm64 `larzscript` package published; repo now serves `all amd64 arm64`.

## 2026-09-09 — Phase 1 cont.: one-tag releases

- `release.yml`: pushing a `v*` tag builds every package (amd64 + arch:all +
  arm64 interpreter), streams them to the repo host over a locked-down
  deploy key (forced command → `repo-publish.sh`), and attaches the `.deb`s
  to a GitHub Release. Cutting a release is now `git tag vX.Y.Z && git push --tags`.
- Cloudflare edge no longer caches apt metadata (dropped `Packages.gz`;
  extensionless indexes are `cache-status: DYNAMIC`). arm64 `apt-get update`
  verifies clean.

## 2026-09-09 — larz-aid daemon + container image

- `larz-aid` is a real HTTP router now (was a CLI stub): `GET /health`,
  `GET /models`, `POST /route {"task"}` -> `{backend, model}`,
  `POST /chat` -> proxied to the Gateway or served locally. Binds
  127.0.0.1:8199, hardened systemd unit. Built on the `tcp` + `http`
  Larzscript libs. Verified end to end on the installed layout.
- `/usr/lib/larzos` is now the shared Larzscript library root every LarzOS
  package imports from (engine + json/toml/tcp/http); `larz-ai` depends on
  `larz-system` for it.
- `Dockerfile` + `docker.yml` -> `ghcr.io/larz-scripter/larzos` (amd64 +
  arm64): Ubuntu 24.04 + the apt repo + `larz-system`/`larz-ai`, entrypoint
  `larz-system`. `docker run -v system.lz:/etc/larzos/system.lz ... plan`.

## 2026-09-09 — WSL image + Phase 1 tail

- `tools/build-rootfs.sh` - debootstrap Ubuntu 24.04 + the LarzOS repo +
  `larz-system`/`larz-ai`/`larzsh`, a `larz` user, `system.lz` seeded,
  `/etc/wsl.conf` with systemd on. Produces one tarball that is the shared
  base for WSL now, Docker and the live ISO next.
- WSL: `wsl --import LarzOS C:\LarzOS larzos-rootfs.tar.gz`.
- `larzsh`: `export`, `larzsh script.lz` non-interactive mode. Pipes /
  redirection / `&&` already worked (unknown commands run via `/bin/sh`).
- systemd module: a `spec.units` key with a `/` is a drop-in path
  (`ssh.service.d/larzos.conf`) - override a distro unit without replacing it.

## 2026-09-09 — WSL rootfs published

- larzos.com/larzos-linux/larzos-rootfs-amd64.tar.gz (57 MB) is live -
  `wsl --import` it. Verified by importing into Docker on the build host and
  running `larz-system plan` clean.
- Packages declare dpkg conffiles (`/etc/larzos/system.lz`, `ai.toml`);
  `larz-system` ships a minimal commented default spec.
- repo-publish.sh prunes the pool to the newest version per package/arch.
- release.yml now also builds + attaches the rootfs tarball on a tag.

## 2026-09-09 — live ISO + larz-install

- `tools/build-iso.sh` - hybrid BIOS/UEFI live ISO from the rootfs: adds
  `linux-image-generic` + `casper`, squashes the filesystem, autologin as
  `larz` into `larzsh`, `grub-mkrescue`. Serial console on so it can be
  boot-tested headlessly.
- `larz-install <disk>` (in `larz-system`) - the LarzOS-native disk
  installer, in Larzscript: GPT (EFI + ext4 root), rsync the live system,
  fstab by UUID, GRUB for UEFI or BIOS, keeps `/etc/larzos/system.lz`.
  No Calamares - the installer is Larzscript, like everything else.

## 2026-09-09 — live ISO: builds, boot-test in progress

- `tools/build-iso.sh` produces a hybrid BIOS/UEFI ISO (928 MB): casper
  live layer over the rootfs, autologin to larzsh, `grub-mkrescue`.
- Headless QEMU (TCG, no KVM) boot: GRUB OK, kernel OK, then casper panics
  `modprobe -b overlay || panic "cow format ... no support found"` and drops
  to the initramfs shell - despite overlay.ko.zst + modules.dep.bin +
  kmod + libzstd all present in the initrd. Added overlay/squashfs/isofs to
  the initramfs and MODULES=most; still fails under TCG. Needs a real
  VirtualBox / bare-metal boot (PC2/VBox was offline this session).
- `larz-install` is done regardless - it runs from any live environment.

## 2026-09-09 (later) — ISO slimmed + real VM test underway

- `build-iso.sh`: `linux-image-virtual` + `mksquashfs -comp xz` + strip
  doc/man/locale → **116 MB** ISO (was 928 MB).
- Testing on real VirtualBox 7.2 (PC2, reached via the NetBridge SOCKS
  path) — QEMU's software emulation couldn't get casper past the overlay
  probe; a real hypervisor is the right test surface.

## 2026-09-09 (later) — live ISO VERIFIED on VirtualBox

- The 116 MB ISO boots clean on real VirtualBox 7.2: GRUB -> kernel ->
  casper -> autologin to `larzsh` (hostname `larzos`). `larz-aid route`,
  `larz-system plan` (all 8 modules) run in the live session. The
  QEMU-TCG overlay panic did not reproduce on a real hypervisor.
- Published: https://larzos.com/larzos-linux/larzos-live-amd64.iso
- `larz-install` first pass hit `sgdisk: not found` (minbase is bare) ->
  ISO now bundles gdisk/parted/dosfstools/rsync/grub-*-bin, and
  `larz-install` preflights its tools. Re-verifying (v0.1.4).
