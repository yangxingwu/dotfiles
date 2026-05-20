# Module: homebrew

Homebrew shell environment setup for macOS.

Homebrew itself is installed by `bootstrap-macos.sh`. This module only writes
the shell initialization block so that `brew` is available in login shells.

## What it does

Writes a managed block to `~/.zprofile` that runs `eval "$(brew shellenv)"`.
This adds Homebrew's bin/sbin directories to PATH and sets HOMEBREW_PREFIX,
HOMEBREW_CELLAR, HOMEBREW_REPOSITORY, MANPATH, and INFOPATH.

## Module hooks

| Hook | Action |
|---|---|
| `install` | Write shellenv block to ~/.zprofile |
| `uninstall` | Remove shellenv block from ~/.zprofile |

## Configuration

| File | Content |
|---|---|
| `~/.zprofile` block `homebrew` | `eval "$(brew shellenv)"` |

## Notes

- Platform: macOS only (automatically skipped on Linux).
- Must be the first module in install order — all subsequent modules that use
  `brew install` (via `core::pkg_install`) depend on brew being in PATH.
- Homebrew installation itself happens in `bootstrap-macos.sh`, not here.

## `--mirror-cn` flag

When `./install.sh --mirror-cn` is used, the homebrew module configures USTC
mirrors for faster access in China:
- `HOMEBREW_BREW_GIT_REMOTE` — points to USTC brew mirror
- `HOMEBREW_BOTTLE_DOMAIN` — points to USTC bottle mirror
- Additional API/core tap remote variables as needed
