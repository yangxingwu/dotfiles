# Dotfiles Project Gaps — TODO

Date: 2026-05-12 | Updated: 2026-05-13

Identified gaps for the "full daily dev environment" goal. Each section is an
independent sub-project — implement in any order, one at a time.

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

## Priority 1 — High value, low effort

### README Update

- [x] Document bootstrap-first workflow (bootstrap-macos.sh / bootstrap-linux.sh)
- [x] Document --verbose flag and output behavior
- [x] Document --summary flag
- [x] Document --only/--skip with examples
- [x] Document module list and order

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

### Log File Rotation
Not worth the complexity. /tmp is cleaned by the OS on reboot anyway.
