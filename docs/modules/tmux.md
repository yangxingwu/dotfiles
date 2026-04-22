# Module: tmux

tmux configuration using [oh-my-tmux](https://github.com/gpakosz/.tmux) as the base,
with a local override file for machine-specific settings.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/tmux/tmux.conf.local` | `~/.config/tmux/tmux.conf.local` | all |

`~/.config/tmux/tmux.conf` is **not** managed via `LINKS` — it is symlinked by
`post_install` to point at the oh-my-tmux clone.

## Module hooks

| Hook | Action |
|---|---|
| `pre_install` | no-op |
| `install` | `core::pkg_install tmux` (both platforms) |
| `post_install` | clones oh-my-tmux; symlinks `~/.config/tmux/tmux.conf` |

## oh-my-tmux

```
https://github.com/gpakosz/.tmux.git
```

`post_install` does the following:

1. Clones oh-my-tmux to `~/.local/share/tmux/oh-my-tmux/` if not already present.
2. Creates `~/.config/tmux/tmux.conf → ~/.local/share/tmux/oh-my-tmux/.tmux.conf` symlink.

Both steps are idempotent.

## Local overrides

`config/tmux/tmux.conf.local` is symlinked to `~/.config/tmux/tmux.conf.local`.
oh-my-tmux sources this file automatically, so all machine-specific tweaks go here
without touching the upstream config.
