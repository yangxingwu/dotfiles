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

**Hook responsibilities:**

- `install()` runs after bootstrap + `detect::pkg_manager`, so it may assume
  `DOTFILES_OS` and `DOTFILES_PKG_MANAGER` are both set and that
  `core::pkg_install` works. Use `core::pkg_install` for packages; never call
  brew/apt/dnf directly (per the invariant above).

- `uninstall()` runs only after `detect::os`, so it may use `DOTFILES_OS`
  (the orchestrator's platform gate uses it) but **must not** depend on
  `DOTFILES_PKG_MANAGER`: no `core::pkg_install` calls, no direct brew/apt/dnf
  calls, no reads of the variable. Uninstall must succeed on a machine whose
  package manager is gone or broken — its job is to clean up this module's
  own side effects (clones, downloaded files, build artefacts). Symlink
  removal is handled by the orchestrator from `LINKS`, not by the hook.

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
