# Bootstrap Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a fresh macOS or Linux machine run `./install.sh` from zero by installing Homebrew + Xcode Command Line Tools (macOS) or zsh/git/curl/compiler toolchain (Linux) before any module runs.

**Architecture:** New `lib/bootstrap.sh` provides three public primitives (`bootstrap::xcode_clt`, `bootstrap::homebrew`, `bootstrap::dev_tools`). `install.sh`'s `main()` is rewritten as three explicit stages: ensure pkg manager → detect pkg manager → install dev tools. `lib/detect.sh` drops its two auto-run lines so the call sequence is now explicit in every consumer; `pacman` branches are removed from both `detect.sh` and `core.sh` since Arch is not supported.

**Tech Stack:** Bash 4+, strict mode (`set -euo pipefail`), shellcheck, shfmt 3.13.1.

**Source of truth:** `docs/changes/2026-04-23-bootstrap-module/design.md` (same directory).

---

## Ordering Rationale

Tasks are ordered so the tree compiles at every step:

1. Add `lib/bootstrap.sh` first — standalone new file, nothing references it yet.
2. Modify `lib/core.sh` (drop pacman) — standalone, callers unchanged.
3. Modify `lib/detect.sh` (drop pacman + remove auto-run) — **breaks** `install.sh`/`uninstall.sh` until tasks 4+5 land, since those scripts rely on the auto-run lines. Commits 4 and 5 follow immediately.
4. Rewrite `install.sh` `main()` with the three-stage orchestration — fixes the auto-run breakage and wires in `bootstrap.sh`.
5. Rewrite `uninstall.sh` `main()` with explicit `detect::os` / `detect::pkg_manager` — fixes the auto-run breakage.
6. Update `README.md` (prerequisites + first-run note) — docs only.
7. Update `.claude/rules/shell-style.md` (add `bootstrap::` namespace row) — docs only.
8. Final sweep — shellcheck + shfmt on every touched file, grep for stale `pacman` references.

Each code task follows the same shape: write/modify → `bash -n` → `shellcheck` → `shfmt -d` → commit. Markdown tasks skip the shell-specific checks.

**Commit trailer:** every commit includes `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. **Do not** pass `--no-verify` to any git command; if a pre-commit hook fails, fix the root cause and create a new commit.

---

## Task 1: Create `lib/bootstrap.sh`

**Files:**
- Create: `lib/bootstrap.sh`

- [ ] **Step 1: Write the new file**

Create `/Volumes/Code/dotfiles/lib/bootstrap.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# lib/bootstrap.sh — Platform-prerequisite installers.
# Ensures the tools every module assumes exist are present on a fresh machine:
# Xcode Command Line Tools + Homebrew on macOS; zsh/git/curl/compiler toolchain
# on Linux. Called from install.sh's main() before any module runs.
# Safe to source multiple times (pure function definitions, no side effects).
#
# The three macOS-specific functions are called in different slots of the
# install.sh orchestration sequence (CLT + brew run BEFORE detect::pkg_manager;
# dev_tools runs AFTER, because it needs DOTFILES_PKG_MANAGER set). See the
# design doc in docs/changes/2026-04-23-bootstrap-module/design.md, Section 3.
set -euo pipefail
IFS=$'\n\t'

# Poll interval and ceiling for Xcode CLT install. 15s interval keeps progress
# logs frequent enough to reassure the user; 30-minute ceiling bounds the wait
# (typical CLT install completes in 5-15 minutes on a good network).
_BOOTSTRAP_CLT_POLL_INTERVAL=15
_BOOTSTRAP_CLT_MAX_WAIT=1800

# macOS only. Install the Xcode Command Line Tools (git, curl, clang, make,
# etc.) if absent. `xcode-select --install` pops a GUI confirmation dialog and
# returns immediately while the download runs in the background; we then poll
# `xcode-select -p` until the toolchain appears. Apple provides no synchronous
# install API — every automation tool (Homebrew's own installer, Ansible,
# Chef, nix-darwin) uses the same polling pattern.
bootstrap::xcode_clt() {
  if xcode-select -p &>/dev/null; then
    core::log INFO "Xcode Command Line Tools already installed"
    return 0
  fi

  core::log INFO "Triggering Xcode Command Line Tools install (GUI dialog)..."
  # `xcode-select --install` returns non-zero if the dialog is already open
  # or the tools are already present — the poll loop below is the real gate.
  xcode-select --install &>/dev/null || true

  local waited=0
  while ! xcode-select -p &>/dev/null; do
    if ((waited >= _BOOTSTRAP_CLT_MAX_WAIT)); then
      core::log ERROR "Xcode CLT install did not complete within ${_BOOTSTRAP_CLT_MAX_WAIT}s"
      core::log ERROR "Finish the install via the GUI dialog, then re-run ./install.sh"
      return 1
    fi
    core::log INFO "Waiting for Xcode CLT install to finish (${waited}s/${_BOOTSTRAP_CLT_MAX_WAIT}s)..."
    sleep "${_BOOTSTRAP_CLT_POLL_INTERVAL}"
    waited=$((waited + _BOOTSTRAP_CLT_POLL_INTERVAL))
  done

  core::log INFO "Xcode Command Line Tools installed"
}

# macOS only. Install Homebrew via the official upstream installer, then eval
# `brew shellenv` so later modules in this install run can call `brew install`.
# Persistent PATH wiring for future shells is handled by the zsh module's
# zshrc.mac symlink (which already contains `eval "$(brew shellenv)"`).
bootstrap::homebrew() {
  if command -v brew &>/dev/null; then
    core::log INFO "Homebrew already installed"
    return 0
  fi

  core::log INFO "Installing Homebrew (official installer)..."
  # Interactive by default — brew prompts "Press RETURN to continue" so the
  # user can review what is about to happen before granting sudo. We do NOT
  # set NONINTERACTIVE=1.
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Load brew into the current shell's PATH for the rest of this install run.
  # /opt/homebrew is Apple Silicon; /usr/local is Intel.
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    core::log ERROR "Homebrew installer completed but brew binary not found"
    core::log ERROR "Checked /opt/homebrew/bin/brew and /usr/local/bin/brew"
    return 1
  fi

  core::log INFO "Homebrew installed and loaded into PATH"
}

# Both platforms. Install the dev tools every module assumes exist.
# Bypasses core::pkg_install and calls native pm commands directly because
# (a) bootstrap already knows the pm, and (b) dnf requires `groupinstall` for
# "Development Tools" which core::pkg_install does not support.
#
# Requires DOTFILES_PKG_MANAGER to be set — call detect::pkg_manager first.
bootstrap::dev_tools() {
  case "${DOTFILES_PKG_MANAGER}" in
  brew)
    # CLT already provides git, curl, clang, make. macOS (Catalina+) ships
    # zsh as the default login shell. Only modern build systems are missing.
    brew install cmake meson ninja gettext
    ;;
  apt)
    sudo apt-get install -y zsh git curl cmake meson ninja-build gettext
    sudo apt-get install -y build-essential
    ;;
  dnf)
    sudo dnf install -y zsh git curl cmake meson ninja-build gettext
    sudo dnf groupinstall -y "Development Tools"
    ;;
  *)
    core::log ERROR "Unsupported package manager: ${DOTFILES_PKG_MANAGER}"
    core::log ERROR "Supported: brew (macOS), apt (Debian/Ubuntu), dnf (Fedora/RHEL)"
    exit 1
    ;;
  esac

  core::log INFO "Dev tools installed"
}
```

- [ ] **Step 2: Syntax check with `bash -n`**

Run: `bash -n lib/bootstrap.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck lib/bootstrap.sh`
Expected: no output, exit 0.

If shellcheck flags `core::log` as an unknown command, add a directive at the top of the file (just under the header comment):

```bash
# shellcheck disable=SC2154  # core::log is defined in lib/core.sh and sourced before us
```

Do NOT add this pre-emptively — only if shellcheck actually complains. `core::log` is a function, not a variable, and shellcheck does not warn about undefined functions by default.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d lib/bootstrap.sh`
Expected: no diff output, exit 0.

If shfmt prints a diff, apply it with `shfmt -w lib/bootstrap.sh` and re-run `shfmt -d` to confirm clean.

- [ ] **Step 5: Commit**

```bash
git add lib/bootstrap.sh
git commit -m "$(cat <<'EOF'
feat(bootstrap): add lib/bootstrap.sh with xcode_clt, homebrew, dev_tools

Three public primitives that let a fresh macOS or Linux machine reach the
point where modules can run: Xcode CLT + Homebrew on mac, zsh/git/curl/
cmake/meson/ninja/gettext + build-essential or "Development Tools" on Linux.

No callers yet — wired in by the following install.sh commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Drop pacman branch from `lib/core.sh`

**Files:**
- Modify: `lib/core.sh` (lines 204-211)

- [ ] **Step 1: Remove the pacman branch**

Edit `/Volumes/Code/dotfiles/lib/core.sh`. Delete exactly this block (currently lines 204-211):

```bash
    pacman)
      if pacman -Q "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        sudo pacman -S --noconfirm "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
```

After deletion, the `case` should flow directly from the `dnf)` arm's `;;` into the `*)` fallback arm.

- [ ] **Step 2: Syntax check**

Run: `bash -n lib/core.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck lib/core.sh`
Expected: no output, exit 0 (or the same warnings as before — no new ones introduced).

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d lib/core.sh`
Expected: no diff.

- [ ] **Step 5: Commit**

```bash
git add lib/core.sh
git commit -m "$(cat <<'EOF'
refactor(core): drop pacman branch from core::pkg_install

Arch Linux is out of scope for this installer — bootstrap cannot install
pacman's equivalent of build-essential, so keeping a pkg_install branch the
installer cannot actually bootstrap on is misleading. The "*)" fallback
remains and logs WARN for any unknown pm.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Restructure `lib/detect.sh`

**Files:**
- Modify: `lib/detect.sh`

- [ ] **Step 1: Apply three changes**

Three independent edits, shown here separately for clarity but applied in a single pass:

**Change 3.1 — remove the pacman branch from `detect::pkg_manager`.** Delete this line (currently line 44):

```bash
    elif command -v pacman &>/dev/null; then
      export DOTFILES_PKG_MANAGER="pacman"
```

(Two lines total — the `elif` and its body.)

**Change 3.2 — enhance the "unknown pm" warn message.** Replace:

```bash
      printf 'warn: no supported package manager found\n' >&2
```

with:

```bash
      printf 'warn: no supported package manager found on Linux (supported: apt, dnf)\n' >&2
```

**Change 3.3 — remove the two trailing auto-run lines.** Delete these lines from the end of the file (currently lines 57-58):

```bash
[[ -n "${DOTFILES_OS:-}" ]] || detect::os
[[ -n "${DOTFILES_PKG_MANAGER:-}" ]] || detect::pkg_manager
```

**Change 3.4 — update the header comment.** The current header (lines 2-10) says the file is safe to source multiple times; add "zero side effects on source" to reflect the new contract. Replace:

```bash
# lib/detect.sh — Runtime environment detection.
# Detects OS and package manager; exports DOTFILES_OS and DOTFILES_PKG_MANAGER.
# Safe to source multiple times (idempotent variable exports).
#
# Override knobs:
#   DOTFILES_OS=<mac|linux>
#   DOTFILES_PKG_MANAGER=<brew|apt|dnf|pacman>
# Set either variable before sourcing to skip detection (e.g. linuxbrew users
# who want brew on Linux: DOTFILES_PKG_MANAGER=brew).
```

with:

```bash
# lib/detect.sh — Runtime environment detection.
# Defines detect::os and detect::pkg_manager; callers decide when to invoke
# them (install.sh orchestrates this alongside bootstrap steps). Sourcing
# this file has zero side effects — it only defines functions.
#
# Override knobs:
#   DOTFILES_OS=<mac|linux>
#   DOTFILES_PKG_MANAGER=<brew|apt|dnf>
# Set either variable before calling detect::* to skip detection (e.g.
# linuxbrew users who want brew on Linux: DOTFILES_PKG_MANAGER=brew).
```

After all four changes, `lib/detect.sh` should look like this in full:

```bash
#!/usr/bin/env bash
# lib/detect.sh — Runtime environment detection.
# Defines detect::os and detect::pkg_manager; callers decide when to invoke
# them (install.sh orchestrates this alongside bootstrap steps). Sourcing
# this file has zero side effects — it only defines functions.
#
# Override knobs:
#   DOTFILES_OS=<mac|linux>
#   DOTFILES_PKG_MANAGER=<brew|apt|dnf>
# Set either variable before calling detect::* to skip detection (e.g.
# linuxbrew users who want brew on Linux: DOTFILES_PKG_MANAGER=brew).
set -euo pipefail
IFS=$'\n\t'

detect::os() {
  case "$(uname -s)" in
  Darwin) export DOTFILES_OS="mac" ;;
  Linux) export DOTFILES_OS="linux" ;;
  *)
    printf 'error: unsupported OS: %s\n' "$(uname -s)" >&2
    return 1
    ;;
  esac
}

# Must be called after detect::os — dispatches by ${DOTFILES_OS} so that a
# Linux machine with linuxbrew installed does not accidentally pick brew over
# the system package manager. Users who want that can set
# DOTFILES_PKG_MANAGER=brew before sourcing.
detect::pkg_manager() {
  case "${DOTFILES_OS}" in
  mac)
    if command -v brew &>/dev/null; then
      export DOTFILES_PKG_MANAGER="brew"
    else
      export DOTFILES_PKG_MANAGER="unknown"
      printf 'warn: Homebrew not found on macOS\n' >&2
    fi
    ;;
  linux)
    if command -v apt-get &>/dev/null; then
      export DOTFILES_PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
      export DOTFILES_PKG_MANAGER="dnf"
    else
      export DOTFILES_PKG_MANAGER="unknown"
      printf 'warn: no supported package manager found on Linux (supported: apt, dnf)\n' >&2
    fi
    ;;
  *)
    export DOTFILES_PKG_MANAGER="unknown"
    ;;
  esac
}
```

(No trailing auto-run lines, no pacman branch, updated warn message.)

- [ ] **Step 2: Syntax check**

Run: `bash -n lib/detect.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck lib/detect.sh`
Expected: no output, exit 0.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d lib/detect.sh`
Expected: no diff.

- [ ] **Step 5: Verify no-side-effect contract manually**

Run:

```bash
bash -c 'set -euo pipefail; source lib/detect.sh; echo "DOTFILES_OS=${DOTFILES_OS:-<unset>}"; echo "DOTFILES_PKG_MANAGER=${DOTFILES_PKG_MANAGER:-<unset>}"'
```

Expected: both variables print `<unset>` (sourcing no longer triggers detection).

- [ ] **Step 6: Commit**

```bash
git add lib/detect.sh
git commit -m "$(cat <<'EOF'
refactor(detect): remove auto-run on source, drop pacman, clarify warn

- Remove the two trailing lines that auto-called detect::os and
  detect::pkg_manager. Sourcing lib/detect.sh is now side-effect-free;
  callers (install.sh, uninstall.sh) invoke both functions explicitly.
  This is what lets install.sh run work (bootstrap::xcode_clt /
  bootstrap::homebrew) between detect::os and detect::pkg_manager.

- Drop the pacman branch from detect::pkg_manager. Arch is not supported
  (bootstrap cannot install a pacman base toolchain), so detecting it
  would only mislead.

- Enhance the Linux "no supported package manager" warn to name the
  supported set (apt, dnf).

NOTE: after this commit, install.sh and uninstall.sh are temporarily
broken — they rely on the auto-run. The next two commits fix this by
wiring explicit detect::* calls into their main() functions.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Rewrite `install.sh` main() — three-stage orchestration

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Source `lib/bootstrap.sh`**

In `/Volumes/Code/dotfiles/install.sh`, after the existing library sources (currently lines 18-21), add one line:

```bash
# shellcheck source=lib/detect.sh
source "${DOTFILES_ROOT}/lib/detect.sh"
# shellcheck source=lib/core.sh
source "${DOTFILES_ROOT}/lib/core.sh"
# shellcheck source=lib/bootstrap.sh
source "${DOTFILES_ROOT}/lib/bootstrap.sh"
```

- [ ] **Step 2: Rewrite `main()`**

Replace the current `main()` body (lines 64-74) with the three-stage orchestration. The new function:

```bash
main() {
  # Detect OS first — bootstrap steps and the module loop both dispatch by it.
  detect::os

  # Stage A: ensure a package manager exists.
  # macOS requires Xcode CLT + Homebrew; Linux's apt/dnf ships with the distro.
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    bootstrap::xcode_clt
    bootstrap::homebrew
  fi

  # Stage B: identify the package manager now that one is guaranteed present.
  detect::pkg_manager

  # Stage C: install dev tools every module assumes exist (shell, vcs,
  # downloader, compiler toolchain, build systems). Hard-exits on an
  # unsupported package manager rather than letting modules limp along.
  bootstrap::dev_tools

  core::log INFO "Platform: ${DOTFILES_OS} | Package manager: ${DOTFILES_PKG_MANAGER}"

  local total=${#_MODULES[@]} i=0 name
  for name in "${_MODULES[@]}"; do
    i=$((i + 1))
    install::run_module "${name}" "${i}" "${total}"
  done

  core::log INFO "Install complete."
}
```

The module loop and the `core::log` summary are unchanged — only the detection/bootstrap prologue is new.

- [ ] **Step 3: Syntax check**

Run: `bash -n install.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Shellcheck**

Run: `shellcheck install.sh`
Expected: no output, exit 0.

- [ ] **Step 5: shfmt diff check**

Run: `shfmt -d install.sh`
Expected: no diff.

- [ ] **Step 6: Dry-source sanity check**

The actual install needs a clean machine to test end-to-end, but we can confirm the call graph wires correctly by sourcing the script in a way that stops just before `main()` runs. Run:

```bash
bash -c 'set -euo pipefail; DOTFILES_ROOT="$(pwd)" source ./lib/detect.sh; source ./lib/core.sh; source ./lib/bootstrap.sh; type bootstrap::xcode_clt bootstrap::homebrew bootstrap::dev_tools detect::os detect::pkg_manager >/dev/null && echo OK'
```

Expected: `OK`.

- [ ] **Step 7: Commit**

```bash
git add install.sh
git commit -m "$(cat <<'EOF'
feat(install): orchestrate bootstrap in three stages before modules run

main() is now:
  detect::os
  if mac: bootstrap::xcode_clt + bootstrap::homebrew
  detect::pkg_manager
  bootstrap::dev_tools
  <existing module loop>

This replaces the old detect.sh auto-run with an explicit call sequence,
which lets bootstrap install a package manager (brew on mac) BETWEEN
detect::os and detect::pkg_manager. Linux has no work to do in Stage A —
apt/dnf ships with the distro — so Stage A is gated by an `if` rather than
a `case` with an empty Linux branch.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Add explicit detect calls to `uninstall.sh`

**Files:**
- Modify: `uninstall.sh`

- [ ] **Step 1: Add `detect::os` and `detect::pkg_manager` to `main()`**

In `/Volumes/Code/dotfiles/uninstall.sh`, replace the current `main()` (lines 65-71):

```bash
main() {
  local name
  for name in "${_MODULES[@]}"; do
    uninstall::run_module "${name}"
  done
  core::log INFO "Uninstall complete."
}
```

with:

```bash
main() {
  # detect.sh no longer auto-runs on source — invoke detection explicitly.
  # No bootstrap: removing dotfile symlinks never requires installing things.
  detect::os
  detect::pkg_manager

  local name
  for name in "${_MODULES[@]}"; do
    uninstall::run_module "${name}"
  done
  core::log INFO "Uninstall complete."
}
```

Do **not** source `lib/bootstrap.sh` in uninstall.sh — it has no callers here and would only add dead dependency weight.

- [ ] **Step 2: Syntax check**

Run: `bash -n uninstall.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Shellcheck**

Run: `shellcheck uninstall.sh`
Expected: no output, exit 0.

- [ ] **Step 4: shfmt diff check**

Run: `shfmt -d uninstall.sh`
Expected: no diff.

- [ ] **Step 5: Commit**

```bash
git add uninstall.sh
git commit -m "$(cat <<'EOF'
fix(uninstall): call detect::os and detect::pkg_manager explicitly

lib/detect.sh no longer auto-runs on source, so uninstall.sh must invoke
the two detection functions itself. No bootstrap — removing dotfile
symlinks never requires installing anything.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Update `README.md` — prerequisites and first-run note

**Files:**
- Modify: `README.md` (Prerequisites section + Quick Install section)

- [ ] **Step 1: Shrink Prerequisites**

In `/Volumes/Code/dotfiles/README.md`, replace the current Prerequisites section (lines 17-22):

```markdown
## Prerequisites

- bash 4+
- git
- curl
```

with:

```markdown
## Prerequisites

- bash 4+

Everything else — Xcode CLT, Homebrew, git, curl, zsh, a C toolchain, cmake,
meson, ninja, gettext — is installed automatically on first run.
```

- [ ] **Step 2: Add first-run note under Quick Install**

After the fenced code block under "## Quick Install" (currently ends at line 29), add a new paragraph:

```markdown
First run on a clean machine may take several minutes. On macOS, the
installer triggers `xcode-select --install` (GUI confirmation required)
and then runs Homebrew's official installer (sudo password required).
On Linux, it installs zsh, git, curl and a compiler toolchain via your
system's package manager (sudo required).
```

The final section should read as:

```markdown
## Quick Install

```bash
git clone https://github.com/<your-username>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

First run on a clean machine may take several minutes. On macOS, the
installer triggers `xcode-select --install` (GUI confirmation required)
and then runs Homebrew's official installer (sudo password required).
On Linux, it installs zsh, git, curl and a compiler toolchain via your
system's package manager (sudo required).
```

- [ ] **Step 3: Visual check**

Run: `cat README.md | head -40`
Expected: Prerequisites has only `bash 4+` plus the explanatory sentence; Quick Install has the new paragraph directly after the code block.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs(readme): drop git/curl from prerequisites, add first-run note

The installer now bootstraps git, curl, Xcode CLT, Homebrew and the
compiler toolchain itself, so only bash 4+ is a real prerequisite. Added
a Quick Install note warning the user about GUI confirmations (CLT) and
sudo prompts (brew, apt, dnf) on first run.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add `bootstrap::` to shell-style.md namespace table

**Files:**
- Modify: `.claude/rules/shell-style.md`

- [ ] **Step 1: Add the new namespace row**

In `/Volumes/Code/dotfiles/.claude/rules/shell-style.md`, find the namespace table (currently under "## Function Naming", starting at the table header). Add a new row for `lib/bootstrap.sh` **before** the `install.sh` row, so libs stay grouped:

Current table (relevant rows):

```markdown
| File | Namespace | Examples |
|---|---|---|
| `lib/core.sh` | `core::` | `core::log`, `core::symlink`, `core::check_installed`, `core::require_version` |
| `lib/detect.sh` | `detect::` | `detect::os`, `detect::pkg_manager` |
| `install.sh` | `install::` | `install::run_module` |
| `uninstall.sh` | `uninstall::` | `uninstall::run_module` |
| `modules/*.sh` | `module::` / `_<mod>::` | `install`, `uninstall` (interface hooks); `_nvim::install_src` (module-local helper) |
```

New table:

```markdown
| File | Namespace | Examples |
|---|---|---|
| `lib/core.sh` | `core::` | `core::log`, `core::symlink`, `core::check_installed`, `core::require_version` |
| `lib/detect.sh` | `detect::` | `detect::os`, `detect::pkg_manager` |
| `lib/bootstrap.sh` | `bootstrap::` | `bootstrap::xcode_clt`, `bootstrap::homebrew`, `bootstrap::dev_tools` |
| `install.sh` | `install::` | `install::run_module` |
| `uninstall.sh` | `uninstall::` | `uninstall::run_module` |
| `modules/*.sh` | `module::` / `_<mod>::` | `install`, `uninstall` (interface hooks); `_nvim::install_src` (module-local helper) |
```

- [ ] **Step 2: Commit**

```bash
git add .claude/rules/shell-style.md
git commit -m "$(cat <<'EOF'
docs(rules): add bootstrap:: to namespace table

Keeps the shell-style.md namespace reference in sync with the new
lib/bootstrap.sh file.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Final sweep — stale references + full shellcheck/shfmt

**Files:**
- None (verification only)

- [ ] **Step 1: Grep for stale `pacman` references**

Run: `grep -rn 'pacman' lib/ install.sh uninstall.sh README.md .claude/rules/ docs/changes/2026-04-23-bootstrap-module/ 2>/dev/null || true`

Expected: hits in `docs/changes/2026-04-23-bootstrap-module/design.md` and `docs/changes/2026-04-23-bootstrap-module/tasks.md` only (the design doc discusses the removal; this file explains it). **Zero** hits in `lib/`, `install.sh`, `uninstall.sh`, `README.md`, `.claude/rules/`.

If pacman appears anywhere else, open that file and delete it per the same rationale as Tasks 2 and 3, then add a new targeted commit.

- [ ] **Step 2: Grep for stale `base-devel` references**

Run: `grep -rn 'base-devel' lib/ install.sh uninstall.sh README.md .claude/rules/ 2>/dev/null || true`

Expected: zero hits. `base-devel` is the Arch equivalent of `build-essential` and should not be referenced anywhere.

- [ ] **Step 3: Grep for stale detect auto-run assumption**

Ensure nothing still relies on sourcing `lib/detect.sh` triggering detection:

Run: `grep -rn 'source.*lib/detect.sh' . --include='*.sh' 2>/dev/null`

For each hit, confirm the surrounding context either already calls `detect::os` / `detect::pkg_manager` explicitly (e.g. in a `main()`) or is the new `install.sh` / `uninstall.sh` that does so. Modules must not rely on detection — they only read `DOTFILES_OS` / `DOTFILES_PKG_MANAGER`, which are set by the orchestrator before modules run.

Expected: hits in `install.sh` and `uninstall.sh` only — both now call the functions explicitly in `main()`.

- [ ] **Step 4: Full shellcheck sweep**

Run:

```bash
shellcheck install.sh uninstall.sh lib/*.sh modules/*.sh
```

Expected: exit 0, no new warnings. If any new warning appears that is unrelated to this change, it pre-dates this work — leave it alone (out of scope).

- [ ] **Step 5: Full shfmt sweep**

Run:

```bash
shfmt -d install.sh uninstall.sh lib/*.sh modules/*.sh
```

Expected: no diff output, exit 0.

- [ ] **Step 6: Library re-source safety smoke test**

Source each lib file three times in a row under strict mode to catch any accidental `readonly` / once-only side effect:

```bash
bash -c 'set -euo pipefail
for i in 1 2 3; do
  source lib/core.sh
  source lib/detect.sh
  source lib/bootstrap.sh
done
echo OK'
```

Expected: `OK`.

- [ ] **Step 7: Trial install on the current machine**

The current dev machine already has brew + dev tools installed, so the installer should see `Xcode Command Line Tools already installed`, `Homebrew already installed`, and the `brew install cmake meson ninja gettext` line should log `Warning: <pkg> is already installed` for each. No regressions in the subsequent module loop.

Run: `./install.sh`

Expected logs (first few lines):

```
[INFO] Xcode Command Line Tools already installed
[INFO] Homebrew already installed
[INFO] Dev tools installed
[INFO] Platform: mac | Package manager: brew
[INFO] ▶ [1/6] ghostty — ...
```

Followed by each module running exactly as before. Abort the installer with Ctrl+C if any module would make unwanted changes — the first three lines are the actual verification target.

- [ ] **Step 8: No new commit**

Task 8 is verification only. If every step passed, no commit is needed. If any step surfaced a bug, fix it in a new targeted commit before considering the feature done.

---

## Self-Review Notes

- **Spec coverage:** All 10 sections of `design.md` map to tasks above:
  - §1 File inventory → Tasks 1–7
  - §2 bootstrap.sh contract → Task 1
  - §3 install.sh orchestration → Task 4
  - §4 CLT install → Task 1 (bootstrap::xcode_clt body)
  - §5 Homebrew install → Task 1 (bootstrap::homebrew body)
  - §6 bootstrap::dev_tools → Task 1 (case body)
  - §7 detect.sh restructure → Task 3
  - §8 core.sh drop pacman → Task 2
  - §9 README updates → Task 6
  - §10 shell-style.md namespace → Task 7
- **No placeholders:** every task shows the exact code or text to write, with file paths and line-number anchors.
- **Type/name consistency:** `bootstrap::xcode_clt`, `bootstrap::homebrew`, `bootstrap::dev_tools` appear identically in design.md §2, Task 1's function definitions, Task 4's `main()` call sites, and Task 7's namespace table entry. `_BOOTSTRAP_CLT_POLL_INTERVAL` and `_BOOTSTRAP_CLT_MAX_WAIT` are defined once in Task 1 and referenced only in Task 1's `bootstrap::xcode_clt`.
- **No new `readonly` in libs/modules:** bootstrap.sh uses `_BOOTSTRAP_CLT_*` plain-assignment constants per shell-style.md's guidance; re-source safety test in Task 8 verifies this.
- **Commit trailers:** every commit message template includes the `Co-Authored-By` line. No `--no-verify` anywhere.
