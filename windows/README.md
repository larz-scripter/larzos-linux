# LarzOS on Windows

LarzOS runs on Windows as **its own app** — own icon, own desktop shortcut, own
Start-menu entry, own Windows Terminal profile. Double-click it and you're in
LarzOS. Under the hood it uses the Windows Linux engine (the same component
Ubuntu, Debian and Kali use on Windows), but nothing in the UI says "WSL", and
**LarzOS sets that engine up itself on first run** — the user never installs WSL
or opens a Store page.

## First run, on a PC that has never had WSL

1. Double-click LarzOS.
2. It says it's doing a one-time setup; Windows asks permission → **Yes**.
3. LarzOS turns on the Windows virtualization feature and installs the Linux
   engine **from a copy bundled inside LarzOS** — no internet needed.
4. "Restart Windows." A **LarzOS icon is now on the desktop**; after the restart,
   double-click it (it also opens once on its own after you sign back in).
5. LarzOS unpacks (about a minute) and a shell opens as the `larz` user.

Every launch after that is instant.

The only things that genuinely can't be removed: 64-bit Windows 10 2004+ / 11,
CPU virtualization enabled in BIOS (on by default on most machines), admin + one
restart for that first setup. A real Linux environment on Windows needs the
virtualization feature or a full VM — there's no way around it in a plain `.exe`.

## Installers

Both come off the [latest release](https://github.com/larz-scripter/larzos-linux/releases/latest),
both are **fully offline** (the Linux engine is bundled):

### `LarzOS_<ver>_x64.msix` — the installed app (recommended)

Download it plus `LarzOS.cer`. Once:
`LarzOS.cer` → *Install Certificate* → *Local Machine* → *Trusted People*
(needed only until LarzOS is in the Microsoft Store). Then double-click the
`.msix` → *Install*. **LarzOS** lands in the Start menu; first launch does the
engine setup above and drops the desktop icon.

### `LarzOS-WSL-<ver>-x64.zip` — the loose version

Extract anywhere, run **`LarzOS.exe`**. Same first-run flow. The zip is
`LarzOS.exe` + `install.tar.gz` (the LarzOS rootfs) + `wsl.msi` (the offline
engine) — keep them together. SmartScreen shows "unknown publisher" once
(*More info → Run anyway*) until LarzOS is Store-signed.

### `larzos-<ver>.wsl` — for people who use `wsl` directly

`wsl --install --from-file larzos-<ver>.wsl` (WSL 2.4.4+). Assumes WSL is
already set up; doesn't carry the bundled engine.

---

## What's in this directory

A fork of Microsoft's [WSL-DistroLauncher](https://github.com/microsoft/WSL-DistroLauncher)
(MIT — see `LICENSE`), the same mechanism the first-party Ubuntu/Debian/Kali
Windows apps use.

| Path | What it is |
|---|---|
| `DistroLauncher/` | `LarzOS.exe` — the launcher + first-run engine setup (Win32 + `wslapi.dll`) |
| `DistroLauncher-Appx/` | the MSIX packaging project — makes LarzOS an installed app |
| `LarzOS.sln` | both projects, for Visual Studio |
| `build.ps1` | local build helper (`-Appx` also builds the MSIX) |

Changes from upstream: distro name `LarzOS`, output `LarzOS.exe`, execution
alias `larzos.exe`, LarzOS icon + tiles + `#0B1020` colour, all user-facing
strings/URLs, no username prompt (rootfs ships `larz` uid 1000), **first-run
engine bootstrap** (`EnsureEngine` in `DistroLauncher.cpp`: DISM +
bundled `wsl.msi`, or `wsl --install` as backstop), and a desktop shortcut +
RunOnce resume after the setup reboot.

## Building

`LarzOS.exe` alone: **Visual Studio 2022 + "Desktop development with C++"** + a
Windows SDK.

```powershell
.\build.ps1            # -> build\x64\LarzOS.exe
.\build.ps1 -Appx      # also the MSIX (needs the UWP workload + a cert)
```

CI (`.github/workflows/windows.yml`) builds `LarzOS.exe` (x64 + ARM64) and the
signed MSIX on every push touching `windows/`. On a tag, `release.yml` fetches
`microsoft/WSL`'s MIT runtime MSI, bundles it, and attaches the zips + `.msix` +
`.cer`.

> **Status:** everything here compiles in CI. It has **not** been run on a real
> Windows machine yet — the first-run elevation / DISM / reboot-resume path in
> particular needs on-device testing.

### Microsoft Store

The MSIX is **self-signed** today (hence the certificate step). A Store listing —
clean install, no cert, auto-updates — needs a Partner Center account; tracked in
the repo `ROADMAP.md`.
