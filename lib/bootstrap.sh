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

# macOS only. Install the Xcode Command Line Tools (git, curl, clang, make,
# etc.) if absent. `xcode-select --install` pops a GUI confirmation dialog and
# returns immediately while the download runs in the background; we then poll
# `xcode-select -p` until the toolchain appears. Apple provides no synchronous
# install API — every automation tool (Homebrew's own installer, Ansible,
# Chef, nix-darwin) uses the same polling pattern.
bootstrap::xcode_clt() {
  # 15s interval keeps progress logs frequent enough to reassure the user;
  # 30-minute ceiling bounds the wait (typical CLT install completes in
  # 5-15 minutes on a good network).
  local poll_interval=15
  local max_wait=1800

  if xcode-select -p >/dev/null 2>&1; then
    core::log INFO "Xcode Command Line Tools already installed"
    return 0
  fi

  core::log INFO "Triggering Xcode Command Line Tools install (GUI dialog)..."
  # `xcode-select --install` returns non-zero if the dialog is already open
  # or the tools are already present — the poll loop below is the real gate.
  xcode-select --install >/dev/null 2>&1 || true

  local waited=0
  while ! xcode-select -p >/dev/null 2>&1; do
    if ((waited >= max_wait)); then
      core::log ERROR "Xcode CLT install did not complete within ${max_wait}s"
      core::log ERROR "Finish the install via the GUI dialog, then re-run ./install.sh"
      return 1
    fi
    core::log INFO "Waiting for Xcode CLT install to finish (${waited}s/${max_wait}s)..."
    sleep "${poll_interval}"
    waited=$((waited + poll_interval))
  done

  core::log INFO "Xcode Command Line Tools installed"
}

# macOS only. Install Homebrew via the official upstream installer, then eval
# `brew shellenv` so later modules in this install run can call `brew install`.
# Persistent PATH wiring for future shells is handled by the zsh module's
# zshrc.mac symlink (which already contains `eval "$(brew shellenv)"`).
bootstrap::homebrew() {
  if command -v brew >/dev/null 2>&1; then
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
    return 1
    ;;
  esac

  core::log INFO "Dev tools installed"
}
