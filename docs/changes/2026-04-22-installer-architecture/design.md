# Installer Architecture — Module Interface Redesign

**Date:** 2026-04-22
**Status:** Approved

## Problem

The current module interface has two issues:

1. **`DEPS_MAC` / `DEPS_LINUX` arrays conflate "what this module installs" with
   "install mechanism".** There is no dedicated hook for installing the module's
   main subject — everything non-symlink ends up crammed into `post_install`.

2. **Execution order is semantically wrong.** The current order is:
   `DEPS install → pre_install → LINKS → post_install`
   `pre_install` fires *after* deps are already installed, so it cannot meaningfully
   prepare the environment or control how the main subject is installed.

3. **`core::pkg_install` only accepts a single package**, forcing callers to loop
   manually or call it once per package.

## Decision

Replace `DEPS_MAC` / `DEPS_LINUX` with two explicit hooks — `pre_install` and
`install` — and change the execution order so names match what each phase does.
Extend `core::pkg_install` to accept multiple packages in one call.

---

## Design

### New module interface

```bash
MODULE_NAME="<name>"
MODULE_DESC="<description>"
MODULE_PLATFORM="all"   # all | mac | linux

LINKS=(
  "config/<name>/file:${HOME}/.config/<name>/file"
)

pre_install()  { :; }   # install dependencies
install()      { :; }   # install the module's main subject
post_install() { :; }   # post-install configuration
```

`DEPS_MAC` and `DEPS_LINUX` are removed entirely from the interface.

### Execution order

```
pre_install → install → LINKS → post_install
```

| Phase | Responsibility |
|---|---|
| `pre_install()` | Install everything this module *depends on* — pkg manager where possible, special-case where not (e.g. `cargo install`) |
| `install()` | Install the module's main subject — simple calls go via `core::pkg_install`; complex installs (version checks, source builds, external scripts) go here as imperative logic |
| `LINKS` | Create dotfile symlinks (unchanged) |
| `post_install()` | Finalise — clone repos, run config generators, set global git config, etc. |

### Handling platform-specific package names

Platform differences move into `pre_install` / `install` using `detect::os`:

```bash
pre_install() {
  case "$(detect::os)" in
    mac)   core::pkg_install ripgrep fd lazygit node shfmt shellcheck ;;
    linux) core::pkg_install ripgrep fd-find lazygit nodejs npm shfmt shellcheck ;;
  esac
}
```

### `core::pkg_install` — multi-package support

`core::pkg_install` is extended to accept one or more package names, iterating
internally:

```bash
core::pkg_install() {
  local package
  for package in "$@"; do
    # existing per-package logic unchanged
  done
}
```

---

## Changes required

### `install.sh` — `install::run_module`

1. Module state reset: remove `unset DEPS_MAC DEPS_LINUX`; add `install() { :; }`
2. Remove the entire deps install loop (current lines 93-102)
3. Change execution order to: `pre_install → install → LINKS → post_install`

```bash
install::run_module() {
  # ... source module, platform guard, preflight check (unchanged) ...

  core::log INFO "▶ ${MODULE_NAME} — ${MODULE_DESC}"

  pre_install

  install

  local link_entry src target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    src="${link_entry%%:*}"
    target="${link_entry##*:}"
    core::symlink "${src}" "${target}"
  done

  post_install

  core::log INFO "✓ ${MODULE_NAME}"
}
```

### `lib/core.sh`

Extend `core::pkg_install` to loop over `"$@"` instead of taking a single `"${1}"`.

### `modules/*.sh` — all existing modules

| Module | `pre_install()` | `install()` | `post_install()` |
|---|---|---|---|
| `git.sh` | no-op | `core::pkg_install git` | `git config --global hooksPath` |
| `tmux.sh` | no-op | `core::pkg_install tmux` | clone oh-my-tmux + symlink |
| `zsh.sh` | no-op | `core::pkg_install zsh sheldon starship` (linux adds `zsh`) | starship preset + zshrc symlink |
| `ghostty.sh` | no-op | no-op | no-op |
| `nvim.sh` | pkg deps + tree-sitter-cli via cargo | neovim version check + pkg/source build | clone `~/.config/nvim` |
| `rust.sh` (new) | no-op | rustup installer script | source `~/.cargo/env` |

### `lib/preflight.sh`

No changes needed — preflight only reads `LINKS`, `MODULE_NAME`, `MODULE_PLATFORM`.

### `CLAUDE.md`

Update the module interface contract section to reflect the new hooks and remove
`DEPS_MAC` / `DEPS_LINUX`.

---

## What Does Not Change

- `LINKS` array format and processing
- `core::backup`, `core::symlink`, `core::log`
- `preflight.sh` entirely
- CLI flags (`--dry-run`, `--module`)
- DRY_RUN behaviour in all hooks
