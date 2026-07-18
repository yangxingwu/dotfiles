# Dotfiles User Guide

> **English** | [中文](guide.zh-CN.md)

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

### Shell environment and aliases (zsh-config)

The `zsh-config` module configures the shell environment so that everything works
out of the box after install. It writes a managed block to `~/.zshrc` with
environment variables, history tuning, zsh options, and aliases for modern CLI tools.

**Environment variables:**

| Variable | Value | Purpose |
|---|---|---|
| `EDITOR` | `nvim` | Default editor for git commit, crontab, etc. |
| `VISUAL` | `nvim` | Default visual editor |
| `PAGER` | `less -R` | Pager with ANSI color passthrough |
| `LANG` | `en_US.UTF-8` | System locale |
| `LC_ALL` | `en_US.UTF-8` | Override all locale categories |

**History configuration:**

| Setting | Value | Purpose |
|---|---|---|
| `HISTSIZE` | 100000 | In-memory history entries |
| `SAVEHIST` | 100000 | Entries written to file |
| `HISTFILE` | `~/.zsh_history` | History file location |

History options: `share_history` (sync across terminals), `hist_ignore_all_dups`
(no duplicates), `hist_reduce_blanks` (trim whitespace), `hist_verify` (expand
before executing), `extended_history` (timestamps).

**Aliases:**

All aliases are guarded — only defined if the target command exists. If you did a
partial install (e.g. without cli-tools), the aliases simply won't appear.

| Alias | Expands to | What it does |
|---|---|---|
| `ls` | `eza --icons --group-directories-first` | Colorized listing with icons |
| `ll` | `eza -l --icons --git --group-directories-first` | Long format with git status |
| `la` | `eza -la --icons --git --group-directories-first` | Long format including hidden files |
| `lt` | `eza --tree --level=2 --icons` | Tree view (2 levels deep) |
| `cat` | `bat --paging=never` | Syntax-highlighted file viewing |

**Tips:**

- To use the original `cat` (e.g. for binary output): `command cat` or `\cat`
- To use the original `ls`: `command ls` or `\ls`
- `auto_cd` is enabled — you can type a directory name without `cd` to enter it
  (e.g., type `..` instead of `cd ..`, or `~/projects` instead of `cd ~/projects`)
- History is still written to `~/.zsh_history` as a fallback even though atuin
  manages interactive search

**Config location:** `~/.zshrc` (managed block `zsh-config`)

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
# Press Ctrl+R to open the full-screen history search
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

### ast-grep

**What it is:** [ast-grep](https://ast-grep.github.io/) is a structural search and
replace tool based on abstract syntax trees (AST). Unlike ripgrep's text matching,
it understands code structure — it knows what's a function name, argument, or variable.

**Why this tool:** Precisely match code patterns during refactoring without false
positives from comments or string literals. Used in nvim via grug-far (`<leader>sr`)
as a second search engine alongside ripgrep.

**Common usage:**

```bash
# Search all fmt.Println calls
ast-grep -p 'fmt.Println($$$)' -l go

# Replace fmt.Println(x) with log.Info(x)
ast-grep -p 'fmt.Println($ARG)' -r 'log.Info($ARG)' -l go

# In nvim: <leader>sr opens grug-far, switch engine to ast-grep
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

# Delta shows unified diff format with syntax highlighting
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

### fsmonitor (per-repo performance optimization)

Git's fsmonitor feature uses OS filesystem events to track which files changed,
so `git status` only needs to stat those files instead of walking the entire
worktree. This reduces `git status` from seconds to milliseconds on large repos
(e.g. Linux kernel with 80k+ files).

**Platform support:**

| Platform | Method | Status |
|----------|--------|--------|
| macOS | Built-in daemon (FSEvents) | Works out of the box |
| Windows | Built-in daemon (ReadDirectoryChangesW) | Works out of the box |
| Linux | Built-in daemon | **NOT supported** on most distros |
| Linux | Watchman + hook (see below) | Works with manual setup |

**This is NOT enabled globally** — on macOS/Windows each daemon is persistent
(~12 threads, ~5 MB RSS) and never exits once started. If enabled globally,
tools that touch many repos (e.g. Neovim lazy.nvim syncing 40+ plugins) will
spawn dozens of idle daemons. After hours of inactivity, macOS
memory-compresses (or swaps out) their pages. The next `git status` must
decompress/page-in the daemon before it can respond — easily exceeding prompt
timeouts.

**When to enable:**

- Repos with 10k+ tracked files where `git status` is noticeably slow
- Repos you actively develop in (not read-only clones or plugin directories)

**How to enable — macOS (built-in daemon):**

```bash
# Enable on a specific large repo
git -C /path/to/large-repo config core.fsmonitor true

# Check if daemon is running
git -C /path/to/large-repo fsmonitor--daemon status

# Stop daemon for a repo
git -C /path/to/large-repo fsmonitor--daemon stop

# Kill all daemons system-wide (cleanup)
pkill -f 'fsmonitor--daemon'
```

**How to enable — Linux (Watchman + hook):**

The built-in `fsmonitor--daemon` is not available on Linux. Instead, use
[Facebook Watchman](https://facebook.github.io/watchman/) with the sample hook
script that ships with Git (`fsmonitor-watchman.sample` in `.git/hooks/`):

```bash
# 1. Install Watchman — see https://facebook.github.io/watchman/docs/install
#    Fedora/RHEL: dnf install watchman
#    Ubuntu/Debian: install from GitHub releases or build from source

# 2. Activate the hook in your repo
cd /path/to/large-repo
cp .git/hooks/fsmonitor-watchman.sample .git/hooks/query-watchman
git config core.fsmonitor .git/hooks/query-watchman

# 3. Verify Watchman is watching
watchman watch-list
```

> The hook is a Perl script (requires `JSON::PP` or `JSON::XS`). It queries the
> Watchman daemon for files changed since the last token, providing the same
> speedup as the built-in daemon without requiring kernel-level support.

**When NOT to enable:**

- Small repos (< 1k files) — `git status` is already fast enough
- Read-only clones (package manager plugins, vendored dependencies)
- Repos you rarely touch

**References:**

- [git-config: core.fsmonitor](https://git-scm.com/docs/git-config#Documentation/git-config.txt-corefsmonitor)
- [githooks: fsmonitor-watchman](https://git-scm.com/docs/githooks#_fsmonitor_watchman)
- [Facebook Watchman](https://facebook.github.io/watchman/)

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

### Node.js (fnm)

**What it is:** Node.js runtime managed by [fnm](https://github.com/Schniz/fnm)
(Fast Node Manager) — a Rust-based Node.js version manager that handles
installing, switching, and auto-selecting Node versions per project.

**Why this tool:** fnm is fast (Rust binary), supports `.node-version` and
`.nvmrc` files for automatic version switching when you `cd` into a project,
and installs Node versions in user space (no sudo required).

**What you get:**

- `fnm` — Node.js version manager
- `node` — JavaScript runtime (LTS version installed by default)
- `npm` — package manager (bundled with Node)

**Common usage:**

```bash
# Install the latest LTS version
fnm install --lts

# Install a specific version
fnm install 20

# Switch to a version
fnm use 20

# Set default version
fnm default 22

# Per-project version pinning (fnm auto-switches on cd)
echo "22" > .node-version

# Check current version
node -v
npm -v

# List installed versions
fnm list
```

**How auto-switching works:** The shell block in `~/.zprofile` includes
`--use-on-cd`, which makes fnm automatically switch Node versions when you
enter a directory containing a `.node-version` or `.nvmrc` file.

**Binary locations:**
- fnm: `~/.cargo/bin/fnm`
- Node versions and global packages: `~/.local/share/fnm/`

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

### Zellij

**What it is:** A modern terminal multiplexer (written in Rust) — run multiple
terminal sessions in one window, detach and reattach sessions, split panes.

**Why this tool (replacing tmux):**
- Bell notifications pass through transparently — Claude Code notifications work
- Mouse selection is pane-aware — no text bleeding across pane boundaries
- Discoverable UI — bottom bar always shows available keys for the current mode
- Simple configuration — KDL format, excellent defaults out of the box

**Core concepts:**

```
Session (workspace)
 └── Tab (like browser tabs)
      └── Pane (terminal instance)
```

**Mode system:** Zellij organizes keybindings into modes. Enter a mode, then
press a single key to perform an action. The bottom status bar shows available
actions in real time.

**Common keybindings:**

| Action | Keys |
|---|---|
| Enter Pane mode | `Ctrl+p` |
| New pane (down) | `Ctrl+p` → `d` |
| New pane (right) | `Ctrl+p` → `r` |
| Close pane | `Ctrl+p` → `x` |
| Toggle floating pane | `Ctrl+p` → `w` |
| Fullscreen toggle | `Ctrl+p` → `f` |
| Enter Tab mode | `Ctrl+t` |
| New tab | `Ctrl+t` → `n` |
| Enter Session mode | `Ctrl+o` |
| Detach session | `Ctrl+o` → `d` |
| Enter Scroll mode | `Ctrl+s` |
| Enter Resize mode | `Ctrl+n` |

**Common usage:**

```bash
# Start a new named session
zellij --session work

# List sessions
zellij ls

# Reattach to a session
zellij attach work

# Kill a session
zellij kill-session work
```

**Copying text from panes:**

There are two ways to copy text from a Zellij pane:

**Method 1: Via $EDITOR (keyboard-driven)**

1. `Ctrl+s` — enter Scroll mode
2. Press `e` — opens the entire scrollback buffer in `$EDITOR` (i.e. nvim)
3. Use your editor's native selection and copy (in vim: `v` to enter Visual mode, select text, `"+y` to copy to system clipboard)
4. Exit the editor (`:q` in vim)

Note: your `$EDITOR` must have system clipboard integration configured. In Neovim, ensure `clipboard = "unnamedplus"` is set — otherwise copied text stays in the editor's internal register only.

**Method 2: Mouse selection**

| Action | Effect |
|---|---|
| Mouse drag | Copies to Zellij's internal clipboard (paste with system paste key) |
| `Shift` + mouse drag | Bypasses Zellij, uses terminal emulator's native selection → system clipboard |

For quickly copying a small snippet of text, `Shift` + mouse drag is the easiest approach.

**Typical workflows:**

- **Daily dev layout:** Create a session, split right (`Ctrl+p` → `r`), split
  bottom in the right pane (`Ctrl+p` → `d`). Editor left, terminal top-right,
  Claude Code bottom-right.
- **SSH persistence:** Run `zellij --session work` on the remote server. If
  disconnected, reconnect and `zellij attach work` — everything is intact.
- **Floating pane:** `Ctrl+p` → `w` for a quick overlay pane (docs, git log),
  press again to dismiss without disturbing your layout.
- **Multi-project:** Use named sessions per project, detach/attach to switch
  instantly.

**Config location:**
- `~/.config/zellij/config.kdl` — Zellij configuration

**Migrating from tmux:**

| tmux | Zellij | Action |
|---|---|---|
| `tmux new -s work` | `zellij --session work` | Create named session |
| `tmux ls` | `zellij ls` | List sessions |
| `tmux attach -t work` | `zellij attach work` | Attach to session |
| `tmux kill-session -t work` | `zellij kill-session work` | Kill session |
| `Ctrl+b d` | `Ctrl+o` → `d` | Detach session |
| `Ctrl+b "` | `Ctrl+p` → `d` | Split horizontal |
| `Ctrl+b %` | `Ctrl+p` → `r` | Split vertical |
| `Ctrl+b arrow` | `Ctrl+p` → `arrow` | Navigate panes |
| `Ctrl+b c` | `Ctrl+t` → `n` | New tab/window |
| `Ctrl+b [` | `Ctrl+s` | Scroll/copy mode |

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
| `zsh-config` | Environment variables, history, options, aliases |

### Files written to ~/.zprofile (managed blocks)

| Block ID | Content |
|---|---|
| `homebrew` | Homebrew shellenv (macOS only) |
| `rust` | `. "${HOME}/.cargo/env"` |
| `golang` | PATH additions for `/usr/local/go/bin` and `~/go/bin` |
| `python` | `export PATH="${HOME}/.local/bin:${PATH}"` |
| `nodejs` | `eval "$(fnm env --use-on-cd)"` |

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
| `~/.config/zellij/config.kdl` | zellij | Zellij configuration |

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
| `~/.local/share/fnm/` | nodejs | Node.js versions and global packages (managed by fnm) |
| `~/.local/share/fzf/catppuccin/` | fzf | Catppuccin fzf theme (git clone) |
| `~/.local/share/lazygit/catppuccin/` | git | Catppuccin lazygit theme (git clone) |
| `~/.local/share/sheldon/` | sheldon | Downloaded plugin repositories |
| `~/.config/zellij/` | zellij | Zellij config directory |
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
./install.sh --only git,nvim,zellij

# Install everything except certain modules
./install.sh --skip ghostty,font-hack-nerd-font

# List all available modules
./install.sh --list
```

### China mirrors (`--mirror-cn`)

For users in mainland China, the `--mirror-cn` flag configures faster mirrors
for all package sources:

```bash
./install.sh --mirror-cn
```

This sets up:
- **Homebrew**: USTC mirror (brew git remote + bottle domain)
- **Rust**: rsproxy.cn (rustup dist server + cargo sparse registry)
- **Go**: golang.google.cn (tarball download) + goproxy.cn (module proxy)
- **npm**: npmmirror.com (registry mirror)

See the project README for full details on each mirror configuration.

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
- Removes cloned repositories (catppuccin themes, nvim config)
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
9. nodejs
10. fzf
11. zoxide
12. sheldon
13. atuin
14. starship
15. ghostty (macOS only)
16. nvim
17. zellij
18. zsh-config

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
