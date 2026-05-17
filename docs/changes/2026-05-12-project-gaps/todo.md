# Dotfiles Project Gaps — TODO

Date: 2026-05-12 | Updated: 2026-05-16

Project positioning: **"Full auto-installer for macOS & Linux dev environments.
Idempotent, modular, one command."**

Items are ordered by priority. Within each tier, items are ordered by impact.

---

## Completed

- [x] Project Housekeeping (LICENSE, .gitignore, README username)
- [x] Selective Module Install (--only/--skip)
- [x] Output Verbosity Control (core::run_cmd, --verbose, --summary, log file, timing)
- [x] Bootstrap Refactor (separate bootstrap-*.sh from install.sh, homebrew module)
- [x] Output Optimization (merge summary functions, --summary flag, remove file dumps)
- [x] Uninstall Failure Behavior (continue on failure, report at end)
- [x] Sheldon Declarative Config (replace sheldon add with direct TOML generation)
- [x] ~~Modern CLI Tools~~ — cli-tools module (bat, eza, rg, fd, jq, tealdeer via cargo)
- [x] ~~fzf Configuration~~ — fd/bat/eza integration, catppuccin theme, Ctrl+G grep, Ctrl+R disabled
- [x] ~~Git Enhancement (delta)~~ — delta + lazygit in git module, catppuccin theme
- [x] ~~Git Config Completeness~~ — workflow defaults, SSH signing, global gitignore, lazygit
- [x] ~~nvim Backup Accumulation~~ — core::backup with timestamp, remote check + pull
- [x] ~~nvim Headless Init~~ — Lazy! sync + TSUpdate in install phase
- [x] ~~Theme Coherence~~ — catppuccin mocha applied to bat, fzf, lazygit, starship, ghostty
- [x] ~~Shell scripts to `~/.config/dotfiles/`~~ — fzf.zsh + ssh-wrapper.sh extracted from .zshrc
- [x] ~~Module Dependency Declaration~~ — MODULE_DEPS + core::module_is_installed check
- [x] ~~Module Status Query~~ — installed-modules file + --status flag
- [x] ~~CI Idempotency Test~~ — Phase 1b runs install.sh twice, checks no duplicate blocks
- [x] ~~tmux Module Crashes on Re-run~~ — guard clone (pull if exists), ln -sf, unlink guard
- [x] ~~CI Cargo Cache~~ — actions/cache on ~/.cargo/bin + ~/go/bin, Docker volume mount
- [x] ~~Git Identity Hardcoded~~ — env vars + interactive prompt + non-interactive skip
- [x] ~~Python Module~~ — python3, pip, venv, pipx, ~/.local/bin PATH

---

## P0 — Broken Promises (bugs that violate stated claims)

These contradict the project's own description. Fix before any new features.

### ~~tmux Module Crashes on Re-run~~

~~`tmux.sh install()` unconditionally runs `git clone` and `ln -s`. Second run:
git clone fails ("destination path already exists"), ln fails ("File exists").
`uninstall()` calls bare `unlink` — crashes if symlink already gone.~~

~~Violates: **Idempotent**.~~

- [x] Guard `git clone`: if dir exists, do `git -C pull` or skip
- [x] Guard `ln -s`: if symlink exists with correct target, skip
- [x] Guard `unlink`: `[[ -L ... ]] && unlink ... || true`

### ~~CI Doesn't Test Idempotency~~

~~The test suite runs install once. The core promise is untested.~~

- [x] Add Phase 1b in test_install.sh: run install.sh a second time
- [x] Assert zero exit code (no crash)
- [x] Assert no duplicate managed blocks in .zshrc / .zprofile

---

## P1 — Out-of-the-box Experience (what blocks adoption and first use)

### ~~Git Identity Hardcoded~~

~~`user.name` and `user.email` hardcoded in source. #1 barrier to "clone and run."~~

- [x] Read from DOTFILES_GIT_NAME / DOTFILES_GIT_EMAIL env vars
- [x] Interactive prompt as fallback (with TTY check)
- [x] CI: skip entirely (non-interactive)

### Shell Environment Foundation

No EDITOR, no PAGER, no locale, no history tuning, no XDG paths. A fresh
install drops the user into zsh with default 1000-line history, no
deduplication, and `vim` (not nvim) as the fallback editor.

- [ ] Create `modules/zsh-config.sh`
- [ ] EDITOR=nvim, VISUAL=nvim, PAGER="less -R" (or bat-based)
- [ ] LANG=en_US.UTF-8, LC_ALL=en_US.UTF-8
- [ ] History: HISTSIZE=100000, SAVEHIST=100000, HISTFILE=~/.zsh_history
- [ ] setopt: share_history, hist_ignore_all_dups, hist_reduce_blanks,
      hist_verify, extended_history, auto_cd, interactive_comments
- [ ] XDG base dirs: XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_CACHE_HOME,
      XDG_STATE_HOME (many installed tools respect these)
- [ ] Write via core::ensure_block into ~/.zshenv (env vars) and ~/.zshrc (opts)
- [ ] Position: after sheldon, before atuin

### Shell Aliases

Modern tools installed but nobody types `eza -la --git --icons` by hand. This
is the glue between "installed" and "out-of-the-box."

- [ ] Add aliases in `zsh-config` module via core::ensure_block:
      - `alias ls='eza'`
      - `alias ll='eza -l --git --icons'`
      - `alias la='eza -la --git --icons'`
      - `alias lt='eza --tree --level=2'`
      - `alias cat='bat --paging=never'`
- [ ] Guard: only alias if the target command exists (graceful on partial install)
- [ ] Alternative: write ~/.config/dotfiles/aliases.zsh, source from .zshrc block

---

## P2 — Full Dev Environment (what a developer needs in the first day)

### macOS Developer Defaults

macOS ships with hostile defaults for keyboard-heavy users: slow key repeat,
press-and-hold character picker, hidden file extensions, animations everywhere.

- [ ] Create `modules/macos-defaults.sh` (platform: mac)
- [ ] Key repeat: `KeyRepeat -int 2`, `InitialKeyRepeat -int 15`
- [ ] Disable press-and-hold: `ApplePressAndHoldEnabled -bool false`
- [ ] Finder: show all extensions, show hidden files, path bar, status bar,
      default to list view
- [ ] Dock: autohide, minimize-to-application, no recent apps section
- [ ] Trackpad: enable tap-to-click
- [ ] Screenshots: save to ~/Screenshots, disable shadow
- [ ] Restart affected services: Finder, Dock, SystemUIServer
- [ ] Position: first mac-only module (after homebrew, before font)
- [ ] Test: `defaults read` returns expected values

### ~~Python Module~~

~~Python is a daily-use tool — scripting, automation, cloud CLIs, data work.~~

- [x] Create `modules/python.sh`
- [x] macOS: core::pkg_install python3 pipx
- [x] Linux (apt): core::pkg_install python3 python3-pip python3-venv python-is-python3 pipx
- [x] Linux (dnf): core::pkg_install python3 python3-pip pipx
- [x] Install pipx for isolated CLI tool installs (httpie, ruff, black, etc.)
- [x] Add ~/.local/bin to PATH via core::ensure_block in .zprofile
- [x] Add `python` to lib/modules.sh
- [x] Add test assertions (assert_command python3 pip3 pipx)

### Docker Module

Docker — local services, CI parity, reproducible builds.

- [ ] Create `modules/docker.sh`
- [ ] macOS: `core::pkg_install docker` (Homebrew cask — Docker Desktop)
- [ ] Linux (apt): add Docker CE official repo, install docker-ce,
      docker-ce-cli, containerd.io, docker-compose-plugin
- [ ] Linux (dnf): add Docker CE repo, install same packages
- [ ] Add current user to `docker` group (Linux)
- [ ] Idempotency: check if repo already added, if packages already installed
- [ ] Add test assertions (assert_command docker)
- [ ] Note: group membership takes effect on next login (document this)

### Node.js Version Manager

Node without version management is insufficient for JS/TS work. fnm is
rust-based, fast, supports .node-version / .nvmrc.

- [ ] Create `modules/node.sh`
- [ ] Install fnm: macOS: core::pkg_install fnm; Linux: cargo install fnm
- [ ] Shell init: `eval "$(fnm env --use-on-cd)"` via core::ensure_block
- [ ] Install latest LTS as default: `fnm install --lts`
- [ ] Position: after rust (fnm may need cargo on Linux)
- [ ] Add test assertions (assert_command fnm node npm)

### direnv — Per-Project Environment

Auto-loads `.envrc` when entering a directory. Essential for multi-project
workflows (different env vars, PATH extensions, secrets per project).

- [ ] Create `modules/direnv.sh`
- [ ] Install: core::pkg_install direnv (available in brew, apt, dnf)
- [ ] Shell init: `eval "$(direnv hook zsh)"` via core::ensure_block in .zshrc
- [ ] Position: after zsh-config
- [ ] Add test assertions (assert_command direnv, verify .zshrc block)

### Global Git Hooks (optional module)

Global git hooks (`core.hooksPath`) that apply to all repositories. Separate
from project-level hooks (husky, lefthook, etc.). Potential use cases:

- [ ] Prevent committing large files (>10MB size guard)
- [ ] Prevent committing secrets/sensitive files (.env, credentials, private keys)
- [ ] Commit message format enforcement (conventional commits)
- [ ] Dispatcher pattern: global hooks delegate to project-level `.git/hooks/`
      if present (backward compatible)
- [ ] Create as optional module `modules/git-hooks.sh` (not enabled by default?
      or always enabled with minimal safe defaults?)
- [ ] Design decision: what checks are universal enough to force globally?

---

## P3 — Reliability & Infrastructure

### Signal Handling

No trap. Ctrl+C during `cargo install` (3+ min) or Go download (70 MB) leaves
orphaned temp files and no indication of what went wrong.

- [ ] Add `trap` in core::init for INT TERM
- [ ] Clean up known temp artifacts on abort
- [ ] Print log file path on abort

### ~~Module Dependency Declaration~~

~~`--only nvim` crashes with "cargo not found." Dependency graph lives in
comments, not in code. Users of --only get no guidance.~~

- [x] Add optional `MODULE_DEPS=("rust" "golang")` to module interface
- [x] core::run_module checks: are deps in DOTFILES_SELECTED_MODULES?
- [x] If not: clear error listing missing deps, or auto-include with notice
- [x] Graceful: missing MODULE_DEPS means "no deps"

### One-Command Setup

~~Two steps required (bootstrap + install). Not "one command."~~

Moved to Rejected — see rationale below.

### Network Resilience

curl calls have no timeout. Hangs forever on flaky networks.

- [ ] `--connect-timeout 10 --max-time 60` on all curl calls
- [ ] Clear error on network failure (not just empty variable)
- [ ] Document: "requires internet for first install"

### ~~Git Identity Hardcoded~~

~~`user.name` and `user.email` hardcoded in source. #1 barrier to "clone and run."~~

Moved to P1 — highest priority item.

### ~~CI Cargo Cache~~

~~sheldon + atuin + tree-sitter-cli via `cargo install` = 3–5 min (60%+ of CI).~~

- [x] actions/cache on ~/.cargo/bin + ~/.cargo/registry
- [x] Key on crate names + versions

### Faster Sheldon/Atuin Install

Both publish pre-built binaries on GitHub Releases. Cargo compiles from source
for no benefit.

- [ ] Evaluate: download pre-built binary from GitHub Releases
- [ ] Platform detection: linux-x86_64, linux-aarch64, darwin-x86_64, darwin-aarch64
- [ ] Fall back to cargo install if binary unavailable
- [ ] Tradeoff: more code vs. 2-3 min saved per install

---

## P4 — Polish & Long-tail

### ~~Module Status Query~~

~~No way to ask "what's installed?" after install.~~

- [x] Write `~/.config/dotfiles/installed-modules` after each successful run
- [x] Add `--status` flag: list installed modules with timestamps
- [ ] Use state file to skip unchanged modules on re-run (future)

### Self-Update Mechanism

No way to pull changes and re-apply in one command.

- [ ] Add `--update` flag or `./update.sh`: git pull + re-run install.sh
- [ ] Or: simple approach — just git pull + full re-run (idempotent anyway)

### Go Tarball Integrity

go.dev publishes SHA256. 70 MB downloaded without verification.

- [ ] Download and verify checksum before extraction
- [ ] Abort on mismatch

### Interactive Prompts Documentation

- [ ] Document in README: "fully unattended except optional GitHub SSH key push"
- [ ] Consider `--non-interactive` flag

### Partial Install Test Coverage

--only / --skip never tested in CI.

- [ ] Test --only rust,golang
- [ ] Test --skip nvim

### Module Interface Lint

- [ ] Static check: source each module, verify MODULE_NAME matches filename,
      install/uninstall defined

### Troubleshooting Guide

- [ ] "cargo not found" → needs rust module
- [ ] "bash >= 4.3" → run bootstrap first
- [ ] Network timeouts → proxy config
- [ ] gh auth fails → needs browser access

### Configuration Reference

- [ ] All env var overrides
- [ ] Per-module: files written, blocks created, binaries installed

### Curl-to-Shell Documentation

- [ ] SECURITY.md with list of remote script URLs
- [ ] Official verification methods for each

---

## Rejected (with rationale)

### mise Module
YAGNI. rustup + Go tarball + fnm covers current needs. No multi-version
requirement for Rust/Go, and Node is handled by fnm.

### Dry-run Mode
Scripts are idempotent and support --only filtering. Dry-run adds complexity
to every side-effect path for negligible safety benefit.

### ASCII Progress Bar
Already have `▶ [3/13] ssh` + per-module timing + final summary. A `\r`-based
progress bar conflicts with log output and doesn't work in CI.

### Log File Rotation
Not worth the complexity. /tmp is cleaned by the OS on reboot anyway.

### Full Parallelization
Dependency graph is non-trivial (rust→sheldon/atuin/nvim, golang→nvim,
fzf→sheldon/ghostty) and logging isn't concurrent-safe. Revisit after CI
cache eliminates the biggest time sink (cargo builds).

### Brewfile
Fights module architecture. Each module owns its packages; a central Brewfile
creates split ownership. core::pkg_install is already idempotent.

### One-Command Setup
macOS ships /bin/bash 3.2; install.sh requires bash >= 4.3. Any "single entry
point" scheme either triggers package installation on `--help` (violates user
expectations) or requires maintaining duplicate parameter parsing in bash 3.2
syntax. The two-step flow (bootstrap → install) is the clean design.
