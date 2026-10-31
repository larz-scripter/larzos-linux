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

Seventeen standalone tools, each a single Larzscript file, each read-only, each
installable on a stock Debian/Ubuntu box without converting the machine:

```sh
sudo apt install larz-ports larz-cron larz-secrets larz-disk larz-certs \
                 larz-perms larz-net larz-www larz-dns larz-units larz-logs \
                 larz-updates larz-mem larz-fs larz-users larz-backup larz-time
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


**`larz-dns`** — whether the DNS behind your sites still matches reality. The A
record against this host's own addresses, and for any domain with MX: SPF (and
that there is only *one*, since two cancel out), DMARC, DKIM at the common
selectors, and the Spamhaus DBL.

The blocklist check is the careful part. Spamhaus **refuses queries from public
resolvers**, and a refusal is an empty answer — indistinguishable from "not
listed". So before reporting any blocklist result it queries a record that is
*known to be listed* and checks it comes back. If that control fails, blocklists
are reported as **UNKNOWN**:

```
NOTE: this resolver cannot query Spamhaus - the control lookup for
      dbltest.com.dbl.spamhaus.org returned ""
      instead of 127.0.1.2. Blocklist status is reported as UNKNOWN
      rather than clear. Use the host's own resolver, not 8.8.8.8.
```

A false clean bill of health on deliverability is worse than no answer. DBL also
answers for *every* subdomain of a listed domain, so the listing is attributed
to the registrable domain rather than reported once per vhost.

**`larz-units`** — the systemd failure `systemctl --failed` doesn't show. A
service that crashes and is restarted every minute is "active" every time you
look at it, and is also not working:

```
bad   restart loop   worker.service
      5 restarts, and it is between restarts right now (sub-state
      auto-restart) - looks active but keeps dying
```

It also finds services that are enabled but dead, and units stuck activating —
while excluding the three kinds of unit that are enabled and inactive entirely
legitimately: `ConditionResult=no` (systemd skipped it deliberately),
socket-activated (`TriggeredBy` set), and run-once types. Without those
exclusions the check is pure noise.

**`larz-logs`** — what is filling the logs, and what is actually erroring. A log
full of one repeated error is a *single broken thing*, not forty thousand
problems, so error lines are grouped by **shape**: every run of digits becomes
`#`, collapsing timestamps, pids, ports and client addresses.

```
/var/log/auth.log - 1326 error line(s) in the last 4000, by shape:
    343x  sshd[#]: Failed password for root from #.#.#.# port # ssh#
    252x  sshd[#]: pam_unix(sshd:auth): authentication failure; logname= uid
```

Two lines of output that say more than a thousand `tail`s. It also reports each
log's growth since the last run.


**`larz-updates`** — what is missing, and what is installed but not running.
Pending updates with **security ones separated from ordinary ones**, plus three
things `apt list --upgradable` will not tell you:

- **how old the package lists are.** "0 upgradable" from a three-week-old cache
  is a false all-clear, so the age is checked first and shouted about if stale.
- **whether you are running an older kernel than the one installed.** The
  package is current, every package-based check passes, and the machine is
  still on the old kernel. Same question `larz-certs` asks about a renewed
  certificate nobody loaded.
- **obsolete packages** — installed, but no configured repository offers them
  any more, so they will never receive another security update and nothing
  tells you they exist.

**`larz-mem`** — memory pressure, and what the kernel has already killed.
`free -m` counts page cache as "used", so it alarms people over nothing; this
reports **MemAvailable** and uses **PSI** to say whether tasks are actually
stalling. The part nothing else surfaces:

```
OOM KILLS - last 14 days
  1x  larzscript            last: Oct 26 06:38:21

  An OOM kill leaves no trace in the application's own log - the
  process vanishes and gets restarted. If a service here has been
  mysteriously restarting, this is why.
```

Pairs with `larz-units`: a restart loop and an OOM kill are often the same
event seen from two ends.

**`larz-fs`** — the ways a filesystem fails that are *not* about free bytes
(`larz-disk` covers those):

- a filesystem the kernel **remounted read-only** after an I/O error. Writes
  start failing, `df` still shows plenty of space, and nothing says why.
- **inodes exhausted while bytes remain** — the disk is 40% full and you cannot
  create a file. Every space check passes.
- **fstab drift** — an entry that is not mounted, or is mounted with different
  options than fstab asks for, so the next reboot behaves differently from now.

Verified against all three with real failures built in a privileged container:
a 128-inode filesystem filled to 100%, a read-only remount while fstab said
writable, and an unmounted fstab entry.


**`larz-users`** — who can log in, and who can become root. That picture is
assembled from four places nobody reads together: `passwd`/`shadow`, `sudoers`,
*every* `authorized_keys`, and `lastlog`. Two findings nothing else gives you:

- **a sudo grant for a user who does not exist.** It looks harmless and it means
  the day anyone creates an account by that name they get root — with
  `NOPASSWD`, without typing anything. Cloud images ship these.
- **SSH keys split into restricted and open.** A key with a forced command is a
  deploy hook; a bare key is a person with a root shell. Counting them together
  hides the only distinction that matters:

```
SSH keys installed:
  root            4 unrestricted  (1 restricted to a forced command)
    - earnifyhubmailer-server1
    - [forced command] larzos-linux-ci-deploy
    - root@localhost
```

**`larz-backup`** — the failure here is not "no backups". It is a backup job
that is scheduled, has been for two years, and last succeeded in March —
because **a backup that fails quietly produces exactly as much output as one
that works.** So it finds the backup machinery and asks only the question that
matters: when did it last succeed?

It is careful about one thing. It can only see backups taken *from inside* the
machine, so when it finds nothing it says it found nothing — not that nothing
exists:

```
NOTHING ON THIS MACHINE APPEARS TO BACK ANYTHING UP.
That is worth confirming rather than assuming either way, because
this tool can only see backups taken from inside the machine.
```

It also ignores the jobs that match the word "backup" and back up none of your
data — `dpkg-db-backup` ships on every Debian system, and counting it would
suppress that verdict exactly where it is true.

**`larz-time`** — `timedatectl` reports **"NTP service: active"** and
**"System clock synchronized: yes"** as two separate facts, and people read the
first as if it meant the second. A time daemon can run for months having never
once reached a server — blocked outbound UDP 123 is the usual reason, and from
inside the machine it looks exactly like working.

It reports both, and measures the offset against an outside reference, because
the only way to know a clock is right is to compare it with something else. With
`--no-net` it says so rather than claiming agreement it never tested. A wrong
clock surfaces as TLS certificate errors, rejected TOTP codes and logs that
will not line up — each of which gets debugged somewhere else first.

---

## Other Debian/Ubuntu-family distributions

LarzOS packages are ordinary signed `.deb`s, so the diagnostic CLIs install on
any apt-based system &mdash; Debian, Ubuntu, Linux Mint, Pop!_OS, Raspberry Pi
OS, Kali, Devuan, Proxmox and the rest of the family. The install is the same
three lines everywhere:

```sh
curl -fsSL https://larzos.com/apt/KEY.asc | sudo gpg --dearmor -o /usr/share/keyrings/larzos-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/larzos-archive-keyring.gpg] https://larzos.com/apt stable main" | sudo tee /etc/apt/sources.list.d/larzos.list
sudo apt update && sudo apt install larz-ports larz-cron larz-secrets larz-disk larz-certs larz-perms larz-net larz-www
```

`stable` here is *our* suite name, not your distribution's &mdash; the same line
is correct on every release. `apt` pulls in `larzscript` (a statically linked
binary, so no glibc floor), plus `curl` for `larz-www` and `openssl` for
`larz-certs`.

**Verified by installing and running them, not by assumption:**

| Distribution | dpkg | Result |
|---|---|---|
| Ubuntu 24.04 LTS | 1.22 | 8/8 install and run |
| Ubuntu 22.04 LTS | 1.21 | 8/8 install and run |
| Ubuntu 20.04 LTS | 1.19 | 8/8 install and run |
| Debian 13 (trixie) | 1.22 | 8/8 install and run |
| Debian 12 (bookworm) | 1.21 | 8/8 install and run |
| Debian 11 (bullseye) | 1.20 | 8/8 run (its own archive is EOL, so the repo was added by hand) |

Architectures: `amd64` and `arm64`. The tools themselves are `all` &mdash;
architecture-independent Larzscript &mdash; so the only per-arch component is the
interpreter. A 32-bit `armhf` Raspberry Pi is **not** covered yet, because no
`armhf` interpreter is published.

**Degrading gracefully.** These are read-only tools, and anything missing is
reported rather than guessed at. Without systemd, `larz-cron` lists the cron
sources and simply finds no timers. In a container, `larz-ports` and `larz-net`
correctly report that namespace's sockets. And where a tool genuinely cannot
answer, it says so and exits non-zero instead of printing a clean result: with
`curl` removed, `larz-www` refuses rather than reporting "nothing is reachable
over HTTP", and a failed request is counted as **could not be checked**, never
as *blocked*.

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
                       larz-certs / larz-perms / larz-net / larz-www /
                       larz-dns / larz-units / larz-logs / larz-updates /
                       larz-mem / larz-fs / larz-users / larz-backup /
                       larz-time — the seventeen read-only diagnostic CLIs)
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
