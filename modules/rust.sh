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
