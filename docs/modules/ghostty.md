# Module: ghostty

[Ghostty](https://ghostty.org/) terminal emulator configuration. macOS only.

## Module hooks

| Hook | Action |
|---|---|
| `install` | Writes config to `~/.config/ghostty/config` via heredoc |
| `uninstall` | Removes `~/.config/ghostty/config` |

## Notes

Ghostty reads its configuration from `~/.config/ghostty/config` on macOS.

Default settings:

- **Font**: Hack Nerd Font Mono, size 15
- **Theme**: Catppuccin Mocha (built into Ghostty's bundled themes)
- **macOS Option key**: treated as Alt (for terminal keybindings)
