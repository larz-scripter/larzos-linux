# LarzOS on Windows

LarzOS runs on Windows as **its own app** — its own icon, its own Start-menu
entry, its own Windows Terminal profile. You click it and you're in LarzOS. It
uses the Windows Linux engine (the same one Ubuntu, Debian and Kali use on
Windows) underneath, but nothing in the UI says "WSL".

One prerequisite, one time: the Windows Linux engine must be turned on. Most
Windows 11 machines already have it. If not, LarzOS tells you to run
`wsl --install --no-distribution` in an admin PowerShell and reboot — after that
you never touch it again. (There is no way to give a real Linux environment on
Windows without this component or a full virtual machine.)

## 1. `LarzOS` — the installed app (recommended)

Download **`LarzOS_<ver>_x64.msix`** + **`LarzOS.cer`** from the
[latest release](https://github.com/larz-scripter/larzos-linux/releases/latest).

1. Double-click `LarzOS.cer` → *Install Certificate* → *Local Machine* →
   *Place all certificates in the following store* → *Trusted People*. (One time;
   this is only needed until LarzOS is in the Microsoft Store.)
2. Double-click `LarzOS_<ver>_x64.msix` → *Install*.

**LarzOS** is now in your Start menu with the LarzOS icon. Click it → first
launch unpacks (about a minute), then a LarzOS shell opens as the `larz` user.
Every launch after that is instant. Windows Terminal gets a **LarzOS** profile
automatically.

## 2. `LarzOS.exe` — the loose version (no install step)

Download **`LarzOS-WSL-<ver>-x64.zip`**, extract it anywhere, run **`LarzOS.exe`**.
First run registers LarzOS and opens a shell; run it again any time for a shell.
The zip is just `LarzOS.exe` + `install.tar.gz` — keep them together. Windows
SmartScreen shows an "unknown publisher" notice on the first run (*More info →
Run anyway*); that goes away once LarzOS is Store-signed.

```
LarzOS.exe                     install if needed, then open a shell
LarzOS.exe install [--root]    install only; --root skips the default user
LarzOS.exe run <command>       run a command inside LarzOS
LarzOS.exe config --default-user <name>
```

## 3. `.wsl` file — one command, for people who use `wsl` directly

```powershell
wsl --install --from-file larzos-<ver>.wsl        # WSL 2.4.4+
```

Same branded result (name, icon, first-run, terminal profile are baked into the
rootfs), registered through the `wsl` CLI. Classic import for older WSL:
`wsl --import LarzOS C:\LarzOS larzos-rootfs-amd64-<ver>.tar.gz`.

---

## What's in this directory

A fork of Microsoft's [WSL-DistroLauncher](https://github.com/microsoft/WSL-DistroLauncher)
reference implementation (MIT — see `LICENSE`), rebranded for LarzOS. This is the
same mechanism the first-party Ubuntu/Debian/Kali Windows apps are built on.

| Path | What it is |
|---|---|
| `DistroLauncher/` | `LarzOS.exe` — the console launcher (plain Win32 + `wslapi.dll`) |
| `DistroLauncher-Appx/` | the MSIX packaging project — makes `LarzOS.exe` an installed app |
| `LarzOS.sln` | both projects, for Visual Studio |
| `build.ps1` | local build helper (`-Appx` also builds the MSIX) |

Changes from upstream: distro name `LarzOS`, output `LarzOS.exe`, app execution
alias `larzos.exe`, LarzOS icon + tiles, `#0B1020` splash/tile colour, all
user-facing strings and URLs, the "enter a UNIX username" prompt removed (the
rootfs ships `larz` at uid 1000, so the launcher just marks it the default), and
a LarzOS-worded message when the Windows Linux engine is off.

## Building

`LarzOS.exe` alone builds with **Visual Studio 2022 + "Desktop development with
C++"** and a Windows SDK:

```powershell
.\build.ps1                      # -> build\x64\LarzOS.exe
.\build.ps1 -Appx                # also the MSIX (needs the UWP workload)
```

CI (`.github/workflows/windows.yml`) builds both `LarzOS.exe` (x64 + ARM64) and
the signed MSIX on every push touching `windows/`. On a tagged release,
`release.yml` bundles `LarzOS.exe` with the rootfs into `LarzOS-WSL-<ver>-*.zip`
and attaches the `.msix` + `.cer`.

### Microsoft Store

The MSIX is currently **self-signed** (hence the certificate step above). A Store
listing — clean double-click install, no certificate, auto-updates — needs a
Microsoft Partner Center account and a submission; that is tracked in the repo
`ROADMAP.md`.
