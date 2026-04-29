# Module: tmux

tmux terminal multiplexer with [oh-my-tmux](https://github.com/gpakosz/.tmux).

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install tmux`; run oh-my-tmux official installer |
| `uninstall` | remove clone, unlink tmux.conf symlink, remove tmux.conf.local |

## Notes

The oh-my-tmux installer creates:
- `~/.local/share/tmux/oh-my-tmux` — the upstream clone
- `~/.config/tmux/tmux.conf` — symlink into the clone
- `~/.config/tmux/tmux.conf.local` — starter override file

Machine-specific tweaks go in `tmux.conf.local`. oh-my-tmux sources it automatically.
