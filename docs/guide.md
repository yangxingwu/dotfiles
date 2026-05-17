# Dotfiles User Guide

A detailed reference for everything installed and configured by this dotfiles project.
After running `./install.sh`, this guide tells you what you got, how to use it, and
where to find configuration files.

---

## Table of Contents

1. [Shell Environment](#shell-environment)
2. [Fuzzy Finding and Navigation](#fuzzy-finding-and-navigation)
3. [Modern CLI Tools](#modern-cli-tools)
4. [Git and Version Control](#git-and-version-control)
5. [Programming Languages](#programming-languages)
6. [Terminal and Editor](#terminal-and-editor)
7. [SSH](#ssh)
8. [Theme](#theme)
9. [Configuration Files](#configuration-files)
10. [Day-to-Day Operations](#day-to-day-operations)

---

## Shell Environment

### zsh

**What it is:** The Z shell — a modern, POSIX-compatible shell with better
completion, globbing, and scripting features than bash.

**Why this tool:** zsh is the default shell on macOS and offers superior
interactive features (programmable completion, shared history, spelling
correction) while remaining compatible with bash scripts.

**Common usage:**

```bash
# Your shell is already zsh after install. Key features:
# - Tab completion with descriptions
# - Shared history across terminals
# - Glob qualifiers: ls *(.) lists only files, ls *(/) lists only directories
```

**Config location:** `~/.zshrc` (managed blocks written by modules), `~/.zprofile` (PATH setup)

---

### sheldon

**What it is:** A fast, configurable zsh plugin manager written in Rust.

**Why this tool:** sheldon uses a declarative TOML config, installs plugins in
parallel, and generates a single `source` eval — no slow plugin-by-plugin loading
at shell startup.

**Plugins installed:**

| Plugin | Purpose |
|---|---|
| `zsh-users/zsh-autosuggestions` | Fish-like inline command suggestions (grayed text from history) |
| `zsh-users/zsh-syntax-highlighting` | Syntax coloring as you type (valid commands = green, errors = red) |
| `zsh-users/zsh-completions` | Additional completion definitions for hundreds of commands |
| `Aloxaf/fzf-tab` | Replaces default tab completion with fzf-powered fuzzy matching |
| `mattmc3/zsh-safe-rm` | Moves files to trash instead of permanent deletion on `rm` |

**Common usage:**

```bash
# Update all plugins to latest versions
sheldon lock --update

# List installed plugins
sheldon list

# The plugins load automatically — no action needed after install
```

**Config location:** `~/.config/sheldon/plugins.toml`

---

### atuin

**What it is:** A shell history replacement that stores commands in a SQLite
database with full-text search, context (directory, exit code, duration), and a
full-screen TUI for browsing.

**Why this tool:** Traditional shell history is a flat file with no metadata.
Atuin lets you search by command text, filter by directory or exit status, and
see how long commands took. Cloud sync is available but disabled by default
(local history only).

**Common usage:**

```bash
# Press Ctrl+R or Up arrow to open the full-screen history search
# Type to filter, arrow keys to navigate, Enter to select

# Search history from the command line
atuin search "docker"

# Show stats about your shell usage
atuin stats
```

**Config location:** `~/.config/atuin/config.toml`

---

### starship

**What it is:** A cross-shell prompt written in Rust that shows contextual
information (git branch, language versions, command duration, exit status) with
minimal latency.

**Why this tool:** Starship renders in under 10ms, works identically across
shells, and supports every dev ecosystem out of the box. The catppuccin-powerline
preset gives a clean, informative prompt with consistent theming.

**What you see in your prompt:**

- Current directory (abbreviated)
- Git branch + status (dirty, ahead/behind, conflicts)
- Language versions when inside a project (Rust, Go, Python, Node)
- Command duration (if > 2s)
- Exit code indicator (red on failure)

**Common usage:**

```bash
# The prompt configures itself automatically. To customize:
nvim ~/.config/starship.toml

# Regenerate from the preset (overwrites customizations)
starship preset catppuccin-powerline --output ~/.config/starship.toml
```

**Config location:** `~/.config/starship.toml`

---

## Fuzzy Finding and Navigation

### fzf

**What it is:** A general-purpose command-line fuzzy finder. It reads lines from
stdin (or a configured source command) and presents an interactive filter with
real-time matching.

**Why this tool:** fzf transforms every list into an interactive picker. File
selection, history search, git branches, process killing — anything that
produces lines of text can be piped through fzf.

**Key bindings:**

| Shortcut | Action | Preview |
|---|---|---|
| `Ctrl+T` | Fuzzy file picker (insert path at cursor) | bat syntax highlighting |
| `Alt+C` | Fuzzy directory jump (cd into selection) | eza tree view |
| `Ctrl+G` | Interactive ripgrep (search file contents) | bat with line highlight |
| `Ctrl+R` | History search (handled by atuin, not fzf) | — |

**Common usage:**

```bash
# Pipe anything into fzf
git branch | fzf                    # pick a branch
ps aux | fzf                        # find a process
cat ~/.ssh/config | fzf             # search SSH hosts

# Use fzf inline with commands
nvim $(fzf)                         # open a file
cd $(fd --type d | fzf)             # jump to a directory

# Ctrl+G grep workflow:
# 1. Press Ctrl+G
# 2. Type search pattern (ripgrep searches as you type)
# 3. Preview shows syntax-highlighted match context
# 4. Press Enter to open file in nvim at the exact line
```

**Config location:** `~/.config/dotfiles/fzf.zsh` (sourced from `~/.zshrc`)

---

### zoxide

**What it is:** A smarter `cd` command that learns your most-visited directories
and lets you jump to them by typing a partial name. Think of it as `cd` with
fuzzy memory.

**Why this tool:** Instead of typing full paths (`cd ~/projects/company/frontend/src`),
you type `z front` and zoxide jumps to the best match based on frequency and
recency (a "frecency" algorithm).

**Common usage:**

```bash
# Jump to a directory by partial name
z dotfiles                    # cd to ~/Code/dotfiles (or wherever it is)
z proj                        # cd to your most-visited "proj*" directory

# Multiple tokens narrow the match
z code dot                    # matches ~/Code/dotfiles

# Interactive mode (fzf-powered picker)
zi                            # browse all tracked directories
zi proj                       # fuzzy-filter tracked directories matching "proj"

# zoxide learns automatically — just use cd normally and it builds the database
cd ~/some/deep/path           # zoxide records this visit
z deep                        # next time, jump there directly
```

**Database location:** `~/.local/share/zoxide/db.zo` (persists across installs)

---

## Modern CLI Tools

These tools replace traditional Unix utilities with faster, more readable, and
more featureful alternatives. All are installed via cargo (Rust binaries).

### bat

**What it is:** A `cat` replacement with syntax highlighting, line numbers, git
integration, and automatic paging.

**Why this tool:** Reading source files in the terminal becomes instantly more
productive. bat highlights 200+ languages, shows git modifications in the margin,
and integrates with fzf for previews.

**Common usage:**

```bash
# View a file with syntax highlighting
bat src/main.rs

# Show line numbers and git changes (default)
bat --diff config.toml

# Use as a plain pager (no line numbers, no header)
bat --plain README.md

# Concatenate files (like cat, but highlighted)
bat src/*.rs

# List available themes
bat --list-themes
```

**Config location:** `~/.config/bat/config` (sets `--theme="Catppuccin Mocha"`)

---

### eza

**What it is:** A modern replacement for `ls` with color output, file type icons
(via Nerd Font), git status per file, and tree view.

**Why this tool:** eza provides a richer default display — colors by file type,
git status indicators, human-readable sizes, and a built-in tree mode that
replaces the `tree` command.

**Common usage:**

```bash
# Basic listing (colored, with icons if Nerd Font is installed)
eza

# Long format with git status
eza -la --git

# Tree view (replaces `tree` command)
eza --tree --level=3

# Sort by modification time (newest first)
eza -la --sort=modified

# Only directories
eza -D
```

---

### ripgrep (rg)

**What it is:** A line-oriented search tool that recursively searches directories
for a regex pattern. Extremely fast (uses parallelism, memory maps, SIMD).

**Why this tool:** ripgrep is 2-5x faster than grep on large codebases. It
automatically respects `.gitignore`, skips binary files, and provides colored,
contextual output by default.

**Common usage:**

```bash
# Search for a pattern in current directory (recursive)
rg "TODO"

# Search specific file types
rg "import" --type rust
rg "useState" --type tsx

# Case-insensitive search
rg -i "error"

# Show context (2 lines before and after)
rg -C 2 "panic"

# Search with fixed string (no regex interpretation)
rg -F "func(*http.Request)"

# Count matches per file
rg -c "TODO"

# List files that contain a match (no content shown)
rg -l "deprecated"
```

---

### fd

**What it is:** A fast, user-friendly alternative to `find`. Uses sensible
defaults (recursive, colored output, respects `.gitignore`, ignores hidden
files by default).

**Why this tool:** `find` syntax is notoriously awkward (`find . -name "*.rs"
-type f`). fd uses a simpler interface (`fd .rs`) and is 5-10x faster on large
directory trees.

**Common usage:**

```bash
# Find files matching a pattern
fd "test"                     # finds *test* anywhere in filename
fd ".rs$"                     # regex: files ending in .rs

# Find by extension
fd -e json                    # all .json files
fd -e py -e pyi               # multiple extensions

# Find directories only
fd --type d "config"

# Find and execute a command (like find -exec)
fd -e log --exec rm {}

# Include hidden files and gitignored files
fd --hidden --no-ignore "secret"

# Find files modified in the last 24 hours
fd --changed-within 1d
```

---

### jq

**What it is:** A lightweight command-line JSON processor. Reads JSON from
stdin or files, applies transformations, and outputs formatted results.

**Why this tool:** jq is the standard tool for parsing JSON in shell scripts
and one-liners. It handles filtering, mapping, reformatting, and extracting
nested values with a concise expression language.

**Common usage:**

```bash
# Pretty-print JSON
curl -s https://api.github.com/users/octocat | jq .

# Extract a field
echo '{"name": "test", "version": "1.0"}' | jq '.name'

# Filter arrays
cat data.json | jq '.items[] | select(.status == "active")'

# Transform structure
jq '{name: .full_name, stars: .stargazers_count}' repo.json

# Process multiple files
jq '.dependencies' package.json
```

---

### tldr (tealdeer)

**What it is:** A fast client for [tldr-pages](https://tldr.sh/) — community-maintained
command cheatsheets showing practical examples instead of man page verbosity.

**Why this tool:** Man pages are comprehensive but slow to scan for the common
use case. `tldr` shows the 5-10 most common invocations of any command, with
real-world examples.

**Common usage:**

```bash
# Look up common usage for a command
tldr tar
tldr git rebase
tldr curl

# Update the local page cache
tldr --update

# List all available pages
tldr --list
```

---

## Git and Version Control

### delta

**What it is:** A syntax-highlighting pager for `git diff`, `git log`, `git
show`, and `git blame`. Replaces the default diff output with colored,
line-numbered, navigate-able diffs.

**Why this tool:** Default git diffs are monochrome and hard to scan. delta adds
language-aware syntax highlighting, line numbers, and keyboard navigation between
hunks. It integrates transparently — just use `git diff` as normal.

**What changes after install:**

```bash
# These commands now show highlighted, navigable output automatically:
git diff
git show HEAD
git log -p
git stash show -p

# Navigate between diff hunks with n/N (like vim search)

# View side-by-side diffs (configured by default):
# delta shows unified format with side-by-side rendering
```

**Config location:** `~/.gitconfig` (delta section)

---

### lazygit

**What it is:** A terminal UI for git that shows staged/unstaged changes, commit
history, branches, and stashes in interactive panels. Keyboard-driven with vim
bindings.

**Why this tool:** Complex git workflows (interactive rebase, partial staging,
conflict resolution) are faster in a visual interface. lazygit provides that
without leaving the terminal.

**Common usage:**

```bash
# Launch lazygit (the alias loads catppuccin theme automatically)
lazygit

# Inside lazygit:
#   Tab      — switch panels (files, branches, commits, stash)
#   Space    — stage/unstage file
#   c        — commit
#   p        — push
#   P        — pull
#   r        — rebase
#   ?        — show all keybindings
#   q        — quit
```

**Config location:**
- `~/.config/lazygit/config.yml` (Nerd Font icons setting)
- `~/.local/share/lazygit/catppuccin/` (theme repository)

---

### Git workflow defaults

The installer configures modern git defaults that eliminate common friction:

| Setting | Value | What it does |
|---|---|---|
| `init.defaultBranch` | `main` | New repos start with `main` instead of `master` |
| `pull.rebase` | `true` | `git pull` rebases instead of creating merge commits |
| `rebase.autoStash` | `true` | Automatically stash/pop dirty working tree during rebase |
| `push.autoSetupRemote` | `true` | First push auto-sets upstream (no more `-u origin branch`) |
| `rerere.enabled` | `true` | Remember conflict resolutions; auto-apply next time |
| `merge.conflictstyle` | `zdiff3` | Shows base version in conflicts (easier to resolve) |
| `diff.algorithm` | `histogram` | More readable diffs (better at detecting moved blocks) |
| `diff.colorMoved` | `default` | Moved code blocks shown in different color |
| `core.editor` | `nvim` | Neovim for commit messages, interactive rebase, etc. |

### SSH commit signing

All commits and tags are automatically signed with your SSH key. GitHub shows a
"Verified" badge on signed commits. No GPG setup required — the same ed25519 key
used for authentication doubles as your signing key.

```bash
# Verify signing is working
git log --show-signature -1

# View your signing keys on GitHub
gh ssh-key list
```

### Global gitignore

Common OS and editor artifacts are ignored globally (no need to add `.DS_Store`
to every project):

- macOS: `.DS_Store`, `._*`, `.Spotlight-V100`, `.Trashes`
- Linux: `*~`, `.directory`
- Vim/Neovim: `*.swp`, `*.swo`, `tags`, `Session.vim`
- JetBrains: `.idea/`
- VS Code: `.vscode/`, `*.code-workspace`

**Config location:** `~/.config/git/ignore`

---

## Programming Languages

### Rust

**What it is:** The Rust programming language toolchain, installed via rustup
(the official Rust installer and version manager).

**Why it is here:** Many tools in this dotfiles project are written in Rust and
installed via `cargo install` (sheldon, atuin, bat, eza, ripgrep, fd, delta,
tealdeer, tree-sitter-cli). The rust module ensures the toolchain is available
for these installations.

**What you get:**

- `rustc` — the Rust compiler
- `cargo` — package manager and build tool
- `rustup` — toolchain version manager

**Common usage:**

```bash
# Update Rust to latest stable
rustup update

# Install a Rust tool
cargo install tool-name

# Check installed toolchain
rustc --version
cargo --version

# Add a compilation target (e.g., for cross-compilation)
rustup target add x86_64-unknown-linux-musl
```

**Binary location:** `~/.cargo/bin/` (added to PATH via `~/.zprofile`)

---

### Go

**What it is:** The Go programming language toolchain, installed from official
tarballs at go.dev.

**Why it is here:** lazygit is installed via `go install`. The Go toolchain also
supports Go development workflows.

**What you get:**

- `go` — compiler, build tool, and package manager
- `gofmt` — code formatter

**Common usage:**

```bash
# Check version
go version

# Install a Go tool
go install github.com/user/tool@latest

# Initialize a new module
go mod init github.com/user/project

# Build and run
go run main.go
go build -o myapp .
```

**Binary locations:**
- Go toolchain: `/usr/local/go/bin/`
- Installed tools: `~/go/bin/`
- Both added to PATH via `~/.zprofile`

---

### Python

**What it is:** Python 3 runtime with pip, venv support, and pipx for isolated
CLI tool installation.

**Why it is here:** Python is ubiquitous for scripting, automation, and data
work. pipx provides a clean way to install Python CLI tools (like httpie, ruff,
black) without polluting the global environment.

**What you get:**

- `python3` / `python` — the interpreter
- `pip` — package installer
- `python -m venv` — virtual environment creation
- `pipx` — install Python CLI tools in isolated environments

**Common usage:**

```bash
# Install a CLI tool globally (isolated venv, binary in ~/.local/bin)
pipx install httpie
pipx install ruff
pipx install black

# Create a project virtual environment
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Deactivate the venv
deactivate

# List pipx-installed tools
pipx list
```

**Binary location:** `~/.local/bin/` (pipx and pip --user binaries, added to PATH via `~/.zprofile`)

---

## Terminal and Editor

### Ghostty (macOS only)

**What it is:** A fast, GPU-accelerated terminal emulator built with Zig. Native
macOS app with excellent font rendering and low input latency.

**Why this tool:** Ghostty combines the speed of GPU rendering with native
platform integration. It supports ligatures, Nerd Font icons, and ships with
built-in catppuccin themes.

**Configuration applied:**

| Setting | Value |
|---|---|
| Theme | Catppuccin Mocha |
| Font | Hack Nerd Font Mono, size 15 |
| macOS Option key | Treated as Alt (for Alt+C and other bindings) |

**Config location:** `~/.config/ghostty/config`

---

### tmux

**What it is:** A terminal multiplexer — run multiple terminal sessions in one
window, detach and reattach sessions, split panes.

**Why this tool:** tmux lets you maintain persistent terminal sessions that
survive disconnects (critical for remote work), split your terminal into panes,
and switch between "windows" (virtual tabs) without using your terminal emulator's
tab feature.

**Configuration:** Uses [oh-my-tmux](https://github.com/gpakosz/.tmux), a
self-contained tmux configuration with sensible defaults, vim-style bindings,
and a powerline-style status bar.

**Common usage:**

```bash
# Start a new named session
tmux new -s work

# Detach from session (inside tmux)
# Press: Ctrl+b then d

# List sessions
tmux ls

# Reattach to a session
tmux attach -t work

# Inside tmux (prefix is Ctrl+b by default):
#   Ctrl+b c     — new window
#   Ctrl+b n/p   — next/previous window
#   Ctrl+b |     — split pane vertically (oh-my-tmux)
#   Ctrl+b -     — split pane horizontally (oh-my-tmux)
#   Ctrl+b h/j/k/l — navigate panes (vim-style, oh-my-tmux)
#   Ctrl+b z     — zoom (maximize) current pane
#   Ctrl+b [     — enter copy mode (vim keys to navigate/select)
```

**Config location:**
- `~/.config/tmux/tmux.conf` — symlink to oh-my-tmux (do not edit)
- `~/.config/tmux/tmux.conf.local` — your overrides go here
- `~/.local/share/tmux/oh-my-tmux/` — upstream clone

---

### Neovim

**What it is:** A modern, extensible text editor based on Vim. Configured with
[LazyVim](https://www.lazyvim.org/) — a Neovim setup powered by the lazy.nvim
plugin manager with carefully selected defaults and extras.

**Why this tool:** Neovim provides a fast, keyboard-driven editing experience
with full IDE capabilities (LSP, treesitter, debugging, git integration) through
its plugin ecosystem. LazyVim packages this into a coherent, maintained
configuration.

**What you get:**

- Full LSP support (auto-complete, go-to-definition, rename, diagnostics)
- Treesitter syntax highlighting and text objects
- fuzzy finder integration (telescope)
- Git integration (lazygit accessible via leader key)
- File explorer (neo-tree)
- Mason auto-installs language servers on first launch

**Common usage:**

```bash
# Open a file
nvim src/main.rs

# Open a directory (shows neo-tree file explorer)
nvim .

# Inside neovim (Space is the leader key in LazyVim):
#   Space Space  — find files (telescope)
#   Space /      — live grep (search file contents)
#   Space e      — toggle file explorer
#   Space g g    — open lazygit
#   g d          — go to definition
#   K            — hover documentation
#   Space c a    — code actions
#   Space b d    — close buffer
#   :Lazy        — plugin manager UI
#   :Mason       — LSP server manager
```

**Config location:** `~/.config/nvim/` (cloned from yangxingwu/neovim-lua-config)

**First launch note:** Mason will auto-install LSP servers in the background
(~10-20 seconds). You will see progress notifications in the bottom-right corner.
After installation completes, full LSP features are available.

---

## SSH

### Key management

The installer generates an ed25519 SSH key pair (no passphrase) and pushes the
public key to GitHub for both authentication and commit signing.

**What is configured:**

- `~/.ssh/id_ed25519` — private key (generated if absent)
- `~/.ssh/id_ed25519.pub` — public key (pushed to GitHub)
- Key comment format: `user@hostname-YYYYMMDD`

### Connection multiplexing

SSH connections are multiplexed — the first connection to a host opens a socket,
and subsequent connections reuse it. This eliminates connection setup time for
repeated SSH/git operations to the same host.

```
Host *
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 10m
```

After connecting to a host, subsequent SSH commands to the same host are instant
for the next 10 minutes.

### SSH config defaults

| Setting | Value | Purpose |
|---|---|---|
| `ServerAliveInterval` | 60 | Send keepalive every 60s (prevent timeout) |
| `ServerAliveCountMax` | 3 | Disconnect after 3 missed keepalives |
| `Compression` | yes | Compress data (faster on slow links) |
| `ControlMaster` | auto | Connection multiplexing |
| `ControlPersist` | 10m | Keep master connection open 10 minutes |
| `IdentityFile` | `~/.ssh/id_ed25519` | Default key for all hosts |
| `IdentitiesOnly` | yes | Only offer configured keys (not all in agent) |

### Password-based login (sshpass wrapper)

For hosts where key-based auth is not available, the installer provides a
transparent `ssh()` wrapper function. If a password file exists for a host, it
uses `sshpass` automatically.

```bash
# Set up password-based login for a host:
# 1. Create the password file
echo "mypassword" > ~/.ssh/passwords/server.example.com
chmod 600 ~/.ssh/passwords/server.example.com

# 2. Optionally set the username in SSH config
cat >> ~/.ssh/config << 'EOF'
Host server.example.com
    User admin
EOF

# 3. Connect normally — sshpass is used transparently
ssh server.example.com
```

**Config locations:**
- `~/.ssh/config` — host definitions (Include directive at top loads defaults)
- `~/.ssh/config.d/dotfiles-defaults` — managed Host * defaults
- `~/.ssh/passwords/` — password files (one per host, mode 600)
- `~/.ssh/sockets/` — control sockets for multiplexing
- `~/.config/dotfiles/ssh-wrapper.sh` — wrapper function (sourced from .zshrc)

---

## Theme

The entire environment uses the **Catppuccin Mocha** color palette — a soothing
dark theme with pastel accent colors. Every tool that supports theming uses the
same palette for visual consistency.

| Tool | Theme source |
|---|---|
| Ghostty | Built-in `Catppuccin Mocha` theme |
| bat | Built-in `Catppuccin Mocha` theme (bat 0.25+) |
| fzf | Cloned from `catppuccin/fzf` (shell vars) |
| lazygit | Cloned from `catppuccin/lazygit` (merged via alias) |
| starship | `catppuccin-powerline` preset |

**Updating themes:**

```bash
# fzf catppuccin theme
cd ~/.local/share/fzf/catppuccin && git pull

# lazygit catppuccin theme
cd ~/.local/share/lazygit/catppuccin && git pull

# starship preset (regenerates config — overwrites customizations)
starship preset catppuccin-powerline --output ~/.config/starship.toml
```

---

## Configuration Files

### Files written to ~/.zshrc (managed blocks)

Each block is fenced with comments and managed independently by `core::ensure_block`.
Running `./install.sh` again updates them idempotently.

| Block ID | Content |
|---|---|
| `fzf` | `source "${HOME}/.config/dotfiles/fzf.zsh"` |
| `zoxide` | `eval "$(zoxide init zsh)"` |
| `sheldon` | `eval "$(sheldon source)"` + `autoload -Uz compinit && compinit` |
| `atuin` | `eval "$(atuin init zsh)"` |
| `starship` | `eval "$(starship init zsh)"` |
| `lazygit` | Alias merging catppuccin theme via `--use-config-file` |
| `ssh` | `source "${HOME}/.config/dotfiles/ssh-wrapper.sh"` |

### Files written to ~/.zprofile (managed blocks)

| Block ID | Content |
|---|---|
| `homebrew` | Homebrew shellenv (macOS only) |
| `rust` | `. "${HOME}/.cargo/env"` |
| `golang` | PATH additions for `/usr/local/go/bin` and `~/go/bin` |
| `python` | `export PATH="${HOME}/.local/bin:${PATH}"` |

### Files in ~/.config/

| Path | Module | Description |
|---|---|---|
| `~/.config/dotfiles/fzf.zsh` | fzf | fzf environment variables, key bindings, Ctrl+G widget |
| `~/.config/dotfiles/ssh-wrapper.sh` | ssh | ssh() wrapper function for sshpass |
| `~/.config/atuin/config.toml` | atuin | Sync disabled, local history only |
| `~/.config/bat/config` | cli-tools | `--theme="Catppuccin Mocha"` |
| `~/.config/ghostty/config` | ghostty | Theme, font, macOS option key (macOS only) |
| `~/.config/git/ignore` | git | Global gitignore (OS/editor artifacts) |
| `~/.config/lazygit/config.yml` | git | Nerd Font icons setting |
| `~/.config/nvim/` | nvim | LazyVim configuration (cloned repo) |
| `~/.config/sheldon/plugins.toml` | sheldon | Declarative plugin list |
| `~/.config/starship.toml` | starship | Prompt configuration (catppuccin-powerline) |
| `~/.config/tmux/tmux.conf` | tmux | Symlink to oh-my-tmux |
| `~/.config/tmux/tmux.conf.local` | tmux | User overrides |

### Git configuration

| Path | Description |
|---|---|
| `~/.gitconfig` | Identity, workflow defaults, delta pager, SSH signing |

### SSH files

| Path | Description |
|---|---|
| `~/.ssh/config` | Host definitions + Include directive |
| `~/.ssh/config.d/dotfiles-defaults` | Managed Host * defaults |
| `~/.ssh/id_ed25519` | Private key |
| `~/.ssh/id_ed25519.pub` | Public key |
| `~/.ssh/passwords/` | Password files for sshpass (one per host) |
| `~/.ssh/sockets/` | Control sockets for connection multiplexing |

### Other locations

| Path | Module | Description |
|---|---|---|
| `~/.cargo/` | rust | Rust toolchain and cargo-installed binaries |
| `/usr/local/go/` | golang | Go toolchain |
| `~/go/bin/` | golang | Go-installed binaries (lazygit) |
| `~/.local/bin/` | python | pipx and pip --user binaries |
| `~/.local/share/fzf/catppuccin/` | fzf | Catppuccin fzf theme (git clone) |
| `~/.local/share/lazygit/catppuccin/` | git | Catppuccin lazygit theme (git clone) |
| `~/.local/share/sheldon/` | sheldon | Downloaded plugin repositories |
| `~/.local/share/tmux/oh-my-tmux/` | tmux | oh-my-tmux upstream clone |
| `~/.local/share/zoxide/db.zo` | zoxide | Directory frecency database |

---

## Day-to-Day Operations

### Updating

Pull the latest dotfiles and re-run the installer. It is idempotent — already-installed
tools are skipped, configs are updated to the latest desired state.

```bash
cd ~/path/to/dotfiles
git pull
./install.sh
```

### Installing specific modules

```bash
# Install only specific modules
./install.sh --only git,nvim,tmux

# Install everything except certain modules
./install.sh --skip ghostty,font-hack-nerd-font

# List all available modules
./install.sh --list
```

### Uninstalling

```bash
# Uninstall all modules (removes configs, retains binaries)
./uninstall.sh

# Uninstall specific modules only
./uninstall.sh --only git,nvim

# Uninstall everything except certain modules
./uninstall.sh --skip ssh,rust
```

**What uninstall does:**
- Removes managed blocks from `~/.zshrc` and `~/.zprofile`
- Removes configuration files written by each module
- Removes cloned repositories (oh-my-tmux, catppuccin themes, nvim config)
- Does NOT remove installed binaries (brew/apt/cargo/go packages stay)
- Does NOT remove user data (SSH keys, git identity, zoxide database)

### Module order

Modules run in dependency order. The full sequence is:

1. homebrew (macOS only)
2. font-hack-nerd-font (macOS only)
3. ssh
4. rust
5. golang
6. git
7. cli-tools
8. python
9. fzf
10. zoxide
11. sheldon
12. atuin
13. starship
14. ghostty (macOS only)
15. nvim
16. tmux

### Troubleshooting

```bash
# Shell changes not taking effect?
# Source your profile or open a new terminal
source ~/.zprofile
source ~/.zshrc

# Or just open a new terminal tab/window

# Tool not found after install?
# Ensure PATH blocks are loaded
echo $PATH | tr ':' '\n' | grep -E "(cargo|go|local)"

# Sheldon plugins not loading?
sheldon lock --update

# Neovim LSP not working?
# Open neovim and check Mason status
:Mason
# LSP servers auto-install on first launch — wait 10-20 seconds

# fzf key bindings not working?
# Verify fzf is on PATH and the init script is sourced
which fzf
cat ~/.zshrc | grep fzf
```
