# zsh Module Enhancement

**Date:** 2026-04-22
**Status:** Approved

## Problem

The current `modules/zsh.sh` only symlinks `sheldon/plugins.toml` and generates the
starship config. `.zshrc` and `.zshenv` are not tracked in dotfiles at all, which means:

- Shell config is not reproducible across machines
- Changes are not version-controlled
- Machine-specific secrets and tools are mixed in with portable config

## Decision

Track both `.zshrc` and `.zshenv` in dotfiles via symlinks, using a `.local` escape
hatch for machine-specific content.

---

## Design

### Module interface

```bash
LINKS=(
  "config/zsh/zshenv:${HOME}/.zshenv"
)

pre_install()  # no-op
install()      # core::pkg_install sheldon starship (+ zsh on Linux)
post_install() # backup existing non-symlink files; symlink platform-specific zshrc
```

### File structure

```
config/zsh/
  zshrc.mac      ← macOS   → symlinked to ~/.zshrc on macOS
  zshrc.linux    ← Linux   → symlinked to ~/.zshrc on Linux
  zshenv         ← all     → symlinked to ~/.zshenv on all platforms
  sheldon/
    plugins.toml ← already tracked
```

### `install`: Platform-specific packages

```bash
install() {
  case "$(detect::os)" in
    mac)   core::pkg_install sheldon starship ;;
    linux) core::pkg_install zsh sheldon starship ;;
  esac
}
```

macOS ships with zsh and manages it via system updates; Linux needs it explicitly.

### `post_install`: Symlinks

`~/.zshenv` is handled via `LINKS` as usual. `~/.zshrc` is platform-specific and
handled in `post_install` using `detect::os`:

```bash
post_install() {
  # Back up existing non-symlink files before taking ownership
  [[ -f "${HOME}/.zshrc" && ! -L "${HOME}/.zshrc" ]] && core::backup "${HOME}/.zshrc"
  [[ -f "${HOME}/.zshenv" && ! -L "${HOME}/.zshenv" ]] && core::backup "${HOME}/.zshenv"

  # Symlink platform-specific zshrc
  case "$(detect::os)" in
    mac)   core::symlink "config/zsh/zshrc.mac"   "${HOME}/.zshrc" ;;
    linux) core::symlink "config/zsh/zshrc.linux" "${HOME}/.zshrc" ;;
  esac

  # Generate starship config from upstream preset
  # ...
}
```

### .local escape hatch

Both files source a machine-local override file at the end, if it exists:

**`config/zsh/zshrc.mac`** and **`config/zsh/zshrc.linux`** both end with:
```zsh
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
```

**`config/zsh/zshenv`** ends with:
```zsh
[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local
```

Machine-specific content (API keys, IDE-injected PATH entries, NVM, etc.) lives in
`~/.zshenv.local` / `~/.zshrc.local`. These files are never committed to git.

### Content split

**`config/zsh/zshenv`** — environment variables loaded by all shell types:

```zsh
# Cargo / Rust — guard prevents errors on machines where rustup is not yet installed
[[ -f "${HOME}/.cargo/env" ]] && . "${HOME}/.cargo/env"

# machine-local env (API keys, tool-specific vars, etc.)
[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local
```

All other tool-specific env lines belong in `~/.zshenv.local`.

**`config/zsh/zshrc.mac`** — macOS interactive shell config:

```zsh
# Homebrew (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"

# sheldon plugin manager
eval "$(sheldon source)"

# completion system (after sheldon)
autoload -Uz compinit && compinit

# history substring search key bindings (after sheldon)
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down

# Starship prompt
eval "$(starship init zsh)"

# fzf key bindings (Ctrl+R history search, Ctrl+T file search)
eval "$(fzf --zsh)"

# ssh wrapper — auto-fills password from ~/.ssh/passwords/<host> via sshpass
ssh() { ... }

# machine-local overrides (NVM, IDE tools, etc.)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
```

**`config/zsh/zshrc.linux`** — Linux interactive shell config (same as mac, without
brew shellenv and ssh wrapper):

```zsh
# sheldon plugin manager
eval "$(sheldon source)"

# completion system (after sheldon)
autoload -Uz compinit && compinit

# history substring search key bindings (after sheldon)
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down

# Starship prompt
eval "$(starship init zsh)"

# fzf key bindings (Ctrl+R history search, Ctrl+T file search)
eval "$(fzf --zsh)"

# machine-local overrides (NVM, IDE tools, etc.)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
```

Items **not** in either file (stay in `~/.zshrc.local`, managed by user):
- NVM initialisation
- CodeBuddy PATH

### rust module interaction

The `rust` module's `post_install` sources `~/.cargo/env` for the current install
session. The permanent PATH entry (`. ~/.cargo/env`) is already present in
`config/zsh/zshenv` — the rust module does not need to append anything to any file.

### Migration

`post_install` in `modules/zsh.sh` handles the one-time migration on existing machines:

1. If `~/.zshrc` is a regular file (not yet a symlink), back it up via `core::backup`
2. If `~/.zshenv` is a regular file (not yet a symlink), back it up via `core::backup`
3. `core::symlink` creates the new symlinks (standard idempotent behaviour)

The user then manually copies any machine-specific lines from the backup into
`~/.zshrc.local` / `~/.zshenv.local`.

---

## What Changes

### `modules/zsh.sh`

- Remove `DEPS_MAC` / `DEPS_LINUX`
- Add `install()`: `core::pkg_install sheldon starship` (+ `zsh` on Linux)
- Add `config/zsh/zshenv` to `LINKS`
- `post_install`: back up existing non-symlink `~/.zshrc` and `~/.zshenv`
- `post_install`: symlink platform-specific `zshrc.mac` or `zshrc.linux` to `~/.zshrc`

### `config/zsh/zshrc.mac` (new file)

macOS interactive shell config (see content split above).

### `config/zsh/zshrc.linux` (new file)

Linux interactive shell config — same as mac, without brew shellenv and ssh wrapper.

### `config/zsh/zshenv` (new file)

Portable environment variable config. Contains `. ~/.cargo/env`. Ends with
`[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local`.

## What Does Not Change

- `config/zsh/sheldon/plugins.toml` — already tracked, unchanged
- `post_install` starship generation — unchanged
