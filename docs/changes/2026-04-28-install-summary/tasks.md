# Install/Uninstall Summary — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Print a detailed summary table at the end of install.sh/uninstall.sh showing what each bootstrap step and module actually did — including install method, config files touched, and skip reasons.

**Architecture:** Add `core::summary` / `core::print_summary` to core.sh. Each bootstrap function and module's install()/uninstall() appends its own lines. Orchestrators call `core::print_summary` at the end.

**Tech Stack:** Bash, existing core.sh infrastructure.

---

### Task 1: Add summary API to core.sh

**Files:**
- Modify: `lib/core.sh` (append after `core::run_module`)

- [ ] **Step 1: Add `_CORE_SUMMARY` array, `core::summary`, and `core::print_summary`**

Append to `lib/core.sh`:

```bash
# Summary tracking — populated by bootstrap, core::run_module, and modules.
_CORE_SUMMARY=()

# core::summary <entry>
# Appends a line to the summary buffer.
core::summary() {
  _CORE_SUMMARY+=("${1}")
}

# core::print_summary
# Prints the accumulated summary between box-drawing borders.
core::print_summary() {
  printf '\n══════════════════════════════════════════════════\n'
  printf '  Summary\n'
  printf '══════════════════════════════════════════════════\n'
  local line
  for line in "${_CORE_SUMMARY[@]}"; do
    if [[ "${line}" == "---" ]]; then
      printf '──────────────────────────────────────────────────\n'
    else
      printf '%s\n' "${line}"
    fi
  done
  printf '══════════════════════════════════════════════════\n'
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n lib/core.sh`
Expected: no output (success)

- [ ] **Step 3: Commit**

```bash
git add lib/core.sh
git commit -m "feat(core): add summary tracking API (core::summary + core::print_summary)"
```

---

### Task 2: Add summary calls to core::run_module

**Files:**
- Modify: `lib/core.sh` — `core::run_module` function (around line 118)

- [ ] **Step 1: Add module header to summary on execute, header + skip on platform mismatch**

In `core::run_module`, change the platform-skip block:

```bash
  if [[ "${MODULE_PLATFORM}" != "all" ]] &&
    [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
    core::log INFO "Skipping ${name} (platform: ${MODULE_PLATFORM})"
    core::summary "  ${name}"
    core::summary "    — skipped (${MODULE_PLATFORM} only)"
    return 0
  fi
```

Add module header before executing the action:

```bash
  core::summary "  ${name}"
```

(Insert this line right before `"${action}"`)

- [ ] **Step 2: Verify syntax**

Run: `bash -n lib/core.sh`

- [ ] **Step 3: Commit**

```bash
git add lib/core.sh
git commit -m "feat(core): record module results in summary from run_module"
```

---

### Task 3: Add summary calls to bootstrap.sh

**Files:**
- Modify: `lib/bootstrap.sh` — all four functions

- [ ] **Step 1: Add summary to bootstrap::zsh**

At the end of the `if ! command -v zsh` block (after `core::log INFO "zsh installed"`), add:
```bash
    core::summary "  zsh                          ✓ installed"
```

At the end of the else block (after `core::log INFO "zsh already installed"`), add:
```bash
    core::summary "  zsh                          ✓ already installed"
```

- [ ] **Step 2: Add summary to bootstrap::xcode_clt**

After `core::log INFO "Xcode Command Line Tools already installed"`:
```bash
    core::summary "  Xcode Command Line Tools     ✓ already installed"
```

After `core::log INFO "Xcode Command Line Tools installed"`:
```bash
    core::summary "  Xcode Command Line Tools     ✓ installed"
```

- [ ] **Step 3: Add summary to bootstrap::homebrew**

After `core::log INFO "Homebrew already installed"`:
```bash
    core::summary "  Homebrew                     ✓ already installed"
```

After `core::log INFO "Homebrew installed; shellenv wired into ~/.zprofile"`:
```bash
    core::summary "  Homebrew                     ✓ installed"
```

- [ ] **Step 4: Add summary to bootstrap::dev_tools**

Replace the single `core::log INFO "Dev tools installed"` at the end with per-pm summary lines:

```bash
  case "${DOTFILES_PKG_MANAGER}" in
  brew) core::summary "  dev tools                    ✓ installed (cmake, meson, ninja, gettext)" ;;
  apt) core::summary "  dev tools                    ✓ installed (zsh, git, curl, cmake, meson, ninja-build, gettext, build-essential)" ;;
  dnf) core::summary "  dev tools                    ✓ installed (zsh, git, curl, cmake, meson, ninja-build, gettext, Development Tools)" ;;
  esac
  core::log INFO "Dev tools installed"
```

- [ ] **Step 5: Verify syntax**

Run: `bash -n lib/bootstrap.sh`

- [ ] **Step 6: Commit**

```bash
git add lib/bootstrap.sh
git commit -m "feat(bootstrap): add summary lines to all bootstrap functions"
```

---

### Task 4: Add summary calls to all modules

**Files:**
- Modify: all 10 files in `modules/`

Each module's install() and uninstall() appends detail lines via `core::summary`.
The module header (`"  name"`) is already added by `core::run_module` (Task 2).

- [ ] **Step 1: modules/font-hack-nerd-font.sh**

install():
```bash
  core::summary "    ✓ installed via brew cask"
```

uninstall(): no summary needed (no-op)

- [ ] **Step 2: modules/git.sh**

install():
```bash
  core::summary "    ✓ config → ~/.gitconfig (user.name, user.email)"
```

uninstall():
```bash
  core::summary "    ✓ removed config from ~/.gitconfig"
```

- [ ] **Step 3: modules/rust.sh**

install() — after the if/else on rustup:
```bash
  # inside the if (already installed):
  core::summary "    ✓ rustup already installed"
  # inside the else (just installed):
  core::summary "    ✓ installed via rustup"
```

After the ensure_block:
```bash
  core::summary "    ✓ config → ~/.zprofile (cargo env)"
```

uninstall():
```bash
  core::summary "    ✓ removed block from ~/.zprofile"
```

- [ ] **Step 4: modules/fzf.sh**

install():
```bash
  core::summary "    ✓ installed via ${DOTFILES_PKG_MANAGER}"
  core::summary "    ✓ config → ~/.zshrc (fzf init)"
```

uninstall():
```bash
  core::summary "    ✓ removed block from ~/.zshrc"
```

- [ ] **Step 5: modules/zoxide.sh**

install():
```bash
  core::summary "    ✓ installed via ${DOTFILES_PKG_MANAGER}"
  core::summary "    ✓ config → ~/.zshrc (zoxide init)"
```

uninstall():
```bash
  core::summary "    ✓ removed block from ~/.zshrc"
```

- [ ] **Step 6: modules/sheldon.sh**

install() — after the if/else on sheldon binary:
```bash
  # inside the if (already installed):
  core::summary "    ✓ sheldon already installed"
  # inside the else (just installed):
  core::summary "    ✓ installed via cargo"
```

After sheldon lock:
```bash
  local plugin_names
  plugin_names="$(printf '%s' "${_SHELDON_PLUGINS[*]}" | sed 's|[^ ]*/||g' | tr ' ' ', ')"
  core::summary "    ✓ plugins: ${plugin_names}"
```

After ensure_block:
```bash
  core::summary "    ✓ config → ~/.zshrc (sheldon source)"
```

uninstall():
```bash
  core::summary "    ✓ removed plugins and block from ~/.zshrc"
```

- [ ] **Step 7: modules/starship.sh**

install() — after the if/else on starship binary:
```bash
  # inside the if (already installed):
  core::summary "    ✓ starship already installed"
  # inside the else (just installed):
  core::summary "    ✓ installed via curl (official installer)"
```

After preset generation:
```bash
  core::summary "    ✓ config → ~/.config/starship.toml (${_STARSHIP_PRESET})"
  core::summary "    ✓ config → ~/.zshrc (starship init)"
```

uninstall():
```bash
  core::summary "    ✓ removed ~/.config/starship.toml"
  core::summary "    ✓ removed block from ~/.zshrc"
```

- [ ] **Step 8: modules/ghostty.sh**

install():
```bash
  core::summary "    ✓ installed via brew cask"
  core::summary "    ✓ config → ~/.config/ghostty/config"
```

uninstall():
```bash
  core::summary "    ✓ removed ~/.config/ghostty/config"
```

- [ ] **Step 9: modules/nvim.sh**

_nvim::install_deps() — after the case block:
```bash
  core::summary "    ✓ deps: ripgrep, fd, lazygit, node, shfmt, shellcheck"
  core::summary "    ✓ tree-sitter-cli installed via cargo"
```

_nvim::install_nvim() — inside the if (already installed):
```bash
  core::summary "    ✓ $(nvim --version | head -1) already installed"
```

After pkg install or source build:
```bash
  # option 1:
  core::summary "    ✓ installed via ${DOTFILES_PKG_MANAGER}"
  # option 2:
  core::summary "    ✓ installed from source"
```

_nvim::clone_config():
```bash
  core::summary "    ✓ config → ~/.config/nvim (cloned)"
```

uninstall():
```bash
  core::summary "    ✓ removed ~/.config/nvim"
```
If source-built:
```bash
  core::summary "    ✓ uninstalled source-built neovim"
```

- [ ] **Step 10: modules/tmux.sh**

install():
```bash
  core::summary "    ✓ installed via ${DOTFILES_PKG_MANAGER}"
  core::summary "    ✓ oh-my-tmux installed"
```

uninstall():
```bash
  core::summary "    ✓ removed oh-my-tmux clone"
  core::summary "    ✓ unlinked ~/.config/tmux/tmux.conf"
  core::summary "    ✓ removed ~/.config/tmux/tmux.conf.local"
```

- [ ] **Step 11: Verify syntax for all modules**

Run: `for f in modules/*.sh; do bash -n "$f" || echo "FAIL: $f"; done`

- [ ] **Step 12: Commit**

```bash
git add modules/
git commit -m "feat(modules): add summary lines to all module install/uninstall hooks"
```

---

### Task 5: Wire summary into orchestrators

**Files:**
- Modify: `install.sh`
- Modify: `uninstall.sh`

- [ ] **Step 1: Update install.sh**

After `bootstrap::dev_tools` and before the module loop, add:
```bash
  core::summary "---"
```

Replace `core::log INFO "Install complete."` with:
```bash
  core::print_summary
  core::log INFO "Install complete."
```

- [ ] **Step 2: Update uninstall.sh**

Replace `core::log INFO "Uninstall complete."` with:
```bash
  core::print_summary
  core::log INFO "Uninstall complete."
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n install.sh && bash -n uninstall.sh`

- [ ] **Step 4: Commit**

```bash
git add install.sh uninstall.sh
git commit -m "feat: wire core::print_summary into install.sh and uninstall.sh"
```

---

### Task 6: Verification

- [ ] **Step 1: Run full syntax check**

```bash
for f in lib/*.sh modules/*.sh install.sh uninstall.sh; do
  bash -n "$f" || echo "FAIL: $f"
done
```

- [ ] **Step 2: Dry-read the summary output**

Read through install.sh and trace the expected summary output by hand:
- Bootstrap: 4 entries (zsh, xcode_clt, homebrew, dev_tools) — only on macOS; Linux has 2 (zsh, dev_tools)
- Separator: `---`
- Modules: 10 entries, each with header + detail lines
- Platform-skipped modules show `— skipped (mac/linux only)`

- [ ] **Step 3: Commit design doc update**

```bash
git add docs/changes/2026-04-28-install-summary/
git commit -m "docs: update install-summary design with implementation details"
```
