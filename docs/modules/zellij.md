# Module: zellij

Zellij terminal multiplexer with [Catppuccin Mocha](https://github.com/catppuccin/zellij) theme (built-in).

## Module hooks

| Hook | Action |
|---|---|
| `install` | `cargo install zellij`; write `~/.config/zellij/config.kdl` with catppuccin-mocha theme |
| `uninstall` | remove `~/.config/zellij/` directory |

## Configuration

Minimal config — only overrides what we explicitly want:

| Option | Value | Purpose |
|--------|-------|---------|
| `theme` | `"catppuccin-mocha"` | Consistent with all other modules |
| `mouse_mode` | `true` | Click to focus, scroll, drag to resize |
| `copy_on_select` | `true` | Select = copy to system clipboard |
| `pane_frames` | `true` | Visual pane borders |
| `simplified_ui` | `false` | Show keybinding hints bar |

## Files

- `~/.config/zellij/config.kdl` — Zellij configuration

## Notes

- Catppuccin Mocha theme is built into Zellij (no external download needed).
- Zellij transparently forwards terminal bell to the outer terminal emulator
  (unlike tmux which intercepts it by default). This means Claude Code
  notifications work without any special configuration.
- Mouse selection is pane-aware: selecting text with the mouse stays within
  pane boundaries.
