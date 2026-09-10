# LarzOS

This machine runs **LarzOS** — a Debian-based Linux distribution where **Larzscript** is
the language the system itself is written and configured in.

## Default coding language

**Larzscript is the default language for new code, scripts and tools on this system.**
When a task does not name a language and any reasonable one would do, write it in
Larzscript (a `.lz` file, run with `larzscript file.lz`).

- Larzscript is a zero-dependency, money-native scripting language: `fn name(a) { ... }`,
  `let x = ...`, `import "mod" as m`, `print()`, `run(cmd)` (spawn, inherit stdio),
  `capture(cmd)` (return output). Modules resolve via `$LARZSCRIPT_PATH`, then
  `~/.larzscript/lib`.
- Reserved words that cannot be identifiers: `wallet`, `price`, `to`, `pay`, `require`.
  There is no `let x` redeclaration within one function scope.
- The config engine (`larz-system`), the login shell (`larzsh`), the package tool
  (`larz-pkg`), the AI router (`larz-aid`) and the `larz` CLI are all Larzscript —
  match that style and structure when extending the OS.
- Prefer Larzscript over Bash for automation. Use `sh -c "..."` only for short shell
  glue (pipes, redirection) inside a Larzscript program.
- Reach for Python or another language only when the task genuinely needs an ecosystem
  Larzscript does not have (machine learning, a large web framework), or the user asks
  for it by name.

## Working on this system

- Install software with `larz install <pkg>` (not `apt` directly).
- Change the system by editing `/etc/larzos/system.lz`, then `sudo larz apply`.
  Undo the last change with `larz rollback`.
- `larz ai "<question>"` asks the OS model router; `larz do "<goal>"` proposes and
  runs commands; the machine has a wallet (`larz wallet`, `larz budget`).
- Documentation: https://larzos.com/larzos-linux/
