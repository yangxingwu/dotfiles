# Module: zsh

Zsh shell configuration — `zshenv`, sheldon plugin manager, platform-specific `zshrc`,
and starship prompt.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/zsh/sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` | all |
| `config/zsh/zshenv` | `~/.zshenv` | all |

## Execution order

```
pre_install → install → LINKS → post_install
```

---

## pre_install

If `~/.zshenv` is a regular file (not a symlink), `core::backup` is called on it before
the LINKS phase runs. This prevents `ln -sf` from silently overwriting any existing
machine-local env configuration.

---

## install

Installs the shell and prompt toolchain. macOS ships with a system Zsh so it is not
re-installed; Linux needs it explicitly.

| Platform | Packages |
|---|---|
| macOS | `sheldon starship` |
| Linux | `zsh sheldon starship` |

Platform is detected via `${DOTFILES_OS}`.

---

## post_install

1. **Back up existing `.zshrc`**: if `~/.zshrc` is a regular file (not a symlink),
   `core::backup` is called so the user can migrate machine-specific content to
   `~/.zshrc.local`.

2. **Symlink platform-specific zshrc**:
   - macOS → `config/zsh/zshrc.mac`
   - Linux → `config/zsh/zshrc.linux`

3. **Generate starship config** from the upstream preset (unmodified, not tracked):
   ```bash
   starship preset catppuccin-powerline -o ~/.config/starship.toml
   ```
   Running `install.sh` again regenerates the file (idempotent).

In `DRY_RUN=1` mode step 3 is logged and the hook returns early.

---

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

---

## Local escape hatch

Machine-specific content that must never be committed goes in:

| File | Purpose |
|---|---|
| `~/.zshrc.local` | Interactive shell — aliases, PATH tweaks, secrets |
| `~/.zshenv.local` | Non-interactive env — exports needed in all contexts |

Both files are sourced at the end of their respective managed configs, so they can
override anything set above them.

---

## sheldon plugin ordering rules

Enforced in `config/zsh/sheldon/plugins.toml`:

- `zsh-completions` must be loaded with `apply = ["fpath"]` (before `compinit`) so
  `$fpath` is populated before the completion system initialises.
- `zsh-syntax-highlighting` must be loaded **last** — it wraps ZLE widget functions and
  must see all other plugins already registered.
