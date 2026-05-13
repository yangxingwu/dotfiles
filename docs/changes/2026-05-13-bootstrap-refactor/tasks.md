# Bootstrap Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate environment preparation (bootstrap) from module installation (install.sh) so install.sh is fast, quiet, and focused.

**Architecture:** Bootstrap scripts (bootstrap-macos.sh, bootstrap-linux.sh) handle one-time environment setup. install.sh only runs modules. A new homebrew module manages the .zprofile shellenv block. lib/bootstrap.sh is deleted.

**Tech Stack:** Bash (3.2 compat for bootstrap scripts, 4.3+ for install.sh)

---

### Task 1: Create `bootstrap-linux.sh`

**Files:**
- Create: `bootstrap-linux.sh`

- [ ] **Step 1: Write bootstrap-linux.sh**

```bash
#!/bin/bash
# bootstrap-linux.sh — one-time prerequisites for Linux (Ubuntu/Fedora).
#
# Installs zsh, sets it as login shell, installs dev tools needed by
# compilation-heavy modules (sheldon, atuin, nvim). Run ONCE on a fresh
# machine before ./install.sh.
#
# Supports: apt (Debian/Ubuntu), dnf (Fedora/RHEL).
# Idempotent — safe to run multiple times.
#
# Usage: ./bootstrap-linux.sh

set -euo pipefail
IFS=$'\n\t'

log() { printf '[INFO] %s\n' "$1"; }
err() { printf '[ERROR] %s\n' "$1" >&2; }

# Refuse to run on macOS.
if [ "$(uname)" != "Linux" ]; then
  err "bootstrap-linux.sh is for Linux only (detected: $(uname))"
  err "On macOS, run ./bootstrap-macos.sh instead."
  exit 1
fi

# Detect package manager.
if command -v apt-get >/dev/null 2>&1; then
  PKG=apt
elif command -v dnf >/dev/null 2>&1; then
  PKG=dnf
else
  err "No supported package manager found (need apt or dnf)"
  exit 1
fi

# 1. Install zsh if missing.
if command -v zsh >/dev/null 2>&1; then
  log "zsh already installed"
else
  log "Installing zsh..."
  case "${PKG}" in
  apt) sudo apt-get install -y zsh ;;
  dnf) sudo dnf install -y zsh ;;
  esac
  log "zsh installed"
fi

# 2. Set login shell to zsh if not already.
current_shell="$(basename "${SHELL:-/bin/sh}")"
if [ "${current_shell}" != "zsh" ]; then
  log "Changing login shell to zsh..."
  sudo chsh -s "$(command -v zsh)" "$(whoami)"
  log "Login shell changed to zsh"
else
  log "Login shell already zsh"
fi

# 3. Install dev tools.
log "Installing dev tools..."
case "${PKG}" in
apt)
  sudo apt-get install -y git curl cmake meson ninja-build gettext \
    pkg-config libssl-dev libclang-dev build-essential
  ;;
dnf)
  sudo dnf install -y git curl cmake meson ninja-build gettext \
    pkg-config openssl-devel clang-devel
  if dnf group list --installed 2>/dev/null | grep -qi "development tools"; then
    log "@development-tools already installed"
  else
    sudo dnf install -y @development-tools
  fi
  ;;
esac
log "Dev tools installed"

# 4. Touch shell skeleton files.
touch "${HOME}/.zshrc" "${HOME}/.zprofile" "${HOME}/.zshenv"
log "Ensured ~/.zshrc, ~/.zprofile, ~/.zshenv exist"

log ""
log "Bootstrap complete. Run ./install.sh to install modules."
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x bootstrap-linux.sh
```

- [ ] **Step 3: Commit**

```bash
git add bootstrap-linux.sh
git commit -m "feat: add bootstrap-linux.sh for one-time Linux environment setup

Installs zsh, sets login shell, installs dev tools (cmake, meson,
build-essential/@development-tools). Supports apt and dnf. Idempotent."
```

---

### Task 2: Rewrite `bootstrap-macos.sh`

**Files:**
- Modify: `bootstrap-macos.sh`

- [ ] **Step 1: Rewrite bootstrap-macos.sh with full responsibilities**

```bash
#!/bin/bash
# bootstrap-macos.sh — one-time prerequisites for macOS.
#
# Installs Xcode CLT, Homebrew, modern bash, verifies zsh, sets login
# shell, and installs dev tools. Run ONCE on a fresh Mac before
# ./install.sh.
#
# Written in bash 3.2-compatible syntax (runs under macOS system bash).
# Idempotent — safe to run multiple times.
#
# Usage: ./bootstrap-macos.sh

set -euo pipefail
IFS=$'\n\t'

log() { printf '[INFO] %s\n' "$1"; }
err() { printf '[ERROR] %s\n' "$1" >&2; }

# Refuse to run on non-macOS.
if [ "$(uname)" != "Darwin" ]; then
  err "bootstrap-macos.sh is for macOS only (detected: $(uname))"
  err "On Linux, run ./bootstrap-linux.sh instead."
  exit 1
fi

# ── 1. Xcode Command Line Tools ──────────────────────────────────────

if xcode-select -p >/dev/null 2>&1; then
  log "Xcode Command Line Tools already installed"
else
  log "Installing Xcode Command Line Tools (GUI dialog)..."
  xcode-select --install >/dev/null 2>&1 || true

  # Poll until installed (Apple provides no synchronous API).
  poll_interval=15
  max_wait=1800
  waited=0
  while ! xcode-select -p >/dev/null 2>&1; do
    if [ "${waited}" -ge "${max_wait}" ]; then
      err "Xcode CLT install did not complete within ${max_wait}s"
      err "Finish the GUI dialog, then re-run this script."
      exit 1
    fi
    log "Waiting for Xcode CLT... (${waited}s/${max_wait}s)"
    sleep "${poll_interval}"
    waited=$((waited + poll_interval))
  done
  log "Xcode Command Line Tools installed"
fi

# ── 2. Homebrew ───────────────────────────────────────────────────────

if command -v brew >/dev/null 2>&1; then
  log "Homebrew already installed"
else
  log "Installing Homebrew (official installer)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  log "Homebrew installed"
fi

# Locate brew prefix — needed for steps below even if brew was already installed.
if [ -x /opt/homebrew/bin/brew ]; then
  BREW=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then
  BREW=/usr/local/bin/brew
else
  err "brew binary not found at /opt/homebrew/bin/brew or /usr/local/bin/brew"
  exit 1
fi

# Activate brew for the rest of this script.
eval "$("${BREW}" shellenv)"

# ── 3. Modern bash ────────────────────────────────────────────────────

need_major=4
need_minor=3
have_major="${BASH_VERSINFO[0]:-0}"
have_minor="${BASH_VERSINFO[1]:-0}"

if [ "${have_major}" -gt "${need_major}" ] ||
  { [ "${have_major}" -eq "${need_major}" ] && [ "${have_minor}" -ge "${need_minor}" ]; }; then
  log "System bash already >= ${need_major}.${need_minor} (running ${BASH_VERSION})"
elif "${BREW}" list --formula bash >/dev/null 2>&1; then
  log "Homebrew bash already installed"
else
  log "Installing bash via Homebrew..."
  "${BREW}" install bash
  log "bash installed"
fi

# ── 4. Verify zsh ────────────────────────────────────────────────────

if command -v zsh >/dev/null 2>&1; then
  log "zsh available: $(command -v zsh)"
else
  err "zsh not found — this is unusual on macOS (preinstalled since Catalina)"
  err "Install manually: brew install zsh"
  exit 1
fi

# ── 5. Login shell ───────────────────────────────────────────────────

current_shell="$(basename "${SHELL:-/bin/sh}")"
if [ "${current_shell}" != "zsh" ]; then
  log "Changing login shell to zsh..."
  chsh -s "$(command -v zsh)"
  log "Login shell changed to zsh"
else
  log "Login shell already zsh"
fi

# ── 6. Dev tools ─────────────────────────────────────────────────────

log "Installing dev tools..."
"${BREW}" install cmake meson ninja gettext 2>/dev/null || true
log "Dev tools installed"

# ── 7. Shell skeleton files ──────────────────────────────────────────

touch "${HOME}/.zshrc" "${HOME}/.zprofile" "${HOME}/.zshenv"
log "Ensured ~/.zshrc, ~/.zprofile, ~/.zshenv exist"

# ── Done ─────────────────────────────────────────────────────────────

log ""
log "Bootstrap complete. To run the installer:"
log ""
log "  eval \"\$(${BREW} shellenv)\" && ./install.sh"
log ""
log "(install.sh will persist the brew shellenv into ~/.zprofile"
log " so future terminal sessions pick it up automatically.)"
```

- [ ] **Step 2: Commit**

```bash
git add bootstrap-macos.sh
git commit -m "feat: rewrite bootstrap-macos.sh with full environment setup

Now handles: Xcode CLT, Homebrew, modern bash, zsh verification,
login shell, dev tools (cmake/meson/ninja/gettext), and shell
skeleton files. Replaces the old minimal version that only did
brew + bash."
```

---

### Task 3: Create `modules/homebrew.sh`

**Files:**
- Create: `modules/homebrew.sh`

- [ ] **Step 1: Write the homebrew module**

```bash
#!/usr/bin/env bash
# modules/homebrew.sh — Homebrew shell environment (.zprofile block)
# Platform: mac
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="homebrew"
MODULE_DESC="Homebrew shell environment"
MODULE_PLATFORM="mac"

install() {
  # Detect prefix — Apple Silicon uses /opt/homebrew, Intel uses /usr/local.
  local brew_prefix
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_prefix=/opt/homebrew
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_prefix=/usr/local
  else
    core::log ERROR "brew binary not found at /opt/homebrew/bin/brew or /usr/local/bin/brew"
    return 1
  fi

  # Activate for the rest of this install run.
  eval "$("${brew_prefix}/bin/brew" shellenv)"

  # Persist for future login shells.
  core::ensure_block "${HOME}/.zprofile" "homebrew" \
    "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
  core::summary "    ✓ config → ~/.zprofile (brew shellenv)"
}

uninstall() {
  core::remove_block "${HOME}/.zprofile" "homebrew"
  core::summary "    ✓ removed homebrew block from ~/.zprofile"
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/homebrew.sh
git commit -m "feat: add homebrew module for .zprofile shellenv block

Manages the Homebrew shell environment block in ~/.zprofile.
Replaces the block-writing logic that was in bootstrap::homebrew.
macOS only, runs first in the module list."
```

---

### Task 4: Update module list in `lib/modules.sh`

**Files:**
- Modify: `lib/modules.sh:8-23`

- [ ] **Step 1: Add homebrew to the front of the module list**

Replace the `DOTFILES_MODULES` array:

```bash
DOTFILES_MODULES=(
  homebrew             # mac only: .zprofile shellenv (must be first for brew PATH)
  font-hack-nerd-font
  git
  ssh              # after git: identity before connectivity
  rust             # before nvim: cargo is required for tree-sitter-cli
  golang           # before nvim: go install lazygit
  fzf              # before zoxide: zi interactive mode uses fzf
                   # before sheldon: sheldon's fzf-tab plugin requires the fzf binary
  zoxide
  sheldon
  atuin            # after rust (cargo), after sheldon (replaces its history-substring-search)
  starship
  ghostty          # after font/sheldon/zoxide/starship: config assumes these are installed
  nvim             # after rust (cargo) and golang (go install lazygit)
  tmux
)
```

- [ ] **Step 2: Commit**

```bash
git add lib/modules.sh
git commit -m "feat: add homebrew to module list (first position)

homebrew module must run before all other mac modules so brew is
on PATH for core::pkg_install."
```

---

### Task 5: Strip bootstrap from `install.sh`

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Remove bootstrap source and calls, add hint**

Replace install.sh's content (after the bash version gate and `readonly DOTFILES_ROOT`):

```bash
# shellcheck source=lib/modules.sh
source "${DOTFILES_ROOT}/lib/modules.sh"
# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"

main() {
  core::init
  core::parse_args "$@"

  detect::os

  case "${DOTFILES_OS}" in
  mac) core::log INFO "Prerequisites: run ./bootstrap-macos.sh on a fresh machine" ;;
  linux) core::log INFO "Prerequisites: run ./bootstrap-linux.sh on a fresh machine" ;;
  esac

  detect::pkg_manager

  core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

  local total=${#DOTFILES_SELECTED_MODULES[@]} i=0 name
  for name in "${DOTFILES_SELECTED_MODULES[@]}"; do
    i=$((i + 1))
    core::run_module install "${name}" "${i}" "${total}"
  done

  core::print_final_summary
}

main "$@"
```

Key changes:
- Removed `source "${DOTFILES_ROOT}/lib/bootstrap.sh"`
- Removed `bootstrap::zsh`, `bootstrap::xcode_clt`, `bootstrap::homebrew`, `bootstrap::dev_tools` calls
- Removed `core::summary "---"` between bootstrap and modules
- Removed `core::summary_file` calls and `core::print_summary`
- Added platform-specific prerequisites hint
- Kept: version gate, DOTFILES_ROOT, source modules/detect/core, main with init/parse/detect/modules/final_summary

- [ ] **Step 2: Commit**

```bash
git add install.sh
git commit -m "refactor: remove bootstrap from install.sh

install.sh now only runs modules. Bootstrap (zsh, xcode, brew, dev
tools) is handled by bootstrap-macos.sh / bootstrap-linux.sh run
separately. A one-line hint reminds users of the prerequisite."
```

---

### Task 6: Delete `lib/bootstrap.sh`

**Files:**
- Delete: `lib/bootstrap.sh`

- [ ] **Step 1: Remove the file**

```bash
git rm lib/bootstrap.sh
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: delete lib/bootstrap.sh

All bootstrap logic now lives in bootstrap-macos.sh and
bootstrap-linux.sh. install.sh no longer sources this file."
```

---

### Task 7: Update CI workflow and Dockerfiles

**Files:**
- Modify: `.github/workflows/test.yml`
- Modify: `tests/Dockerfile.ubuntu`
- Modify: `tests/Dockerfile.fedora`

- [ ] **Step 1: Update .github/workflows/test.yml**

```yaml
name: Integration Tests

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  test-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v5
      - name: Run bootstrap
        run: ./bootstrap-macos.sh
      - name: Add brew bash to PATH
        run: echo "$(brew --prefix)/bin" >> "$GITHUB_PATH"
      - name: Run integration tests
        run: bash tests/test_install.sh

  test-ubuntu:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: Build test image
        run: docker build -f tests/Dockerfile.ubuntu -t dotfiles-test-ubuntu .
      - name: Run integration tests
        run: docker run --rm dotfiles-test-ubuntu

  test-fedora:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: Build test image
        run: docker build -f tests/Dockerfile.fedora -t dotfiles-test-fedora .
      - name: Run integration tests
        run: docker run --rm dotfiles-test-fedora
```

- [ ] **Step 2: Update tests/Dockerfile.ubuntu**

```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y sudo curl git
RUN useradd -m -s /bin/bash testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER testuser
WORKDIR /home/testuser/dotfiles
COPY --chown=testuser:testuser . .
RUN bash bootstrap-linux.sh
CMD ["bash", "tests/test_install.sh"]
```

- [ ] **Step 3: Update tests/Dockerfile.fedora**

```dockerfile
FROM fedora:latest
RUN dnf install -y sudo curl git
RUN useradd -m -s /bin/bash testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER testuser
WORKDIR /home/testuser/dotfiles
COPY --chown=testuser:testuser . .
RUN bash bootstrap-linux.sh
CMD ["bash", "tests/test_install.sh"]
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/test.yml tests/Dockerfile.ubuntu tests/Dockerfile.fedora
git commit -m "fix(ci): run bootstrap scripts before integration tests

macOS: run bootstrap-macos.sh in workflow step.
Linux: run bootstrap-linux.sh as Docker build step (RUN)."
```

---

### Task 8: Update test assertions for homebrew module

**Files:**
- Modify: `tests/test_install.sh`

- [ ] **Step 1: Add homebrew uninstall assertion**

In Phase 4 (verify uninstall), after the existing homebrew install check (line 146), add an uninstall check. The existing install check at line 145-147 already verifies `BEGIN dotfiles:homebrew` is present after install.

Add to Phase 4 (after the `assert_file_not_contains "${HOME}/.zprofile" "BEGIN dotfiles:rust"` line):

```bash
# Homebrew module uninstall (macOS only)
if [[ "${OS}" == "mac" ]]; then
  assert_file_not_contains "${HOME}/.zprofile" "BEGIN dotfiles:homebrew"
fi
```

- [ ] **Step 2: Commit**

```bash
git add tests/test_install.sh
git commit -m "test: add homebrew module uninstall assertion

Verifies the homebrew .zprofile block is removed after uninstall."
```

---

### Task 9: End-to-end validation

**Files:**
- No new files; validation only

- [ ] **Step 1: Run shellcheck on all modified/new files**

```bash
shellcheck bootstrap-macos.sh bootstrap-linux.sh install.sh uninstall.sh \
  lib/core.sh lib/modules.sh modules/*.sh tests/test_install.sh
```

Expected: No warnings.

- [ ] **Step 2: Verify install.sh works locally (macOS)**

```bash
./install.sh --only git 2>&1
```

Expected: No bootstrap output. Only:
- Prerequisites hint line
- Platform info line
- Module progress for git
- Final summary

- [ ] **Step 3: Verify bootstrap-macos.sh is idempotent**

```bash
./bootstrap-macos.sh
```

Expected: All "already installed" messages, no errors.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: address issues found during end-to-end validation"
```
