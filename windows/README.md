# LarzOS on Windows

Two ways to get LarzOS running under WSL. Both give you the same thing: a
distribution that registers as **LarzOS**, drops you in as the `larz` user
(`larzsh` shell, passwordless sudo), with `larz`, `larz-system`, `larz code`
(Claude Code) and `apt` all working.

Requires Windows 10 21H2+ / Windows 11 with WSL installed (`wsl --install` once,
reboot). WSL 2 recommended.

## 1. The `.wsl` file (one command, no download of this launcher)

```powershell
wsl --install --from-file larzos-<ver>.wsl        # WSL 2.4.4+
```

`larzos-<ver>.wsl` is on the [latest release](https://github.com/larz-scripter/larzos-linux/releases/latest).
This uses the branded name, icon, first-run and Windows Terminal profile baked
into the rootfs (`/etc/wsl-distribution.conf`).

## 2. `LarzOS.exe` (double-click installer)

Download **`LarzOS-WSL-<ver>-x64.zip`** (or `-arm64`) from the release, extract
it anywhere, and run **`LarzOS.exe`**. It registers LarzOS from the bundled
`install.tar.gz`, sets `larz` as the default user, and opens a shell. Run it
again any time to get a LarzOS shell; `wsl -d LarzOS` works too.

```
LarzOS.exe                     install if needed, then open a shell
LarzOS.exe install [--root]    install only; --root skips the default user
LarzOS.exe run <command>       run a command inside LarzOS
LarzOS.exe config --default-user <name>
```

The zip is just `LarzOS.exe` + `install.tar.gz`. Keep them together.

## 3. Classic import (any WSL version)

```powershell
wsl --import LarzOS C:\LarzOS larzos-rootfs-amd64-<ver>.tar.gz
wsl -d LarzOS
```

Default user is `root` with this path; `LarzOS.exe config --default-user larz`
(or edit `/etc/wsl.conf`) to switch.

---

## What's in this directory

A fork of Microsoft's [WSL-DistroLauncher](https://github.com/microsoft/WSL-DistroLauncher)
reference implementation (MIT — see `LICENSE`), rebranded for LarzOS:

| Path | What it is |
|---|---|
| `DistroLauncher/` | the `LarzOS.exe` console launcher (plain Win32 + `wslapi.dll`) |
| `DistroLauncher-Appx/` | MSIX packaging project for a Microsoft Store listing |
| `LarzOS.sln` | both projects, for Visual Studio |
| `build.ps1` | local build helper |

Changes from upstream: distro name `LarzOS`, output `LarzOS.exe`, app execution
alias `larzos.exe`, LarzOS icon and tiles, all user-facing strings and URLs, and
the username prompt removed — the rootfs already ships `larz` at uid 1000, so the
launcher just marks it the default.

## Building

`LarzOS.exe` builds with **Visual Studio 2022 + "Desktop development with C++"**
and a Windows SDK — no UWP workload needed:

```powershell
.\build.ps1                      # -> build\x64\LarzOS.exe
```

CI builds it on every push that touches `windows/` (`.github/workflows/windows.yml`)
and, on a tagged release, bundles it with the rootfs into `LarzOS-WSL-<ver>-*.zip`
(`.github/workflows/release.yml`, `windows-launcher` job).

### MSIX / Microsoft Store

`DistroLauncher-Appx/` produces an `.msixbundle` for a Store submission. It needs
the **"Universal Windows Platform development"** workload and a signing
certificate whose subject matches `Publisher="CN=Larz Scripter"` in
`MyDistro.appxmanifest`. This path is **not built or verified in CI yet** — it is
here for the eventual Store listing (see the repo `ROADMAP.md`). The `.wsl` file
and `LarzOS.exe` above are the supported installers today.
