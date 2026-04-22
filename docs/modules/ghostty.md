# Module: ghostty

[Ghostty](https://ghostty.org/) terminal emulator configuration. macOS only.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/ghostty/config` | `~/.config/ghostty/config` | mac |

## Module hooks

| Hook | Action |
|---|---|
| `pre_install` | no-op |
| `install` | no-op — Ghostty is distributed as a standalone app and is installed manually |
| `post_install` | no-op |

## Notes

Ghostty reads its configuration from `~/.config/ghostty/config` on macOS.

Default settings in `config/ghostty/config`:

- **Font**: system monospace, size 13
- **Theme**: `catppuccin-mocha` (built into Ghostty's bundled themes)
- **Window padding**: 8 px on all sides
- **Background opacity**: 0.95
