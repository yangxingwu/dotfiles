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

# Install zsh if missing, switch the user's login shell to zsh if it isn't
# already, and touch the three zsh startup files as empty skeletons so later
# stages can write managed blocks into them.
#
# This runs as Stage A of install.sh, before detect::pkg_manager. On Linux
# the zsh install dispatches directly on apt-get / dnf presence since
# DOTFILES_PKG_MANAGER isn't set yet. On macOS zsh is preinstalled so no
# package install happens.
#
# chsh failures bubble via set -e (hard fail): wrong password or zsh not in
# /etc/shells will abort the installer; the user fixes the cause and re-runs.
bootstrap::zsh() {
  if ! command -v zsh >/dev/null 2>&1; then
    case "${DOTFILES_OS}" in
    linux)
      if command -v apt-get >/dev/null 2>&1; then
        core::run_cmd "Installing zsh" sudo apt-get install -y zsh
      elif command -v dnf >/dev/null 2>&1; then
        core::run_cmd "Installing zsh" sudo dnf install -y zsh
      else
        core::log ERROR "zsh not found and no supported package manager to install it"
        core::log ERROR "Supported Linux package managers: apt (Debian/Ubuntu), dnf (Fedora/RHEL)"
        return 1
      fi
      ;;
    mac)
      # macOS ships zsh preinstalled since Catalina. Reaching this branch
      # means the system zsh was removed — an unusual state we don't try to
      # repair automatically (installing brew's zsh here would conflict with
      # later brew stage).
      core::log ERROR "zsh not found on macOS; this is unusual (system zsh is preinstalled since Catalina)"
      core::log ERROR "Install zsh manually (e.g. restore /bin/zsh or brew install zsh) and re-run"
      return 1
      ;;
    *)
      core::log ERROR "bootstrap::zsh called with unsupported DOTFILES_OS=${DOTFILES_OS}"
      return 1
      ;;
    esac
    core::log INFO "zsh installed"
    core::summary "  zsh                          ✓ installed"
  else
    core::log INFO "zsh already installed"
    core::summary "  zsh                          ✓ already installed"
  fi

  # SHELL env var is populated from /etc/passwd at login and does not update
  # within the same session after chsh. That is fine: a re-run in a fresh
  # shell will see the updated value, and an accidental second chsh within
  # the same session is a harmless no-op.
  local current_shell
  current_shell="$(basename "${SHELL:-/bin/sh}")"
  if [[ "${current_shell}" != "zsh" ]]; then
    core::run_cmd "Changing login shell to zsh" sudo chsh -s "$(command -v zsh)" "$(whoami)"
  else
    core::log INFO "Login shell already zsh"
  fi

  # Ensure real-file skeletons exist. touch is a no-op on existing files.
  # These files are NOT symlinks — downstream code uses core::ensure_block
  # to write markered blocks into them.
  touch "${HOME}/.zshrc" "${HOME}/.zprofile" "${HOME}/.zshenv"
}

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
    core::summary "  Xcode Command Line Tools     ✓ already installed"
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
  core::summary "  Xcode Command Line Tools     ✓ installed"
}

# macOS only. Install Homebrew via the official upstream installer, write a
# managed "homebrew" block to ~/.zprofile (so brew stays on PATH for future
# login shells), and eval shellenv for the rest of this install run.
#
# On a fresh machine Homebrew should already be present at this point —
# ./bootstrap-macos.sh installs it as a prerequisite for getting bash >= 4.3.
# This function is kept as a defence-in-depth: it still installs brew if
# missing (e.g. user reached install.sh via a system bash that already
# satisfied the version gate without going through bootstrap-macos.sh), and
# it always re-writes the .zprofile shellenv block, which is needed even
# when brew was installed earlier (e.g. by an OS image).
#
# Apple Silicon installs to /opt/homebrew; Intel to /usr/local. A user who
# migrates machines will see core::ensure_block rewrite the block to match
# the new prefix on next run.
bootstrap::homebrew() {
  if command -v brew >/dev/null 2>&1; then
    core::log INFO "Homebrew already installed"
    core::summary "  Homebrew                     ✓ already installed"
  else
    core::log INFO "Installing Homebrew (official installer)..."
    # Interactive by default — brew prompts "Press RETURN to continue" so the
    # user can review what is about to happen before granting sudo. We do NOT
    # set NONINTERACTIVE=1.
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    core::log INFO "Homebrew installed"
    core::summary "  Homebrew                     ✓ installed"
  fi

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

  # Activate for the rest of THIS install run — .zprofile only applies to
  # login shells, but later stages/modules in this same process need brew
  # on PATH now.
  eval "$("${brew_prefix}/bin/brew" shellenv)"

  # Persist for future login shells. ~/.zprofile was touched by
  # bootstrap::zsh in Stage A, so it exists. ${brew_prefix} expands at
  # install-time; the inner $(...) stays literal for zsh to eval at login.
  # Runs unconditionally — even when brew was already installed, the
  # .zprofile block may be missing (e.g. first run on a machine with brew
  # pre-installed by the OS image).
  core::ensure_block "${HOME}/.zprofile" "homebrew" \
    "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
  core::summary "  Homebrew                     ✓ shellenv wired into ~/.zprofile"
}

# Both platforms. Install the dev tools every module assumes exist.
# Requires DOTFILES_PKG_MANAGER to be set — call detect::pkg_manager first.
#
# dnf's @development-tools is a group install — core::pkg_install only
# handles individual packages, so the group is installed directly here.
bootstrap::dev_tools() {
  core::summary "  dev tools"

  case "${DOTFILES_PKG_MANAGER}" in
  brew)
    core::run_cmd "Installing dev tools" core::pkg_install cmake meson ninja gettext
    ;;
  apt)
    core::run_cmd "Installing dev tools" core::pkg_install git curl cmake meson ninja-build gettext \
      pkg-config libssl-dev libclang-dev build-essential
    ;;
  dnf)
    core::run_cmd "Installing dev tools" core::pkg_install git curl cmake meson ninja-build gettext \
      pkg-config openssl-devel clang-devel
    # @development-tools is a dnf group — check and install directly.
    if dnf group list --installed 2>/dev/null | grep -qi "development tools"; then
      core::log INFO "Already installed: @development-tools"
      core::summary "    ✓ @development-tools already installed"
    else
      core::run_cmd "Installing @development-tools" sudo dnf install -y @development-tools
      core::summary "    ✓ @development-tools installed via dnf"
    fi
    ;;
  *)
    core::log ERROR "Unsupported package manager: ${DOTFILES_PKG_MANAGER}"
    core::log ERROR "Supported: brew (macOS), apt (Debian/Ubuntu), dnf (Fedora/RHEL)"
    return 1
    ;;
  esac

  core::log INFO "Dev tools installed"
}
