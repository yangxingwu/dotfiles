# Remove LINKS/symlink mechanism, inline all configs

## Context

Only 3 of 10 modules use the LINKS symlink mechanism (ghostty, git, tmux). The config
files are small and simple enough to generate inline from `install()`. Removing LINKS
eliminates `core::symlink`, `core::backup`, the `config/` directory, and the LINKS
processing loops in both orchestrators.

## Decision

**Approach A: complete removal.** No `config()` hook — `install()` handles both package
installation and configuration.

## Module interface (after)

```bash
MODULE_NAME="<name>"
MODULE_DESC="<description>"
MODULE_PLATFORM="all"   # all | mac | linux

install()   { :; }
uninstall() { :; }
```

`LINKS` is removed from the interface contract entirely.

## Per-module changes

### ghostty.sh (mac only)

`install()` writes config inline:

```bash
install() {
  local config_dir="${HOME}/.config/ghostty"
  mkdir -p "${config_dir}"
  cat >"${config_dir}/config" <<'CONF'
theme = Catppuccin Mocha
font-family = "Hack Nerd Font Mono"
font-size = "15"
macos-option-as-alt = true
CONF
  core::log INFO "Wrote Ghostty config"
}
```

`uninstall()` removes `~/.config/ghostty/config`.

### git.sh (all platforms)

`install()` uses `git config --global` — the idiomatic tool for writing gitconfig:

```bash
install() {
  core::pkg_install git
  git config --global core.quotepath false
  git config --global user.name "yangxingwu"
  git config --global user.email "xingwu.yang@gmail.com"
  core::log INFO "Wrote git global config"
}
```

`uninstall()` stays as no-op. git config entries are not worth reversing.

The `core.hooksPath` setting and the empty `git-hooks/` directory are removed.

### tmux.sh (all platforms)

Remove `LINKS`. Remove the 4-line block that deletes oh-my-tmux's starter
`tmux.conf.local`. The starter file from oh-my-tmux's install script is kept as-is.

### All other modules

Remove the `LINKS=()` declaration line. No other changes.

### nvim.sh

`core::backup` is the only function called from outside core.sh (by nvim.sh). Move it
into `modules/nvim.sh` as `_nvim::backup`. The function body stays the same.

## core.sh changes

Delete:
- `core::symlink` (~55 lines) — no callers remain
- `core::backup` (~8 lines) — moved to nvim.sh

Remaining functions: `core::log`, `core::check_installed`, `core::pkg_install`,
`core::ensure_block`, `core::remove_block`.

## Orchestrator changes

### install.sh `install::run_module`

- Remove `unset LINKS` from the reset block
- Remove the LINKS iteration loop (lines 55-60)
- Update comments referencing LINKS

### uninstall.sh `uninstall::run_module`

- Remove `unset LINKS` from the reset block
- Remove the LINKS symlink-removal loop (lines 47-57)
- Update comments referencing LINKS

## Deleted files

- `config/` directory (all contents: ghostty/config, git/gitconfig, git/git-hooks/,
  tmux/tmux.conf.local)

## Documentation updates

- `CLAUDE.md`: remove LINKS from module interface contract, remove symlink-related
  idempotency notes, update execution order descriptions
- `docs/modules/*.md`: update symlink tables and hook descriptions for affected modules
- `.claude/rules/shell-style.md`: no changes needed (does not reference LINKS)
