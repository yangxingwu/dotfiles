# Dotfiles Project Gaps — TODO

Date: 2026-05-12 | Updated: 2026-05-13

Identified gaps for the "full daily dev environment" goal. Each section is an
independent sub-project — implement in any order, one at a time.

---

## Completed

- [x] Project Housekeeping (LICENSE, .gitignore, README username)
- [x] Selective Module Install (--only/--skip)
- [x] Output Verbosity Control (core::run_cmd, --verbose, log file, timing)

---

## Priority 1 — High value, low effort

### Bootstrap Refactor

Separate "environment preparation" from "module installation" cleanly.

Current problem: install.sh runs bootstrap (zsh, xcode clt, brew, dev_tools)
every time, even with --only. This adds noise and 3s overhead for stuff
that's already done.

Design:
- [ ] install.sh stops running bootstrap — only does module installation
- [ ] install.sh checks prerequisites at startup (zsh, pkg manager, dev tools)
      and fails fast with a message: "Run ./bootstrap-macos.sh (or bootstrap-linux.sh) first"
- [ ] bootstrap-macos.sh (existing) — rework to cover all prerequisites:
      Xcode CLT, Homebrew, modern bash, zsh as login shell, dev tools
- [ ] Create bootstrap-linux.sh — same role for Linux:
      zsh, login shell, git, curl, build-essential/@development-tools
- [ ] Both bootstrap scripts are idempotent and fast when already satisfied
- [ ] Remove lib/bootstrap.sh (its logic moves into the bootstrap-* scripts)

### Output Optimization (install.sh / uninstall.sh)

Current problem: even after verbosity framework, output is noisy with
redundant summary and file dumps.

Design:
- [ ] Remove default Summary block (the big box with per-module details)
- [ ] Add --summary flag to opt-in to the detailed summary
- [ ] Remove core::summary_file (dump of .zprofile/.zshrc) entirely —
      file contents are not useful in output; use `cat` if needed
- [ ] Keep the final summary (module count, timing, log path) — it's concise
- [ ] Bootstrap "already satisfied" checks become silent (after refactor,
      they won't run in install.sh at all)

### README Update

- [ ] Document --verbose flag and output behavior
- [ ] Document final summary (module count, timing, log path)
- [ ] Document --only/--skip with examples
- [ ] Document bootstrap-first workflow

### Uninstall Failure Behavior

- [ ] core::run_module: don't exit on uninstall failure (continue remaining modules)
- [ ] Log failed modules, report in final summary
- [ ] Rationale: uninstall hooks are independent (no dependency chain)

### Modern CLI Tools Module

- [ ] Create `modules/cli-tools.sh` — install bat, eza
- [ ] Note: ripgrep and fd are already installed by nvim module
- [ ] Add `cli-tools` to lib/modules.sh (before nvim)
- [ ] Add test assertions (assert_command bat eza)

### Git Enhancement Module (delta)

- [ ] Create `modules/git-tools.sh` — install delta
- [ ] git config --global core.pager delta
- [ ] git config --global interactive.diffFilter "delta --color-only"
- [ ] Add `git-tools` to lib/modules.sh (after git)
- [ ] Add test assertions (assert_command delta)

## Priority 2 — Moderate value

### Zsh Configuration Module

- [ ] Create `modules/zsh-config.sh`
- [ ] HISTSIZE, HISTFILE, SAVEHIST, setopt (share_history, hist_ignore_dups, etc.)
- [ ] Write via core::ensure_block into ~/.zshrc
- [ ] Add `zsh-config` to lib/modules.sh (after sheldon)
- [ ] Add test assertions

### Python Module

- [ ] Create `modules/python.sh`
- [ ] macOS: core::pkg_install python3; Linux: python3 + python3-pip
- [ ] Add `python` to lib/modules.sh
- [ ] Add test assertions (assert_command python3 pip3)

### Log File Rotation

- [ ] In core::init, delete log files older than 7 days from /tmp/dotfiles-*
- [ ] One line: find /tmp -name 'dotfiles-*.log' -mtime +7 -delete

## Priority 3 — Optional / situational

### Shell Aliases

- [ ] Instead of a full module, add optional source line in zsh-config:
      `[[ -f ~/.aliases ]] && source ~/.aliases`
- [ ] User maintains ~/.aliases manually — not managed by dotfiles

---

## Rejected (with rationale)

### mise Module
YAGNI. Current setup (rustup + Go tarball) works. No multi-version needs.

### Dry-run Mode
Scripts are idempotent and support --only filtering. Dry-run adds complexity
to every side-effect path for negligible safety benefit.

### ASCII Progress Bar
Already have `▶ [3/13] ssh` + per-module timing + final summary. A `\r`-based
progress bar conflicts with log output and doesn't work in CI.
