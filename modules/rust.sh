#!/usr/bin/env bash
# modules/rust.sh — Rust toolchain via rustup
# Platform: all
# shellcheck disable=SC2034,SC2016  # module interface vars + intentional literal shell expansion in zprofile block
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="rust"
MODULE_DESC="Rust toolchain via rustup"
MODULE_PLATFORM="all"

LINKS=()

# Installs the Rust stable toolchain via the official rustup script.
# Idempotent: skips if rustup is already present. After install (or skip),
# sources ~/.cargo/env so later modules (nvim → tree-sitter-cli) can see cargo,
# and writes a "rust" block to ~/.zprofile so future shells pick up cargo too.
install() {
  if core::check_installed rustup; then
    core::log INFO "rustup already installed — skipping"
  else
    # --no-modify-path: we manage PATH via the ~/.zprofile block below,
    # not via rustup's own shell-integration patching.
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

  # Persist cargo env for future login shells. Symmetric with brew's
  # ~/.zprofile wiring in bootstrap::homebrew. ${HOME} is escaped so zsh
  # expands it at login, not bash at install-time.
  core::ensure_block "${HOME}/.zprofile" "rust" \
    '[[ -f "${HOME}/.cargo/env" ]] && . "${HOME}/.cargo/env"'
}

uninstall() {
  core::remove_block "${HOME}/.zprofile" "rust"
}
