#!/usr/bin/env bash
# modules/nodejs.sh — Node.js runtime via fnm (Fast Node Manager)
# https://github.com/Schniz/fnm
# Platform: all
#
# Relationship between tools:
#   fnm       → installs/manages Node.js versions (like pyenv for Python)
#     └── Node.js → JS runtime
#           └── npm  → package manager (bundled with Node.js, not installed separately)
#
# Why fnm over alternatives:
#   - apt/dnf native: Ubuntu 22.04 ships Node 12 (too old for neovim npm package >= 18)
#   - NodeSource PPA: Ubuntu-only fix, no version management
#   - nvm: shell startup overhead (50-200ms), bash script not a binary
#   - n (npm-based): chicken-and-egg problem on fresh install (needs existing npm)
#   - fnm: single Rust binary, <1ms shell init, cross-platform
#
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="nodejs"
MODULE_DESC="Node.js runtime via fnm (Fast Node Manager)"
MODULE_PLATFORM="all"
MODULE_DEPS=("rust")

install() {
  # Step 1: Install fnm via cargo (rust module guarantees cargo is available).
  if core::check_installed fnm; then
    core::log INFO "fnm already installed"
    core::summary "    ✓ fnm already installed"
  else
    core::run_cmd "Installing fnm" cargo install --locked fnm || return 1
    core::summary "    ✓ fnm installed via cargo"
  fi

  # Activate mirror for the rest of this install run.
  if [[ "${_CORE_MIRROR_CN}" == "true" ]]; then
    export FNM_NODE_DIST_MIRROR="https://npmmirror.com/mirrors/node/"
  fi

  # Step 2: Install Node.js LTS.
  # fnm install --lts is idempotent: if the current LTS is already installed
  # it completes instantly; if a newer LTS is available it installs it.
  # This ensures we always have a node >= 18 (current LTS is 22.x).
  core::run_cmd "Installing Node.js LTS" fnm install --lts || return 1
  fnm default lts-latest
  core::summary "    ✓ Node.js LTS installed ($(fnm exec --using=lts-latest node -v))"

  # Activate fnm for the rest of this install run (same pattern as rust module
  # sourcing ~/.cargo/env). Without this, node/npm won't be in PATH for
  # subsequent modules that depend on nodejs (e.g. nvim's npm install -g neovim).
  eval "$(fnm env --use-on-cd)"

  # Step 3: Configure npm registry mirror for China (when --mirror-cn is used).
  # npmmirror.com is maintained by Alibaba (Taobao team), syncs every 10 min.
  # See: https://npmmirror.com/
  if [[ "${_CORE_MIRROR_CN}" == "true" ]]; then
    npm config set registry https://registry.npmmirror.com
    core::log INFO "Using npmmirror.com registry for npm"
    core::summary "    ✓ npm registry → https://registry.npmmirror.com"
  fi

  # Step 4: Shell integration.
  # eval "$(fnm env --use-on-cd)" activates fnm and enables automatic version
  # switching when entering a directory with .node-version or .nvmrc.
  # Invoke fnm by its absolute cargo path rather than a bare `command -v fnm`:
  # ~/.cargo/bin is only added to PATH by the rust block, and .zshenv block
  # order isn't guaranteed, so a bare probe can run before cargo's PATH exists
  # and silently skip activation (breaking `fnm current`).
  local block_content
  block_content=$(cat <<'EOF'
[[ -x "${HOME}/.cargo/bin/fnm" ]] && eval "$("${HOME}/.cargo/bin/fnm" env --use-on-cd)"
EOF
  )
  if [[ "${_CORE_MIRROR_CN}" == "true" ]]; then
    block_content=$(cat <<EOF
export FNM_NODE_DIST_MIRROR="https://npmmirror.com/mirrors/node/"
${block_content}
EOF
    )
  fi
  core::ensure_block "${HOME}/.zshenv" "nodejs" "${block_content}"
  core::summary "    ✓ config → ~/.zshenv (fnm env)"
}

uninstall() {
  # Remove shell integration block.
  core::remove_block "${HOME}/.zshenv" "nodejs"
  core::summary "    ✓ removed nodejs block from ~/.zshenv"

  # Remove fnm-managed Node.js versions and global npm packages.
  # fnm stores everything under ~/.local/share/fnm/ — each Node version
  # includes its own npm and globally installed packages (npm install -g).
  rm -rf "${HOME}/.local/share/fnm"
  core::summary "    ✓ removed ~/.local/share/fnm (Node versions + global packages)"

  # fnm binary (~/.cargo/bin/fnm) is NOT removed — consistent with other
  # modules that install via cargo (uninstall cleans config/data, not binaries).
}
