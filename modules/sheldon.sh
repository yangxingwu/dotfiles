#!/usr/bin/env bash
# modules/sheldon.sh — sheldon zsh plugin manager with curated plugin set
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="sheldon"
MODULE_DESC="sheldon plugin manager with curated plugin set"
MODULE_PLATFORM="all"

_SHELDON_PLUGINS=(
  "zsh-users/zsh-autosuggestions"
  "zsh-users/zsh-syntax-highlighting"
  "zsh-users/zsh-completions"
  "Aloxaf/fzf-tab"
  "mattmc3/zsh-safe-rm"
  "zsh-users/zsh-history-substring-search"
)

# The zshrc block written by this module. Order is load-bearing:
# 1. sheldon source — populates fpath and loads plugins
# 2. compinit — consumes the expanded fpath
# 3. bindkey — requires history-substring-search plugin already loaded
_SHELDON_ZSHRC_BLOCK='eval "$(sheldon source)"
autoload -Uz compinit && compinit
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down'

install() {
  core::pkg_install sheldon

  local config="${HOME}/.config/sheldon/plugins.toml"
  if [[ ! -f "${config}" ]]; then
    sheldon init --shell zsh
  fi

  local plugin name
  for plugin in "${_SHELDON_PLUGINS[@]}"; do
    name="${plugin##*/}"
    sheldon add "${name}" --github "${plugin}" 2>/dev/null || true
  done

  _sheldon::patch_fpath_for_zsh_completions "${config}"

  core::ensure_block "${HOME}/.zshrc" "sheldon" "${_SHELDON_ZSHRC_BLOCK}"
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "sheldon"
}

# Patches zsh-completions in plugins.toml to use `apply = ["fpath"]`.
# Without this, zsh-completions triggers "insecure directories" warnings.
# Idempotent: no-op if the apply key is already present.
_sheldon::patch_fpath_for_zsh_completions() {
  local config="${1}"

  if grep -q 'apply = \["fpath"\]' "${config}" 2>/dev/null; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk '
    /^\[plugins\.zsh-completions\]/ {
      print
      print "apply = [\"fpath\"]"
      next
    }
    { print }
  ' "${config}" >"${tmp}"
  chmod 644 "${tmp}"
  mv "${tmp}" "${config}"
  core::log INFO "Patched zsh-completions to use fpath in ${config}"
}
