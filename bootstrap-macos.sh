#!/bin/bash
# bootstrap-macos.sh — one-time prerequisites for macOS only.
#
# Apple ships /bin/bash 3.2 (frozen on GPLv2) and never updates it, but the
# rest of this project requires bash >= 4.3 (associative arrays + `[[ -v
# arr[k] ]]`). This script bridges the gap on a fresh Mac:
#
#   1. Installs Homebrew if missing.
#   2. Installs a modern bash via `brew install bash` if /bin/bash is too old.
#
# Run this ONCE before ./install.sh on a fresh macOS machine. It is
# deliberately written in bash 3.2-compatible syntax so the system bash can
# execute it directly. Linux users do not need this script — every supported
# distro (Ubuntu, Fedora, RHEL) ships bash >= 4.3.
#
# Usage: ./bootstrap-macos.sh

set -euo pipefail
IFS=$'\n\t'

log() { printf '[INFO] %s\n' "$1"; }
err() { printf '[ERROR] %s\n' "$1" >&2; }

# 1. Refuse to run anywhere except macOS — the script's whole reason to
#    exist is the system's frozen bash 3.2.
if [ "$(uname)" != "Darwin" ]; then
  err "bootstrap-macos.sh is for macOS only (detected: $(uname))"
  err "On Linux, run ./install.sh directly — bash 4+ ships by default."
  exit 1
fi

# 2. Install Homebrew if absent. Uses the official upstream installer; it is
#    interactive (prompts before sudo) so the user can review what it does.
if command -v brew >/dev/null 2>&1; then
  log "Homebrew already installed: $(command -v brew)"
else
  log "Installing Homebrew (official installer)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 3. Locate the brew prefix so we can call brew without depending on PATH —
#    the installer writes the shellenv block to ~/.zprofile, which is only
#    sourced at login, so within THIS shell brew may still be off PATH.
if   [ -x /opt/homebrew/bin/brew ]; then BREW=/opt/homebrew/bin/brew  # Apple Silicon
elif [ -x /usr/local/bin/brew    ]; then BREW=/usr/local/bin/brew     # Intel
else
  err "brew binary not found at /opt/homebrew/bin/brew or /usr/local/bin/brew"
  err "Re-run this script — Homebrew install may have been interrupted."
  exit 1
fi

# 4. Install a modern bash if the system one is too old. Compare major and
#    minor as separate integers — concatenating them (e.g. "${maj}${min}")
#    misbehaves once minor reaches double digits (4.10 -> "410" vs need 43).
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

log ""
log "Bootstrap complete. To run the installer in the same shell:"
log ""
log "  eval \"\$(${BREW} shellenv)\" && ./install.sh"
log ""
log "(./install.sh will write the brew shellenv into ~/.zprofile so future"
log " terminal sessions pick it up automatically.)"
