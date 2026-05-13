#!/bin/bash
# bootstrap-linux.sh — one-time prerequisites for Linux servers/workstations.
#
# Detects the system package manager (apt or dnf), installs zsh and core
# development tools, sets zsh as the login shell, and creates shell init
# files. Run this ONCE on a fresh Linux machine before ./install.sh.
#
# Written in bash 3.2-compatible syntax ([ ] not [[ ]]) for maximum
# portability, though in practice every supported distro ships bash >= 4.
#
# Usage: ./bootstrap-linux.sh

set -euo pipefail
IFS=$'\n\t'

log() { printf '[INFO] %s\n' "$1"; }
err() { printf '[ERROR] %s\n' "$1" >&2; }

# ── 1. Platform check ────────────────────────────────────────────────────

if [ "$(uname)" != "Linux" ]; then
  err "bootstrap-linux.sh is for Linux only (detected: $(uname))"
  err "On macOS, run ./bootstrap-macos.sh instead."
  exit 1
fi

# ── 2. Detect package manager ────────────────────────────────────────────

PKG_MANAGER=""
if command -v apt-get >/dev/null 2>&1; then
  PKG_MANAGER="apt"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MANAGER="dnf"
else
  err "No supported package manager found (need apt-get or dnf)"
  exit 1
fi
log "Detected package manager: ${PKG_MANAGER}"

# ── 3. Install zsh if missing ────────────────────────────────────────────

if command -v zsh >/dev/null 2>&1; then
  log "zsh already installed: $(command -v zsh)"
else
  log "Installing zsh..."
  case "${PKG_MANAGER}" in
  apt)
    sudo apt-get update -y
    sudo apt-get install -y zsh
    ;;
  dnf)
    sudo dnf install -y zsh
    ;;
  esac
fi

# ── 4. Set login shell to zsh if not already ─────────────────────────────

ZSH_PATH="$(command -v zsh)"
CURRENT_SHELL="$(getent passwd "$(whoami)" | cut -d: -f7)"

if [ "${CURRENT_SHELL}" = "${ZSH_PATH}" ]; then
  log "Login shell already set to zsh"
else
  log "Setting login shell to ${ZSH_PATH}..."
  # Ensure zsh is in /etc/shells before chsh.
  if ! grep -qxF "${ZSH_PATH}" /etc/shells; then
    printf '%s\n' "${ZSH_PATH}" | sudo tee -a /etc/shells >/dev/null
  fi
  sudo chsh -s "${ZSH_PATH}" "$(whoami)"
  log "Login shell changed to zsh (takes effect on next login)"
fi

# ── 5. Install development tools ─────────────────────────────────────────

log "Installing development tools..."
case "${PKG_MANAGER}" in
apt)
  sudo apt-get update -y
  sudo apt-get install -y \
    git \
    curl \
    cmake \
    meson \
    ninja-build \
    gettext \
    pkg-config \
    libssl-dev \
    libclang-dev \
    build-essential
  ;;
dnf)
  sudo dnf install -y \
    git \
    curl \
    cmake \
    meson \
    ninja-build \
    gettext \
    pkg-config \
    openssl-devel \
    clang-devel
  sudo dnf install -y @development-tools
  ;;
esac
log "Development tools installed"

# ── 6. Create shell init files ────────────────────────────────────────────

touch "${HOME}/.zshrc" "${HOME}/.zprofile" "${HOME}/.zshenv"
log "Ensured ~/.zshrc, ~/.zprofile, ~/.zshenv exist"

# ── Done ──────────────────────────────────────────────────────────────────

log ""
log "Bootstrap complete. Run ./install.sh to install modules."
