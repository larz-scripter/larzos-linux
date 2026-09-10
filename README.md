# LarzOS

**A Linux distribution you configure and package entirely in
[Larzscript](https://github.com/larz-scripter/larzscript).**

LarzOS takes a stock Debian/Ubuntu base and makes one high-level language —
Larzscript, the money-native language — the *only* thing a human writes to
run the machine. Your whole system is one `system.lz` file. Packages are
`.lz` files. Services, audio, users, the AI stack: all declared in
Larzscript, realized by `larz-system`.

The kernel, libc, and the userland binaries stay C — millions of
hardened lines nobody should rewrite. Everything *above* that, everything
you touch, is Larzscript.

> **Precedent:** [GNU Guix](https://guix.gnu.org) defines an entire distro
> in Guile Scheme; [NixOS](https://nixos.org) does it with the Nix
> language. LarzOS does it with Larzscript.

This repository is the config engine, the package tooling, and the distro's
own packages. It is **Phase 0** — the language surface works today on any
Debian/Ubuntu box; the installable ISO comes later (see
[ROADMAP.md](ROADMAP.md)).

---

## Three tiers

| Tier | Language | Why |
|---|---|---|
| Kernel, libc, coreutils, systemd, PipeWire, Mesa, browser | **C** (unchanged) | Decades of hardening. Rewriting this kills the project. |
| PID 1 / the executor | **systemd** (C) | The boot path must not depend on a young interpreter. But you never hand-write a unit. |
| Everything a human writes — system config, packages, services, the shell, the AI router, setup | **Larzscript, 100%** | This is what makes it LarzOS instead of another Ubuntu remix. |

`larz-system` reads your Larzscript declarations and *generates* the
systemd units, PipeWire config, apt actions, and user setup. Surface is
pure Larzscript; the thing that runs at boot is still battle-tested C.

---

## Install (Ubuntu 24.04, amd64)

A signed apt repo is live. One command adds it and installs the desktop
metapackage (Larz shell + low-latency audio + AI manager):

```sh
curl -fsSL https://larzos.com/larzos-linux/install.sh | sudo sh
# or just the engine:  ... | sudo sh -s -- larz-system
```

Repo line: `deb [signed-by=/usr/share/keyrings/larzos-archive-keyring.gpg] https://larzos.com/apt stable main`
· key: <https://larzos.com/apt/KEY.asc>

Then edit `/etc/larzos/system.lz`, run `larz-system plan`, then
`sudo larz-system apply`.

## Windows (WSL)

LarzOS ships as a first-class WSL distribution — its own name, icon, first-run
and Windows Terminal profile. Grab `larzos-<ver>.wsl` from the
[latest release](https://github.com/larz-scripter/larzos-linux/releases/latest):

```powershell
wsl --install --from-file larzos-0.1.8.wsl     # WSL 2.4.4+
```

It registers as **LarzOS**, drops you in as the `larz` user (`larzsh` shell,
passwordless sudo), and `larz`, `larz-system`, `larz code` (Claude Code) and
`apt` all work. `larz apply` converges packages and files; systemd services run
(WSL runs systemd). Classic path:
`wsl --import LarzOS C:\LarzOS larzos-rootfs-amd64-<ver>.tar.gz`.

## Try it in a container

```sh
docker run --rm -v "$PWD/examples/system.lz:/etc/larzos/system.lz" \
    ghcr.io/larz-scripter/larzos plan
```

The image is `debian:trixie` with the LarzOS repo + `larz-system` + `larz-ai`
preinstalled (amd64 and arm64).

## Run from source (any Debian/Ubuntu box)

```sh
git clone https://github.com/larz-scripter/larzos-linux
cd larzos-linux
export LARZSCRIPT_PATH=lib          # dev only; installed system uses stdlib

larzscript bin/larz-system plan examples/system.lz     # preview, touches nothing
sudo -E larzscript bin/larz-system apply examples/system.lz
```

---

## What's here

```
bin/larz-system        evaluate a system.lz and converge the machine
bin/larz-pkg           build .deb packages from packages/<name>/package.lz
lib/larzos/            the config engine + realization modules
lib/larzos/modules/    hostname, locale, users, packages, services, audio, ai
examples/              reference machine specs (desktop, server)
packages/              the distro's own packages (larz-desktop, larz-ai, larzsh,
                       larz-claude-code — `larz code`, Claude Code preinstalled)
docs/                  design notes and the system.lz schema
```

## The `system.lz` model

A spec file is ordinary Larzscript — it can compute values, branch on the
host, import helpers. It just hands one table to `larzos.system(...)`:

```larzscript
import "larzos" as larzos

larzos.system({
  "hostname": "larzbox",
  "users":    [ { "name": "larz", "groups": ["sudo", "audio"], "shell": "/usr/bin/larzsh" } ],
  "packages": ["larz-desktop", "git", "firefox"],
  "services": { "ssh": "enabled", "larz-ai": "enabled" },
  "audio":    { "profile": "pro", "quantum": 128, "rate": 48000 },
  "ai":       { "local_models": ["qwen2.5-coder:7b"], "gateway": "https://gateway.larzpay.com" },
})
```

`larz-system plan` diffs that against the live system, module by module.
`larz-system apply` runs the diff and records the applied spec at
`/var/lib/larzos/spec.json`.

See [docs/design.md](docs/design.md) for the module contract and the
package format.

## Status

Phase 0, actively built in the open. Progress log:
[larzos.com/larzos-linux](https://larzos.com/larzos-linux/) ·
[BUILDLOG.md](BUILDLOG.md)

## License

MIT — see [LICENSE](LICENSE). Part of the [Larz stack](https://larzos.com/stack/).
