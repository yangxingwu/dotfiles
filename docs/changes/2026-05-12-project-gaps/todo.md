# Dotfiles Project Gaps — TODO

Date: 2026-05-12 | Updated: 2026-05-14

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

---

## P0 — Broken Promises (bugs that violate stated claims)

These contradict the project's own description. Fix before any new features.

### tmux Module Crashes on Re-run

`tmux.sh install()` unconditionally runs `git clone` and `ln -s`. Second run:
git clone fails ("destination path already exists"), ln fails ("File exists").
`uninstall()` calls bare `unlink` — crashes if symlink already gone.

Violates: **Idempotent**.

- [ ] Guard `git clone`: if dir exists, do `git -C pull` or skip
- [ ] Guard `ln -s`: if symlink exists with correct target, skip
- [ ] Guard `unlink`: `[[ -L ... ]] && unlink ... || true`

### nvim Backup Accumulation

`_nvim::clone_config` always moves ~/.config/nvim to .bak. Second install
either fails (mv to existing .bak) or loses the real config.

Violates: **Idempotent**.

- [ ] If ~/.config/nvim/.git exists with correct remote+branch → skip clone
- [ ] Only back up if .bak doesn't already exist

### CI Doesn't Test Idempotency

The test suite runs install once. The core promise is untested.

Violates: **Idempotent** (no verification).

- [ ] Add Phase 1b in test_install.sh: run install.sh a second time
- [ ] Assert zero exit code (no crash)
- [ ] Assert no duplicate managed blocks in .zshrc / .zprofile
- [ ] Assert tmux/nvim don't error on existing state

---

## P1 — Core CLI Experience (what a developer notices in the first 5 minutes)

These are the gaps between "tools installed" and "out-of-the-box modern CLI."

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

### Modern CLI Tools

~~bat (cat), eza (ls), jq (JSON), yazi (file manager), tldr (command help),
htop (processes). ripgrep and fd already installed via nvim deps.~~

- [x] Create `modules/cli-tools.sh` — install bat, eza, rg, fd, jq, tealdeer via cargo
- [x] Position: before fzf (fzf preview commands depend on bat and eza)
- [x] bat config: set theme to catppuccin-mocha via config file
- [x] rg/fd moved from nvim module to cli-tools
- [x] Add test assertions (assert_command bat eza rg fd jq tldr)

### fzf Configuration

~~fzf is installed but completely unconfigured — bare Ctrl+R/Ctrl+T with default
`find` as source, no preview, no theme. The full power is locked behind env
vars the module never sets.~~

- [x] FZF_DEFAULT_COMMAND: use fd (respects .gitignore, fast)
- [x] FZF_CTRL_T_COMMAND + FZF_CTRL_T_OPTS: bat preview
- [x] FZF_ALT_C_COMMAND + FZF_ALT_C_OPTS: eza tree preview
- [x] FZF_DEFAULT_OPTS: catppuccin mocha color scheme (via clone + source)
- [x] Layout: --height=60% --layout=reverse --border --info=inline
- [x] Disable Ctrl+R (atuin handles history search)
- [x] Expand ensure_block to include env vars above the `eval` line

### Git Enhancement — delta

~~`git diff` and `git log` output raw, colorless patches. delta provides
syntax-highlighted, side-by-side diffs with line numbers.~~

- [x] Install delta via cargo (in git module, not separate git-tools module)
- [x] Install lazygit via go (moved from nvim module)
- [x] git config: core.pager=delta, interactive.diffFilter, delta.navigate, delta.dark
- [x] git config: merge.conflictstyle=zdiff3
- [x] Add test assertions (assert_command delta, verify git config)

### Git Config Completeness

~~The git module only sets user.name + user.email. Missing modern defaults that
prevent daily friction.~~

- [x] init.defaultBranch=main, pull.rebase, rebase.autoStash, push.autoSetupRemote
- [x] diff.algorithm=histogram, diff.colorMoved=default
- [x] rerere.enabled=true, core.editor=nvim
- [x] SSH commit signing (gpg.format=ssh, user.signingkey)
- [x] Global gitignore (~/.config/git/ignore)
- [x] lazygit catppuccin theme (clone + --use-config-file alias)
- [x] Integrated into existing `modules/git.sh` (no new module)

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

### Python Module

Python is a daily-use tool — scripting, automation, cloud CLIs, data work.

- [ ] Create `modules/python.sh`
- [ ] macOS: core::pkg_install python3
- [ ] Linux (apt): core::pkg_install python3 python3-pip python3-venv
- [ ] Linux (dnf): core::pkg_install python3 python3-pip
- [ ] Install pipx for isolated CLI tool installs (httpie, ruff, black, etc.)
- [ ] Add `python` to lib/modules.sh
- [ ] Add test assertions (assert_command python3 pip3 pipx)

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

### Theme Coherence

catppuccin-mocha is set for starship and ghostty but other tools use defaults.
No visual consistency.

- [ ] bat: set theme in ~/.config/bat/config (`--theme="Catppuccin Mocha"`)
- [ ] fzf: catppuccin colors in FZF_DEFAULT_OPTS
- [ ] lazygit: catppuccin theme in ~/.config/lazygit/config.yml
- [ ] yazi: catppuccin theme if available
- [ ] Document: "all tools use catppuccin mocha" as a project design choice

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

### Module Dependency Declaration

`--only nvim` crashes with "cargo not found." Dependency graph lives in
comments, not in code. Users of --only get no guidance.

- [ ] Add optional `MODULE_DEPS=("rust" "golang")` to module interface
- [ ] core::run_module checks: are deps in DOTFILES_SELECTED_MODULES?
- [ ] If not: clear error listing missing deps, or auto-include with notice
- [ ] Graceful: missing MODULE_DEPS means "no deps"

### One-Command Setup

Two steps required (bootstrap + install). Not "one command."

- [ ] Create `./setup.sh`: detect platform → run bootstrap → run install.sh
- [ ] Keep bootstrap-*.sh / install.sh as standalone for power users
- [ ] Or: make install.sh detect "not bootstrapped" and auto-bootstrap

### Network Resilience

curl calls have no timeout. Hangs forever on flaky networks.

- [ ] `--connect-timeout 10 --max-time 60` on all curl calls
- [ ] Clear error on network failure (not just empty variable)
- [ ] Document: "requires internet for first install"

### Git Identity Hardcoded

`user.name` and `user.email` hardcoded in source. #1 barrier to "clone and run."

- [ ] Read from DOTFILES_GIT_NAME / DOTFILES_GIT_EMAIL env vars
- [ ] Interactive prompt as fallback (with TTY check)
- [ ] Cache in ~/.config/dotfiles/identity for re-runs
- [ ] CI: skip entirely (non-interactive)

### CI Cargo Cache

sheldon + atuin + tree-sitter-cli via `cargo install` = 3–5 min (60%+ of CI).

- [ ] actions/cache on ~/.cargo/bin + ~/.cargo/registry
- [ ] Key on crate names + versions

### Faster Sheldon/Atuin Install

Both publish pre-built binaries on GitHub Releases. Cargo compiles from source
for no benefit.

- [ ] Evaluate: download pre-built binary from GitHub Releases
- [ ] Platform detection: linux-x86_64, linux-aarch64, darwin-x86_64, darwin-aarch64
- [ ] Fall back to cargo install if binary unavailable
- [ ] Tradeoff: more code vs. 2-3 min saved per install

---

## P4 — Polish & Long-tail

### Module Status Query

No way to ask "what's installed?" after install.

- [ ] Write `~/.config/dotfiles/installed-modules` after each successful run
- [ ] Add `--status` flag: list installed modules with timestamps
- [ ] Use state file to skip unchanged modules on re-run (future)

### Self-Update Mechanism

No way to pull changes and re-apply in one command.

- [ ] Add `--update` flag or `./update.sh`: git pull + re-run install.sh
- [ ] Or: simple approach — just git pull + full re-run (idempotent anyway)

### lazygit Configuration

Installed (via nvim module) but zero configuration.

- [ ] Write `~/.config/lazygit/config.yml`
- [ ] Set catppuccin-mocha theme
- [ ] Integrate into git-tools module

### Git Commit Signing

Modern workflows increasingly require signed commits.

- [ ] Conditional signing config: only if key exists
- [ ] Support SSH signing (simpler, no GPG):
      `git config --global gpg.format ssh`
      `git config --global user.signingkey ~/.ssh/id_ed25519.pub`
- [ ] Gate: don't break headless installs

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
