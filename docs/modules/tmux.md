# Module: tmux

tmux configuration using [oh-my-tmux](https://github.com/gpakosz/.tmux) as the base.
The upstream project is installed via its official `install.sh` one-liner.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install tmux`; run oh-my-tmux's upstream installer |
| `uninstall` | remove `~/.config/tmux/.tmux/` clone and `~/.config/tmux/tmux.conf` symlink |

## Notes

The oh-my-tmux installer creates:
- `~/.config/tmux/.tmux/` — the upstream clone
- `~/.config/tmux/tmux.conf` — symlink into the clone
- `~/.config/tmux/tmux.conf.local` — starter override file (kept as-is)

Machine-specific tweaks go in `tmux.conf.local`. oh-my-tmux sources it automatically.
