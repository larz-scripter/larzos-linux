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

## The diagnostic CLIs

Eight standalone tools, each a single Larzscript file, each read-only, each
installable on a stock Debian/Ubuntu box without converting the machine:

```sh
sudo apt install larz-ports larz-cron larz-secrets larz-disk \
                 larz-certs larz-perms larz-net larz-www
```

**`larz-ports`** — what is listening, and who can reach it. `ss` lists sockets;
it does not tell you which ones a stranger can get to. This reads
`/proc/net/tcp{,6}` and gives every listener a verdict:

```
ADDRESS                   PORT  VERDICT PROCESS
0.0.0.0                     22  EXPOSED 1/systemd
::                         443  EXPOSED 1012/apache2
127.0.0.1                 5432  LOCAL   1643/docker-proxy
```

`EXPOSED` means bound to every interface, `IFACE` to one address, `LOCAL` to
loopback. `--exposed` shows only the first kind; `--json` feeds a cron check.

**`larz-cron`** — every scheduled job in one list, in English. Scheduled work
hides in six places (`/etc/crontab`, `/etc/cron.d`, each user's spool crontab,
the three `run-parts` directories, and systemd timers) and nothing in the base
system shows them together, so a job you forgot is invisible:

```
[crontab:root]
every 20 minutes                  root    /usr/bin/python3 /root/feed_ingest.py
daily at 02:15, 08:15, 14:15, ... root    /usr/bin/python3 /root/critical.py
on Mon-Fri at 23:30               root    /usr/bin/python3 /root/digest.py
```

**`larz-secrets`** — credentials committed into files. The usual way a password
gets loose is not an attack: someone pastes it into a script to get something
working and it stays there. This walks a tree, separates a real credential from
a placeholder, and reports the file mode next to it, because the same secret in
a `600` file and a `644` file are different problems:

```
SEVERITY  MODE  WHAT
critical  644   AWS access key id  WORLD-READABLE
                ./deploy/app.py:2
                AK***E1 (21 chars)
```

It never prints a secret — values are masked to their first and last two
characters, so the output is safe to paste into a ticket. On its own repository
it reports nothing; on a fixture of 10 planted credentials and 12 lookalike
placeholders it finds 10 and flags 0.


**`larz-disk`** — what is eating the disk, and what you can delete. `df` says
the disk is full and `du` says which directory is big; neither answers the
question you actually have at 2am. This reports the heavy directories and
files, then separates out the space that is *reclaimable* — package caches,
rotated logs, the journal, backup copies, build caches — and gives the command
for each:

```
RECLAIMABLE - safe to remove on a running system
    1.9G  systemd journal
          $ sudo journalctl --vacuum-size=200M
  862.0M  Playwright browsers
          $ rm -rf /root/.cache/ms-playwright

About 4.7G is reclaimable without touching anything live.
```

**`larz-certs`** — TLS expiry, on disk *and as actually served*. Two outages
hide here. The obvious one is a certificate nobody renewed. The quieter one is
a certificate that renewed perfectly and was never loaded, because nothing
reloaded the web server: the files on disk are correct, every check that reads
those files passes, and visitors keep getting the old certificate. `--served`
connects to :443 and compares, and it tells a CDN in front of the origin apart
from a stale web server by comparing issuers:

```
OK           89  Jan 29 10:51:05 2027 GMT  gateway.example.com
                 *** SERVED CERT IS OLDER: Nov  9 08:11:01 2026 GMT
                 *** renewed on disk but never loaded - reload the web server
```

That is not a hypothetical example — it is the first thing this tool found on
the machine it was written on.

**`larz-perms`** — permissions that hand someone else root. Deliberately not
"every file with an odd mode": that list is long, mostly harmless, and
therefore ignored. It checks the cases that are an escalation path — a root
cron job whose script a non-root user can edit, a systemd unit writable by
non-root, an SSH private key readable by others, a SUID binary no package owns,
world-writable paths outside the sticky temp dirs.

**`larz-net`** — the outbound counterpart to `larz-ports`. That one answers
what can reach you; this answers what you are reaching, and which process is
doing it. Connections are grouped by peer and process, so a connection pool's
hundred sockets become one line, and peers inside the network are separated
from peers on the internet.

**`larz-www`** — files in a web root the server will hand to anyone. A
sensitive file *on disk* in a document root is untidy; one the server actually
*returns over HTTP* is a disclosure. Every "find the .env in your webroot"
one-liner only finds the first. This locates each candidate and then requests
it through the web server, so the report distinguishes the two:

```
STATUS    SEVERITY  ON DISK  WHAT
EXPOSED   critical        1  backup of a PHP file - served as source  (*.php.bak*)
                    HTTP 200  /control.php.bak
blocked   critical      400  dated backup copy  (*.bak-*)
                    HTTP 403  /emi-calculator/index.html.bak-2026-09-15
```

---

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
(WSL runs systemd).

Prefer a double-click installer? Grab `LarzOS-WSL-<ver>-x64.zip` from the same
release, extract it, and run **`LarzOS.exe`** — it registers LarzOS from the
bundled rootfs and opens a shell. Classic path (any WSL version):
`wsl --import LarzOS C:\LarzOS larzos-rootfs-amd64-<ver>.tar.gz`. See
[`windows/`](windows/) for all three and the launcher source.

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
                       larz-claude-code — `larz code`, Claude Code preinstalled,
                       larz-ports / larz-cron / larz-secrets / larz-disk /
                       larz-certs / larz-perms / larz-net / larz-www — the
                       read-only diagnostic CLIs)
windows/               LarzOS.exe — the rebranded WSL distro-launcher + MSIX
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
