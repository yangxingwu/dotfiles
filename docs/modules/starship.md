# Module: starship

[Starship](https://starship.rs/) prompt, configured with the
`catppuccin-powerline` preset.

## Module hooks

| Hook | Action |
|---|---|
| `install` | install starship via official curl installer; generate `~/.config/starship.toml` from preset; write managed `starship` block to `~/.zshrc` |
| `uninstall` | remove `~/.config/starship.toml`; remove `starship` block from `~/.zshrc` |

## Notes

- Installed via `curl -sS https://starship.rs/install.sh | sh` (official installer,
  works on both macOS and Linux).
- `starship.toml` is regenerated from the preset on every install run.
- The managed `starship` block in `~/.zshrc` contains: `eval "$(starship init zsh)"`.
