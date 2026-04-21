# Module: zsh

Zsh shell configuration — sheldon plugin manager and starship prompt.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/zsh/sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` | all |
| `config/zsh/starship.toml` | `~/.config/starship.toml` | all |

## Dependencies

| Platform | Packages |
|---|---|
| macOS | `sheldon`, `starship` |
| Linux | `zsh`, `sheldon`, `starship` |

## Notes

`.zshrc` is **not** managed by this module — it is kept machine-local. The module only
links the plugin manager configuration and the prompt theme.

**sheldon plugin ordering rules** (enforced in `plugins.toml`):

- `zsh-completions` must be loaded synchronously (before `compinit`) so `$fpath` is
  populated correctly.
- `zsh-syntax-highlighting` must be loaded synchronously **and last** — it wraps ZLE
  widget functions and must see all other plugins already registered.
- `zsh-autosuggestions` is safe to defer with `apply = ["defer"]`.

To activate sheldon in `.zshrc`:

```zsh
eval "$(sheldon source)"
eval "$(starship init zsh)"
```
