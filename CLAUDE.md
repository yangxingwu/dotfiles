# dotfiles

A full auto-installer for macOS and Linux development configurations. Not just a config
archive — it installs packages, creates symlinks, and handles conflicts gracefully.

## Platform Support

- **macOS**: full install (all modules including GUI terminal configs)
- **Linux**: minimal/server install (core dev tools only, no GUI)

## Architecture

See `docs/changes/2026-04-21-dotfiles-project-design/design.md` for the initial design
and `docs/changes/2026-04-22-system-optimization/design.md` for the current shape.

Key invariants:
- **Idempotent**: safe to run `install.sh` multiple times; conflicts prompt the user per
  symlink inside `core::symlink`.
- **No direct package manager calls in modules**: use `core::pkg_install` inside
  `install()`; never call brew/apt/dnf/pacman directly.

## Module Interface Contract

Every file in `modules/` must declare:

```bash
MODULE_NAME="<name>"
MODULE_DESC="<description>"
MODULE_PLATFORM="all"           # all | mac | linux

LINKS=(
  "config/<name>/file:${HOME}/.config/<name>/file"
)

install()   { :; }   # install packages / external tools / clone external repos
uninstall() { :; }   # clean up install()'s external side effects
```

Both hooks are required. Use `{ :; }` when a module has nothing to do.

Execution order:
- `./install.sh`:   `install() → LINKS`
- `./uninstall.sh`: `LINKS → uninstall()`

## Development Workflow

**Large changes** (new modules, architecture changes):
1. Run `superpowers:brainstorm` → produces `docs/changes/YYYY-MM-DD-<topic>/design.md`
2. Run `writing-plans` → produces `docs/changes/YYYY-MM-DD-<topic>/tasks.md`
3. Implement
4. Run `/change` to record a lightweight summary (optional if design.md covers it)

**Small changes** (bugfix, config tweak, small feature):
1. Implement directly
2. Session end: Stop hook will remind you if changes are undocumented
3. Run `/change` to record the change

All change docs save to `docs/changes/YYYY-MM-DD-<slug>/`.

## Shell Script Standards

See `.claude/rules/shell-style.md` (auto-loaded each session).

## Language

All code, comments, and documentation must be written in **English**.
