# Module: tmux

tmux terminal multiplexer configuration with true-color support and a local override
mechanism for machine-specific settings.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` | all |
| `config/tmux/tmux.conf.local` | `~/.config/tmux/tmux.conf.local` | all |

## Dependencies

| Platform | Packages |
|---|---|
| macOS | `tmux` |
| Linux | `tmux` |

## Notes

`tmux.conf` sources `tmux.conf.local` at the end, so machine-specific overrides can be
added to `tmux.conf.local` without touching the shared config.

Key settings in `tmux.conf`:

- **Prefix**: `C-a` (instead of the default `C-b`)
- **Escape time**: `set -sg escape-time 10` — prevents the 500 ms Escape delay when
  running Neovim inside tmux
- **True color**: `set -g default-terminal "tmux-256color"` and
  `set -ga terminal-overrides ",xterm-256color:Tc"` — required for Catppuccin and other
  24-bit colorschemes to render correctly
- **Mouse**: enabled
- **Vi keys**: copy mode uses vi key bindings
- **Window indexing**: starts at 1 (not 0) for keyboard ergonomics
- **History**: 50 000 lines
