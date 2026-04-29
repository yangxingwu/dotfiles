# Module: ghostty

[Ghostty](https://ghostty.org/) terminal emulator. macOS only.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install ghostty`; writes config to `~/.config/ghostty/config` |
| `uninstall` | removes `~/.config/ghostty/config` |

## Notes

Default settings:

- **Font**: Hack Nerd Font Mono, size 15
- **Theme**: Catppuccin Mocha
- **macOS Option key**: treated as Alt
