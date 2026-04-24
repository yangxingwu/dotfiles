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

Everything else — Xcode CLT, Homebrew, git, curl, zsh, a C toolchain, cmake,
meson, ninja, gettext — is installed automatically on first run.

## Quick Install

```bash
git clone https://github.com/<your-username>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

First run on a clean machine may take several minutes. On macOS, the
installer triggers `xcode-select --install` (GUI confirmation required)
and then runs Homebrew's official installer (sudo password required).
On Linux, it installs zsh, git, curl and a compiler toolchain via your
system's package manager (sudo required).

## Modules

| Module | Platform | What it manages |
|---|---|---|
| `git` | all | gitconfig + custom hooks |
| `fzf` | all | fzf fuzzy finder + zsh key bindings |
| `sheldon` | all | zsh plugin manager + curated plugins |
| `starship` | all | Starship prompt (catppuccin-powerline preset) |
| `nvim` | all | Neovim + LazyVim configuration |
| `tmux` | all | tmux + oh-my-tmux configuration |
| `ghostty` | macOS | Ghostty terminal config |

See [`docs/modules/`](docs/modules/) for per-module details. (The `rust` module runs as
an internal dependency of `nvim`; it is not a user-facing module.)

The zsh shell itself, `~/.zshrc`, `~/.zprofile`, and `~/.zshenv` are
managed by the installer's bootstrap stage, not by a module. Each tool
module (fzf / sheldon / starship) writes its own initialization block
into `~/.zshrc`; `bootstrap::homebrew` and the rust module write to
`~/.zprofile`. Blocks are delimited by `# BEGIN dotfiles:<id>` /
`# END dotfiles:<id>` markers and are safe to re-apply — only content
inside the markers is overwritten on re-run.

## Usage

```bash
# Install all modules for the current platform
./install.sh

# Remove all dotfile symlinks and clean up module side effects
./uninstall.sh
```

## Conflict Handling

When `install.sh` tries to create a symlink and the target already exists as a real file
or a foreign symlink, you get an interactive prompt per conflict:

- **[b] backup** — existing file moves to `~/.dotfiles-backup/YYYYMMDD-HHMMSS/`, symlink created
- **[s] skip**   — this symlink is not created; your file is preserved (module may end up incomplete)
- **[q] quit**   — installer exits; fix things and re-run

The installer is idempotent — re-running is always safe.

## Restoring a Backup

```bash
# List available backups
ls ~/.dotfiles-backup/

# Restore a specific file
cp -r ~/.dotfiles-backup/20260421-143022/.config/nvim ~/.config/nvim
```

## Manual Cleanup After Uninstall

`./uninstall.sh` removes managed symlinks and cleans up each module's external side
effects (oh-my-tmux clone, LazyVim config, etc.). The following are **not** removed
automatically — clean up manually if desired:

- Rust toolchain: `rustup self uninstall`
- Installed packages: uninstall via your package manager
- Backups: `rm -rf ~/.dotfiles-backup/`

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).
