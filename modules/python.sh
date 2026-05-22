#!/usr/bin/env bash
# modules/python.sh — Python 3, pip, venv, pipx
# Platform: all
#
# Ensures python3/pip/venv are available, installs pipx for isolated CLI tool
# management, and adds ~/.local/bin to PATH.
#
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="python"
MODULE_DESC="Python 3, pip, venv, pipx"
MODULE_PLATFORM="all"
MODULE_DEPS=()

# Install python3, pip, venv, and pipx via system package manager.
_python::install_packages() {
  case "${DOTFILES_PKG_MANAGER}" in
  brew)
    core::pkg_install python3 pipx || return 1
    ;;
  apt)
    core::pkg_install python3 python3-pip python3-venv python-is-python3 pipx || return 1
    ;;
  dnf)
    core::pkg_install python3 python3-pip pipx || return 1
    ;;
  esac

  core::summary "    ✓ python3, pip, venv, pipx installed"
}

# Add ~/.local/bin to PATH (pip --user and pipx binaries).
_python::configure_path() {
  local block_content
  block_content=$(cat <<'EOF'
# Python: ~/.local/bin (pip --user and pipx binaries)
case ":${PATH}:" in
  *:"${HOME}/.local/bin":*) ;;
  *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac
EOF
  )
  core::ensure_block "${HOME}/.zshenv" "python" "${block_content}"
  core::summary "    ✓ config → ~/.zshenv (PATH += ~/.local/bin)"
}

install() {
  _python::install_packages || return 1
  _python::configure_path || return 1
}

uninstall() {
  core::remove_block "${HOME}/.zshenv" "python"
  core::log INFO "Removed python PATH block from ~/.zshenv"
  core::summary "    ✓ removed PATH block from ~/.zshenv"
}
