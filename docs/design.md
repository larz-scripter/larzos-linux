# LarzOS design notes

## The idea

One language — Larzscript — for everything a human writes to run the
machine. The system is a declaration; `larz-system` makes reality match it.
This is the Guix/Nix model with a Debian executor underneath instead of a
custom one.

## Evaluation vs realization

These are deliberately separate:

1. **Evaluation.** A `system.lz` file is run as an ordinary Larzscript
   program. It may compute anything, then calls `larzos.system(spec)`.
   That call normalizes the spec (fills defaults, checks shape) and, when
   `$LARZOS_SPEC_OUT` is set, writes the canonical spec as JSON. The spec
   file never touches the system.

2. **Realization.** `larz-system` sets `$LARZOS_SPEC_OUT`, runs the spec
   file in a subprocess, reads the JSON back, then asks each module to
   diff it against the live system and (on `apply`) execute the diff.

Because evaluation is a plain subprocess, a broken or malicious spec can't
corrupt `larz-system`'s own state, and the spec language is the full
language — no restricted DSL.

## The module contract

A realization module is `lib/larzos/modules/<id>.lz` and exports:

```larzscript
let id    = "hostname"        # stable identifier
let title = "Hostname"        # heading shown in plans

fn plan(spec, ctx) {         # -> list of action tables
  # inspect the live system, compare to `spec`, return actions
}
```

An **action** is one of:

```larzscript
{ "desc": "...", "cmd": "shell command", "skip": false }   # run a command
{ "desc": "...", "file": "/path", "content": "...", "skip": false }  # write a file
{ "desc": "...", "cmd": "", "skip": true }                 # already converged
```

`plan()` must be pure-ish: it reads system state, never changes it.
`larz-system apply` is what runs `cmd` / writes `file`. Modules should
always return at least one action so the plan shows the area was checked.

Modules run in the order listed in `bin/larz-system` (`MODULES`).
`hostname` and `locale` first, `packages` before `services` (so a unit a
package ships exists before we enable it), `audio`/`ai` last (they only
write config).

### Current modules

| id | converges |
|----|-----------|
| `hostname` | `/etc/hostname` via `hostnamectl` |
| `locale` | timezone (`timedatectl`) + `LANG` (`locale-gen`) |
| `users` | account existence, login shell, group membership (never deletes) |
| `packages` | installs missing packages via `apt-get` (no removal yet) |
| `systemd` | renders `spec.units` to `/etc/systemd/system/*` + `daemon-reload` |
| `services` | `systemctl enable --now` / `disable --now` to match `services.*` |
| `audio` | `/etc/pipewire/pipewire.conf.d/99-larzos.conf` from `audio.profile` |
| `ai` | `/etc/larzos/ai.toml` from `ai.*`, consumed by `larz-aid` |

## The package format

`packages/<name>/package.lz` calls `pkg.package({...})` (from
`lib/larzos/pkg.lz`). Fields: `name`, `version`, `summary` (required);
`arch` (default `all`), `maintainer`, `depends`, `section`, `build`,
`install`.

`build` lines run in the package source directory. `install` lines run
with `$DESTDIR` pointing at a staged root; they populate it (`install
-Dm755 files/x $DESTDIR/usr/bin/x`). `larz-pkg deb <dir>` stages, writes
`DEBIAN/control` from the definition, and calls `dpkg-deb`.

The output is a normal `.deb`. The `.lz` file is just a cleaner, testable
way to author one than hand-maintained `debian/` trees — and it's
Larzscript, so it fits the rest of the system.

## `system.lz` schema (v1)

```
hostname   string
timezone   string                          default "UTC"
locale     string                          default "en_US.UTF-8"
users      list of {
             name    string  (required)
             groups  list of string        default []
             shell   string                default "/bin/bash"
             sudo    bool  (auto-true if "sudo" in groups)
           }
packages   list of string
services   map of name -> "enabled" | "disabled"   (name may be foo or foo.timer)
units      map of unit-filename -> { Section -> { key -> value } }
             value: string | number | bool (-> yes/no) | list (-> repeated key= lines)
             written to /etc/systemd/system; a change runs daemon-reload
audio      { profile "pro"|"desktop"|"off", rate int, quantum int }
ai         { local_models list of string, gateway string }
```

Unknown top-level keys are currently ignored; that will become a warning.
