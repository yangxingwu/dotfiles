# dotfiles

A full auto-installer for macOS and Linux development configurations. Not just a config
archive — it installs packages, writes configs, and manages shell init blocks.

## Platform Support

- **macOS**: full install (all modules including GUI terminal configs)
- **Linux**: minimal/server install (core dev tools only, no GUI)

## Architecture

See `docs/changes/2026-04-21-dotfiles-project-design/design.md` for the initial design
and `docs/changes/2026-04-22-system-optimization/design.md` for the current shape.

Key invariants:
- **Idempotent**: safe to run `install.sh` multiple times.
- **No direct package manager calls in modules**: use `core::pkg_install` inside
  `install()`; never call brew/apt/dnf directly. Exception: modules that install
  via cargo, curl, or rustup (sheldon, starship, rust) handle it themselves.

## Module Interface Contract

Every file in `modules/` must declare:

```bash
MODULE_NAME="<name>"
MODULE_DESC="<description>"
MODULE_PLATFORM="all"           # all | mac | linux

install()   { :; }   # install packages / external tools / write config files
uninstall() { :; }   # clean up install()'s side effects
```

Both hooks are required. Use `{ :; }` when a module has nothing to do.

**Hook responsibilities:**

- `install()` runs after bootstrap + `detect::pkg_manager`, so it may assume
  `DOTFILES_OS` and `DOTFILES_PKG_MANAGER` are both set and that
  `core::pkg_install` works. Use `core::pkg_install` for packages; never call
  brew/apt/dnf directly (per the invariant above). Config files are written
  inline (heredoc, `git config`, `core::ensure_block`, etc.).

- `uninstall()` runs only after `detect::os`, so it may use `DOTFILES_OS`
  (the orchestrator's platform gate uses it) but **must not** depend on
  `DOTFILES_PKG_MANAGER`: no `core::pkg_install` calls, no direct brew/apt/dnf
  calls, no reads of the variable. Uninstall must succeed on a machine whose
  package manager is gone or broken — its job is to clean up this module's
  own side effects (config files, clones, downloaded files, build artefacts).

Execution order:
- `./install.sh`:   runs `install()` for each module
- `./uninstall.sh`: runs `uninstall()` for each module

## Development Workflow

**Large changes** (new modules, architecture changes):
1. Run `superpowers:brainstorming` → produces `docs/changes/YYYY-MM-DD-<topic>/design.md`
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

## Testing

Integration tests run in CI via GitHub Actions (`.github/workflows/test.yml`):
- **macOS**: `macos-latest` runner
- **Ubuntu**: Docker container (`tests/Dockerfile.ubuntu`)
- **Fedora**: Docker container (`tests/Dockerfile.fedora`)

Test script: `tests/test_install.sh` — runs install.sh, verifies binaries/configs/blocks,
runs uninstall.sh, verifies cleanup. Do NOT run locally — it modifies the environment.

Manual trigger: `gh workflow run "Integration Tests"`

## Language

All code, comments, and documentation must be written in **English**.
