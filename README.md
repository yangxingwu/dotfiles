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

## Quick Start

```bash
git clone https://github.com/yangxingwu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Step 1: Bootstrap (one-time environment setup)
./bootstrap-macos.sh   # macOS
./bootstrap-linux.sh   # Linux (Ubuntu/Fedora)

# Step 2: Install modules
./install.sh
```

## Bootstrap

Bootstrap scripts prepare the environment once on a fresh machine. They are
idempotent — safe to re-run.

**macOS** (`./bootstrap-macos.sh`):
- Xcode Command Line Tools
- Homebrew
- Modern bash (>= 4.3)
- Verify zsh + set as login shell
- Dev tools (cmake, meson, ninja, gettext)
- Shell skeleton files (~/.zshrc, ~/.zprofile, ~/.zshenv)

**Linux** (`./bootstrap-linux.sh`):
- zsh + set as login shell
- Dev tools (git, curl, cmake, meson, ninja-build, build-essential, etc.)
- Shell skeleton files

After bootstrap, run `./install.sh` to install modules.

## Modules

| Module | Platform | What it manages |
|---|---|---|
| `homebrew` | macOS | Homebrew shell environment (.zprofile block) |
| `font-hack-nerd-font` | macOS | Hack Nerd Font (Homebrew cask) |
| `git` | all | Git global config (user.name, user.email) |
| `ssh` | all | SSH client config, key generation, sshpass wrapper, GitHub pubkey |
| `rust` | all | Rust toolchain via rustup |
| `golang` | all | Go toolchain from go.dev |
| `cli-tools` | all | Modern CLI tools: bat, eza, rg, fd, jq, tldr (catppuccin theme) |
| `fzf` | all | fzf fuzzy finder + zsh key bindings |
| `zoxide` | all | zoxide smarter cd command |
| `sheldon` | all | zsh plugin manager + curated plugins |
| `atuin` | all | Atuin shell history with fuzzy search |
| `starship` | all | Starship prompt (catppuccin-powerline preset) |
| `ghostty` | macOS | Ghostty terminal emulator + config |
| `nvim` | all | Neovim + LazyVim configuration |
| `tmux` | all | tmux + oh-my-tmux |

Modules run in the order listed above. Platform-gated modules (macOS only) are
automatically skipped on Linux.

## Usage

```bash
# Install all modules
./install.sh

# Install only specific modules
./install.sh --only ssh,git,rust

# Skip specific modules
./install.sh --skip ghostty,font-hack-nerd-font

# Show full command output (package manager, compiler, etc.)
./install.sh --verbose

# Show detailed summary after completion
./install.sh --summary

# Combine flags
./install.sh --verbose --summary --only nvim

# List available modules
./install.sh --list

# Uninstall all module configurations
./uninstall.sh

# Uninstall specific modules only
./uninstall.sh --only tmux,nvim
```

### Output Behavior

By default, `install.sh` shows concise progress:

```
[INFO] ▶ [1/14] homebrew — Homebrew shell environment
[INFO] ✓ homebrew
[INFO] ▶ [2/14] git — Git configuration
[INFO] Wrote git global config
[INFO] ✓ git (0s)
...
[INFO] Install complete: 14 modules (120s). Log: /tmp/dotfiles-install-20260513.log
```

- `--verbose` — shows full output from package managers, compilers, git clones
- `--summary` — shows a detailed box with per-module results after completion
- Log file — all command output is always captured to `/tmp/dotfiles-install-*.log`

## Idempotency

The installer is idempotent — re-running is always safe. Configuration is managed
through **managed blocks** delimited by `# BEGIN dotfiles:<id>` / `# END dotfiles:<id>`
markers. These blocks are automatically updated or removed without affecting
surrounding content.

## Manual Cleanup After Uninstall

`./uninstall.sh` removes config files, managed blocks, and module side effects.
The following are **not** removed — clean up manually if desired:

- Rust toolchain: `rustup self uninstall`
- SSH keys: `rm -rf ~/.ssh/` (caution: destroys all keys)
- Installed packages: uninstall via your package manager
- Go toolchain: `sudo rm -rf /usr/local/go`
