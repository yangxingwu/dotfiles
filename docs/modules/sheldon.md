# Module: sheldon

[sheldon](https://github.com/rossmacarthur/sheldon) zsh plugin manager with a
curated plugin set.

## Module hooks

| Hook | Action |
|---|---|
| `install` | install sheldon via cargo; `sheldon init`; add plugins; `sheldon lock --update`; write managed `sheldon` block to `~/.zshrc` |
| `uninstall` | `sheldon remove` each plugin; `sheldon lock --update`; remove `sheldon` block from `~/.zshrc` |

## Plugins

| Plugin | Purpose |
|---|---|
| `zsh-users/zsh-autosuggestions` | fish-like command suggestions |
| `zsh-users/zsh-syntax-highlighting` | syntax coloring while typing |
| `zsh-users/zsh-completions` | additional completion definitions (apply = fpath) |
| `Aloxaf/fzf-tab` | fzf-powered tab completion |
| `mattmc3/zsh-safe-rm` | trash instead of real `rm` |
| `zsh-users/zsh-history-substring-search` | history substring navigation |

## Notes

- sheldon is not in apt/dnf — installed via `cargo install sheldon --locked`
  on all platforms for consistency.
- `zsh-completions` uses `--apply fpath` to avoid "insecure directories" warnings.
- The managed `sheldon` block in `~/.zshrc` contains: `eval "$(sheldon source)"`.
