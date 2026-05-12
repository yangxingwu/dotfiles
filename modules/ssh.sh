#!/usr/bin/env bash
# modules/ssh.sh — SSH client configuration and key management
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
# shellcheck disable=SC2088  # tildes in log strings are intentional (display only)
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="ssh"
MODULE_DESC="SSH client configuration and key management"
MODULE_PLATFORM="all"

# Install sshpass and gh with platform-specific source setup.
# gh install follows official docs:
#   https://github.com/cli/cli/blob/trunk/docs/install_linux.md
#   https://github.com/cli/cli/blob/trunk/docs/install_macos.md
_ssh::install_packages() {
  # sshpass: available in homebrew-core, apt, and dnf default repos.
  core::run_cmd "Installing sshpass" core::pkg_install sshpass

  # gh (GitHub CLI): platform-specific repository setup before install.
  case "${DOTFILES_PKG_MANAGER}" in
  apt)
    # https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
    if [[ ! -f /etc/apt/sources.list.d/github-cli.list ]]; then
      (type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) &&
        sudo mkdir -p -m 755 /etc/apt/keyrings &&
        out=$(mktemp) && wget -nv -O"${out}" https://cli.github.com/packages/githubcli-archive-keyring.gpg &&
        cat "${out}" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null &&
        rm -f "${out}" &&
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
        sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
        sudo apt update >/dev/null 2>&1
      core::log INFO "Added GitHub CLI APT repository"
    fi
    ;;
  dnf)
    if [[ ! -f /etc/yum.repos.d/gh-cli.repo ]]; then
      # Try dnf5 first (Fedora 41+), fall back to dnf4 (Fedora 40 and below).
      if dnf5 --version >/dev/null 2>&1; then
        # https://github.com/cli/cli/blob/trunk/docs/install_linux.md#dnf5
        sudo dnf install -y dnf5-plugins
        sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
      else
        # https://github.com/cli/cli/blob/trunk/docs/install_linux.md#dnf4
        sudo dnf install -y 'dnf-command(config-manager)'
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      fi
      core::log INFO "Added GitHub CLI DNF repository"
    fi
    # gh-cli repo requires explicit --repo flag per official docs.
    sudo dnf install -y gh --repo gh-cli
    core::summary "    ✓ gh installed via dnf"
    ;;
  esac
  # On brew/apt, core::pkg_install handles gh normally.
  if [[ "${DOTFILES_PKG_MANAGER}" != "dnf" ]]; then
    core::run_cmd "Installing gh" core::pkg_install gh
  fi
}

# Create ~/.ssh directory structure and write default config if absent.
_ssh::setup_dirs_and_config() {
  local ssh_dir="${HOME}/.ssh"

  mkdir -p "${ssh_dir}" "${ssh_dir}/passwords" "${ssh_dir}/sockets"
  chmod 700 "${ssh_dir}" "${ssh_dir}/passwords" "${ssh_dir}/sockets"
  core::log INFO "Ensured directory structure: ~/.ssh, ~/.ssh/passwords, ~/.ssh/sockets"
  core::summary "    ✓ directories: ~/.ssh, ~/.ssh/passwords, ~/.ssh/sockets (mode 700)"

  if [[ -f "${ssh_dir}/config" ]]; then
    core::log INFO "~/.ssh/config already exists — skipping (write-once policy)"
    core::summary "    ✓ ~/.ssh/config already exists (not overwritten)"
  else
    cat >"${ssh_dir}/config" <<'SSH_CONFIG'
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 10m
    IdentityFile ~/.ssh/id_ed25519
SSH_CONFIG
    chmod 600 "${ssh_dir}/config"
    core::log INFO "Wrote default ~/.ssh/config"
    core::summary "    ✓ wrote ~/.ssh/config (Host * defaults)"
  fi
}

# Generate ed25519 key pair if not already present.
_ssh::generate_key() {
  local key_file="${HOME}/.ssh/id_ed25519"

  if [[ -f "${key_file}" ]]; then
    core::log INFO "SSH key already exists: ${key_file}"
    core::summary "    ✓ key already exists: ~/.ssh/id_ed25519"
  else
    ssh-keygen -t ed25519 -C "xingwu.yang@gmail.com" -f "${key_file}" -N ""
    core::log INFO "Generated SSH key: ${key_file}"
    core::summary "    ✓ generated key: ~/.ssh/id_ed25519"
  fi
}

# Push public key to GitHub via gh CLI. Authenticates interactively if needed.
# Skipped entirely in non-interactive environments (CI) where no one can
# complete the browser auth flow.
_ssh::push_key_to_github() {
  local pub_key="${HOME}/.ssh/id_ed25519.pub"
  local key_title
  key_title="$(uname -n)"

  # Ensure gh is authenticated — run interactive login if not.
  if ! gh auth status >/dev/null 2>&1; then
    # Non-interactive (no TTY on stdin) — skip rather than hang waiting for auth.
    if [[ ! -t 0 ]]; then
      core::log INFO "gh not authenticated and no TTY — skipping GitHub key push"
      core::summary "    — skipped GitHub key push (non-interactive)"
      return 0
    fi
    core::log INFO "gh not authenticated — starting interactive login"
    gh auth login
  fi

  # Check if this key is already registered on GitHub.
  local pub_content
  pub_content="$(cat "${pub_key}")"
  if gh ssh-key list | grep -qF "${pub_content##* }"; then
    core::log INFO "SSH key already registered on GitHub"
    core::summary "    ✓ public key already on GitHub"
  else
    gh ssh-key add "${pub_key}" --title "${key_title}"
    core::log INFO "Pushed SSH public key to GitHub (title: ${key_title})"
    core::summary "    ✓ public key pushed to GitHub (title: ${key_title})"
  fi
}

# Write the ssh() wrapper function to ~/.ssh/ssh-wrapper.sh and source it
# from .zshrc via a managed block.
_ssh::install_wrapper() {
  local wrapper_file="${HOME}/.ssh/ssh-wrapper.sh"

  cat >"${wrapper_file}" <<'WRAPPER'
# ssh-wrapper.sh — transparent password-based SSH via sshpass
#
# Credential layout:
#   - Username: defined in ~/.ssh/config via "User" directive per Host.
#   - Password: stored as plain text (one password per file, no other content)
#     in ~/.ssh/passwords/<hostname> with mode 600.
#
# If a password file exists for the target host, sshpass feeds it automatically.
# Otherwise, plain ssh runs as normal (key-based or interactive password prompt).

ssh() {
  # Resolve the effective hostname via ssh's own config parser.
  # Handles aliases, User@Host, -p port, etc. without manual parsing.
  local host
  host=$(command ssh -G "$@" 2>/dev/null | awk '/^hostname / {print $2; exit}')

  # If a password file exists for this host, prepend sshpass.
  local password_file="${HOME}/.ssh/passwords/${host}"
  if [[ -n "${host}" ]] && [[ -f "${password_file}" ]]; then
    sshpass -f "${password_file}" command ssh "$@"
    return
  fi

  command ssh "$@"
}
WRAPPER
  chmod 644 "${wrapper_file}"
  core::log INFO "Wrote ssh wrapper to ~/.ssh/ssh-wrapper.sh"

  core::ensure_block "${HOME}/.zshrc" "ssh-wrapper" \
    "source \"\${HOME}/.ssh/ssh-wrapper.sh\""
  core::summary "    ✓ ssh-wrapper.sh → ~/.ssh/ssh-wrapper.sh"
  core::summary "    ✓ config → ~/.zshrc (source ssh-wrapper.sh)"
}

install() {
  _ssh::install_packages
  _ssh::setup_dirs_and_config
  _ssh::generate_key
  _ssh::push_key_to_github
  _ssh::install_wrapper
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "ssh-wrapper"
  core::summary "    ✓ removed ssh-wrapper block from ~/.zshrc"

  rm -f "${HOME}/.ssh/ssh-wrapper.sh"
  core::summary "    ✓ removed ~/.ssh/ssh-wrapper.sh"

  # Intentionally NOT removed: ~/.ssh, keys, config, passwords (user data);
  # sshpass, gh (other tools may depend on them).
  core::summary "    — retained ~/.ssh, sshpass, gh (user data and shared tools)"
}
