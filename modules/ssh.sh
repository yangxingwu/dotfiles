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
      # shellcheck disable=SC2016
      core::run_cmd "Adding GitHub CLI APT repository" bash -c '
        (type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) &&
        sudo mkdir -p -m 755 /etc/apt/keyrings &&
        out=$(mktemp) && wget -nv -O"${out}" https://cli.github.com/packages/githubcli-archive-keyring.gpg &&
        cat "${out}" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null &&
        rm -f "${out}" &&
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
        sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
        sudo apt update
      '
    fi
    ;;
  dnf)
    if [[ ! -f /etc/yum.repos.d/gh-cli.repo ]]; then
      # Try dnf5 first (Fedora 41+), fall back to dnf4 (Fedora 40 and below).
      if dnf5 --version >/dev/null 2>&1; then
        # https://github.com/cli/cli/blob/trunk/docs/install_linux.md#dnf5
        core::run_cmd "Adding GitHub CLI DNF repository" bash -c 'sudo dnf install -y dnf5-plugins && sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo'
      else
        # https://github.com/cli/cli/blob/trunk/docs/install_linux.md#dnf4
        core::run_cmd "Adding GitHub CLI DNF repository" bash -c "sudo dnf install -y 'dnf-command(config-manager)' && sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo"
      fi
    fi
    # gh-cli repo requires explicit --repo flag per official docs.
    core::run_cmd "Installing gh" sudo dnf install -y gh --repo gh-cli
    core::log INFO "Installed gh via dnf (--repo gh-cli)"
    core::summary "    ✓ gh installed via dnf"
    ;;
  esac
  # On brew/apt, core::pkg_install handles gh normally.
  if [[ "${DOTFILES_PKG_MANAGER}" != "dnf" ]]; then
    core::run_cmd "Installing gh" core::pkg_install gh
  fi
}

# Create ~/.ssh directory structure and write managed defaults via Include.
_ssh::setup_dirs_and_config() {
  local ssh_dir="${HOME}/.ssh"
  local ssh_config_dir="${ssh_dir}/config.d"
  local defaults_file="${ssh_config_dir}/dotfiles-defaults"

  mkdir -p "${ssh_dir}" "${ssh_dir}/passwords" "${ssh_dir}/sockets" "${ssh_config_dir}"
  chmod 700 "${ssh_dir}" "${ssh_dir}/passwords" "${ssh_dir}/sockets" "${ssh_config_dir}"
  core::log INFO "Ensured directory structure: ~/.ssh, ~/.ssh/{passwords,sockets,config.d} (mode 700)"
  core::summary "    ✓ directories: ~/.ssh, ~/.ssh/{passwords,sockets,config.d} (mode 700)"

  # Create config file if absent (user may already have one).
  if [[ ! -f "${ssh_dir}/config" ]]; then
    touch "${ssh_dir}/config"
    chmod 600 "${ssh_dir}/config"
  fi

  # Write fully-managed defaults file (overwritten each run).
  cat >"${defaults_file}" <<'SSH_DEFAULTS'
# Managed by dotfiles — do not edit manually.
# Override any value by setting it in ~/.ssh/config above the Include line.
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 10m
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
SSH_DEFAULTS
  chmod 600 "${defaults_file}"
  core::log INFO "Wrote managed defaults to ~/.ssh/config.d/dotfiles-defaults"

  # Insert Include directive at the TOP of ~/.ssh/config. OpenSSH uses
  # first-match-wins: an Include at the bottom would be shadowed by any
  # Host block above it that already set the same keys. Placing it at
  # the top means the defaults file acts as a fallback for all hosts.
  core::ensure_block "${ssh_dir}/config" "ssh" \
    "Include config.d/dotfiles-defaults" "prepend"
  core::summary "    ✓ ~/.ssh/config.d/dotfiles-defaults (managed Host * defaults)"
  core::summary "    ✓ ~/.ssh/config Include directive (top of file)"
}

# Generate ed25519 key pair if not already present.
_ssh::generate_key() {
  local key_file="${HOME}/.ssh/id_ed25519"

  if [[ -f "${key_file}" ]]; then
    core::log INFO "SSH key already exists: ${key_file}"
    core::summary "    ✓ key already exists: ~/.ssh/id_ed25519"
  else
    # Comment includes user@hostname-date for easy identification when
    # multiple keys are registered on GitHub/GitLab (one per device).
    local comment
    comment="$(whoami)@$(uname -n)-$(date +%Y%m%d)"
    core::run_cmd "Generating SSH key" ssh-keygen -t ed25519 -C "${comment}" -f "${key_file}" -N "" -a 64
    core::log INFO "Generated SSH key: ${key_file}"
    core::summary "    ✓ generated key: ~/.ssh/id_ed25519 (${comment})"
  fi
}

# Push public key to GitHub via gh CLI. Authenticates interactively if needed.
# Skipped entirely in non-interactive environments (CI) where no one can
# complete the browser auth flow.
_ssh::push_key_to_github() {
  local pub_key="${HOME}/.ssh/id_ed25519.pub"
  local key_title
  key_title="$(awk '{print $3}' "${pub_key}")"

  # Ensure gh is authenticated — run interactive login if not.
  if ! gh auth status >/dev/null 2>&1; then
    # Non-interactive (no TTY on stdin) — skip rather than hang waiting for auth.
    if [[ ! -t 0 ]]; then
      core::log INFO "gh not authenticated and no TTY — skipping GitHub key push"
      core::summary "    — skipped GitHub key push (non-interactive)"
      return 0
    fi
    core::log INFO "gh not authenticated — starting interactive login"
    if ! gh auth login; then
      core::log WARN "GitHub authentication failed — skipping key push"
      core::summary "    — skipped GitHub key push (auth failed)"
      return 0
    fi
  fi

  # Check if this key is already registered on GitHub.
  # Compare the base64 key body — gh ssh-key list's table output truncates keys,
  # so use --json to get full content.
  local key_body
  key_body="$(awk '{print $2}' "${pub_key}")"
  if gh ssh-key list --json key --jq '.[].key' 2>/dev/null | grep -qF "${key_body}"; then
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

  core::ensure_block "${HOME}/.zshrc" "ssh" \
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
  # ssh-wrapper: remove file first, then the zshrc source line that references it.
  rm -f "${HOME}/.ssh/ssh-wrapper.sh"
  core::log INFO "Removed ~/.ssh/ssh-wrapper.sh"
  core::summary "    ✓ removed ~/.ssh/ssh-wrapper.sh"

  core::remove_block "${HOME}/.zshrc" "ssh"
  core::summary "    ✓ removed ssh block from ~/.zshrc"

  # ssh config defaults: remove managed file first, then the Include directive.
  rm -f "${HOME}/.ssh/config.d/dotfiles-defaults"
  core::log INFO "Removed ~/.ssh/config.d/dotfiles-defaults"
  core::summary "    ✓ removed ~/.ssh/config.d/dotfiles-defaults"

  core::remove_block "${HOME}/.ssh/config" "ssh"
  core::summary "    ✓ removed ssh block from ~/.ssh/config"

  # Intentionally NOT removed:
  #   ~/.ssh, keys, config, passwords — user data that may predate this module
  #   sshpass, gh — packages are not removed per the module uninstall contract
  core::log INFO "Retained ~/.ssh (keys, config, passwords) and packages (sshpass, gh)"
  core::summary "    — retained ~/.ssh (keys, config, passwords) and packages (sshpass, gh)"
}
