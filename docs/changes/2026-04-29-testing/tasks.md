# Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add integration tests that run install.sh and uninstall.sh on clean environments (macOS, Ubuntu, Fedora) via GitHub Actions, verifying binaries, configs, and cleanup.

**Architecture:** One test script (`tests/test_install.sh`) with a simple assert helper. Two Dockerfiles for Linux. One GitHub Actions workflow with three parallel jobs.

**Tech Stack:** Bash, Docker, GitHub Actions.

---

### Task 1: Create test helper and test script

**Files:**
- Create: `tests/test_install.sh`

- [ ] **Step 1: Write `tests/test_install.sh`**

```bash
#!/usr/bin/env bash
# tests/test_install.sh — Integration test for install.sh and uninstall.sh.
# Runs on a clean system (CI only — will modify the environment).
set -euo pipefail
IFS=$'\n\t'

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

assert() {
  local desc="${1}"
  shift
  if "$@"; then
    printf '  ✓ %s\n' "${desc}"
  else
    printf '  ✗ %s\n' "${desc}" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

assert_file_exists() { assert "file exists: ${1}" test -f "${1}"; }
assert_file_missing() { assert "file missing: ${1}" test ! -f "${1}"; }
assert_dir_exists() { assert "dir exists: ${1}" test -d "${1}"; }
assert_dir_missing() { assert "dir missing: ${1}" test ! -d "${1}"; }
assert_command() { assert "command on PATH: ${1}" command -v "${1}"; }
assert_file_contains() { assert "file ${1} contains '${2}'" grep -q "${2}" "${1}"; }
assert_file_not_contains() { assert "file ${1} missing '${2}'" ! grep -q "${2}" "${1}"; }

detect_os() {
  case "$(uname -s)" in
  Darwin) printf 'mac' ;;
  Linux) printf 'linux' ;;
  esac
}

OS="$(detect_os)"

# ─── Phase 1: Install ──────────────────────────────────────────────
printf '\n══ Phase 1: Running install.sh ══\n'

# Pipe "1" for nvim's interactive prompt (choose package manager).
printf '1\n' | "${DOTFILES_ROOT}/install.sh"

# ─── Phase 2: Verify install ───────────────────────────────────────
printf '\n══ Phase 2: Verifying install ══\n'

# Binaries (all platforms)
assert_command git
assert_command zsh
assert_command nvim
assert_command tmux
assert_command fzf
assert_command zoxide
assert_command cargo
assert_command rustup
assert_command sheldon
assert_command starship

# macOS-only binaries
if [[ "${OS}" == "mac" ]]; then
  assert "ghostty installed" brew list --cask ghostty
  assert "font-hack-nerd-font installed" brew list --cask font-hack-nerd-font
fi

# Git config
assert_file_contains "${HOME}/.gitconfig" "yangxingwu"

# Ghostty config (macOS only)
if [[ "${OS}" == "mac" ]]; then
  assert_file_exists "${HOME}/.config/ghostty/config"
  assert_file_contains "${HOME}/.config/ghostty/config" "Hack Nerd Font Mono"
fi

# Starship config
assert_file_exists "${HOME}/.config/starship.toml"

# Nvim config (cloned repo)
assert_dir_exists "${HOME}/.config/nvim/.git"

# tmux (oh-my-tmux)
assert_dir_exists "${HOME}/.local/share/tmux/oh-my-tmux"
assert "tmux.conf is a symlink" test -L "${HOME}/.config/tmux/tmux.conf"

# Shell init blocks in ~/.zshrc
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:fzf"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:zoxide"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:sheldon"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:starship"

# Shell init blocks in ~/.zprofile
assert_file_contains "${HOME}/.zprofile" "BEGIN dotfiles:rust"
if [[ "${OS}" == "mac" ]]; then
  assert_file_contains "${HOME}/.zprofile" "BEGIN dotfiles:homebrew"
fi

# ─── Phase 3: Uninstall ────────────────────────────────────────────
printf '\n══ Phase 3: Running uninstall.sh ══\n'

"${DOTFILES_ROOT}/uninstall.sh"

# ─── Phase 4: Verify uninstall ─────────────────────────────────────
printf '\n══ Phase 4: Verifying uninstall ══\n'

# Config files removed
if [[ "${OS}" == "mac" ]]; then
  assert_file_missing "${HOME}/.config/ghostty/config"
fi
assert_file_missing "${HOME}/.config/starship.toml"
assert_dir_missing "${HOME}/.config/nvim"

# tmux cleanup
assert_dir_missing "${HOME}/.local/share/tmux/oh-my-tmux"
assert "tmux.conf symlink removed" test ! -L "${HOME}/.config/tmux/tmux.conf"
assert_file_missing "${HOME}/.config/tmux/tmux.conf.local"

# Managed blocks removed from ~/.zshrc
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:fzf"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:zoxide"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:sheldon"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:starship"

# Managed blocks removed from ~/.zprofile
assert_file_not_contains "${HOME}/.zprofile" "BEGIN dotfiles:rust"

# Git config entries removed
assert_file_not_contains "${HOME}/.gitconfig" "yangxingwu" || true

# ─── Result ─────────────────────────────────────────────────────────
printf '\n══ Result ══\n'
if ((FAILURES > 0)); then
  printf '%d test(s) failed\n' "${FAILURES}" >&2
  exit 1
else
  printf 'All tests passed\n'
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/test_install.sh
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n tests/test_install.sh
```

- [ ] **Step 4: Commit**

```bash
git add tests/test_install.sh
git commit -m "feat(tests): add integration test script for install/uninstall"
```

---

### Task 2: Create Dockerfiles

**Files:**
- Create: `tests/Dockerfile.ubuntu`
- Create: `tests/Dockerfile.fedora`

- [ ] **Step 1: Write `tests/Dockerfile.ubuntu`**

```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y sudo curl git
RUN useradd -m -s /bin/bash testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER testuser
WORKDIR /home/testuser/dotfiles
COPY --chown=testuser:testuser . .
CMD ["bash", "tests/test_install.sh"]
```

- [ ] **Step 2: Write `tests/Dockerfile.fedora`**

```dockerfile
FROM fedora:latest
RUN dnf install -y sudo curl git
RUN useradd -m -s /bin/bash testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER testuser
WORKDIR /home/testuser/dotfiles
COPY --chown=testuser:testuser . .
CMD ["bash", "tests/test_install.sh"]
```

- [ ] **Step 3: Commit**

```bash
git add tests/Dockerfile.ubuntu tests/Dockerfile.fedora
git commit -m "feat(tests): add Dockerfiles for Ubuntu and Fedora test environments"
```

---

### Task 3: Create GitHub Actions workflow

**Files:**
- Create: `.github/workflows/test.yml`

- [ ] **Step 1: Write `.github/workflows/test.yml`**

```yaml
name: Integration Tests

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run integration tests
        run: bash tests/test_install.sh

  test-ubuntu:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build test image
        run: docker build -f tests/Dockerfile.ubuntu -t dotfiles-test-ubuntu .
      - name: Run integration tests
        run: docker run --rm dotfiles-test-ubuntu

  test-fedora:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build test image
        run: docker build -f tests/Dockerfile.fedora -t dotfiles-test-fedora .
      - name: Run integration tests
        run: docker run --rm dotfiles-test-fedora
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/test.yml
git commit -m "feat(ci): add GitHub Actions workflow for integration tests"
```

---

### Task 4: Verification

- [ ] **Step 1: Syntax check test script**

```bash
bash -n tests/test_install.sh
shellcheck tests/test_install.sh
```

- [ ] **Step 2: Verify Docker builds locally (optional, Linux only)**

```bash
docker build -f tests/Dockerfile.ubuntu -t dotfiles-test-ubuntu .
docker run --rm dotfiles-test-ubuntu
```

- [ ] **Step 3: Push and verify CI**

Push to a branch, open a PR, confirm all three jobs pass in GitHub Actions.

- [ ] **Step 4: Commit any fixes**

If CI fails, fix and commit.
