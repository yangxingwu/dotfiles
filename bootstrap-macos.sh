#!/bin/bash
# bootstrap-macos.sh — one-time prerequisites for macOS.
#
# Apple ships /bin/bash 3.2 (frozen on GPLv2) and never updates it, but the
# rest of this project requires bash >= 4.3 (associative arrays + `[[ -v
# arr[k] ]]`). This script bridges the gap on a fresh Mac:
#
#   1. Installs Xcode Command Line Tools (if absent)
#   2. Installs Homebrew (if absent)
#   3. Installs modern bash via brew if system bash < 4.3
#   4. Verifies zsh exists (ships with macOS by default)
#   5. Sets login shell to zsh if not already
#   6. Installs dev tools (cmake, meson, ninja, gettext)
#   7. Creates shell init files
#
# Run this ONCE before ./install.sh on a fresh macOS machine. It is
# deliberately written in bash 3.2-compatible syntax so the system bash can
# execute it directly.
#
# Usage: ./bootstrap-macos.sh

set -euo pipefail
IFS=$'\n\t'

log() { printf '[INFO] %s\n' "$1"; }
err() { printf '[ERROR] %s\n' "$1" >&2; }

# ── Parse arguments ──────────────────────────────────────────────────────

MIRROR_CN="false"
while [ $# -gt 0 ]; do
  case "${1}" in
  --mirror-cn)
    MIRROR_CN="true"
    shift
    ;;
  *)
    err "Unknown option: ${1}"
    exit 1
    ;;
  esac
done

# ── 1. Platform check ────────────────────────────────────────────────────

if [ "$(uname)" != "Darwin" ]; then
  err "bootstrap-macos.sh is for macOS only (detected: $(uname))"
  err "On Linux, run ./bootstrap-linux.sh instead."
  exit 1
fi

# ── 2. Install Xcode Command Line Tools ──────────────────────────────────

if xcode-select -p >/dev/null 2>&1; then
  log "Xcode CLT already installed: $(xcode-select -p)"
else
  log "Installing Xcode Command Line Tools..."
  # Trigger the softwareupdate mechanism. The touch creates a sentinel file
  # that causes the CLT package to appear in softwareupdate --list.
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  xcode-select --install 2>/dev/null || true

  # Poll until the tools are installed (max 1800s / 30 minutes).
  ELAPSED=0
  INTERVAL=15
  TIMEOUT=1800
  while ! xcode-select -p >/dev/null 2>&1; do
    if [ "${ELAPSED}" -ge "${TIMEOUT}" ]; then
      err "Timed out waiting for Xcode CLT installation (${TIMEOUT}s)"
      err "Please install manually: xcode-select --install"
      rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
      exit 1
    fi
    log "Waiting for Xcode CLT installation... (${ELAPSED}s elapsed)"
    sleep "${INTERVAL}"
    ELAPSED=$((ELAPSED + INTERVAL))
  done
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  log "Xcode CLT installed: $(xcode-select -p)"
fi

# ── 3. Install Homebrew ───────────────────────────────────────────────────

# Set Homebrew mirror for China if requested.
# See: https://mirrors.ustc.edu.cn/help/brew.git.html
#      https://mirrors.ustc.edu.cn/help/homebrew-bottles.html
if [ "${MIRROR_CN}" = "true" ]; then
  # Remote for the brew CLI repository itself (used by `brew update`)
  export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
  # Remote for the package definition repository (used by `brew update`)
  export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
  # URL prefix for downloading prebuilt binary packages (used by `brew install`)
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
  # URL for the JSON API that lists available packages (used by `brew search/info`)
  export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
  log "Using USTC mirror for Homebrew"
fi

if command -v brew >/dev/null 2>&1; then
  log "Homebrew already installed: $(command -v brew)"
else
  if [ "${MIRROR_CN}" = "true" ]; then
    log "Installing Homebrew (USTC mirror)..."
    /bin/bash -c "$(curl -fsSL https://mirrors.ustc.edu.cn/misc/brew-install.sh)"
  else
    log "Installing Homebrew (official installer)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
fi

# ── 4. Locate brew prefix ────────────────────────────────────────────────

if [ -x /opt/homebrew/bin/brew ]; then
  BREW=/opt/homebrew/bin/brew  # Apple Silicon
elif [ -x /usr/local/bin/brew ]; then
  BREW=/usr/local/bin/brew     # Intel
else
  err "brew binary not found at /opt/homebrew/bin/brew or /usr/local/bin/brew"
  err "Re-run this script — Homebrew install may have been interrupted."
  exit 1
fi
log "Using brew: ${BREW}"

# Activate brew for the rest of this script.
eval "$(${BREW} shellenv)"

# ── 5. Install modern bash if system bash < 4.3 ──────────────────────────

need_major=4
need_minor=3
have_major="${BASH_VERSINFO[0]:-0}"
have_minor="${BASH_VERSINFO[1]:-0}"

if [ "${have_major}" -gt "${need_major}" ] ||
  { [ "${have_major}" -eq "${need_major}" ] && [ "${have_minor}" -ge "${need_minor}" ]; }; then
  log "System bash already >= ${need_major}.${need_minor} (running ${BASH_VERSION})"
elif "${BREW}" list --formula bash >/dev/null 2>&1; then
  log "Homebrew bash already installed: $("${BREW}" --prefix)/bin/bash"
else
  log "Installing bash via Homebrew..."
  "${BREW}" install bash
fi

# ── 6. Verify zsh exists ─────────────────────────────────────────────────

if ! command -v zsh >/dev/null 2>&1; then
  err "zsh not found — this is unusual on macOS."
  err "Install it with: ${BREW} install zsh"
  exit 1
fi
log "zsh found: $(command -v zsh)"

# ── 7. Set login shell to zsh if not already ─────────────────────────────

ZSH_PATH="$(command -v zsh)"
CURRENT_SHELL="$(dscl . -read "/Users/$(whoami)" UserShell | awk '{print $2}')"

if [ "${CURRENT_SHELL}" = "${ZSH_PATH}" ]; then
  log "Login shell already set to zsh"
else
  log "Setting login shell to ${ZSH_PATH}..."
  sudo chsh -s "${ZSH_PATH}" "$(whoami)"
  log "Login shell changed to zsh (takes effect on next login)"
fi

# ── 8. Install dev tools ─────────────────────────────────────────────────

log "Installing development tools via Homebrew..."
# Note: clangd is provided by Xcode Command Line Tools (/usr/bin/clangd),
# no brew install needed.
"${BREW}" install cmake meson ninja gettext wget 2>/dev/null || true
log "Development tools installed"

# ── 9. Create shell init files ────────────────────────────────────────────

touch "${HOME}/.zshrc" "${HOME}/.zprofile" "${HOME}/.zshenv"
log "Ensured ~/.zshrc, ~/.zprofile, ~/.zshenv exist"

# ── Done ──────────────────────────────────────────────────────────────────

log ""
log "Bootstrap complete. To run the installer in the same shell:"
log ""
log "  eval \"\$(${BREW} shellenv)\" && ./install.sh"
log ""
log "(./install.sh will write the brew shellenv into ~/.zshenv so future"
log " terminal sessions pick it up automatically.)"
