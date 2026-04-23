# System Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the installer, collapse the module interface to two hooks, remove `DRY_RUN` and `preflight.sh`, call oh-my-tmux's upstream installer, and unify shell style across the repo.

**Architecture:** Incremental task ordering that keeps the repo working at every commit. `lib/core.sh` is upgraded first so modules can depend on new helpers (`core::check_installed`, `core::require_version`) and the new interactive `core::symlink`. Each module is migrated one at a time. `install.sh` and `uninstall.sh` are rewritten after all modules have been migrated to the `install()` / `uninstall()` interface. Docs sync last so they describe the final shape.

**Tech Stack:** bash 4+, shellcheck, shfmt (2-space indent, `switch-case-indent=true`, `binary-next-line=true`), git. No test harness — verification is manual: `bash -n`, `shellcheck`, and trial runs of `./install.sh` / `./uninstall.sh`.

**Reference:** `docs/changes/2026-04-22-system-optimization/design.md`.

**Style rules** (`.claude/rules/shell-style.md`, auto-loaded):
- Every script: `#!/usr/bin/env bash`, `set -euo pipefail`, `IFS=$'\n\t'`.
- Quote every expansion; always `${var}` braces.
- `[[ ]]` not `[ ]`; `printf` not `echo`.
- All module output via `core::log` (direct `printf` only allowed in `lib/core.sh`).
- Namespaces: `core::`, `detect::`, `install::`, `uninstall::`, `_<mod>::` (module-local helpers).
- `case` items indent 2 spaces; bodies 4 spaces (shfmt enforces).
- `&&`/`||` goes at the start of the next line when a statement wraps.

---

## Prerequisites

- [ ] **Step 1: Confirm working tree is clean**

Run:
```bash
cd /Volumes/Code/dotfiles && git status
```

Expected: `nothing to commit, working tree clean` (the branch may be ahead of origin/main — that is fine).

- [ ] **Step 2: Read the full design**

Run:
```bash
cat docs/changes/2026-04-22-system-optimization/design.md
```

Expected: read the whole spec so the task context is in-memory before starting.

---

## Task 1: Generate `config/zsh/starship.toml`

We need to seed the tracked starship config from the upstream preset before `zsh.sh` can stop generating it at runtime.

**Files:**
- Create: `config/zsh/starship.toml`

- [ ] **Step 1: Verify starship is installed**

Run:
```bash
command -v starship && starship --version
```

Expected: a path and a version line. If starship is missing, install it (`brew install starship` on macOS) before continuing — we need it to generate the file.

- [ ] **Step 2: Generate the file from the preset**

Run:
```bash
starship preset catppuccin-powerline -o config/zsh/starship.toml
```

Expected: no output; `config/zsh/starship.toml` now exists and is non-empty.

- [ ] **Step 3: Sanity-check the generated file**

Run:
```bash
head -5 config/zsh/starship.toml && wc -l config/zsh/starship.toml
```

Expected: TOML-looking content (starts with `"$schema"` or a `[...]` section) and several hundred lines.

- [ ] **Step 4: Commit**

```bash
git add config/zsh/starship.toml
git commit -m "feat(zsh): track starship.toml generated from catppuccin-powerline preset"
```

---

## Task 2: Upgrade `lib/core.sh` — remove DRY_RUN, add helpers, interactive `core::symlink`

This is the single biggest code change. Every later task depends on the new `core.sh`, so it lands first. After this task the modules still use the old three-hook interface and `install.sh` still references DRY_RUN — we accept a temporary broken state until Task 3.

**Files:**
- Modify: `lib/core.sh` (full rewrite)

- [ ] **Step 1: Overwrite `lib/core.sh` with the new contents**

Write this exact content to `lib/core.sh`:

```bash
#!/usr/bin/env bash
# lib/core.sh — Standard library for all modules and the orchestrator.
# Provides: core::log, core::backup, core::symlink, core::pkg_install,
#           core::check_installed, core::require_version.
# Requires: DOTFILES_ROOT exported, DOTFILES_PKG_MANAGER set by detect.sh.
set -euo pipefail
IFS=$'\n\t'

# Idempotent re-source guard — colour constants are readonly and would otherwise
# abort the script if this file were sourced twice (e.g. from tests).
[[ -n "${_CORE_SH_LOADED:-}" ]] && return 0
readonly _CORE_SH_LOADED=1

# ANSI colour codes (used only when stdout is a terminal)
if [[ -t 1 ]]; then
  readonly _CORE_RESET=$'\033[0m'
  readonly _CORE_GREEN=$'\033[0;32m'
  readonly _CORE_YELLOW=$'\033[0;33m'
  readonly _CORE_RED=$'\033[0;31m'
else
  readonly _CORE_RESET=''
  readonly _CORE_GREEN=''
  readonly _CORE_YELLOW=''
  readonly _CORE_RED=''
fi

# core::log <level> <message>
# Levels: INFO WARN ERROR
# ERROR and WARN are written to stderr so they survive stdout redirection.
core::log() {
  local level="${1}"
  local message="${2}"
  local prefix
  local fd=1

  case "${level}" in
    INFO) prefix="${_CORE_GREEN}[INFO]${_CORE_RESET}" ;;
    WARN)
      prefix="${_CORE_YELLOW}[WARN]${_CORE_RESET}"
      fd=2
      ;;
    ERROR)
      prefix="${_CORE_RED}[ERROR]${_CORE_RESET}"
      fd=2
      ;;
    *) prefix="[${level}]" ;;
  esac

  printf '%s %s\n' "${prefix}" "${message}" >&"${fd}"
}

# core::check_installed <binary>
# Returns 0 if the binary is on PATH, 1 otherwise. Pure detection, no side effects.
core::check_installed() {
  command -v "${1}" &>/dev/null
}

# core::require_version <binary> <min-major> <min-minor>
# Returns 0 if `<binary> --version` reports >= min-major.min-minor, 1 otherwise.
# Parses the first "<digits>.<digits>" substring on the first output line.
core::require_version() {
  local bin="${1}" min_major="${2}" min_minor="${3}"
  local version major minor
  version="$("${bin}" --version 2>/dev/null | head -1 |
    grep -oE '[0-9]+\.[0-9]+' || true)"
  [[ -z "${version}" ]] && return 1
  major="${version%.*}"
  minor="${version#*.}"
  ((major > min_major)) && return 0
  ((major == min_major)) && ((minor >= min_minor)) && return 0
  return 1
}

# core::backup <absolute-path>
# Moves an existing file/dir to ~/.dotfiles-backup/YYYYMMDD-HHMMSS/ preserving
# relative path from HOME.
core::backup() {
  local target="${1}"
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local backup_dir="${HOME}/.dotfiles-backup/${timestamp}"
  if [[ "${target}" != "${HOME}"/* ]]; then
    core::log ERROR "Backup target must be under HOME: ${target}"
    return 1
  fi
  local relative="${target#"${HOME}/"}"
  local backup_path="${backup_dir}/${relative}"

  if ! mkdir -p "$(dirname "${backup_path}")"; then
    core::log ERROR "Failed to create backup directory for: ${target}"
    return 1
  fi
  if ! mv "${target}" "${backup_path}"; then
    core::log ERROR "Failed to backup: ${target}"
    return 1
  fi
  core::log INFO "Backed up: ${target} → ${backup_path}"
}

# core::symlink <repo-relative-src> <absolute-target>
# Creates symlink target → DOTFILES_ROOT/src. On conflict (target exists as a
# real file, directory, or foreign symlink), prompts the user interactively:
#   [b] backup existing target to ~/.dotfiles-backup/<ts>/ and replace
#   [s] skip — do NOT create the symlink; user's file is preserved
#   [q] quit the installer immediately (exit 1)
# Idempotent: if target is already the correct symlink, logs and returns 0.
core::symlink() {
  local src="${1}"
  local target="${2}"
  local abs_src="${DOTFILES_ROOT}/${src}"

  # Already correctly linked — no-op
  if [[ -L "${target}" ]] && [[ "$(readlink "${target}")" == "${abs_src}" ]]; then
    core::log INFO "Already linked: ${target}"
    return 0
  fi

  # Target absent — create parent, link, done
  if [[ ! -e "${target}" ]] && [[ ! -L "${target}" ]]; then
    if ! mkdir -p "$(dirname "${target}")"; then
      core::log ERROR "Failed to create parent dirs for: ${target}"
      return 1
    fi
    if ! ln -sf "${abs_src}" "${target}"; then
      core::log ERROR "Failed to create symlink: ${target}"
      return 1
    fi
    core::log INFO "Linked: ${target} → ${abs_src}"
    return 0
  fi

  # Conflict — interactive resolution
  core::log WARN "Conflict: ${target} exists (not managed by dotfiles)"
  printf '  [b] backup to ~/.dotfiles-backup/<ts>/ and replace\n' >&2
  printf '  [s] skip this symlink (existing file preserved)\n' >&2
  printf '  [q] quit installer\n' >&2
  printf 'Choice: ' >&2

  local choice
  read -r choice

  case "${choice}" in
    b)
      core::backup "${target}" || return 1
      if ! mkdir -p "$(dirname "${target}")"; then
        core::log ERROR "Failed to create parent dirs for: ${target}"
        return 1
      fi
      if ! ln -sf "${abs_src}" "${target}"; then
        core::log ERROR "Failed to create symlink: ${target}"
        return 1
      fi
      core::log INFO "Linked: ${target} → ${abs_src}"
      ;;
    s)
      core::log WARN "Skipped: ${target} — your file is unchanged, module may be incomplete"
      ;;
    q)
      core::log ERROR "Aborted by user"
      exit 1
      ;;
    *)
      core::log ERROR "Invalid choice: ${choice}"
      exit 1
      ;;
  esac
}

# core::pkg_install <package> [package ...]
# Installs one or more packages via the detected package manager.
# Skips individual packages that are already installed.
core::pkg_install() {
  local package

  for package in "$@"; do
    case "${DOTFILES_PKG_MANAGER}" in
      brew)
        if brew list --formula "${package}" &>/dev/null ||
          brew list --cask "${package}" &>/dev/null; then
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
  done
}
```

- [ ] **Step 2: Syntax check**

Run:
```bash
bash -n lib/core.sh
```

Expected: no output (success).

- [ ] **Step 3: Shellcheck**

Run:
```bash
shellcheck lib/core.sh
```

Expected: no findings.

- [ ] **Step 4: Format check (shfmt)**

Run:
```bash
shfmt -d lib/core.sh
```

Expected: no diff. If shfmt proposes changes, apply them with `shfmt -w lib/core.sh` and re-run.

- [ ] **Step 5: Quick smoke test of helpers**

Run:
```bash
bash -c 'DOTFILES_ROOT=/tmp source lib/core.sh && core::check_installed bash && echo OK'
```

Expected: `OK`.

Run:
```bash
bash -c 'DOTFILES_ROOT=/tmp source lib/core.sh && core::require_version bash 3 0 && echo OK'
```

Expected: `OK` (every system bash is ≥ 3.0).

- [ ] **Step 6: Commit**

```bash
git add lib/core.sh
git commit -m "refactor(core): remove DRY_RUN; add check_installed/require_version; interactive core::symlink"
```

---

## Task 3: Rewrite `install.sh` — no flags, no DRY_RUN, install() → LINKS

After this task the orchestrator expects every module to expose `install()` and `uninstall()`. The current modules still export `pre_install`/`install`/`post_install` — the `pre_install`/`post_install` hooks will silently be no-ops until their modules are migrated in Tasks 6–11. **Do not run `./install.sh` between Task 3 and Task 11** — behaviour will be partially correct.

**Files:**
- Modify: `install.sh` (full rewrite)

- [ ] **Step 1: Overwrite `install.sh`**

Write this exact content:

```bash
#!/usr/bin/env bash
# install.sh — dotfiles orchestrator
# Usage: ./install.sh
#
# Installs every module in ${_MODULES} for the current platform. Idempotent.
# Conflicts are resolved interactively per symlink inside core::symlink.
set -euo pipefail
IFS=$'\n\t'

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
export DOTFILES_ROOT

# Explicit install order — dependencies first.
# rust must precede nvim (cargo is required for tree-sitter-cli).
readonly _MODULES=(ghostty git rust nvim tmux zsh)

# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"

# install::run_module <name> <index> <total>
# Sources modules/<name>.sh, validates interface, runs install() then LINKS.
install::run_module() {
  local name="${1}" index="${2}" total="${3}"
  local module_file="${DOTFILES_ROOT}/modules/${name}.sh"

  # Reset module state to prevent bleed-through between modules.
  install() { :; }
  uninstall() { :; }
  unset MODULE_NAME MODULE_DESC MODULE_PLATFORM LINKS

  # shellcheck source=/dev/null
  source "${module_file}"

  : "${MODULE_NAME:?missing MODULE_NAME in ${module_file}}"
  : "${MODULE_DESC:?missing MODULE_DESC in ${module_file}}"
  : "${MODULE_PLATFORM:?missing MODULE_PLATFORM in ${module_file}}"
  if [[ "${MODULE_NAME}" != "${name}" ]]; then
    core::log ERROR "MODULE_NAME=${MODULE_NAME} does not match filename ${name}.sh"
    return 1
  fi

  if [[ "${MODULE_PLATFORM}" != "all" ]] &&
    [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
    core::log INFO "Skipping ${name} (platform: ${MODULE_PLATFORM})"
    return 0
  fi

  core::log INFO "▶ [${index}/${total}] ${name} — ${MODULE_DESC}"
  install

  local link_entry src target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    src="${link_entry%%:*}"
    target="${link_entry##*:}"
    core::symlink "${src}" "${target}"
  done

  core::log INFO "✓ ${name}"
}

main() {
  core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

  local total=${#_MODULES[@]} i=0 name
  for name in "${_MODULES[@]}"; do
    i=$((i + 1))
    install::run_module "${name}" "${i}" "${total}"
  done

  core::log INFO "Install complete."
}

main "$@"
```

- [ ] **Step 2: Make it executable**

Run:
```bash
chmod +x install.sh
```

- [ ] **Step 3: Syntax/shellcheck/shfmt**

Run:
```bash
bash -n install.sh && shellcheck install.sh && shfmt -d install.sh
```

Expected: no output (all three pass).

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "refactor(install): drop --module/--dry-run flags; install() → LINKS order; 2-hook interface"
```

---

## Task 4: Rewrite `uninstall.sh` — LINKS → uninstall()

**Files:**
- Modify: `uninstall.sh` (full rewrite)

- [ ] **Step 1: Overwrite `uninstall.sh`**

Write this exact content:

```bash
#!/usr/bin/env bash
# uninstall.sh — removes dotfile symlinks and runs each module's uninstall() hook.
# Usage: ./uninstall.sh
set -euo pipefail
IFS=$'\n\t'

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_ROOT
export DOTFILES_ROOT

readonly _MODULES=(ghostty git rust nvim tmux zsh)

# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"

# uninstall::run_module <name>
# Sources modules/<name>.sh, removes LINKS symlinks, then runs uninstall().
uninstall::run_module() {
  local name="${1}"
  local module_file="${DOTFILES_ROOT}/modules/${name}.sh"

  install() { :; }
  uninstall() { :; }
  unset MODULE_NAME MODULE_DESC MODULE_PLATFORM LINKS

  # shellcheck source=/dev/null
  source "${module_file}"

  if [[ "${MODULE_PLATFORM}" != "all" ]] &&
    [[ "${MODULE_PLATFORM}" != "${DOTFILES_OS}" ]]; then
    core::log INFO "Skipping ${name} (platform: ${MODULE_PLATFORM})"
    return 0
  fi

  core::log INFO "▶ Uninstalling ${name}"

  # 1. Remove LINKS symlinks first (relinquish ownership)
  local link_entry target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    target="${link_entry##*:}"
    if [[ -L "${target}" ]]; then
      rm "${target}"
      core::log INFO "Removed symlink: ${target}"
    elif [[ -e "${target}" ]]; then
      core::log WARN "Not a symlink — skipping: ${target}"
    fi
  done

  # 2. Run uninstall() to clean up external side effects (clones, etc.)
  uninstall

  core::log INFO "✓ ${name}"
}

main() {
  local name
  for name in "${_MODULES[@]}"; do
    uninstall::run_module "${name}"
  done
  core::log INFO "Uninstall complete."
}

main "$@"
```

- [ ] **Step 2: Make it executable**

Run:
```bash
chmod +x uninstall.sh
```

- [ ] **Step 3: Syntax/shellcheck/shfmt**

Run:
```bash
bash -n uninstall.sh && shellcheck uninstall.sh && shfmt -d uninstall.sh
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add uninstall.sh
git commit -m "refactor(uninstall): drop flags; LINKS → uninstall() order; 2-hook interface"
```

---

## Task 5: Delete `lib/preflight.sh`

`install.sh` and `uninstall.sh` no longer source it. Remove the file and verify nothing else in the repo references it.

**Files:**
- Delete: `lib/preflight.sh`

- [ ] **Step 1: Remove the file**

Run:
```bash
git rm lib/preflight.sh
```

Expected: `rm 'lib/preflight.sh'`.

- [ ] **Step 2: Verify no dangling references**

Run:
```bash
grep -R "preflight" --include='*.sh' --include='*.md' . || true
```

Expected: matches only in historical `docs/changes/` directories (the design docs for earlier refactors). No matches in `lib/`, `modules/`, `install.sh`, `uninstall.sh`, `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `.claude/`.

If there are unexpected matches outside historical design docs, stop and investigate.

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor(lib): delete preflight.sh — conflicts handled in core::symlink"
```

---

## Task 6: Migrate `modules/ghostty.sh`

Simplest module — pure LINKS, both hooks no-op. Gets the new interface established.

**Files:**
- Modify: `modules/ghostty.sh`

- [ ] **Step 1: Overwrite `modules/ghostty.sh`**

Write this exact content:

```bash
#!/usr/bin/env bash
# modules/ghostty.sh — Ghostty terminal emulator configuration
# Platform: mac
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="ghostty"
MODULE_DESC="Ghostty terminal emulator configuration"
MODULE_PLATFORM="mac"

LINKS=(
  "config/ghostty/config:${HOME}/.config/ghostty/config"
)

install() { :; }
uninstall() { :; }
```

- [ ] **Step 2: Syntax/shellcheck/shfmt**

Run:
```bash
bash -n modules/ghostty.sh && shellcheck modules/ghostty.sh && shfmt -d modules/ghostty.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add modules/ghostty.sh
git commit -m "refactor(ghostty): migrate to 2-hook interface"
```

---

## Task 7: Migrate `modules/git.sh` — drop redundant post_install

`config/git/gitconfig` already declares `[core] hooksPath = ~/.git-hooks` (verified before writing this plan), so the `git config --global core.hooksPath` line in the current `post_install` is redundant.

**Files:**
- Modify: `modules/git.sh`

- [ ] **Step 1: Verify gitconfig already has hooksPath**

Run:
```bash
grep -n 'hooksPath' config/git/gitconfig
```

Expected: one line similar to `2:	hooksPath = ~/.git-hooks`. If that line is missing, add it under a `[core]` section before continuing.

- [ ] **Step 2: Overwrite `modules/git.sh`**

Write this exact content:

```bash
#!/usr/bin/env bash
# modules/git.sh — Git configuration and global hooks
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="git"
MODULE_DESC="Git configuration and global hooks"
MODULE_PLATFORM="all"

LINKS=(
  "config/git/gitconfig:${HOME}/.gitconfig"
  "config/git/git-hooks:${HOME}/.git-hooks"
)

install() {
  core::pkg_install git
}

uninstall() { :; }
```

- [ ] **Step 3: Syntax/shellcheck/shfmt**

Run:
```bash
bash -n modules/git.sh && shellcheck modules/git.sh && shfmt -d modules/git.sh
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add modules/git.sh
git commit -m "refactor(git): migrate to 2-hook interface; drop redundant post_install hooksPath setter"
```

---

## Task 8: Migrate `modules/rust.sh` — fold post_install into install

Rust's old `post_install` did `source ~/.cargo/env` so nvim could see `cargo` later in the same install run. That work now happens inside `install()` itself, right after the rustup install.

**Files:**
- Modify: `modules/rust.sh`

- [ ] **Step 1: Overwrite `modules/rust.sh`**

Write this exact content:

```bash
#!/usr/bin/env bash
# modules/rust.sh — Rust toolchain via rustup
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="rust"
MODULE_DESC="Rust toolchain via rustup"
MODULE_PLATFORM="all"

LINKS=()

# Installs the Rust stable toolchain via the official rustup script.
# Idempotent: skips if rustup is already present. After install (or skip),
# sources ~/.cargo/env so later modules (nvim → tree-sitter-cli) can see cargo.
install() {
  if core::check_installed rustup; then
    core::log INFO "rustup already installed — skipping"
  else
    # --no-modify-path: ~/.cargo/env is already sourced via config/zsh/zshenv
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
      sh -s -- -y --no-modify-path
    core::log INFO "rustup installed"
  fi

  if [[ -f "${HOME}/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
  else
    core::log WARN "${HOME}/.cargo/env not found — cargo may not be on PATH"
  fi
}

uninstall() { :; }
```

- [ ] **Step 2: Syntax/shellcheck/shfmt**

Run:
```bash
bash -n modules/rust.sh && shellcheck modules/rust.sh && shfmt -d modules/rust.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add modules/rust.sh
git commit -m "refactor(rust): migrate to 2-hook interface; fold post_install source into install"
```

---

## Task 9: Migrate `modules/nvim.sh` — merge three hooks into one install()

All of `pre_install` (runtime deps + tree-sitter-cli), `install` (nvim itself), and `post_install` (clone LazyVim config) collapse into a single `install()`. Old manual `command -v nvim` + version-regex code is replaced by `core::check_installed` + `core::require_version`.

**Files:**
- Modify: `modules/nvim.sh`

- [ ] **Step 1: Overwrite `modules/nvim.sh`**

Write this exact content:

```bash
#!/usr/bin/env bash
# modules/nvim.sh — Neovim editor with LazyVim configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="nvim"
MODULE_DESC="Neovim editor with LazyVim configuration (yangxingwu/neovim-lua-config)"
MODULE_PLATFORM="all"

LINKS=()

readonly _NVIM_SRC_REPO="https://github.com/neovim/neovim.git"
readonly _NVIM_BUILD_DIR="/tmp/neovim-build-$$"
readonly _NVIM_MIN_MAJOR=0
readonly _NVIM_MIN_MINOR=9
readonly _NVIM_REPO="git@github.com:yangxingwu/neovim-lua-config.git"
readonly _NVIM_BRANCH="LazyVimV2"
readonly _NVIM_TARGET="${HOME}/.config/nvim"

install() {
  # 1. LazyVim runtime dependencies
  case "${DOTFILES_OS}" in
    mac) core::pkg_install ripgrep fd lazygit node shfmt shellcheck ;;
    linux) core::pkg_install ripgrep fd-find lazygit nodejs npm shfmt shellcheck ;;
  esac

  # tree-sitter-cli has no pkg-manager package — install via cargo
  if core::check_installed cargo; then
    cargo install --locked tree-sitter-cli
  else
    core::log WARN "cargo not found — skipping tree-sitter-cli (run rust module first)"
  fi

  # 2. Neovim itself — version check, prompt on miss
  if core::check_installed nvim &&
    core::require_version nvim "${_NVIM_MIN_MAJOR}" "${_NVIM_MIN_MINOR}"; then
    core::log INFO "Neovim >= ${_NVIM_MIN_MAJOR}.${_NVIM_MIN_MINOR} already installed — skipping"
  else
    local choice
    printf '\nNeovim not found (or too old — LazyVim requires >= 0.9)\n'
    printf 'Install options:\n'
    printf '  1) Package manager (brew/apt)\n'
    printf '  2) Build from source (latest stable tag)\n'
    printf 'Choice [1]: '
    read -r choice
    choice="${choice:-1}"
    case "${choice}" in
      1) _nvim::install_pkg ;;
      2) _nvim::install_src ;;
      *) core::log WARN "Unknown choice '${choice}' — skipping Neovim install" ;;
    esac
  fi

  # 3. Clone config repo to ~/.config/nvim
  if [[ -d "${_NVIM_TARGET}/.git" ]]; then
    core::log INFO "Neovim config already cloned — skipping"
    return 0
  fi

  if [[ -L "${_NVIM_TARGET}" ]]; then
    rm "${_NVIM_TARGET}"
    core::log INFO "Removed stale symlink at ${_NVIM_TARGET}"
  elif [[ -d "${_NVIM_TARGET}" ]]; then
    core::backup "${_NVIM_TARGET}"
  fi

  git clone --branch "${_NVIM_BRANCH}" "${_NVIM_REPO}" "${_NVIM_TARGET}"
  core::log INFO "Cloned neovim config to ${_NVIM_TARGET}"
}

uninstall() {
  if [[ -d "${_NVIM_TARGET}/.git" ]]; then
    rm -rf "${_NVIM_TARGET}"
    core::log INFO "Removed ${_NVIM_TARGET}"
  fi
}

# Install Neovim from the system package manager.
_nvim::install_pkg() {
  core::pkg_install neovim
}

# Build and install Neovim from source at the latest stable tag.
_nvim::install_src() {
  # Ensure the build directory is cleaned up on both success and failure.
  trap 'rm -rf "${_NVIM_BUILD_DIR}"' RETURN

  # Remove brew-managed neovim on macOS to avoid PATH conflicts with the source build.
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    if core::check_installed brew && brew list neovim &>/dev/null; then
      brew uninstall neovim
    fi
  fi

  case "${DOTFILES_OS}" in
    mac) core::pkg_install ninja cmake gettext curl ;;
    linux) core::pkg_install ninja-build gettext cmake curl build-essential ;;
  esac

  git clone --depth 1 "${_NVIM_SRC_REPO}" "${_NVIM_BUILD_DIR}"

  local latest_tag
  latest_tag="$(cd "${_NVIM_BUILD_DIR}" && git tag --sort=-v:refname |
    { grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true; } | head -1)"
  if [[ -z "${latest_tag}" ]]; then
    core::log ERROR "No stable release tag found in ${_NVIM_SRC_REPO}"
    return 1
  fi
  (cd "${_NVIM_BUILD_DIR}" && git checkout "${latest_tag}")
  (cd "${_NVIM_BUILD_DIR}" && make CMAKE_BUILD_TYPE=RelWithDebInfo)
  (cd "${_NVIM_BUILD_DIR}" && sudo make install)

  core::log INFO "Neovim built and installed from source (${latest_tag})"
}
```

- [ ] **Step 2: Syntax/shellcheck/shfmt**

Run:
```bash
bash -n modules/nvim.sh && shellcheck modules/nvim.sh && shfmt -d modules/nvim.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add modules/nvim.sh
git commit -m "refactor(nvim): migrate to 2-hook interface; merge 3 hooks into install(); use core helpers"
```

---

## Task 10: Migrate `modules/tmux.sh` — call oh-my-tmux's upstream one-liner

Replace hand-rolled clone + symlink with `curl -fsSL .../install.sh | bash`. Our `LINKS` entry takes over `tmux.conf.local` after the upstream installer cp's its starter version.

**Files:**
- Modify: `modules/tmux.sh`

- [ ] **Step 1: Overwrite `modules/tmux.sh`**

Write this exact content:

```bash
#!/usr/bin/env bash
# modules/tmux.sh — tmux terminal multiplexer configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="tmux"
MODULE_DESC="tmux configuration (oh-my-tmux base + local overrides)"
MODULE_PLATFORM="all"

# tmux.conf.local is our local override; oh-my-tmux sources it automatically.
# tmux.conf and the upstream clone are created by oh-my-tmux's install.sh.
LINKS=(
  "config/tmux/tmux.conf.local:${HOME}/.config/tmux/tmux.conf.local"
)

readonly _TMUX_INSTALL_URL="https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh"
readonly _TMUX_CLONE_DIR="${HOME}/.config/tmux/.tmux"

install() {
  core::pkg_install tmux

  if [[ -d "${_TMUX_CLONE_DIR}/.git" ]]; then
    core::log INFO "oh-my-tmux already present — skipping"
    return 0
  fi

  # Ensure ~/.config/tmux exists so the installer picks the XDG path,
  # not the home-directory fallback.
  mkdir -p "${HOME}/.config/tmux"

  # Official one-liner — clones to ~/.config/tmux/.tmux, creates tmux.conf
  # symlink, and cp's a starter tmux.conf.local.
  curl -fsSL "${_TMUX_INSTALL_URL}" | bash
  core::log INFO "oh-my-tmux installed"

  # Remove upstream's starter tmux.conf.local only if it is a real file
  # (not already our symlink from a prior run), so LINKS can take over
  # without a spurious conflict prompt.
  if [[ -f "${HOME}/.config/tmux/tmux.conf.local" ]] &&
    [[ ! -L "${HOME}/.config/tmux/tmux.conf.local" ]]; then
    rm "${HOME}/.config/tmux/tmux.conf.local"
  fi
}

uninstall() {
  if [[ -d "${_TMUX_CLONE_DIR}/.git" ]]; then
    rm -rf "${_TMUX_CLONE_DIR}"
    core::log INFO "Removed ${_TMUX_CLONE_DIR}"
  fi
  if [[ -L "${HOME}/.config/tmux/tmux.conf" ]]; then
    rm "${HOME}/.config/tmux/tmux.conf"
    core::log INFO "Removed ${HOME}/.config/tmux/tmux.conf"
  fi
}
```

- [ ] **Step 2: Syntax/shellcheck/shfmt**

Run:
```bash
bash -n modules/tmux.sh && shellcheck modules/tmux.sh && shfmt -d modules/tmux.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add modules/tmux.sh
git commit -m "refactor(tmux): use oh-my-tmux upstream installer; migrate to 2-hook interface"
```

---

## Task 11: Migrate `modules/zsh.sh` — platform-split LINKS, track starship.toml, drop pre/post_install

- Platform-specific `.zshrc` becomes a conditional `LINKS+=(...)` at module top level.
- `starship.toml` is added to `LINKS` (the file was tracked in Task 1).
- `pre_install` (proactive `.zshenv` backup) and `post_install` (zshrc symlink + starship preset generation) both disappear — conflicts are handled by `core::symlink`, starship config is tracked.

**Files:**
- Modify: `modules/zsh.sh`

- [ ] **Step 1: Overwrite `modules/zsh.sh`**

Write this exact content:

```bash
#!/usr/bin/env bash
# modules/zsh.sh — Zsh configuration (sheldon plugin manager, starship prompt)
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="zsh"
MODULE_DESC="Zsh shell configuration (sheldon plugins, starship prompt)"
MODULE_PLATFORM="all"

LINKS=(
  "config/zsh/sheldon/plugins.toml:${HOME}/.config/sheldon/plugins.toml"
  "config/zsh/starship.toml:${HOME}/.config/starship.toml"
  "config/zsh/zshenv:${HOME}/.zshenv"
)

# Platform-specific .zshrc is expressed as an additional LINKS entry.
case "${DOTFILES_OS}" in
  mac) LINKS+=("config/zsh/zshrc.mac:${HOME}/.zshrc") ;;
  linux) LINKS+=("config/zsh/zshrc.linux:${HOME}/.zshrc") ;;
esac

install() {
  # macOS ships with a system zsh; Linux needs it explicitly.
  case "${DOTFILES_OS}" in
    mac) core::pkg_install sheldon starship ;;
    linux) core::pkg_install zsh sheldon starship ;;
  esac
}

uninstall() { :; }
```

- [ ] **Step 2: Syntax/shellcheck/shfmt**

Run:
```bash
bash -n modules/zsh.sh && shellcheck modules/zsh.sh && shfmt -d modules/zsh.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add modules/zsh.sh
git commit -m "refactor(zsh): migrate to 2-hook interface; platform-split LINKS; track starship.toml"
```

---

## Task 12: Full-repo style sweep

All modules are migrated. Do a final pass to confirm nothing references the old interface, the old flags, or `DRY_RUN`, and that everything passes shellcheck/shfmt.

- [ ] **Step 1: Verify no `DRY_RUN` remains in code**

Run:
```bash
grep -R 'DRY_RUN' --include='*.sh' .
```

Expected: no matches.

- [ ] **Step 2: Verify no `pre_install` / `post_install` remain in modules**

Run:
```bash
grep -RE 'pre_install|post_install' --include='*.sh' modules/ lib/ install.sh uninstall.sh
```

Expected: no matches.

- [ ] **Step 3: Verify no `--dry-run` / `--module` flag handling remains**

Run:
```bash
grep -RE '\-\-dry-run|\-\-module' --include='*.sh' install.sh uninstall.sh lib/ modules/
```

Expected: no matches.

- [ ] **Step 4: Shellcheck everything**

Run:
```bash
find lib modules install.sh uninstall.sh -name '*.sh' -print0 | xargs -0 shellcheck
```

Expected: no findings.

- [ ] **Step 5: Shfmt diff check**

Run:
```bash
shfmt -d install.sh uninstall.sh lib/*.sh modules/*.sh
```

Expected: no diff. If any file diverges, apply the formatter (`shfmt -w <file>`) and include the changes in this task's commit.

- [ ] **Step 6: Commit (only if shfmt made changes in Step 5; otherwise skip)**

```bash
git add -u
git commit -m "style: apply shfmt across refactored scripts"
```

If nothing was modified in Step 5, skip the commit and continue.

---

## Task 13: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Overwrite `CLAUDE.md`**

Write this exact content:

````markdown
# dotfiles

A full auto-installer for macOS and Linux development configurations. Not just a config
archive — it installs packages, creates symlinks, and handles conflicts gracefully.

## Platform Support

- **macOS**: full install (all modules including GUI terminal configs)
- **Linux**: minimal/server install (core dev tools only, no GUI)

## Architecture

See `docs/changes/2026-04-21-dotfiles-project-design/design.md` for the initial design
and `docs/changes/2026-04-22-system-optimization/design.md` for the current shape.

Key invariants:
- **Idempotent**: safe to run `install.sh` multiple times; conflicts prompt the user per
  symlink inside `core::symlink`.
- **No direct package manager calls in modules**: use `core::pkg_install` inside
  `install()`; never call brew/apt/dnf/pacman directly.

## Module Interface Contract

Every file in `modules/` must declare:

```bash
MODULE_NAME="<name>"
MODULE_DESC="<description>"
MODULE_PLATFORM="all"           # all | mac | linux

LINKS=(
  "config/<name>/file:${HOME}/.config/<name>/file"
)

install()   { :; }   # install packages / external tools / clone external repos
uninstall() { :; }   # clean up install()'s external side effects
```

Both hooks are required. Use `{ :; }` when a module has nothing to do.

Execution order:
- `./install.sh`:   `install() → LINKS`
- `./uninstall.sh`: `LINKS → uninstall()`

## Development Workflow

**Large changes** (new modules, architecture changes):
1. Run `superpowers:brainstorm` → produces `docs/changes/YYYY-MM-DD-<topic>/design.md`
2. Run `writing-plans` → produces `docs/changes/YYYY-MM-DD-<topic>/tasks.md`
3. Implement
4. Run `/change` to record a lightweight summary (optional if design.md covers it)

**Small changes** (bugfix, config tweak, small feature):
1. Implement directly
2. Session end: Stop hook will remind you if changes are undocumented
3. Run `/change` to record the change

All change docs save to `docs/changes/YYYY-MM-DD-<slug>/`.

## Shell Script Standards

See `.claude/rules/shell-style.md` (auto-loaded each session).

## Language

All code, comments, and documentation must be written in **English**.
````

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): update module interface contract; remove DRY_RUN invariant"
```

---

## Task 14: Update `.claude/rules/shell-style.md`

Three targeted edits: namespace table (add `install::`/`uninstall::`, remove `preflight::`), add "Case Indentation" section, delete "DRY_RUN Pattern" section.

**Files:**
- Modify: `.claude/rules/shell-style.md`

- [ ] **Step 1: Replace the Function Naming table**

Find this block:

````markdown
| File | Namespace | Examples |
|---|---|---|
| `lib/core.sh` | `core::` | `core::log`, `core::symlink`, `core::backup` |
| `lib/detect.sh` | `detect::` | `detect::os`, `detect::pkg_manager` |
| `lib/preflight.sh` | `preflight::` | `preflight::scan_module`, `preflight::report_and_prompt` |
| `modules/*.sh` | `module::` | `pre_install`, `post_install` (these are interface hooks) |
````

Replace with:

````markdown
| File | Namespace | Examples |
|---|---|---|
| `lib/core.sh` | `core::` | `core::log`, `core::symlink`, `core::check_installed`, `core::require_version` |
| `lib/detect.sh` | `detect::` | `detect::os`, `detect::pkg_manager` |
| `install.sh` | `install::` | `install::run_module` |
| `uninstall.sh` | `uninstall::` | `uninstall::run_module` |
| `modules/*.sh` | `module::` / `_<mod>::` | `install`, `uninstall` (interface hooks); `_nvim::install_src` (module-local helper) |
````

- [ ] **Step 2: Insert the Case Indentation section before `## DRY_RUN Pattern`**

Add this new section just above the `## DRY_RUN Pattern` heading:

````markdown
## Case Indentation

`case` branches are indented one level deeper than `case` itself (2 spaces); case item
bodies get another 2 spaces. `.shfmt.toml` already sets `switch-case-indent = true` so
the formatter enforces this — write code that matches.

```bash
# Correct
case "${DOTFILES_OS}" in
  mac) core::pkg_install sheldon starship ;;
  linux) core::pkg_install zsh sheldon starship ;;
esac

# Wrong — flat case
case "${DOTFILES_OS}" in
mac) core::pkg_install sheldon starship ;;
linux) core::pkg_install zsh sheldon starship ;;
esac
```

---
````

- [ ] **Step 3: Delete the DRY_RUN Pattern section**

Remove the entire `## DRY_RUN Pattern` section (heading through the trailing `---` before the next top-level heading). This includes the code block showing `core::symlink` with a DRY_RUN branch and the paragraph explaining `DRY_RUN` is set by `install.sh`.

- [ ] **Step 4: Verify the file is still valid markdown with consistent horizontal rules**

Run:
```bash
grep -c '^---$' .claude/rules/shell-style.md
```

Expected: a small integer (original count minus however many `---` belonged to the deleted section). Then view the file and confirm visually that sections still flow correctly.

Run:
```bash
cat .claude/rules/shell-style.md
```

Expected: Strict Mode → Variables → Function Naming (with updated table) → Conditionals → Output → Error Handling → Binary Detection → Directory Changes → Case Indentation → Comments → Formatting. No `DRY_RUN Pattern` section.

- [ ] **Step 5: Commit**

```bash
git add .claude/rules/shell-style.md
git commit -m "docs(rules): add install::/uninstall:: namespaces; add case-indent rule; drop DRY_RUN section"
```

---

## Task 15: Update `.claude/commands/new-module.md`

Scaffold emits 2-hook interface; references to DRY_RUN, `--module`, and `--dry-run` removed; DEPS wording gone.

**Files:**
- Modify: `.claude/commands/new-module.md`

- [ ] **Step 1: Overwrite with new content**

Write this exact content to `.claude/commands/new-module.md`:

````markdown
Scaffold a new dotfiles module named: $ARGUMENTS

Create these three files:

**1. `modules/$ARGUMENTS.sh`**

```bash
#!/usr/bin/env bash
# modules/$ARGUMENTS.sh — [brief description of what this module manages]
# shellcheck disable=SC2034
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="$ARGUMENTS"
MODULE_DESC="[One-line description]"
MODULE_PLATFORM="all"   # all | mac | linux

LINKS=()

install() {
  # Install packages, external tools, or clone external repositories.
  # Example: core::pkg_install $ARGUMENTS
  :
}

uninstall() {
  # Clean up external side effects produced by install().
  # LINKS symlinks are removed automatically by uninstall.sh — do not touch them here.
  :
}
```

**2. `docs/modules/$ARGUMENTS.md`**

```markdown
# Module: $ARGUMENTS

[Description of what this module manages]

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/$ARGUMENTS/` | `~/.config/$ARGUMENTS/` | all |

## Module hooks

| Hook | Action |
|---|---|
| `install` | [what install() does] |
| `uninstall` | [what uninstall() does, or "no-op"] |

## Notes

[Any special setup steps, post-install configuration, or caveats]
```

**3. `.claude/rules/module-$ARGUMENTS.md`**

```markdown
---
paths:
  - "modules/$ARGUMENTS.sh"
  - "config/$ARGUMENTS/**"
---

@docs/modules/$ARGUMENTS.md
```

After creating all three files, remind the user to:
1. Fill in `MODULE_DESC`, `MODULE_PLATFORM`, `LINKS`, and add `core::pkg_install` calls
   in `install()` for any packages needed
2. Create `config/$ARGUMENTS/` and add the actual config files
3. Update `docs/modules/$ARGUMENTS.md` with accurate symlink and hooks tables
4. Run `./install.sh` to verify the module works end-to-end
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/new-module.md
git commit -m "docs(new-module): scaffold emits 2-hook interface; drop DEPS/DRY_RUN references"
```

---

## Task 16: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Overwrite with new content**

Write this exact content to `README.md`:

````markdown
# dotfiles

Full auto-installer for macOS and Linux development configurations.

## Overview

Installs packages, creates symlinks, and handles conflicts gracefully — not just a config
archive. Re-running is safe: the installer is fully idempotent.

## Platform Support

| Platform | Support |
|---|---|
| macOS | Full (all modules including GUI terminal configs) |
| Linux | Minimal (core dev tools, SSH-friendly, no GUI terminals) |

## Prerequisites

- bash 4+
- git
- curl

## Quick Install

```bash
git clone https://github.com/<your-username>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

## Modules

| Module | Platform | What it manages |
|---|---|---|
| `git` | all | gitconfig + custom hooks |
| `zsh` | all | sheldon (plugin manager) + starship (prompt) |
| `nvim` | all | Neovim + LazyVim configuration |
| `tmux` | all | tmux + oh-my-tmux configuration |
| `ghostty` | macOS | Ghostty terminal config |

See [`docs/modules/`](docs/modules/) for per-module details. (The `rust` module runs as
an internal dependency of `nvim`; it is not a user-facing module.)

## Usage

```bash
# Install all modules for the current platform
./install.sh

# Remove all dotfile symlinks and clean up module side effects
./uninstall.sh
```

## Conflict Handling

When `install.sh` tries to create a symlink and the target already exists as a real file
or a foreign symlink, you get an interactive prompt per conflict:

- **[b] backup** — existing file moves to `~/.dotfiles-backup/YYYYMMDD-HHMMSS/`, symlink created
- **[s] skip**   — this symlink is not created; your file is preserved (module may end up incomplete)
- **[q] quit**   — installer exits; fix things and re-run

The installer is idempotent — re-running is always safe.

## Restoring a Backup

```bash
# List available backups
ls ~/.dotfiles-backup/

# Restore a specific file
cp -r ~/.dotfiles-backup/20260421-143022/.config/nvim ~/.config/nvim
```

## Manual Cleanup After Uninstall

`./uninstall.sh` removes managed symlinks and cleans up each module's external side
effects (oh-my-tmux clone, LazyVim config, etc.). The following are **not** removed
automatically — clean up manually if desired:

- Rust toolchain: `rustup self uninstall`
- Installed packages: uninstall via your package manager
- Backups: `rm -rf ~/.dotfiles-backup/`

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs(readme): drop --dry-run/--module; 5-module table; new conflict/cleanup sections"
```

---

## Task 17: Update `CONTRIBUTING.md`

**Files:**
- Modify: `CONTRIBUTING.md`

- [ ] **Step 1: Replace the "Adding a New Module" section**

Find this block:

````markdown
## Adding a New Module

Use the `/new-module <name>` slash command in Claude Code. It creates:

- `modules/<name>.sh` — module with standard interface (fill in LINKS, DEPS)
- `docs/modules/<name>.md` — documentation template
- `.claude/rules/module-<name>.md` — path-scoped context rule

Then add the actual config files to `config/<name>/` and run:

```bash
./install.sh --module <name> --dry-run
```
````

Replace with:

````markdown
## Adding a New Module

Use the `/new-module <name>` slash command in Claude Code. It creates:

- `modules/<name>.sh` — module with standard interface (fill in LINKS and `install()`)
- `docs/modules/<name>.md` — documentation template
- `.claude/rules/module-<name>.md` — path-scoped context rule

Then add the actual config files to `config/<name>/`, add `<name>` to the `_MODULES`
array in `install.sh` and `uninstall.sh`, and run:

```bash
./install.sh
```
````

- [ ] **Step 2: Verify no stale `--module`/`--dry-run` references remain**

Run:
```bash
grep -nE '\-\-module|\-\-dry-run|DEPS' CONTRIBUTING.md || true
```

Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs(contributing): drop --module/--dry-run example; wire new modules via _MODULES array"
```

---

## Task 18: Update `docs/modules/ghostty.md`

**Files:**
- Modify: `docs/modules/ghostty.md`

- [ ] **Step 1: Replace the Module hooks table**

Find this block:

```markdown
## Module hooks

| Hook | Action |
|---|---|
| `pre_install` | no-op |
| `install` | no-op — Ghostty is distributed as a standalone app and is installed manually |
| `post_install` | no-op |
```

Replace with:

```markdown
## Module hooks

| Hook | Action |
|---|---|
| `install` | no-op — Ghostty is distributed as a standalone app and is installed manually |
| `uninstall` | no-op |
```

- [ ] **Step 2: Commit**

```bash
git add docs/modules/ghostty.md
git commit -m "docs(ghostty): hooks table → install/uninstall"
```

---

## Task 19: Update `docs/modules/git.md`

**Files:**
- Modify: `docs/modules/git.md`

- [ ] **Step 1: Overwrite with new content**

Write this exact content:

```markdown
# Module: git

Git global configuration and a shared hooks directory. `core.hooksPath` is declared
directly inside `config/git/gitconfig`, so every repository on the machine automatically
picks up the shared hooks directory without per-repo configuration.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/git/gitconfig` | `~/.gitconfig` | all |
| `config/git/git-hooks/` | `~/.git-hooks/` | all |

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install git` (both platforms) |
| `uninstall` | no-op |

## Notes

`core.hooksPath = ~/.git-hooks` is declared in the tracked `config/git/gitconfig` file
itself — no hook-time `git config --global` call is needed.

Add hook scripts to `config/git/git-hooks/` and make them executable. The installer
symlinks the whole directory, so new hooks are picked up automatically on the next
`install.sh` run.
```

- [ ] **Step 2: Commit**

```bash
git add docs/modules/git.md
git commit -m "docs(git): 2-hook table; document hooksPath lives in gitconfig, not a hook"
```

---

## Task 20: Update `docs/modules/nvim.md`

**Files:**
- Modify: `docs/modules/nvim.md`

- [ ] **Step 1: Overwrite with new content**

Write this exact content:

````markdown
# Module: nvim

Neovim editor with LazyVim configuration. The module installs runtime dependencies,
installs or upgrades Neovim itself, and clones the config repo directly to
`~/.config/nvim` — all inside a single `install()` hook.

## Symlinks

This module sets `LINKS=()` — no standard symlinks are created. `install()` clones the
config repo directly to `~/.config/nvim` instead.

## Module hooks

| Hook | Action |
|---|---|
| `install` | runtime deps → tree-sitter-cli → nvim (version-checked) → clone config |
| `uninstall` | `rm -rf ~/.config/nvim` if a git checkout |

## install()

The hook performs four sub-steps in order:

### 1. Runtime dependencies

Installed via `core::pkg_install`:

| Platform | Packages |
|---|---|
| macOS | `ripgrep fd lazygit node shfmt shellcheck` |
| Linux | `ripgrep fd-find lazygit nodejs npm shfmt shellcheck` |

### 2. `tree-sitter-cli`

Installed via `cargo install --locked tree-sitter-cli`. If `cargo` is not available
(i.e. the `rust` module has not run yet), this step is skipped with a `WARN` log rather
than a hard failure.

> **Module ordering:** `rust` must appear before `nvim` in `_MODULES` so `cargo` is
> available here.

### 3. Neovim version check

Uses `core::check_installed nvim && core::require_version nvim 0 9`. When the check
fails, the user is prompted:

```
Neovim not found (or too old — LazyVim requires >= 0.9)
Install options:
  1) Package manager (brew/apt)
  2) Build from source (latest stable tag)
Choice [1]:
```

Constants used:

| Constant | Value |
|---|---|
| `_NVIM_MIN_MAJOR` | `0` |
| `_NVIM_MIN_MINOR` | `9` |
| `_NVIM_SRC_REPO` | `https://github.com/neovim/neovim.git` |
| `_NVIM_BUILD_DIR` | `/tmp/neovim-build-$$` |

#### Option 1 — package manager

Calls `core::pkg_install neovim` (same package name on both platforms).

#### Option 2 — build from source

Build steps:

1. **macOS only**: if a Homebrew-managed `neovim` is installed, it is uninstalled first
   to avoid PATH conflicts with the source build.
2. Install platform-specific build dependencies:
   - macOS: `ninja cmake gettext curl`
   - Linux: `ninja-build gettext cmake curl build-essential`
3. Shallow-clone `_NVIM_SRC_REPO` into `_NVIM_BUILD_DIR`.
4. Find the latest stable semver tag (pattern `v[0-9]+.[0-9]+.[0-9]+`), check it out.
5. Build: `make CMAKE_BUILD_TYPE=RelWithDebInfo`.
6. Install: `sudo make install`.
7. A `trap … RETURN` ensures `_NVIM_BUILD_DIR` is removed on both success and failure.

### 4. Clone the LazyVim config repo

Constants used:

| Constant | Value |
|---|---|
| `_NVIM_REPO` | `git@github.com:yangxingwu/neovim-lua-config.git` |
| `_NVIM_BRANCH` | `LazyVimV2` |
| `_NVIM_TARGET` | `~/.config/nvim` |

The clone is idempotent — the step handles four possible states of `_NVIM_TARGET`:

| State | Action |
|---|---|
| Contains `.git/` (already cloned) | Skip |
| Stale symlink | Remove symlink, then clone |
| Existing non-git directory | `core::backup`, then clone |
| Absent | Clone |

## uninstall()

If `~/.config/nvim/.git` exists, removes the whole directory.
````

- [ ] **Step 2: Commit**

```bash
git add docs/modules/nvim.md
git commit -m "docs(nvim): 2-hook table; describe single merged install()"
```

---

## Task 21: Update `docs/modules/tmux.md`

**Files:**
- Modify: `docs/modules/tmux.md`

- [ ] **Step 1: Overwrite with new content**

Write this exact content:

```markdown
# Module: tmux

tmux configuration using [oh-my-tmux](https://github.com/gpakosz/.tmux) as the base,
with a local override file for machine-specific settings. The upstream project is
installed via its official `install.sh` one-liner.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/tmux/tmux.conf.local` | `~/.config/tmux/tmux.conf.local` | all |

`~/.config/tmux/tmux.conf` and `~/.config/tmux/.tmux/` are created by oh-my-tmux's
upstream installer — they are not in our `LINKS`.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install tmux`; run oh-my-tmux's upstream installer |
| `uninstall` | remove `~/.config/tmux/.tmux/` and the `~/.config/tmux/tmux.conf` symlink |

## install()

Steps:

1. `core::pkg_install tmux`.
2. If `~/.config/tmux/.tmux/.git` already exists, skip the rest (idempotent).
3. `mkdir -p ~/.config/tmux/` so the upstream installer picks the XDG path rather than
   the home-directory fallback.
4. `curl -fsSL "${_TMUX_INSTALL_URL}" | bash` — oh-my-tmux clones itself to
   `~/.config/tmux/.tmux/`, creates the `tmux.conf` symlink, and `cp`'s its starter
   `tmux.conf.local`.
5. Remove that starter `tmux.conf.local` (only if it is still a real file, not our
   symlink from a prior run) so the upcoming LINKS phase can install our repo copy
   without triggering a conflict prompt.

Constants:

| Constant | Value |
|---|---|
| `_TMUX_INSTALL_URL` | `https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh` |
| `_TMUX_CLONE_DIR` | `${HOME}/.config/tmux/.tmux` |

## uninstall()

- `rm -rf ~/.config/tmux/.tmux/` if it is a git checkout.
- `rm ~/.config/tmux/tmux.conf` if it is a symlink.

## Local overrides

`config/tmux/tmux.conf.local` is symlinked to `~/.config/tmux/tmux.conf.local`.
oh-my-tmux sources this file automatically, so machine-specific tweaks go here without
touching the upstream config.
```

- [ ] **Step 2: Commit**

```bash
git add docs/modules/tmux.md
git commit -m "docs(tmux): 2-hook table; describe upstream installer flow; update clone path"
```

---

## Task 22: Update `docs/modules/zsh.md`

**Files:**
- Modify: `docs/modules/zsh.md`

- [ ] **Step 1: Overwrite with new content**

Write this exact content:

````markdown
# Module: zsh

Zsh shell configuration — `zshenv`, sheldon plugin manager, platform-specific `zshrc`,
and starship prompt.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/zsh/sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` | all |
| `config/zsh/starship.toml` | `~/.config/starship.toml` | all |
| `config/zsh/zshenv` | `~/.zshenv` | all |
| `config/zsh/zshrc.mac` | `~/.zshrc` | mac |
| `config/zsh/zshrc.linux` | `~/.zshrc` | linux |

The last two entries are pushed into `LINKS` conditionally based on `${DOTFILES_OS}` at
module-load time, so only the matching one is active.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install sheldon starship` (macOS) or `zsh sheldon starship` (Linux) |
| `uninstall` | no-op |

## install()

Installs the shell and prompt toolchain. macOS ships with a system Zsh so it is not
re-installed; Linux needs it explicitly.

| Platform | Packages |
|---|---|
| macOS | `sheldon starship` |
| Linux | `zsh sheldon starship` |

Platform is detected via `${DOTFILES_OS}`.

## Config files

### `config/zsh/zshenv`

Portable, non-interactive environment variables. Loaded by Zsh on every invocation
(interactive or not, login or not).

- Sources `~/.cargo/env` if the file exists (guarded).
- Ends with `[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local` for machine-local
  overrides.

### `config/zsh/zshrc.mac`

macOS interactive shell configuration:

- Homebrew `shellenv` initialisation
- `sheldon source` for plugin loading
- `compinit`
- History key bindings
- `starship init zsh`
- fzf shell integration
- `ssh()` wrapper
- `[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local`

### `config/zsh/zshrc.linux`

Linux interactive shell configuration — same as the macOS version minus the Homebrew
`shellenv` block and the `ssh()` wrapper.

### `config/zsh/starship.toml`

Generated once from the upstream `catppuccin-powerline` preset and tracked in the repo.
To regenerate after an upstream change:

```bash
starship preset catppuccin-powerline -o config/zsh/starship.toml
```

## Local escape hatch

Machine-specific content that must never be committed goes in:

| File | Purpose |
|---|---|
| `~/.zshrc.local` | Interactive shell — aliases, PATH tweaks, secrets |
| `~/.zshenv.local` | Non-interactive env — exports needed in all contexts |

Both files are sourced at the end of their respective managed configs, so they can
override anything set above them.

## sheldon plugin ordering rules

Enforced in `config/zsh/sheldon/plugins.toml`:

- `zsh-completions` must be loaded with `apply = ["fpath"]` (before `compinit`) so
  `$fpath` is populated before the completion system initialises.
- `zsh-syntax-highlighting` must be loaded **last** — it wraps ZLE widget functions and
  must see all other plugins already registered.
````

- [ ] **Step 2: Commit**

```bash
git add docs/modules/zsh.md
git commit -m "docs(zsh): 2-hook table; add starship.toml symlink row; drop pre/post_install sections"
```

---

## Task 23: Final verification

Everything is migrated and committed. Last sweep to catch anything that slipped through.

- [ ] **Step 1: Repo-wide stale-reference grep**

Run:
```bash
grep -RE 'DRY_RUN|pre_install|post_install|preflight|--dry-run|--module|DEPS_MAC|DEPS_LINUX' \
  --include='*.sh' --include='*.md' --include='*.toml' \
  --exclude-dir=docs/changes \
  .
```

Expected: no matches. `docs/changes/` is excluded because historical design docs legitimately reference old names.

If any match appears outside `docs/changes/`, fix the file and add a follow-up commit before proceeding.

- [ ] **Step 2: Full shellcheck**

Run:
```bash
find . -name '*.sh' -not -path './docs/*' -print0 | xargs -0 shellcheck
```

Expected: no findings.

- [ ] **Step 3: Full shfmt diff check**

Run:
```bash
shfmt -d install.sh uninstall.sh lib/*.sh modules/*.sh
```

Expected: no diff.

- [ ] **Step 4: End-to-end trial on the local machine**

> This step mutates `~/.config`, `~/.zshrc`, and friends. Only run it on the dev
> machine the dotfiles are intended for. You can re-run freely — the installer is
> idempotent. If you want a zero-touch confidence check instead, skip to Step 5.

Run:
```bash
./install.sh
```

Expected: the log walks through all 6 modules in order, reports `Already linked` for
targets already managed, prompts interactively on any real conflict, and ends with
`Install complete.` Watch for any ERROR output.

- [ ] **Step 5: Git log sanity check**

Run:
```bash
git log --oneline $(git merge-base HEAD origin/main)..HEAD
```

Expected: a chain of ~22 commits, one per task, titles matching the "git commit -m" strings from the tasks above.

- [ ] **Step 6: Final commit (optional)**

If Step 4 surfaced any adjustments, commit them:

```bash
git add -u
git commit -m "fix: post-trial corrections from end-to-end install run"
```

Otherwise nothing to commit. The refactor is complete.

---

## Spec coverage check (self-review)

| Spec requirement | Task |
|---|---|
| oh-my-tmux via upstream one-liner | Task 10 |
| Remove `--module` and `--dry-run` flags | Tasks 3, 4 |
| Delete `lib/preflight.sh` | Task 5 |
| Unified shell style (case indent) | Tasks 12, 14 |
| Remove DRY_RUN from core/install/uninstall/modules | Tasks 2, 3, 4, 6–11; Task 12 verifies |
| Module interface → install/uninstall | Tasks 6–11 |
| Execution order install()→LINKS; LINKS→uninstall() | Tasks 3, 4 |
| `core::check_installed` | Task 2; used in Tasks 8, 9, 10 |
| `core::require_version` | Task 2; used in Task 9 |
| `core::symlink` interactive [b]/[s]/[q] | Task 2 |
| git.sh drop redundant post_install (hooksPath in gitconfig) | Task 7 |
| starship.toml tracked in repo | Tasks 1, 11 |
| zsh.sh platform-split via LINKS | Task 11 |
| README module table = 5 | Task 16 |
| Docs sync: CLAUDE.md, shell-style.md, new-module.md, README.md, CONTRIBUTING.md, docs/modules/*.md | Tasks 13, 14, 15, 16, 17, 18, 19, 20, 21, 22 |

All spec requirements mapped to at least one task. No placeholders remain in the plan.
