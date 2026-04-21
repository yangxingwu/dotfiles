# Dotfiles Project Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a modular, idempotent dotfiles auto-installer for macOS (full) and Linux
(minimal), with preflight conflict detection, DRY_RUN simulation, and a self-describing
module interface.

**Architecture:** Central `install.sh` orchestrator sources three lib layers (`detect.sh`,
`core.sh`, `preflight.sh`) then iterates over self-describing module files. Each module
declares its own metadata (platform, symlinks, dependencies) and lifecycle hooks; the
orchestrator drives them uniformly. No external runtime dependencies beyond bash 4+.

**Tech Stack:** bash 4+, shellcheck (lint), shfmt (formatting)

---

### Task 1: Scaffold Directory Structure

**Files:**
- Create: `lib/` (directory — populated in Tasks 2–4)
- Create: `modules/` (directory — populated in Tasks 7–9)
- Create: `config/git/git-hooks/` with `.gitkeep`
- Create: `config/nvim/` with `.gitkeep`
- Create: `config/tmux/` (populated in Task 10)
- Create: `config/zsh/sheldon/` (populated in Task 10)
- Create: `config/ghostty/` (populated in Task 10)
- Create: `config/kitty/` with `.gitkeep`

- [ ] **Step 1: Create all directories**

```bash
mkdir -p lib modules \
  config/git/git-hooks \
  config/nvim \
  config/tmux \
  config/zsh/sheldon \
  config/ghostty \
  config/kitty
```

- [ ] **Step 2: Add `.gitkeep` to directories with no immediate files**

```bash
touch config/nvim/.gitkeep \
      config/kitty/.gitkeep \
      config/git/git-hooks/.gitkeep
```

- [ ] **Step 3: Verify directory tree**

```bash
find . \
  -not -path './.git/*' \
  -not -path './docs/*' \
  -not -path './.claude/*' \
  -type d | sort
```

Expected output:
```
.
./config
./config/git
./config/git/git-hooks
./config/ghostty
./config/kitty
./config/nvim
./config/tmux
./config/zsh
./config/zsh/sheldon
./lib
./modules
```

- [ ] **Step 4: Commit**

```bash
git add config/
git commit -m "chore: scaffold config directory structure"
```

---

### Task 2: lib/detect.sh — OS and Package Manager Detection

**Files:**
- Create: `lib/detect.sh`

- [ ] **Step 1: Write the test (will fail — file does not exist yet)**

```bash
bash -c '
  source lib/detect.sh 2>/dev/null || { echo "FAIL: lib/detect.sh not found"; exit 1; }
  [[ -n "${DOTFILES_OS}" ]] \
    || { echo "FAIL: DOTFILES_OS not set"; exit 1; }
  [[ "${DOTFILES_OS}" == "mac" || "${DOTFILES_OS}" == "linux" ]] \
    || { echo "FAIL: unexpected DOTFILES_OS=${DOTFILES_OS}"; exit 1; }
  [[ -n "${DOTFILES_PKG_MANAGER}" ]] \
    || { echo "FAIL: DOTFILES_PKG_MANAGER not set"; exit 1; }
  echo "PASS: OS=${DOTFILES_OS}, PKG=${DOTFILES_PKG_MANAGER}"
'
```

Expected output: `FAIL: lib/detect.sh not found`

- [ ] **Step 2: Write `lib/detect.sh`**

```bash
#!/usr/bin/env bash
# lib/detect.sh — Runtime environment detection.
# Detects OS and package manager; exports DOTFILES_OS and DOTFILES_PKG_MANAGER.
# Safe to source multiple times (idempotent variable exports).
set -euo pipefail
IFS=$'\n\t'

detect::os() {
  case "$(uname -s)" in
    Darwin) DOTFILES_OS="mac" ;;
    Linux)  DOTFILES_OS="linux" ;;
    *)
      printf 'error: unsupported OS: %s\n' "$(uname -s)" >&2
      return 1
      ;;
  esac
  export DOTFILES_OS
}

detect::pkg_manager() {
  if command -v brew &>/dev/null; then
    DOTFILES_PKG_MANAGER="brew"
  elif command -v apt-get &>/dev/null; then
    DOTFILES_PKG_MANAGER="apt"
  elif command -v dnf &>/dev/null; then
    DOTFILES_PKG_MANAGER="dnf"
  elif command -v pacman &>/dev/null; then
    DOTFILES_PKG_MANAGER="pacman"
  else
    DOTFILES_PKG_MANAGER="unknown"
    printf 'warn: no supported package manager found\n' >&2
  fi
  export DOTFILES_PKG_MANAGER
}

detect::os
detect::pkg_manager
```

- [ ] **Step 3: Run the test to confirm it passes**

```bash
bash -c '
  source lib/detect.sh 2>/dev/null || { echo "FAIL: lib/detect.sh not found"; exit 1; }
  [[ -n "${DOTFILES_OS}" ]] \
    || { echo "FAIL: DOTFILES_OS not set"; exit 1; }
  [[ "${DOTFILES_OS}" == "mac" || "${DOTFILES_OS}" == "linux" ]] \
    || { echo "FAIL: unexpected DOTFILES_OS=${DOTFILES_OS}"; exit 1; }
  [[ -n "${DOTFILES_PKG_MANAGER}" ]] \
    || { echo "FAIL: DOTFILES_PKG_MANAGER not set"; exit 1; }
  echo "PASS: OS=${DOTFILES_OS}, PKG=${DOTFILES_PKG_MANAGER}"
'
```

Expected output on macOS with Homebrew: `PASS: OS=mac, PKG=brew`

- [ ] **Step 4: Lint**

```bash
bash -n lib/detect.sh && echo "syntax OK"
shellcheck lib/detect.sh && echo "shellcheck OK"
```

Expected output:
```
syntax OK
shellcheck OK
```

- [ ] **Step 5: Commit**

```bash
git add lib/detect.sh
git commit -m "feat: add lib/detect.sh — OS and package manager detection"
```

---

### Task 3: lib/core.sh — Logging, Backup, Symlink, Package Install

**Files:**
- Create: `lib/core.sh`

- [ ] **Step 1: Write the tests (will fail — file does not exist yet)**

```bash
bash -c '
  export DOTFILES_ROOT="$(pwd)"
  export DRY_RUN=1
  source lib/detect.sh 2>/dev/null \
    || { echo "FAIL: lib/detect.sh not found"; exit 1; }
  source lib/core.sh 2>/dev/null \
    || { echo "FAIL: lib/core.sh not found"; exit 1; }

  # Test: core::log produces output
  output=$(core::log INFO "hello")
  [[ "${output}" == *"INFO"* && "${output}" == *"hello"* ]] \
    || { echo "FAIL: core::log output missing INFO or message"; exit 1; }

  # Test: core::symlink in dry-run prints DRY-RUN line
  output=$(core::symlink "config/git/gitconfig" "${HOME}/.gitconfig")
  [[ "${output}" == *"DRY-RUN"* ]] \
    || { echo "FAIL: dry-run symlink output missing DRY-RUN tag"; exit 1; }

  # Test: core::pkg_install in dry-run prints DRY-RUN line
  output=$(core::pkg_install "git")
  [[ "${output}" == *"DRY-RUN"* ]] \
    || { echo "FAIL: dry-run pkg_install output missing DRY-RUN tag"; exit 1; }

  echo "PASS"
'
```

Expected output: `FAIL: lib/core.sh not found`

- [ ] **Step 2: Write `lib/core.sh`**

```bash
#!/usr/bin/env bash
# lib/core.sh — Standard library for all modules and the orchestrator.
# Provides: core::log, core::backup, core::symlink, core::pkg_install.
# Requires: DOTFILES_ROOT exported, DOTFILES_PKG_MANAGER set by detect.sh.
# DRY_RUN=1 makes all destructive operations no-ops (logged only).
set -euo pipefail
IFS=$'\n\t'

# ANSI colour codes (used only when stdout is a terminal)
if [[ -t 1 ]]; then
  readonly _CORE_RESET=$'\033[0m'
  readonly _CORE_GREEN=$'\033[0;32m'
  readonly _CORE_YELLOW=$'\033[0;33m'
  readonly _CORE_RED=$'\033[0;31m'
  readonly _CORE_CYAN=$'\033[0;36m'
else
  readonly _CORE_RESET=''
  readonly _CORE_GREEN=''
  readonly _CORE_YELLOW=''
  readonly _CORE_RED=''
  readonly _CORE_CYAN=''
fi

# core::log <level> <message>
# Levels: INFO WARN ERROR DRY
core::log() {
  local level="${1}"
  local message="${2}"
  local prefix

  case "${level}" in
    INFO)  prefix="${_CORE_GREEN}[INFO]${_CORE_RESET}" ;;
    WARN)  prefix="${_CORE_YELLOW}[WARN]${_CORE_RESET}" ;;
    ERROR) prefix="${_CORE_RED}[ERROR]${_CORE_RESET}" ;;
    DRY)   prefix="${_CORE_CYAN}[DRY-RUN]${_CORE_RESET}" ;;
    *)     prefix="[${level}]" ;;
  esac

  printf '%s %s\n' "${prefix}" "${message}"
}

# core::backup <absolute-path>
# Moves an existing file/dir to ~/.dotfiles-backup/YYYYMMDD-HHMMSS/ preserving
# relative path from HOME.
core::backup() {
  local target="${1}"
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local backup_dir="${HOME}/.dotfiles-backup/${timestamp}"
  local relative="${target#"${HOME}/"}"
  local backup_path="${backup_dir}/${relative}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would backup: ${target} → ${backup_path}"
    return 0
  fi

  mkdir -p "$(dirname "${backup_path}")"
  mv "${target}" "${backup_path}"
  core::log INFO "Backed up: ${target} → ${backup_path}"
}

# core::symlink <repo-relative-src> <absolute-target>
# Creates symlink target → DOTFILES_ROOT/src. Idempotent: skips if already correct.
core::symlink() {
  local src="${1}"
  local target="${2}"
  local abs_src="${DOTFILES_ROOT}/${src}"

  # Already correctly linked — skip silently
  if [[ -L "${target}" ]] && [[ "$(readlink "${target}")" == "${abs_src}" ]]; then
    core::log INFO "Already linked: ${target}"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would symlink: ${target} → ${abs_src}"
    return 0
  fi

  mkdir -p "$(dirname "${target}")"
  ln -sf "${abs_src}" "${target}"
  core::log INFO "Linked: ${target} → ${abs_src}"
}

# core::pkg_install <package-name>
# Installs a package via the detected package manager. Skips if already installed.
core::pkg_install() {
  local package="${1}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would install package: ${package}"
    return 0
  fi

  case "${DOTFILES_PKG_MANAGER}" in
    brew)
      if brew list --formula "${package}" &>/dev/null \
          || brew list --cask "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        brew install "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    apt)
      if dpkg -s "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        sudo apt-get install -y "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    dnf)
      if rpm -q "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        sudo dnf install -y "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    pacman)
      if pacman -Q "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        sudo pacman -S --noconfirm "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    *)
      core::log WARN "Unknown package manager — cannot install: ${package}"
      ;;
  esac
}
```

- [ ] **Step 3: Run the tests to confirm they pass**

```bash
bash -c '
  export DOTFILES_ROOT="$(pwd)"
  export DRY_RUN=1
  source lib/detect.sh
  source lib/core.sh

  output=$(core::log INFO "hello")
  [[ "${output}" == *"INFO"* && "${output}" == *"hello"* ]] \
    || { echo "FAIL: core::log"; exit 1; }

  output=$(core::symlink "config/git/gitconfig" "${HOME}/.gitconfig")
  [[ "${output}" == *"DRY-RUN"* ]] \
    || { echo "FAIL: dry-run symlink"; exit 1; }

  output=$(core::pkg_install "git")
  [[ "${output}" == *"DRY-RUN"* ]] \
    || { echo "FAIL: dry-run pkg_install"; exit 1; }

  echo "PASS"
'
```

Expected output: `PASS`

- [ ] **Step 4: Lint**

```bash
bash -n lib/core.sh && echo "syntax OK"
shellcheck lib/core.sh && echo "shellcheck OK"
```

Expected output:
```
syntax OK
shellcheck OK
```

- [ ] **Step 5: Commit**

```bash
git add lib/core.sh
git commit -m "feat: add lib/core.sh — logging, symlink, backup, pkg_install"
```

---

### Task 4: lib/preflight.sh — Conflict Scan Engine

**Files:**
- Create: `lib/preflight.sh`

- [ ] **Step 1: Write the test (will fail — file does not exist yet)**

```bash
bash -c '
  export DOTFILES_ROOT="$(pwd)"
  export DRY_RUN=1
  source lib/detect.sh
  source lib/core.sh
  source lib/preflight.sh 2>/dev/null \
    || { echo "FAIL: lib/preflight.sh not found"; exit 1; }

  # Test: scan with no modules produces no conflicts
  preflight::scan_all
  [[ ${#_PREFLIGHT_CONFLICTS[@]} -eq 0 ]] \
    || { echo "FAIL: expected 0 conflicts, got ${#_PREFLIGHT_CONFLICTS[@]}"; exit 1; }

  # Test: is_skipped returns false for unknown module
  preflight::is_skipped "nonexistent" \
    && { echo "FAIL: is_skipped should return false"; exit 1; } \
    || true

  echo "PASS"
'
```

Expected output: `FAIL: lib/preflight.sh not found`

- [ ] **Step 2: Write `lib/preflight.sh`**

```bash
#!/usr/bin/env bash
# lib/preflight.sh — Full conflict scan engine.
# Scans all module LINKS[] before any changes are made; presents a unified conflict
# report; prompts user for resolution strategy (backup all / skip all / per item).
# Requires: DOTFILES_ROOT, core.sh sourced, DOTFILES_OS set.
set -euo pipefail
IFS=$'\n\t'

# _PREFLIGHT_CONFLICTS entries: "module_name|src|target"
_PREFLIGHT_CONFLICTS=()
# PREFLIGHT_SKIP_MODULES: modules to skip during install (populated by resolution)
PREFLIGHT_SKIP_MODULES=()

# preflight::scan_module <module-file>
# Sources module in a subshell, checks each LINKS[] entry for conflicts.
# Prints conflict lines to stdout: "module_name|src|target"
preflight::scan_module() {
  local module_file="${1}"

  (
    # shellcheck source=/dev/null
    source "${module_file}"

    # Skip if wrong platform
    if [[ "${MODULE_PLATFORM}" != "all" ]] \
        && [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
      return 0
    fi

    local link_entry src target abs_src
    for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
      src="${link_entry%%:*}"
      target="${link_entry##*:}"
      abs_src="${DOTFILES_ROOT}/${src}"

      # Already correctly linked — not a conflict
      if [[ -L "${target}" ]] \
          && [[ "$(readlink "${target}")" == "${abs_src}" ]]; then
        continue
      fi

      # Conflict: target exists as anything (file, directory, or wrong symlink)
      if [[ -e "${target}" ]] || [[ -L "${target}" ]]; then
        printf '%s|%s|%s\n' "${MODULE_NAME}" "${src}" "${target}"
      fi
    done
  )
}

# preflight::scan_all
# Iterates all modules/*.sh files and collects conflicts into _PREFLIGHT_CONFLICTS.
preflight::scan_all() {
  local modules_dir="${DOTFILES_ROOT}/modules"
  _PREFLIGHT_CONFLICTS=()

  local module_file conflict
  for module_file in "${modules_dir}"/*.sh; do
    [[ -f "${module_file}" ]] || continue
    while IFS= read -r conflict; do
      [[ -n "${conflict}" ]] && _PREFLIGHT_CONFLICTS+=("${conflict}")
    done < <(preflight::scan_module "${module_file}")
  done
}

# preflight::report
# Prints conflict table and prompts user to choose resolution strategy.
# No-op if there are no conflicts.
preflight::report() {
  if [[ ${#_PREFLIGHT_CONFLICTS[@]} -eq 0 ]]; then
    core::log INFO "Preflight: no conflicts"
    return 0
  fi

  printf '\n%s\n' "── Conflicts detected ──────────────────────────────────────"
  printf '  %-14s  %-34s  %s\n' "MODULE" "SOURCE" "TARGET"
  printf '  %-14s  %-34s  %s\n' "--------------" "----------------------------------" "------"

  local conflict module src target
  for conflict in "${_PREFLIGHT_CONFLICTS[@]}"; do
    module="${conflict%%|*}"
    src="${conflict#*|}"
    src="${src%%|*}"
    target="${conflict##*|}"
    printf '  %-14s  %-34s  %s\n' "${module}" "${src}" "${target}"
  done

  printf '%s\n\n' "────────────────────────────────────────────────────────────"
  printf 'Resolve conflicts:\n'
  printf '  [b] Backup all conflicting targets and continue\n'
  printf '  [s] Skip all conflicting modules\n'
  printf '  [d] Decide per item\n'
  printf '  [q] Quit\n'
  printf '\nChoice: '

  local choice
  read -r choice
  case "${choice}" in
    b) preflight::_resolve_backup_all ;;
    s) preflight::_resolve_skip_all ;;
    d) preflight::_resolve_per_item ;;
    q) printf 'Aborted.\n'; exit 0 ;;
    *)
      printf 'error: invalid choice\n' >&2
      exit 1
      ;;
  esac
}

preflight::_resolve_backup_all() {
  local conflict target
  for conflict in "${_PREFLIGHT_CONFLICTS[@]}"; do
    target="${conflict##*|}"
    core::backup "${target}"
  done
}

preflight::_resolve_skip_all() {
  local conflict module
  for conflict in "${_PREFLIGHT_CONFLICTS[@]}"; do
    module="${conflict%%|*}"
    PREFLIGHT_SKIP_MODULES+=("${module}")
  done
  core::log WARN "Skipping modules: ${PREFLIGHT_SKIP_MODULES[*]}"
}

preflight::_resolve_per_item() {
  local conflict module target choice
  for conflict in "${_PREFLIGHT_CONFLICTS[@]}"; do
    module="${conflict%%|*}"
    target="${conflict##*|}"

    printf '\nConflict: %s  (module: %s)\n' "${target}" "${module}"
    printf '  [b] Backup this target\n'
    printf '  [s] Skip this module\n'
    printf '  [q] Quit\n'
    printf 'Choice: '
    read -r choice

    case "${choice}" in
      b) core::backup "${target}" ;;
      s) PREFLIGHT_SKIP_MODULES+=("${module}") ;;
      q) printf 'Aborted.\n'; exit 0 ;;
      *)
        printf 'warn: invalid choice — skipping module %s\n' "${module}" >&2
        PREFLIGHT_SKIP_MODULES+=("${module}")
        ;;
    esac
  done
}

# preflight::is_skipped <module-name>
# Returns 0 (true) if the module is in the skip list; 1 (false) otherwise.
preflight::is_skipped() {
  local module="${1}"
  local skipped
  for skipped in "${PREFLIGHT_SKIP_MODULES[@]+"${PREFLIGHT_SKIP_MODULES[@]}"}"; do
    [[ "${skipped}" == "${module}" ]] && return 0
  done
  return 1
}
```

- [ ] **Step 3: Run the tests to confirm they pass**

```bash
bash -c '
  export DOTFILES_ROOT="$(pwd)"
  export DRY_RUN=1
  source lib/detect.sh
  source lib/core.sh
  source lib/preflight.sh

  preflight::scan_all
  [[ ${#_PREFLIGHT_CONFLICTS[@]} -eq 0 ]] \
    || { echo "FAIL: expected 0 conflicts, got ${#_PREFLIGHT_CONFLICTS[@]}"; exit 1; }

  preflight::is_skipped "nonexistent" \
    && { echo "FAIL: is_skipped should return false"; exit 1; } \
    || true

  echo "PASS"
'
```

Expected output: `PASS`

- [ ] **Step 4: Lint**

```bash
bash -n lib/preflight.sh && echo "syntax OK"
shellcheck lib/preflight.sh && echo "shellcheck OK"
```

Expected output:
```
syntax OK
shellcheck OK
```

- [ ] **Step 5: Commit**

```bash
git add lib/preflight.sh
git commit -m "feat: add lib/preflight.sh — conflict scan and resolution engine"
```

---

### Task 5: install.sh — Orchestrator

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Write the test (will fail — file does not exist yet)**

```bash
bash -c 'bash -n install.sh 2>/dev/null \
  || { echo "FAIL: install.sh not found or syntax error"; exit 1; }
echo "PASS: syntax OK"'
```

Expected output: `FAIL: install.sh not found or syntax error`

- [ ] **Step 2: Write `install.sh`**

```bash
#!/usr/bin/env bash
# install.sh — dotfiles orchestrator
# Usage:
#   ./install.sh                        — install all modules
#   ./install.sh --dry-run              — simulate; no system changes
#   ./install.sh --module <name>        — install one module only
#   ./install.sh --module <name> --dry-run
set -euo pipefail
IFS=$'\n\t'

readonly DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

DRY_RUN=0
TARGET_MODULE=""

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --module)
      [[ $# -ge 2 ]] \
        || { printf 'error: --module requires an argument\n' >&2; exit 1; }
      TARGET_MODULE="${2}"
      shift 2
      ;;
    *)
      printf 'error: unknown argument: %s\n' "${1}" >&2
      exit 1
      ;;
  esac
done

export DRY_RUN

# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"
# shellcheck source=lib/preflight.sh
source "${DOTFILES_ROOT}/lib/preflight.sh"

if [[ "${DRY_RUN}" == "1" ]]; then
  core::log DRY "Dry-run mode — no changes will be made"
fi

core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

# Run full preflight scan when installing all modules.
# Single-module installs skip preflight (user is targeting a specific module).
if [[ -z "${TARGET_MODULE}" ]]; then
  preflight::scan_all
  preflight::report
fi

# install::run_module <module-file>
# Sources the module, checks platform and skip-list, then installs deps + symlinks.
install::run_module() {
  local module_file="${1}"

  # shellcheck source=/dev/null
  source "${module_file}"

  # Honour --module filter
  if [[ -n "${TARGET_MODULE}" ]] \
      && [[ "${MODULE_NAME}" != "${TARGET_MODULE}" ]]; then
    return 0
  fi

  # Platform guard
  if [[ "${MODULE_PLATFORM}" != "all" ]] \
      && [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
    core::log INFO "Skipping ${MODULE_NAME} (platform: ${MODULE_PLATFORM})"
    return 0
  fi

  # Preflight skip list
  if preflight::is_skipped "${MODULE_NAME}"; then
    core::log WARN "Skipping ${MODULE_NAME} (conflict not resolved)"
    return 0
  fi

  core::log INFO "▶ ${MODULE_NAME} — ${MODULE_DESC}"

  # Install platform-specific dependencies
  local -a deps=()
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    [[ ${#DEPS_MAC[@]} -gt 0 ]] && deps=("${DEPS_MAC[@]}")
  else
    [[ ${#DEPS_LINUX[@]} -gt 0 ]] && deps=("${DEPS_LINUX[@]}")
  fi
  for dep in "${deps[@]+"${deps[@]}"}"; do
    core::pkg_install "${dep}"
  done

  pre_install

  local link_entry src target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    src="${link_entry%%:*}"
    target="${link_entry##*:}"
    core::symlink "${src}" "${target}"
  done

  post_install

  core::log INFO "✓ ${MODULE_NAME}"
}

# Iterate all module files in alphabetical order
for _module_file in "${DOTFILES_ROOT}/modules"/*.sh; do
  [[ -f "${_module_file}" ]] || continue
  install::run_module "${_module_file}"
done

core::log INFO "Install complete."
```

- [ ] **Step 3: Make executable**

```bash
chmod +x install.sh
```

- [ ] **Step 4: Verify syntax and lint**

```bash
bash -n install.sh && echo "syntax OK"
shellcheck install.sh && echo "shellcheck OK"
```

Expected output:
```
syntax OK
shellcheck OK
```

- [ ] **Step 5: Smoke-test with no modules (no modules/ files yet — safe)**

```bash
./install.sh --dry-run
```

Expected output (macOS with Homebrew):
```
[DRY-RUN] Dry-run mode — no changes will be made
[INFO] Platform: mac | Package manager: brew
[INFO] Preflight: no conflicts
[INFO] Install complete.
```

- [ ] **Step 6: Commit**

```bash
git add install.sh
git commit -m "feat: add install.sh — module orchestrator with dry-run and preflight"
```

---

### Task 6: uninstall.sh — Symlink Removal

**Files:**
- Create: `uninstall.sh`

- [ ] **Step 1: Write `uninstall.sh`**

```bash
#!/usr/bin/env bash
# uninstall.sh — removes dotfile symlinks created by install.sh
# Usage:
#   ./uninstall.sh                 — remove all module symlinks
#   ./uninstall.sh --dry-run       — simulate removal
#   ./uninstall.sh --module <name> — remove one module only
set -euo pipefail
IFS=$'\n\t'

readonly DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

DRY_RUN=0
TARGET_MODULE=""

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --module)
      [[ $# -ge 2 ]] \
        || { printf 'error: --module requires an argument\n' >&2; exit 1; }
      TARGET_MODULE="${2}"
      shift 2
      ;;
    *)
      printf 'error: unknown argument: %s\n' "${1}" >&2
      exit 1
      ;;
  esac
done

export DRY_RUN

# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"

if [[ "${DRY_RUN}" == "1" ]]; then
  core::log DRY "Dry-run mode — no changes will be made"
fi

# uninstall::run_module <module-file>
# Removes symlinks created by the module; skips non-symlinks with a warning.
uninstall::run_module() {
  local module_file="${1}"

  # shellcheck source=/dev/null
  source "${module_file}"

  if [[ -n "${TARGET_MODULE}" ]] \
      && [[ "${MODULE_NAME}" != "${TARGET_MODULE}" ]]; then
    return 0
  fi

  if [[ "${MODULE_PLATFORM}" != "all" ]] \
      && [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
    return 0
  fi

  core::log INFO "▶ Uninstalling ${MODULE_NAME}"

  local link_entry target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    target="${link_entry##*:}"

    if [[ -L "${target}" ]]; then
      if [[ "${DRY_RUN:-0}" == "1" ]]; then
        core::log DRY "Would remove symlink: ${target}"
      else
        rm "${target}"
        core::log INFO "Removed symlink: ${target}"
      fi
    elif [[ -e "${target}" ]]; then
      core::log WARN "Not a symlink — skipping: ${target}"
    else
      core::log INFO "Already absent: ${target}"
    fi
  done

  core::log INFO "✓ ${MODULE_NAME}"
}

for _module_file in "${DOTFILES_ROOT}/modules"/*.sh; do
  [[ -f "${_module_file}" ]] || continue
  uninstall::run_module "${_module_file}"
done

core::log INFO "Uninstall complete."
```

- [ ] **Step 2: Make executable and lint**

```bash
chmod +x uninstall.sh
bash -n uninstall.sh && echo "syntax OK"
shellcheck uninstall.sh && echo "shellcheck OK"
```

Expected output:
```
syntax OK
shellcheck OK
```

- [ ] **Step 3: Smoke-test dry-run**

```bash
./uninstall.sh --dry-run
```

Expected output:
```
[DRY-RUN] Dry-run mode — no changes will be made
[INFO] Uninstall complete.
```

- [ ] **Step 4: Commit**

```bash
git add uninstall.sh
git commit -m "feat: add uninstall.sh — remove dotfile symlinks"
```

---

### Task 7: modules/git.sh and modules/zsh.sh

**Files:**
- Create: `modules/git.sh`
- Create: `modules/zsh.sh`

- [ ] **Step 1: Write `modules/git.sh`**

```bash
#!/usr/bin/env bash
# modules/git.sh — Git configuration and global hooks
# Platform: all
MODULE_NAME="git"
MODULE_DESC="Git configuration and global hooks"
MODULE_PLATFORM="all"

LINKS=(
  "config/git/gitconfig:${HOME}/.gitconfig"
  "config/git/git-hooks:${HOME}/.git-hooks"
)

DEPS_MAC=("git")
DEPS_LINUX=("git")

pre_install() { :; }

post_install() {
  # Register the global hooks directory so git uses it by default.
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would run: git config --global core.hooksPath ~/.git-hooks"
    return 0
  fi
  git config --global core.hooksPath "${HOME}/.git-hooks"
  core::log INFO "Set global git hooks path: ${HOME}/.git-hooks"
}
```

- [ ] **Step 2: Write `modules/zsh.sh`**

```bash
#!/usr/bin/env bash
# modules/zsh.sh — Zsh configuration (sheldon plugin manager, starship prompt)
# Platform: all
MODULE_NAME="zsh"
MODULE_DESC="Zsh shell configuration (sheldon plugins, starship prompt)"
MODULE_PLATFORM="all"

LINKS=(
  "config/zsh/sheldon/plugins.toml:${HOME}/.config/sheldon/plugins.toml"
  "config/zsh/starship.toml:${HOME}/.config/starship.toml"
)

DEPS_MAC=("sheldon" "starship")
DEPS_LINUX=("sheldon" "starship")

pre_install() { :; }
post_install() { :; }
```

- [ ] **Step 3: Lint both modules**

```bash
bash -n modules/git.sh && bash -n modules/zsh.sh && echo "syntax OK"
shellcheck modules/git.sh && shellcheck modules/zsh.sh && echo "shellcheck OK"
```

Expected output:
```
syntax OK
shellcheck OK
```

- [ ] **Step 4: Smoke-test both modules via dry-run install**

First create the placeholder config files needed for the symlink checks:

```bash
mkdir -p config/git && touch config/git/gitconfig
mkdir -p config/git/git-hooks
mkdir -p config/zsh/sheldon && touch config/zsh/sheldon/plugins.toml
touch config/zsh/starship.toml
```

Then run:

```bash
./install.sh --dry-run --module git
./install.sh --dry-run --module zsh
```

Expected output for `--module git`:
```
[DRY-RUN] Dry-run mode — no changes will be made
[INFO] Platform: mac | Package manager: brew
[INFO] ▶ git — Git configuration and global hooks
[DRY-RUN] Would install package: git
[DRY-RUN] Would symlink: /Users/<you>/.gitconfig → <dotfiles>/config/git/gitconfig
[DRY-RUN] Would symlink: /Users/<you>/.git-hooks → <dotfiles>/config/git/git-hooks
[DRY-RUN] Would run: git config --global core.hooksPath ~/.git-hooks
[INFO] ✓ git
[INFO] Install complete.
```

- [ ] **Step 5: Commit**

```bash
git add modules/git.sh modules/zsh.sh config/git/gitconfig config/zsh/sheldon/plugins.toml config/zsh/starship.toml
git commit -m "feat: add git and zsh modules with placeholder config files"
```

---

### Task 8: modules/nvim.sh and modules/tmux.sh

**Files:**
- Create: `modules/nvim.sh`
- Create: `modules/tmux.sh`

- [ ] **Step 1: Write `modules/nvim.sh`**

```bash
#!/usr/bin/env bash
# modules/nvim.sh — Neovim editor configuration (LazyVim)
# Platform: all
MODULE_NAME="nvim"
MODULE_DESC="Neovim editor configuration (LazyVim)"
MODULE_PLATFORM="all"

LINKS=(
  "config/nvim:${HOME}/.config/nvim"
)

DEPS_MAC=("neovim")
DEPS_LINUX=("neovim")

pre_install() { :; }
post_install() { :; }
```

- [ ] **Step 2: Write `modules/tmux.sh`**

```bash
#!/usr/bin/env bash
# modules/tmux.sh — tmux terminal multiplexer configuration
# Platform: all
MODULE_NAME="tmux"
MODULE_DESC="tmux terminal multiplexer configuration"
MODULE_PLATFORM="all"

LINKS=(
  "config/tmux/tmux.conf:${HOME}/.config/tmux/tmux.conf"
  "config/tmux/tmux.conf.local:${HOME}/.config/tmux/tmux.conf.local"
)

DEPS_MAC=("tmux")
DEPS_LINUX=("tmux")

pre_install() { :; }
post_install() { :; }
```

- [ ] **Step 3: Create placeholder config files**

```bash
touch config/tmux/tmux.conf config/tmux/tmux.conf.local
```

Note: `config/nvim/` already has `.gitkeep` from Task 1. The actual LazyVim config (lua files, `init.lua`, `lazy-lock.json`, etc.) should be placed there by the user separately. The module symlinks the entire directory.

Note on tmux: if you have an existing `tmux.conf` at `/Volumes/Code/tmux.conf`, copy it now:

```bash
# Only if the standalone file exists:
cp /Volumes/Code/tmux.conf config/tmux/tmux.conf
```

- [ ] **Step 4: Lint both modules**

```bash
bash -n modules/nvim.sh && bash -n modules/tmux.sh && echo "syntax OK"
shellcheck modules/nvim.sh && shellcheck modules/tmux.sh && echo "shellcheck OK"
```

- [ ] **Step 5: Smoke-test**

```bash
./install.sh --dry-run --module nvim
./install.sh --dry-run --module tmux
```

Expected output for `--module nvim` (macOS):
```
[DRY-RUN] Dry-run mode — no changes will be made
[INFO] Platform: mac | Package manager: brew
[INFO] ▶ nvim — Neovim editor configuration (LazyVim)
[DRY-RUN] Would install package: neovim
[DRY-RUN] Would symlink: /Users/<you>/.config/nvim → <dotfiles>/config/nvim
[INFO] ✓ nvim
[INFO] Install complete.
```

- [ ] **Step 6: Commit**

```bash
git add modules/nvim.sh modules/tmux.sh config/tmux/tmux.conf config/tmux/tmux.conf.local
git commit -m "feat: add nvim and tmux modules with placeholder config files"
```

---

### Task 9: modules/ghostty.sh and modules/kitty.sh (macOS only)

**Files:**
- Create: `modules/ghostty.sh`
- Create: `modules/kitty.sh`

- [ ] **Step 1: Write `modules/ghostty.sh`**

```bash
#!/usr/bin/env bash
# modules/ghostty.sh — Ghostty terminal emulator configuration
# Platform: mac (Ghostty is macOS-only)
MODULE_NAME="ghostty"
MODULE_DESC="Ghostty terminal emulator configuration"
MODULE_PLATFORM="mac"

LINKS=(
  "config/ghostty/config:${HOME}/.config/ghostty/config"
)

DEPS_MAC=()
DEPS_LINUX=()

pre_install() { :; }
post_install() { :; }
```

- [ ] **Step 2: Write `modules/kitty.sh`**

```bash
#!/usr/bin/env bash
# modules/kitty.sh — kitty terminal emulator configuration
# Platform: mac
MODULE_NAME="kitty"
MODULE_DESC="kitty terminal emulator configuration"
MODULE_PLATFORM="mac"

LINKS=(
  "config/kitty:${HOME}/.config/kitty"
)

DEPS_MAC=()
DEPS_LINUX=()

pre_install() { :; }
post_install() { :; }
```

- [ ] **Step 3: Create placeholder config files**

```bash
touch config/ghostty/config
```

Note: `config/kitty/` already has `.gitkeep` from Task 1. Place your kitty config files
(`kitty.conf`, `themes/`, etc.) directly in `config/kitty/`. The module symlinks the
entire directory.

- [ ] **Step 4: Lint both modules**

```bash
bash -n modules/ghostty.sh && bash -n modules/kitty.sh && echo "syntax OK"
shellcheck modules/ghostty.sh && shellcheck modules/kitty.sh && echo "shellcheck OK"
```

Expected output:
```
syntax OK
shellcheck OK
```

- [ ] **Step 5: Smoke-test**

```bash
./install.sh --dry-run --module ghostty
./install.sh --dry-run --module kitty
```

Expected output for `--module ghostty` (macOS):
```
[DRY-RUN] Dry-run mode — no changes will be made
[INFO] Platform: mac | Package manager: brew
[INFO] ▶ ghostty — Ghostty terminal emulator configuration
[DRY-RUN] Would symlink: /Users/<you>/.config/ghostty/config → <dotfiles>/config/ghostty/config
[INFO] ✓ ghostty
[INFO] Install complete.
```

On Linux, ghostty and kitty are skipped:
```
[INFO] Skipping ghostty (platform: mac)
```

- [ ] **Step 6: Commit**

```bash
git add modules/ghostty.sh modules/kitty.sh config/ghostty/config
git commit -m "feat: add ghostty and kitty modules (mac-only)"
```

---

### Task 10: Seed Real Config File Content

**Files:**
- Modify: `config/git/gitconfig`
- Create (optional): `config/git/git-hooks/commit-msg`
- Modify: `config/zsh/sheldon/plugins.toml`
- Modify: `config/zsh/starship.toml`

This task replaces placeholder files with real configuration content. Populate each file
with your actual settings. Minimal valid defaults are provided below as a starting point.

- [ ] **Step 1: Populate `config/git/gitconfig`**

Replace with your own name/email and preferred settings:

```ini
[user]
  name  = Your Name
  email = you@example.com

[core]
  editor     = nvim
  hooksPath  = ~/.git-hooks
  autocrlf   = false

[init]
  defaultBranch = main

[push]
  default = current

[pull]
  rebase = true

[diff]
  tool = vimdiff

[alias]
  st  = status -sb
  lg  = log --oneline --graph --decorate --all
  co  = checkout
  br  = branch
```

- [ ] **Step 2: Populate `config/zsh/sheldon/plugins.toml`**

Minimal valid sheldon config (add your own plugins):

```toml
shell = "zsh"

[plugins.zsh-syntax-highlighting]
github = "zsh-users/zsh-syntax-highlighting"

[plugins.zsh-autosuggestions]
github = "zsh-users/zsh-autosuggestions"
```

- [ ] **Step 3: Populate `config/zsh/starship.toml`**

Minimal starship prompt config:

```toml
# Starship prompt configuration
# Full reference: https://starship.rs/config/

add_newline = true

[character]
success_symbol = "[❯](bold green)"
error_symbol   = "[❯](bold red)"
```

- [ ] **Step 4: Populate `config/ghostty/config`**

Minimal valid Ghostty config:

```
# Ghostty terminal configuration
# Full reference: https://ghostty.org/docs/config

font-size = 14
theme = dark:GruvboxDark,light:GruvboxLight
```

- [ ] **Step 5: Verify dry-run with all modules**

```bash
./install.sh --dry-run
```

Confirm all modules are visited (except ghostty/kitty on Linux) and no errors appear.

- [ ] **Step 6: Remove .gitkeep from populated directories**

```bash
# Only remove .gitkeep if the directory now has real config files
# config/nvim/.gitkeep stays until LazyVim config is added
# config/kitty/.gitkeep stays until kitty config files are added
# config/git/git-hooks/.gitkeep stays until real hooks are added
git status
```

- [ ] **Step 7: Commit config files**

```bash
git add config/
git commit -m "chore: seed initial config file content"
```

---

### Task 11: End-to-End Dry-Run Smoke Test

This task verifies the full pipeline works together: detect → core → preflight → all modules.
No test framework needed — the dry-run output is the test.

- [ ] **Step 1: Run full dry-run install**

```bash
./install.sh --dry-run
```

Expected output (macOS, no existing configs):
```
[DRY-RUN] Dry-run mode — no changes will be made
[INFO] Platform: mac | Package manager: brew
[INFO] Preflight: no conflicts
[DRY-RUN] ▶ git — Git configuration and global hooks
[DRY-RUN] Would install package: git
[DRY-RUN] Would symlink: /Users/<you>/.gitconfig → .../config/git/gitconfig
[DRY-RUN] Would symlink: /Users/<you>/.git-hooks → .../config/git/git-hooks
[DRY-RUN] Would run: git config --global core.hooksPath ~/.git-hooks
[INFO] ✓ git
... (ghostty, kitty, nvim, tmux, zsh modules follow)
[INFO] Install complete.
```

- [ ] **Step 2: Verify preflight conflict detection**

Create a fake conflict and confirm preflight catches it:

```bash
touch /tmp/test-gitconfig-conflict
ln -sf /tmp/test-gitconfig-conflict "${HOME}/.gitconfig" 2>/dev/null || true
./install.sh --dry-run 2>&1 | head -20
rm -f "${HOME}/.gitconfig"
```

Expected: conflict table appears showing `.gitconfig` as a conflict under module `git`.

- [ ] **Step 3: Verify single-module install**

```bash
./install.sh --dry-run --module nvim
```

Expected: only nvim module runs; no preflight scan output (single-module skips preflight).

- [ ] **Step 4: Verify platform filtering on Linux (macOS only test — simulate)**

```bash
DOTFILES_OS=linux ./install.sh --dry-run 2>&1 | grep -E "ghostty|kitty"
```

Expected: `[INFO] Skipping ghostty (platform: mac)` and `[INFO] Skipping kitty (platform: mac)`

Note: this overrides `DOTFILES_OS` temporarily; after the subshell exits, your real OS is
used again.

- [ ] **Step 5: Run full shellcheck pass on all scripts**

```bash
shellcheck install.sh uninstall.sh lib/*.sh modules/*.sh
echo "All files pass shellcheck"
```

Expected output: `All files pass shellcheck` (no warnings or errors)

- [ ] **Step 6: Final commit**

```bash
git add .
git status  # verify no untracked files you didn't intend to include
git commit -m "chore: complete dotfiles installer — all modules pass dry-run smoke test"
```
