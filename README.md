# dotfiles

> **English** | [中文](README.zh-CN.md)

Full auto-installer for macOS and Linux development configurations.

## Overview

Installs packages, writes configs, and manages shell init blocks — not just a config
archive. Re-running is safe: the installer is fully idempotent.

## Platform Support

| Platform | Support |
|---|---|
| macOS | Full (all modules including GUI terminal configs) |
| Linux | Minimal (core dev tools, SSH-friendly, no GUI terminals) |

Architectures: `x86_64` and `arm64` — Apple Silicon and Intel Macs, and
`x86_64`/`arm64` Linux (Ubuntu/Debian via `apt`, Fedora/RHEL via `dnf`).

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

| Module | Platform | Depends on | What it manages |
|---|---|---|---|
| `homebrew` | macOS | — | Homebrew shell environment (.zshrc block) |
| `font-hack-nerd-font` | macOS | — | Hack Nerd Font (Homebrew cask) |
| `ssh` | all | — | SSH client config, key generation, sshpass wrapper, GitHub pubkey |
| `rust` | all | — | Rust toolchain via rustup |
| `golang` | all | — | Go toolchain from go.dev (sha256-verified) |
| `git` | all | ssh, rust, golang | Git config, delta, lazygit, SSH signing, global gitignore |
| `cli-tools` | all | rust | Modern CLI tools: bat, eza, rg, fd, jq, tldr (catppuccin theme) |
| `python` | all | — | Python 3, pip, venv, pipx, ~/.local/bin PATH |
| `nodejs` | all | rust | Node.js runtime via fnm (Fast Node Manager) |
| `fzf` | all | cli-tools | fzf fuzzy finder with fd/bat/eza integration (catppuccin theme) |
| `zoxide` | all | — | zoxide smarter cd command |
| `sheldon` | all | rust | zsh plugin manager + curated plugins |
| `atuin` | all | rust | Atuin shell history with fuzzy search |
| `starship` | all | rust | Starship prompt (catppuccin macchiato) |
| `ghostty` | macOS | — | Ghostty terminal emulator + config |
| `nvim` | all | rust, golang, git, cli-tools, python, nodejs | Neovim + LazyVim configuration |
| `zellij` | all | rust | Zellij terminal multiplexer (catppuccin) |
| `zsh-config` | all | cli-tools | Shell environment, history, options, eza/bat aliases |

Modules run in the order listed above. Platform-gated modules (macOS only) are
automatically skipped on Linux.

## Module Order & Dependencies

The install order in [`lib/modules.sh`](lib/modules.sh) is the single source of
truth, and it is not arbitrary — later modules build on tools installed by earlier
ones. The layering is:

1. **Foundation** — `homebrew` (brew must be on PATH first), fonts, `ssh`.
2. **Language toolchains** — `rust`, then `golang`. `rust` underpins most of the
   installed tooling: `cli-tools`, `sheldon`, `atuin`, `starship`, `zellij`, the
   `fnm` used by `nodejs`, and `tree-sitter-cli` in `nvim` are all built with cargo.
3. **Core tools** — `git` (needs ssh + rust + golang), `cli-tools`, `python`, `nodejs`.
4. **Shell UX** — `fzf`, `zoxide`, `sheldon`, `atuin`, `starship`.
5. **Editor / terminal** — `ghostty`, `nvim` (the heaviest — it depends on rust,
   golang, git, cli-tools, python, and nodejs), `zellij`.
6. **Shell glue last** — `zsh-config` (its aliases assume `eza`/`bat`, its `EDITOR`
   assumes `nvim`).

The `Depends on` column above lists **hard dependencies** that are checked at
install time (via each module's `MODULE_DEPS`). If a required module has not been
installed, the dependent module is skipped with an error. This matters most with
`--only`: pull in the dependencies too, e.g.

```bash
# fzf needs cli-tools, which needs rust — install the whole chain
./install.sh --only rust,cli-tools,fzf
```

A full `./install.sh` always satisfies dependencies because it runs every module
in the correct order.

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

# Use China mirrors (Homebrew USTC, Rust rsproxy.cn, Go goproxy.cn, npm npmmirror.com)
./bootstrap-macos.sh --mirror-cn
./install.sh --mirror-cn

# Show detailed summary after completion
./install.sh --summary

# Combine flags
./install.sh --verbose --summary --only nvim

# List available modules
./install.sh --list

# Uninstall all module configurations
./uninstall.sh

# Uninstall specific modules only
./uninstall.sh --only zellij,nvim

# Show installed modules and timestamps
./install.sh --status
```

### Git Identity

Git identity (`user.name` / `user.email`) is resolved from existing `git config --global`.
If not configured, the installer prompts interactively. For unattended installs (CI),
pre-configure with `git config --global` before running.

### China Mirrors (`--mirror-cn`)

For users in mainland China, pass `--mirror-cn` to both bootstrap and install:

```bash
./bootstrap-macos.sh --mirror-cn   # uses USTC mirror for Homebrew install
./install.sh --mirror-cn           # uses mirrors for cargo, Go, brew bottles
```

This configures:
- **Homebrew**: USTC mirror (`mirrors.ustc.edu.cn`)
- **Rust/cargo**: rsproxy.cn (install script + sparse registry)
- **Go**: `golang.google.cn` (tarball download) + `goproxy.cn` (module proxy)
- **npm**: npmmirror.com (Alibaba/Taobao team, syncs every 10 min)

GitHub access is not handled — set `https_proxy` or `git config --global http.proxy`
before running if GitHub is slow.

### Output Behavior

By default, `install.sh` shows concise progress:

```
[INFO] ▶ [1/18] homebrew — Homebrew shell environment
[INFO] ✓ homebrew
[INFO] ▶ [6/18] git — Git configuration, delta, lazygit, SSH signing
[INFO] ✓ git (1s)
...
[INFO] Install complete: 18 modules (120s). Log: /tmp/dotfiles-install-20260513.log
```

- `--verbose` — shows full output from package managers, compilers, git clones
- `--summary` — shows a detailed box with per-module results after completion
- Log file — all command output is always captured to `/tmp/dotfiles-install-*.log`

## Idempotency

The installer is idempotent — re-running is always safe. Configuration is managed
through **managed blocks** delimited by `# BEGIN dotfiles:<id>` / `# END dotfiles:<id>`
markers. These blocks are automatically updated or removed without affecting
surrounding content.

## Troubleshooting

**`error: bash >= 4.3 required`** — the system bash is too old (macOS ships 3.2).
Run `./bootstrap-macos.sh` first, then either open a new terminal or run
`eval "$(brew shellenv)"` in the current one before `./install.sh`.

**A tool installed by a module isn't found in my current shell** (e.g. `cargo`,
`go`, `nvim`). `install.sh` runs in a child process, so PATH changes it makes don't
affect the shell you launched it from. Open a new terminal, or `source ~/.zshenv`
to pick them up.

**macOS: `brew: command not found` right after bootstrap** — the current shell
hasn't loaded the brew environment yet. Run `eval "$(/opt/homebrew/bin/brew shellenv)"`
(Intel Macs: `/usr/local/bin/brew`). The `homebrew` module writes this into
`~/.zshrc` so future terminals pick it up automatically.

**Linux: login shell didn't change to zsh** — `chsh` can fail for accounts not in
the local `/etc/passwd` (LDAP/SSSD). Workaround: add `RemoteCommand /usr/bin/zsh -l`
to your SSH client config, or ask an administrator to change the shell.

**macOS: Xcode Command Line Tools install hangs or times out** — install it
manually with `xcode-select --install`, wait for it to finish, then re-run
`./bootstrap-macos.sh`.

**`<module> requires: … — not installed`** — you used `--only` and skipped a
dependency. Include the dependency (see [Module Order & Dependencies](#module-order--dependencies)),
or run the full `./install.sh`.

**`git status` is slow / Starship prompt occasionally times out** — do **not**
enable `fsmonitor` globally; it spawns a persistent daemon per repo. Enable it
per-repo only on large codebases: `git -C /path/to/large-repo config core.fsmonitor true`.

**CI / non-interactive: git identity or SSH signing key was skipped** — identity
prompts and the GitHub signing-key upload require a TTY. Pre-configure
`git config --global user.name` / `user.email`; the signing-key push is skipped in
non-interactive environments by design.

## Manual Cleanup After Uninstall

`./uninstall.sh` removes config files, managed blocks, and module side effects.
The following are **not** removed — clean up manually if desired:

- Rust toolchain: `rustup self uninstall`
- SSH keys: `rm -rf ~/.ssh/` (caution: destroys all keys)
- Installed packages: uninstall via your package manager
- Go toolchain: `sudo rm -rf /usr/local/go`

## Documentation

- [User Guide (English)](docs/guide.md) — what you get after install, how to use each tool
- [User Guide (中文)](docs/guide.zh-CN.md) — the same guide, in Chinese
