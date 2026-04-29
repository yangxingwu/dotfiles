# dotfiles

Full auto-installer for macOS and Linux development configurations.

## Overview

Installs packages, writes configs, and manages shell init blocks — not just a config
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
| `font-hack-nerd-font` | macOS | Hack Nerd Font (Homebrew cask) |
| `git` | all | Git global config (user.name, user.email) |
| `rust` | all | Rust toolchain via rustup |
| `fzf` | all | fzf fuzzy finder + zsh key bindings |
| `zoxide` | all | zoxide smarter cd command |
| `sheldon` | all | zsh plugin manager + curated plugins |
| `starship` | all | Starship prompt (catppuccin-powerline preset) |
| `ghostty` | macOS | Ghostty terminal emulator + config |
| `nvim` | all | Neovim + LazyVim configuration |
| `tmux` | all | tmux + oh-my-tmux |

See [`docs/modules/`](docs/modules/) for per-module details.

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

# Remove all dotfile configurations and clean up module side effects
./uninstall.sh
```

## Idempotency

The installer is idempotent — re-running is always safe. Configuration is managed
through **managed blocks** delimited by `# BEGIN dotfiles:<id>` / `# END dotfiles:<id>`
markers. These blocks are automatically updated or removed without prompting. Each
module is responsible for handling conflicts with existing configurations:

- If a module cannot safely replace an existing file, it logs a `WARN` and skips that step
- The module may offer an interactive prompt for user guidance (e.g., the `nvim` module)
- On re-run, the installer will attempt the same steps again

This design ensures the installer never silently overwrites user data without prior notice.

## Manual Cleanup After Uninstall

`./uninstall.sh` removes config files, managed blocks, and cleans up each module's
external side effects (oh-my-tmux clone, LazyVim config, etc.). The following are
**not** removed automatically — clean up manually if desired:

- Rust toolchain: `rustup self uninstall`
- Installed packages: uninstall via your package manager
- Backups: `rm -rf ~/.dotfiles-backup/`

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).
