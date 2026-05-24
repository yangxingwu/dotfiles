#!/usr/bin/env bash
# modules/rust.sh — Rust toolchain via rustup
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="rust"
MODULE_DESC="Rust toolchain via rustup"
MODULE_PLATFORM="all"

# Installs the Rust stable toolchain via the official rustup script.
# Idempotent: skips if rustup is already present. After install (or skip),
# sources ~/.cargo/env so later modules (nvim → tree-sitter-cli) can see cargo,
# and writes a "rust" block to ~/.zshenv so future shells pick up cargo too.
install() {
  # Activate cargo env if present (e.g. restored from CI cache or previous run).
  # Without this, ~/.cargo/bin may not be in PATH and check_installed fails
  # even though rustup binary exists.
  if [[ -f "${HOME}/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
  fi

  if core::check_installed rustup; then
    core::log INFO "rustup already installed — skipping"
    core::summary "    ✓ rustup already installed"
  else
    # Install rustup. Use rsproxy.cn mirror in China for faster download.
    # See: https://rsproxy.cn/#getStarted
    if [[ "${_CORE_MIRROR_CN}" == "true" ]]; then
      export RUSTUP_DIST_SERVER="https://rsproxy.cn"
      export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
      core::log INFO "Using rsproxy.cn mirror for rustup"
      core::run_cmd "Installing rustup" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://rsproxy.cn/rustup-init.sh | sh -s -- -y --no-modify-path' || return 1
    else
      core::run_cmd "Installing rustup" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path' || return 1
    fi
    core::summary "    ✓ installed via rustup"
  fi

  if [[ ! -f "${HOME}/.cargo/env" ]]; then
    core::log ERROR "${HOME}/.cargo/env not found — rustup install may have failed"
    return 1
  fi

  # Activate cargo for the rest of this install run.
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"

  # Ensure a default toolchain is configured (CI cache may restore rustup without one).
  if ! rustup show active-toolchain >/dev/null 2>&1; then
    core::run_cmd "Setting default Rust toolchain" rustup default stable || return 1
  fi

  # rust-analyzer is required by rustaceanvim (Rust LSP in nvim). The rustup
  # proxy shim at ~/.cargo/bin/rust-analyzer exists by default but fails with
  # "Unknown binary" unless the component is explicitly installed.
  rustup component add rust-analyzer >/dev/null 2>&1 || true

  # Persist for future shells.
  local block_content
  block_content=$(cat <<'EOF'
[[ -f "${HOME}/.cargo/env" ]] && . "${HOME}/.cargo/env"
EOF
  )
  if [[ "${_CORE_MIRROR_CN}" == "true" ]]; then
    # Write cargo registry mirror config.
    # See: https://rsproxy.cn/#getStarted
    mkdir -p "${HOME}/.cargo"
    cat >"${HOME}/.cargo/config.toml" <<'TOML'
[source.crates-io]
replace-with = 'rsproxy-sparse'

[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"

[registries.rsproxy-sparse]
index = "sparse+https://rsproxy.cn/index/"

[net]
git-fetch-with-cli = true
TOML
    core::log INFO "Wrote cargo mirror config: ~/.cargo/config.toml"
    core::summary "    ✓ config → ~/.cargo/config.toml (rsproxy.cn)"
  fi
  core::ensure_block "${HOME}/.zshenv" "rust" "${block_content}"
  core::summary "    ✓ config → ~/.zshenv (cargo env)"
}

uninstall() {
  core::remove_block "${HOME}/.zshenv" "rust"
  rm -f "${HOME}/.cargo/config.toml"
  core::summary "    ✓ removed block from ~/.zshenv"
  core::summary "    ✓ removed ~/.cargo/config.toml"
}
