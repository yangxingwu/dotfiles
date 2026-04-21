# Dotfiles Project Design

Date: 2026-04-21
Type: design
Status: approved

## Overview

A full auto-installer for Mac and Linux development configurations. Not just an archive — it
installs packages, creates symlinks, and handles conflicts. The installer is idempotent: safe
to re-run at any time.

Platform support:
- **macOS**: full install (all modules)
- **Linux**: minimal/server only (core dev tools, no GUI terminals)

---

## Architecture: Modular + Platform Layer

Three approaches were considered:

1. **Flat scripts** — simple but hard to maintain across platforms; no reuse
2. **Config-driven** (YAML/TOML manifest) — clean data, but requires a parser dependency
3. **Modular with central orchestrator** ✅ — self-describing shell modules + `install.sh` as
   orchestrator; no external dependencies, easy to add/remove modules, testable in isolation

**Decision**: Option 3. Each module is a plain `.sh` file that declares its own metadata and
provides a standard interface. The orchestrator sources modules and drives them uniformly.

---

## Directory Structure

```
dotfiles/
├── install.sh                  # entry point / orchestrator
├── uninstall.sh
├── lib/
│   ├── core.sh                 # log / symlink / backup / pkg_install
│   ├── detect.sh               # OS and package manager detection
│   └── preflight.sh            # full conflict scan engine
├── modules/
│   ├── git.sh                  # platform: all
│   ├── zsh.sh                  # platform: all
│   ├── nvim.sh                 # platform: all
│   ├── tmux.sh                 # platform: all
│   ├── ghostty.sh              # platform: mac
│   ├── kitty.sh                # platform: mac
│   └── iterm2.sh               # platform: mac
└── config/
    ├── git/
    │   ├── gitconfig
    │   └── git-hooks/           # commit-msg, pre-commit, pre-push, etc.
    ├── nvim/                    # LazyVim config (symlinked to ~/.config/nvim)
    ├── tmux/
    │   ├── tmux.conf
    │   └── tmux.conf.local
    ├── zsh/
    │   ├── sheldon/
    │   │   └── plugins.toml
    │   └── starship.toml
    ├── ghostty/
    │   └── config
    └── kitty/
```

---

## Module Interface Contract

Every module in `modules/` must declare the following variables and functions:

```bash
# Required metadata
MODULE_NAME="nvim"
MODULE_DESC="Neovim editor config (LazyVim)"
MODULE_PLATFORM="all"           # all | mac | linux

# Symlinks to create: "repo-relative-source:absolute-target"
LINKS=(
  "config/nvim:${HOME}/.config/nvim"
)

# Package dependencies (resolved by lib/detect.sh)
DEPS_MAC=("neovim")
DEPS_LINUX=("neovim")

# Lifecycle hooks (no-op by default)
pre_install()  { :; }
post_install() { :; }
```

Rules:
- `MODULE_PLATFORM` controls whether the orchestrator runs the module on the current OS
- `LINKS[]` entries are processed by `core::symlink` — never raw `ln` calls in modules
- `DEPS_*` entries are passed to `core::pkg_install` — never raw `brew`/`apt` calls in modules
- All user-visible output goes through `lib/core.sh` logging functions

---

## lib/ Layer

### `lib/detect.sh`

Detects runtime environment and exports:
- `DOTFILES_OS` — `mac` | `linux`
- `DOTFILES_PKG_MANAGER` — `brew` | `apt` | `dnf` | `pacman` | `unknown`

Modules never call package managers directly; they declare `DEPS_MAC`/`DEPS_LINUX` and let
`core::pkg_install` dispatch based on `DOTFILES_PKG_MANAGER`.

### `lib/core.sh`

Provides the standard library used by all modules and the orchestrator:

- `core::log <level> <message>` — structured output (INFO / WARN / ERROR)
- `core::symlink <src> <target>` — creates symlink; delegates to preflight results
- `core::backup <path>` — moves file to `~/.dotfiles-backup/YYYYMMDD-HHMMSS/`
- `core::pkg_install <package>` — dispatches to correct package manager

### `lib/preflight.sh`

Full conflict scan engine. Runs before any changes are made.

- Scans every `LINKS[]` entry across all enabled modules
- Collects all conflicts (existing files / symlinks pointing elsewhere)
- Presents one unified summary report to the user
- User chooses one of three resolution strategies:
  - **Backup all** — move all conflicting targets to `~/.dotfiles-backup/YYYYMMDD-HHMMSS/`
  - **Skip all** — leave all conflicting targets untouched (those modules are skipped)
  - **Decide per item** — interactive prompt for each conflict individually

The scan is always full (all modules) before any action is taken — never item-by-item.

---

## Backup Strategy

Backups go to: `~/.dotfiles-backup/YYYYMMDD-HHMMSS/`

The directory mirrors the target path structure, e.g.:
```
~/.dotfiles-backup/20260421-143022/
└── .config/
    └── nvim/          # original contents before symlink was created
```

This makes it easy to restore: `cp -r ~/.dotfiles-backup/20260421-143022/.config/nvim ~/.config/nvim`

---

## DRY_RUN Mode

All destructive operations (`core::symlink`, `core::backup`, `core::pkg_install`) check
`DRY_RUN` before executing:

```bash
DRY_RUN=1 ./install.sh           # full simulation, no system changes
./install.sh --dry-run            # same via flag
./install.sh --module nvim --dry-run   # single module dry run
```

In dry-run mode, every would-be action is logged with a `[DRY-RUN]` prefix.

---

## Idempotency

Running `install.sh` multiple times is safe:
- `core::symlink` checks if the symlink already points to the correct target — skips if so
- `core::pkg_install` checks if the package is already installed — skips if so
- Preflight only reports conflicts for targets that are not already correctly symlinked

---

## Error Handling

- `set -euo pipefail` + `IFS=$'\n\t'` in all scripts
- Any unhandled error exits with a non-zero code and logs to stderr
- Partial installs leave the system in a known state: preflight runs first, no partial
  symlink creation mid-module

---

## Configs to Manage

| Config | Source | Target | Platform |
|---|---|---|---|
| Neovim (LazyVim) | `config/nvim/` | `~/.config/nvim` | all |
| tmux | `config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` | all |
| tmux local | `config/tmux/tmux.conf.local` | `~/.config/tmux/tmux.conf.local` | all |
| sheldon | `config/zsh/sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` | all |
| starship | `config/zsh/starship.toml` | `~/.config/starship.toml` | all |
| gitconfig | `config/git/gitconfig` | `~/.gitconfig` | all |
| git-hooks | `config/git/git-hooks/` | `~/.git-hooks/` | all |
| ghostty | `config/ghostty/config` | `~/.config/ghostty/config` | mac |
| kitty | `config/kitty/` | `~/.config/kitty` | mac |

> Note: `/Volumes/Code/tmux.conf` (standalone) needs to be migrated into `config/tmux/` as
> part of initial setup.
