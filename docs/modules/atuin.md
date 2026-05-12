# Module: atuin

Shell history replacement with SQLite storage and full-screen fuzzy search.
Replaces zsh-history-substring-search.

## Module hooks

| Hook | Action |
|---|---|
| `install` | install atuin via cargo; write config (sync disabled); add init to .zshrc |
| `uninstall` | remove .zshrc block; remove config file |

## Key bindings (provided by atuin init)

- **↑/↓ arrow**: full-screen history search
- **Ctrl+R**: full-screen history search

## Configuration

`~/.config/atuin/config.toml` — write-once, not overwritten on re-run.
Default: sync disabled (local history only).

## Notes

- Installed via cargo (same as sheldon). Requires rust module.
- Replaces `zsh-users/zsh-history-substring-search` (removed from sheldon module).
- fzf Ctrl+R binding is overridden by atuin (atuin loads later). fzf's Ctrl+T
  and Alt+C remain functional.
