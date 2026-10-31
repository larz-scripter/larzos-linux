# LarzOS build log

Newest first. Mirrored to <https://larzos.com/larzos-linux/>.

## 2026-10-31 - 0.1.23: larz-users, larz-backup, larz-time

Three more, taking the set to seventeen. Each positive control found a real bug
in the tool it was testing, which is the whole argument for writing them.

- **`larz-users`** assembles the login and escalation picture from
  passwd/shadow, sudoers, every authorized_keys and lastlog. Two findings
  nothing else gives you: **a sudo grant for a user who does not exist** (cloud
  images ship these - `ubuntu ALL=(ALL) NOPASSWD:ALL` sat in
  `/etc/sudoers.d/90-cloud-init-users` on this machine with no such account, so
  creating that name would have handed out passwordless root), and
  **authorized_keys split into restricted and open**, because a key with a
  forced command is a deploy hook and a bare key is a person with a root shell.
  Verified against a container with a second UID 0 account, an emptied
  password and a NOPASSWD grant planted: all three fired. Two refinements the
  output needed: `%admin` and `%sudo` ship in Debian's stock sudoers with the
  group often absent, so the note now says so rather than alarming on every
  box; and UID 0 was being reported twice, by the generic duplicate-UID check
  and the specific one.
- **`larz-backup`** asks when each backup job last *succeeded*, because a
  backup that fails quietly produces exactly as much output as one that works.
  Three things it had to get right:
  - **`dpkg-db-backup` is not a backup of your data.** It ships on every
    Debian system and matches the word; left in, it suppressed the one verdict
    that matters - "nothing here backs anything up" - on every stock box. It is
    now listed separately as ignored, with the reason.
  - **the log path is not in the last `>`-separated field.** A cron line almost
    always ends `2>&1`, so splitting on `>` and taking the tail returns `&1`.
    Caught by the positive control, which reported "nothing records whether it
    worked" for a job that plainly redirected to a log.
  - **a failed run matters whenever it happened.** The never-fired check came
    first and returned, so a timer whose last run exited non-zero was reported
    as "never fired" instead of "FAILED". Also caught by the control.
  When it finds nothing it says it found nothing - not that nothing exists -
  because a hypervisor snapshot or provider volume backup is invisible from
  inside the machine, and reporting "no backups" without that caveat would be
  both wrong and alarming.
- **`larz-time`** is built on the distinction that keeps recurring:
  `timedatectl` reports "NTP service: active" and "System clock synchronized"
  as two separate facts, and a time daemon can run for months having never
  reached a server (blocked outbound UDP 123, which from inside looks exactly
  like working). It reports both and measures the offset against an external
  HTTPS `Date` header, since the only way to know a clock is right is to
  compare it with something else. The skew thresholds are unit-tested across 11
  cases including negative offsets.
  One bug worth recording because it is the exact failure this whole series is
  built to avoid: under `--no-net` the all-clear still read "it agrees with an
  outside reference to within 2 seconds" - claiming a check that had not run.
  It now says the machine *believes* its clock is right, which is a different
  statement.

All three are wired into the daily health card, now at fourteen checks. On this
machine the card immediately surfaced two things worth a decision: the dead
`ubuntu` sudo grant, and that nothing visible from inside the box backs anything
up.

## 2026-10-31 - 0.1.22: larz-updates, larz-mem, larz-fs

Three more, taking the set to fourteen. All three follow the pattern that has
turned out to be the most useful one in this series: **something is installed
or configured, and is not actually in effect.**

- **`larz-updates`** separates security updates from ordinary ones and adds
  three things `apt list --upgradable` does not answer:
  - **the age of the package lists.** "0 upgradable" from a three-week-old
    cache is the same false all-clear an unreachable check gives you, so the
    age is checked first and reported before any count. Verified by backdating
    `/var/lib/apt/lists` 30 days in a container: the warning fires and says a
    count of zero would mean "nothing known", not "nothing pending".
  - **running kernel versus newest installed kernel.** A kernel update changes
    nothing until a reboot; the package is current and the machine is not. The
    version comparison is numeric, not string - a plain string compare says
    `6.8.0-64 > 6.8.0-147`, which is exactly backwards. Unit-tested against 8
    pairs including that one.
  - **obsolete packages** (`installed,local`) - no configured repository offers
    them, so they will never get another security update and nothing says they
    exist.
- **`larz-mem`** reports MemAvailable rather than `free`'s "used", which counts
  page cache and so alarms people over nothing, and uses PSI to say whether
  tasks are genuinely stalling. The part nothing else surfaces is **OOM-kill
  history**: an OOM kill leaves no trace in the application's own log - the
  process vanishes and systemd restarts it, and the only record is one line in
  the kernel ring buffer that nobody greps for until the mystery restarts have
  been going on for weeks. On this machine it immediately found `larzscript`
  OOM-killed on 2026-10-26 at 17.9GB of virtual memory on a 5.9GB box.
  Cross-checked against `/proc/meminfo` and the journal: totals match exactly
  and the kill count matches `grep -c`.
- **`larz-fs`** covers the filesystem failures that are not about free bytes
  (`larz-disk` has those): a filesystem the kernel **remounted read-only** after
  an I/O error, **inodes exhausted while bytes remain**, and **fstab drift** -
  an entry not mounted, or mounted without the `noexec`/`nosuid`/`nodev`/`ro`
  that fstab asks for, so the next reboot differs from now. It also surfaces
  what the kernel itself has said about the block devices.
  All three failure modes were verified by **building them for real** in a
  privileged container: a 16MB filesystem made with `-N 128` and filled to
  100% of its inodes, a `remount,ro` while fstab said writable, and an fstab
  entry pointing at a device that does not exist. Each fired.

All three are wired into the daily infrastructure health card, which now runs
eleven checks. One tuning note worth recording: the card asks `larz-mem` for a
**3-day** OOM window rather than the tool's interactive 14-day default, because
a daily report should distinguish "it is happening" from "it happened" - an OOM
kill five days ago is worth knowing once, not flagging as urgent every morning
for a fortnight.

## 2026-10-31 - 0.1.21: larz-dns, larz-units, larz-logs

Three more read-only CLIs, taking the set to eleven.

- **`larz-dns`** checks the A record against this host's own addresses, and for
  any domain with MX: SPF (and that there is only one, since two cancel out),
  DMARC, DKIM at the common selectors, and the Spamhaus DBL.
  The blocklist check is the part worth the care. **Spamhaus refuses queries
  from public resolvers, and a refusal is an empty answer - identical to "not
  listed".** So before reporting any blocklist result it queries a record that
  is known to be listed (`dbltest.com.dbl.spamhaus.org`, which must answer
  `127.0.1.2`) and checks it comes back. If the control fails, blocklists are
  reported as UNKNOWN with an explanation. Verified by running it in a
  container pinned to `--dns 8.8.8.8`: against a domain that really is listed
  as a phish domain, it correctly said UNKNOWN rather than clear.
  Second correction found while testing: **DBL answers for every subdomain of a
  listed domain** - even `totally-random-xyz123.larzos.com` returns the parent's
  code - so one listing was being reported as four separate problems. Listings
  are now attributed to the registrable domain.
- **`larz-units`** finds what `systemctl --failed` does not: a service that
  crashes and is restarted every minute is "active" at every instant and is
  also not working. The first design divided restarts by *system uptime*, which
  was wrong - a unit that restarted 8 times in 8 seconds scored 1.1/day against
  a 7.4-day uptime and read as healthy. Two signals actually identify a live
  loop: `SubState=auto-restart` (systemd is between restarts right now, free
  and instant) and a second `NRestarts` read a few seconds later. The
  rate-against-uptime stays, but only as the soft "has restarted" note it
  always really was.
  Three kinds of unit are enabled and inactive entirely legitimately, and
  without excluding them the check is pure noise: `ConditionResult=no` (systemd
  skipped it - open-vm-tools on a host that is not a VMware guest),
  `TriggeredBy` set (socket-activated, like snapd), and run-once types
  (`oneshot`, `idle`).
- **`larz-logs`** groups error lines by shape rather than text: every run of
  digits becomes `#`, so lines differing only by timestamp, pid, port or client
  address collapse into one pattern with a count. A log full of one repeated
  error is a single broken thing, not forty thousand problems. It also reports
  each log's growth since the last run, from a small baseline file.
  Getting the normalisation right took three corrections, all caught by
  looking at the output: an IP-collapsing rule that mangled timestamps into
  `#:#:#.#.#.#`; the leading timestamp eating most of the display width; and -
  the good one - `T` and `Z` in the leading-strip character class (they appear
  in ISO timestamps) turning **"Traceback"** into **"raceback"** and "The above
  exception" into "he above exception". The strip now only fires on a run that
  *starts* with a digit.
  The grouping pipeline is sed/sort/uniq rather than character-by-character
  Larzscript: that is exactly the short shell glue those tools exist for, and
  it keeps a scan of tens of thousands of lines at 0.15s.

All three are wired into the daily infrastructure health card on the build host
alongside the other eight.

## 2026-10-31 - 0.1.20: larz-www was reading the wrong Apache config entirely

Found while wiring the diagnostic CLIs into a daily health report: `larz-www`
discovered document roots with `grep -r` over `sites-enabled`, and **`grep -r`
does not follow symlinks** found during traversal. Debian's `a2ensite` enables
a vhost by *symlinking* `sites-available/x.conf` into `sites-enabled`, so on a
normally-administered Debian or Ubuntu box every real vhost was invisible.

What it read instead were the only regular files in that directory - the
`larzos-ssl.conf.bak-20261026` style copies left beside them. Apache ignores
those (it includes only `sites-enabled/*.conf`), but the scan was parsing them,
so it reported a **stale** hostname (`www.larzos.com` instead of `larzos.com`)
and missed a whole document root. A `.php.bak` that curl fetched with a 200 was
not reported at all.

Fixed by enumerating the files the servers actually load - `ls` by glob, which
follows symlinks - and parsing **each file separately**, so a `ServerName` in
one file can no longer pair with a `DocumentRoot` in the next. Non-`.conf`
leftovers are skipped explicitly.

Verified: the tool now finds both document roots on the host, with the correct
hostnames from the live configs, and correctly reports a served `*.php.bak` as
`EXPOSED (200)` where it previously reported nothing. The three-way positive
control for the health report - port-baseline drift, a served sensitive file,
a world-writable path - now fires on all three.

Lesson worth keeping: `grep -r` is the wrong tool for any Debian config
directory, because the Debian convention for "enabled" *is* a symlink.

## 2026-10-31 - 0.1.19: every package was uninstallable on Debian 11 and older

Asked whether the diagnostic CLIs work on other apt distributions, the answer
turned out to be "not as widely as they should have". Three real packaging
defects, all found by installing into clean containers rather than by reasoning
about it.

- **Every LarzOS .deb was zstd-compressed.** `dpkg-deb --build` with no `-Z`
  flag takes the *build host's* default, which on Ubuntu 24.04 is zstd - and
  dpkg could not read zstd until 1.21.18 (Debian 12 / Ubuntu 22.04). On
  anything older every package failed with the thoroughly unhelpful
  `uses unknown compression for member 'control.tar.zst'`. `bin/larz-pkg` now
  passes **`-Zxz`**, understood by every dpkg since 2009. The `larzscript` deb
  got *smaller* in the process (2,057,630 -> 1,931,560 bytes), and both the
  amd64 and arm64 interpreter packages were rebuilt. Debian 11 (dpkg 1.20.14)
  and Ubuntu 20.04 (dpkg 1.19.7) now install and run everything.
- **`larz-www` needed `curl` and `larz-certs` needed `openssl`, and neither
  declared it.** Both are priority `optional` on Debian, so a minimal install
  does not have them. Worse than failing: both failed *silently with a false
  all-clear*. Without curl, `larz-www` printed `HTTP ---` for every probe and
  concluded **"Nothing sensitive is reachable over HTTP"**; without openssl,
  `larz-certs` reported **"No TLS certificates found"** with a certificate
  sitting right there. On a security tool that is the worst possible failure
  mode. Both now declare the dependency *and* check for the command at
  startup, printing why they cannot answer and exiting 2.
- **`curl` reports `000`, not an empty string, on a refused connection.** The
  first version of the guard only caught empty output, so in a container with
  no web server `larz-www` still read `000` as "not 200" and therefore
  "blocked" - another false all-clear. A request that did not complete is now
  its own state, **UNKNOWN**, counted separately, and the summary refuses to
  say "nothing is reachable" when any probe failed.
- **`return N` from `main()` is not the process exit status.** The refusal paths
  exited 0, so a cron check would have read them as success. They call
  `exit(2)` now.

Verified by installing and running, on Ubuntu 24.04 / 22.04 / 20.04 and Debian
13 / 12 / 11: 8/8 tools install and run on each. The `larzscript` binary is
statically linked, so there is no glibc floor - the floor was always dpkg's
compression support. Still no `armhf` interpreter, so 32-bit Raspberry Pi OS
remains uncovered.

## 2026-10-31 - five more diagnostic CLIs, and the outage the first one found

Released 0.1.17: `larz-disk`, `larz-certs`, `larz-perms`, `larz-net`,
`larz-www`. Same shape as the first three - one self-contained Larzscript file
each, no imports, read-only, `--json` on all of them.

**`larz-certs` found a live outage on the machine it was written on**, which is
worth recording in full because it is the exact failure the tool exists for.

- Two certificates (`larzos.com`, `gateway.larzos.com`) were 8 days from expiry
  and certbot had been failing every run: *"All renewals failed"*. Two
  independent causes:
  - **`larzos.com`**: certbot's `webroot_path` was `/var/www/larzos` while
    Apache aliased `/.well-known/acme-challenge/` to `/var/www/letsencrypt`.
    Certbot wrote the challenge token to a directory the server never served
    it from, so the CA got a 404. Fixed by pointing `webroot_path` at the
    directory the alias actually uses, as the other two certificates already
    did.
  - **`gateway.larzos.com`**: `000-default.conf` had no `ServerName`, so Apache
    gave it the *system hostname* - which on this box is `gateway.larzos.com` -
    and being the first `*:80` vhost it shadowed `gateway.larzos.com.conf`,
    where the ACME alias lives. Every challenge was answered by the wrong
    vhost. Fixed with an explicit, deliberately non-resolving `ServerName`; it
    is still the catch-all default because it is still first.
- With both fixed, `certbot renew --dry-run` reported *"no renewal failures"*
  and the real renewal succeeded.
- **Then `larz-certs --served` immediately caught the second half**: both
  certificates now had 89 days on disk, and `:443` was still serving the
  8-day-old one. Nothing reloads Apache after renewal -
  `/etc/letsencrypt/renewal-hooks/deploy/` was empty. Every file-based check
  would have called this healthy. Added the deploy hook, reloaded, and
  `larz-certs --served` now reports *"served on :443 matches this file"*.

The other four:

- **`larz-disk`** separates heavy from *reclaimable*, which is the distinction
  `du` does not make: package caches, rotated logs, the journal, backup copies,
  build caches, surplus kernels, docker's own reclaimable figure - each with the
  command to reclaim it. Verified against `du` to the kilobyte. One real bug
  fixed: the percentage must be `used/(used+avail)` rounded up, because that is
  what `df` prints; dividing by the raw total reads ~3 points low and makes the
  tool look wrong next to `df`.
- **`larz-perms`** checks escalation paths rather than odd modes. Four
  false-positive classes had to go first, and each is a trap worth knowing:
  GNU `stat` reports a **symlink's own mode (always 777)** unless given `-L`, so
  every symlinked binary read as world-writable; a **masked systemd unit is a
  symlink to /dev/null**, so dereferencing it yields 666; the first absolute
  path on a cron line is the **interpreter**, not the script a user could
  tamper with; and **usrmerge** means dpkg records `/bin/foo` for a file at
  `/usr/bin/foo`, so a plain `dpkg -S` makes every merged SUID binary look
  unpackaged. With those handled it reports nothing on a clean box, and a
  fixture of four deliberate holes fires all four.
- **`larz-net`** is the egress counterpart to `larz-ports`: outbound
  connections grouped by peer and process, public peers separated from internal
  ones. Verified by interleaved sampling against `/proc/net/tcp{,6}` - the
  delta against the immediately-following kernel read was 0 in every sample,
  which is the only honest way to check a continuously changing value.
- **`larz-www`** asks whether a sensitive file in a document root is merely
  present or actually being served, by requesting each candidate through the
  web server. On this estate it confirmed 400 `*.bak-*` files present and all
  **403** - the deny rule added on 2026-10-29 is holding - and a positive
  control in a root with no deny rule was correctly reported **EXPOSED (200)**.
  It requests against `127.0.0.1` with a `Host` header, so it tests the origin
  rather than whatever a CDN in front of it caches.

## 2026-10-31 - three diagnostic CLIs (larz-ports, larz-cron, larz-secrets)

- `larz doctor` already covers identity, engine, AI, packages, wallet and disk.
  These three fill the gaps it leaves, and each is one self-contained
  Larzscript file with no imports, so they install and run on a stock
  Debian/Ubuntu box without converting the machine.
- **`larz-ports`** reads `/proc/net/tcp{,6}` directly and gives every LISTEN
  socket a verdict: `EXPOSED` (bound to `0.0.0.0` or `::`), `IFACE` (one
  address) or `LOCAL` (loopback). `ss` lists sockets but will not tell you which
  of them a stranger can reach, which is the only question that matters. The hex
  in `/proc` is decoded with digit arithmetic because the language has no
  bitwise operators, and the IPv4 octets are reversed (host byte order).
  Verified against `ss -ltnH` on a live box: 40 sockets to `ss`'s 40, and an
  identical exposed-port set (22 80 443 8001 8011 8130 8791).
- **`larz-cron`** collects all six places scheduled work hides - `/etc/crontab`,
  `/etc/cron.d`, every user's spool crontab, the three `run-parts` directories
  and systemd timers - and renders the cron fields as a sentence. On a box with
  56 jobs it describes all 56; anything it cannot describe confidently falls
  back to the raw expression, since a wrong sentence is worse than the syntax.
  Three bugs worth recording: `/etc/crontab` is **tab**-separated, so splitting
  on spaces left whole rows unparsed and shifted the user field; the systemd
  property is `TimersCalendar` (wrapped in `{ OnCalendar=... ; next_elapse=... }`),
  not `OnCalendar`, which returns empty; and a day-of-week range printed raw
  ("weekly on 1-5") reads as once a week when it means five times.
- **`larz-secrets`** walks a tree, separates a real credential from a
  placeholder, and prints the file mode beside each finding - the same secret in
  a `600` file and a `644` file are different problems. Values are always masked
  to their first and last two characters, so output is safe to paste into a
  ticket. Measured on a fixture of 10 planted credentials and 12 lookalike
  placeholders: **10 found, 0 false positives**. Getting there took five rules,
  each from a real false positive rather than a guess:
  - `"secret"` cannot be a substring placeholder, or the real password
    `Sup3rSecretPw99` is discarded for containing it. Exact-match and
    substring placeholder lists are now separate.
  - a value with whitespace is a command line
    (`/p:PackageCertificatePassword=larzos /m /nologo`), not a credential.
  - a value with `$`, `(` or `.get` is a variable reference or a code
    expression (`"$AUTH_TOKEN"`, `usage.get("prompt_tokens", 0)`).
  - `!=` / `==` mean the line *compares* a secret, not defines one;
    splitting on `=` invented a value out of a conditional.
  - in a source file a credential literal is quoted, so an unquoted
    right-hand side is an identifier (`principal.api_key_id`). Config formats
    legitimately leave values bare, so the rule applies only to code.
  - `-` and `_` are word separators, not entropy, so a kebab-case English
    phrase (`"http-endpoint-no-token"`) no longer looks random.
  Those rules took a real tree from 241 findings to 47, all of them in `.env`
  files, stale `.env.bak-*` copies and test fixtures - and left its own
  repository reporting clean.
- All three ship `--json`, since this is the kind of tool that ends up in a cron
  check. Larzscript 1.42 has no `join()` on strings or lists, so the separator
  is tracked by hand.
- Released as 0.1.16 and published to the signed apt repo; verified end to end
  through a sandboxed `apt-get update` against `https://larzos.com/apt`
  (signature checked, candidate 0.1.16, deb downloads).

## 2026-09-10 - LarzOS as its own Windows app (LarzOS.exe + MSIX)

- `windows/` is a fork of Microsoft's `WSL-DistroLauncher` (MIT), rebranded to
  LarzOS: distro name `LarzOS`, output **`LarzOS.exe`**, execution alias
  `larzos.exe`, LarzOS icon + Start tiles + `#0B1020` colour, all strings and
  URLs ours, the "enter a UNIX username" prompt removed (rootfs ships `larz`
  uid 1000).
- **Works with no WSL installed, fully offline.** On first run `LarzOS.exe`
  turns the Windows Linux engine on itself: elevated DISM enables Virtual
  Machine Platform (in-box, no network) and `msiexec` installs the WSL runtime
  from a **`wsl.msi` bundled in the download** (Microsoft's WSL is MIT);
  `wsl --install` is only the backstop when nothing is bundled. Then it drops a
  **LarzOS shortcut on the desktop**, sets a RunOnce to reopen once after
  sign-in, and asks for one restart. Every launch after that is instant.
- Two installers, both offline: `LarzOS_<ver>_x64.msix` (LarzOS as an installed
  app — Start tile, icon; self-signed + `LarzOS.cer` until it's Store-listed)
  and `LarzOS-WSL-<ver>-{x64,arm64}.zip` (loose `LarzOS.exe` + rootfs +
  `wsl.msi`). `larzos-<ver>.wsl` stays for `wsl --install --from-file`.
- CI: `windows.yml` (`windows-launcher-ci`, on `windows-2022`) builds
  `LarzOS.exe` (x64 + ARM64) **and** the signed MSIX on every push touching
  `windows/` — both green. `release.yml` `windows-launcher` fetches
  `microsoft/WSL`'s MIT MSI, bundles it, and attaches the zips + `.msix` +
  `.cer` on a tag.
- Unavoidable prerequisites: 64-bit Windows 10 2004+/11, BIOS virtualization on,
  admin + one restart for that first setup.
- **Compiles in CI; never built or run on a real Windows machine** — the
  elevation / DISM / MSI / reboot-resume / desktop-shortcut path needs
  on-device testing.

## 2026-09-10 - LarzOS as a first-class WSL distribution

- The rootfs now carries `/etc/wsl-distribution.conf`, so it is a branded WSL
  distro, not just an importable tarball. `wsl --install --from-file
  larzos-<ver>.wsl` (WSL 2.4.4+) registers it as **LarzOS** with the LarzOS
  icon (`larz-branding` ships `larzos.ico`), a λ first-run (`wsl-oobe.sh`), a
  Start-menu shortcut, and a LarzOS Windows Terminal profile + colour scheme.
  Default user `larz` (uid 1000).
- `release.yml` publishes `larzos-<ver>.wsl` (= the amd64 rootfs, which contains
  the manifest) alongside the plain tarball.
- `build-rootfs.sh` gained `LARZOS_CLAUDE=0` to build without the ~450 MB
  node + Claude Code layer (for a lean phone/base image).
- Done next: `LarzOS.exe`, the double-click installer (see the entry above).

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
