# Module: font-hack-nerd-font

[Hack Nerd Font](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/Hack)
— the Hack typeface patched with Nerd Font glyphs (Powerline, Devicons, Font Awesome,
etc.). macOS only.

## Symlinks

None — fonts are installed system-wide by Homebrew into `~/Library/Fonts/`.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install font-hack-nerd-font` (Homebrew cask) |
| `uninstall` | no-op — `brew uninstall` is left to the user to avoid removing a font other tools depend on |

## Notes

- The cask installs `.ttf` files into `~/Library/Fonts/` — no manual font-cache refresh
  is needed on macOS.
- Terminal emulators (Ghostty, iTerm2, etc.) must be configured separately to use the
  font. The Ghostty module's config already references `Hack Nerd Font`.
- Linux is not supported by this module. On Linux, Nerd Fonts can be installed manually
  or via distro packages (`fonts-hack-nerd` on some distros).
