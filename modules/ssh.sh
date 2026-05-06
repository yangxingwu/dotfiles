#!/usr/bin/env bash
# modules/ssh.sh — SSH client configuration and key management
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="ssh"
MODULE_DESC="SSH client configuration and key management"
MODULE_PLATFORM="all"

# Install sshpass and gh with platform-specific source setup.
_ssh::install_packages() {
  # sshpass: available in homebrew-core, apt, and dnf default repos.
  core::pkg_install sshpass

  # gh (GitHub CLI): platform-specific repository setup before install.
  case "${DOTFILES_PKG_MANAGER}" in
  apt)
    if [[ ! -f /etc/apt/sources.list.d/github-cli.list ]]; then
      sudo mkdir -p -m 755 /etc/apt/keyrings
      local tmp
      tmp="$(mktemp)"
      wget -nv -O "${tmp}" https://cli.github.com/packages/githubcli-archive-keyring.gpg
      cat "${tmp}" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
      rm -f "${tmp}"
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' \
        "$(dpkg --print-architecture)" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update >/dev/null 2>&1
      core::log INFO "Added GitHub CLI APT repository"
    fi
    ;;
  dnf)
    if [[ ! -f /etc/yum.repos.d/gh-cli.repo ]]; then
      sudo dnf install -y dnf5-plugins 2>/dev/null || true
      sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
      core::log INFO "Added GitHub CLI DNF repository"
    fi
    ;;
  esac
  core::pkg_install gh
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

install() {
  _ssh::install_packages
  _ssh::setup_dirs_and_config
  _ssh::generate_key
}

uninstall() {
  :
}
