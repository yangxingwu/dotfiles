# Module: zsh

Zsh shell configuration — sheldon plugin manager and starship prompt.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/zsh/sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` | all |

## Dependencies

| Platform | Packages |
|---|---|
| macOS | `sheldon`, `starship` |
| Linux | `zsh`, `sheldon`, `starship` |

## starship

`post_install` generates `~/.config/starship.toml` from the upstream
`catppuccin-powerline` preset:

```bash
starship preset catppuccin-powerline -o ~/.config/starship.toml
```

The preset is used unmodified, so there is no point tracking it in the repo.
Running `install.sh` again will regenerate the file (idempotent).

## Notes

`.zshrc` is **not** managed by this module — it is kept machine-local. The module only
links the plugin manager configuration and generates the prompt theme.

**sheldon plugin ordering rules** (enforced in `plugins.toml`):

- `zsh-completions` must be loaded with `apply = ["fpath"]` (before `compinit`) so
  `$fpath` is populated correctly.
- `zsh-syntax-highlighting` must be loaded last — it wraps ZLE widget functions and
  must see all other plugins already registered.

To activate sheldon and starship in `.zshrc`:

```zsh
eval "$(sheldon source)"
eval "$(starship init zsh)"
```

