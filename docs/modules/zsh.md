# Module: zsh

Zsh shell configuration — `zshenv`, sheldon plugin manager, platform-specific `zshrc`,
and starship prompt.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/zsh/sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` | all |
| `config/zsh/starship.toml` | `~/.config/starship.toml` | all |
| `config/zsh/zshenv` | `~/.zshenv` | all |
| `config/zsh/zshrc.mac` | `~/.zshrc` | mac |
| `config/zsh/zshrc.linux` | `~/.zshrc` | linux |

The last two entries are pushed into `LINKS` conditionally based on `${DOTFILES_OS}` at
module-load time, so only the matching one is active.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install sheldon starship` (macOS) or `zsh sheldon starship` (Linux) |
| `uninstall` | no-op |

## install()

Installs the shell and prompt toolchain. macOS ships with a system Zsh so it is not
re-installed; Linux needs it explicitly.

| Platform | Packages |
|---|---|
| macOS | `sheldon starship` |
| Linux | `zsh sheldon starship` |

Platform is detected via `${DOTFILES_OS}`.

## Config files

### `config/zsh/zshenv`

Portable, non-interactive environment variables. Loaded by Zsh on every invocation
(interactive or not, login or not).

- Sources `~/.cargo/env` if the file exists (guarded).
- Ends with `[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local` for machine-local
  overrides.

### `config/zsh/zshrc.mac`

macOS interactive shell configuration:

- Homebrew `shellenv` initialisation
- `sheldon source` for plugin loading
- `compinit`
- History key bindings
- `starship init zsh`
- fzf shell integration
- `ssh()` wrapper
- `[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local`

### `config/zsh/zshrc.linux`

Linux interactive shell configuration — same as the macOS version minus the Homebrew
`shellenv` block and the `ssh()` wrapper.

### `config/zsh/starship.toml`

Generated once from the upstream `catppuccin-powerline` preset and tracked in the repo.
To regenerate after an upstream change:

```bash
starship preset catppuccin-powerline -o config/zsh/starship.toml
```

## Local escape hatch

Machine-specific content that must never be committed goes in:

| File | Purpose |
|---|---|
| `~/.zshrc.local` | Interactive shell — aliases, PATH tweaks, secrets |
| `~/.zshenv.local` | Non-interactive env — exports needed in all contexts |

Both files are sourced at the end of their respective managed configs, so they can
override anything set above them.

## sheldon plugin ordering rules

Enforced in `config/zsh/sheldon/plugins.toml`:

- `zsh-completions` must be loaded with `apply = ["fpath"]` (before `compinit`) so
  `$fpath` is populated before the completion system initialises.
- `zsh-syntax-highlighting` must be loaded **last** — it wraps ZLE widget functions and
  must see all other plugins already registered.
