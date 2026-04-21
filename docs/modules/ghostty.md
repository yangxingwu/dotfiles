# Module: ghostty

[Ghostty](https://ghostty.org/) terminal emulator configuration. macOS only.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/ghostty/config` | `~/.config/ghostty/config` | mac |

## Dependencies

| Platform | Packages |
|---|---|
| macOS | — (Ghostty is distributed as a standalone app) |
| Linux | — (not installed) |

## Notes

Ghostty reads its configuration from `~/.config/ghostty/config` on macOS.

Default settings in `config/ghostty/config`:

- **Font**: system monospace, size 13
- **Theme**: `catppuccin-mocha` (built into Ghostty's bundled themes)
- **Window padding**: 8 px on all sides
- **Background opacity**: 0.95
