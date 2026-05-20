# Module: starship

[Starship](https://starship.rs/) prompt, configured with the
`catppuccin-powerline` preset.

## Module hooks

| Hook | Action |
|---|---|
| `install` | install starship via `cargo install starship`; generate `~/.config/starship.toml` from preset; write managed `starship` block to `~/.zshrc` |
| `uninstall` | remove `~/.config/starship.toml`; remove `starship` block from `~/.zshrc` |

## Notes

- Installed via `cargo install starship` (the official curl installer assumes
  /usr/local/bin exists, which fails on Apple Silicon; cargo is already available
  from the rust module).
- `starship.toml` is regenerated from the preset on every install run.
- The managed `starship` block in `~/.zshrc` contains: `eval "$(starship init zsh)"`.
