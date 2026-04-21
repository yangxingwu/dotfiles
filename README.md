# dotfiles

Full auto-installer for macOS and Linux development configurations.

## Overview

Installs packages, creates symlinks, and handles conflicts gracefully — not just a config
archive. Re-running is safe: the installer is fully idempotent.

## Platform Support

| Platform | Support |
|---|---|
| macOS | Full (all modules including GUI terminal configs) |
| Linux | Minimal (core dev tools, SSH-friendly, no GUI terminals) |

## Prerequisites

- bash 4+
- git

## Quick Install

```bash
git clone https://github.com/<your-username>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh --dry-run    # preview changes without touching anything
./install.sh              # apply
```

## Modules

| Module | Platform | What it manages |
|---|---|---|
| `git` | all | gitconfig + custom hooks |
| `zsh` | all | sheldon (plugin manager) + starship (prompt) |
| `nvim` | all | Neovim configuration (LazyVim) |
| `tmux` | all | tmux configuration |
| `ghostty` | macOS | Ghostty terminal config |
| `kitty` | macOS | Kitty terminal config |
| `iterm2` | macOS | iTerm2 preferences |

See [`docs/modules/`](docs/modules/) for per-module details.

## Usage

```bash
# Install all modules for the current platform
./install.sh

# Preview without making changes
./install.sh --dry-run

# Install a single module
./install.sh --module nvim

# Preview a single module
./install.sh --module nvim --dry-run
```

## Conflict Handling

Before making any changes, the installer scans all symlink targets for conflicts.
If conflicts are found, you choose one resolution strategy for the entire run:

- **Backup all** — existing files move to `~/.dotfiles-backup/YYYYMMDD-HHMMSS/`
- **Skip all** — conflicting targets are left untouched (those modules are skipped)
- **Interactive** — decide each conflict individually

## Restoring a Backup

```bash
# List available backups
ls ~/.dotfiles-backup/

# Restore a specific file
cp -r ~/.dotfiles-backup/20260421-143022/.config/nvim ~/.config/nvim
```

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).
