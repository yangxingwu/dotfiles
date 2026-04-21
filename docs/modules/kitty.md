# Module: kitty

[kitty](https://sw.kovidgoyal.net/kitty/) terminal emulator configuration. macOS only.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/kitty/` | `~/.config/kitty/` | mac |

## Dependencies

| Platform | Packages |
|---|---|
| macOS | — (kitty is distributed as a standalone app) |
| Linux | — (not installed) |

## Notes

The entire `config/kitty/` directory is symlinked as a single unit so that theme files
under `config/kitty/themes/` are also available at `~/.config/kitty/themes/`.

Default settings in `config/kitty/kitty.conf`:

- **Font**: system monospace, size 13
- **Background opacity**: 0.95
- **Theme**: `catppuccin-mocha` via `include themes/catppuccin-mocha.conf`
- **Window padding**: 8 px on all sides

The Catppuccin Mocha color palette is stored in `config/kitty/themes/catppuccin-mocha.conf`
and checked into the repository — kitty does not bundle themes, so the file must be
present in the symlinked directory.
