# Module: fzf

[fzf](https://github.com/junegunn/fzf) fuzzy finder with fd/bat/eza integration
and catppuccin mocha theme.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install fzf`; clone catppuccin/fzf theme; write managed `fzf` block to `~/.zshrc` with fd source, bat/eza preview, catppuccin colors, layout defaults |
| `uninstall` | remove the `fzf` block from `~/.zshrc`; remove catppuccin theme clone (package is preserved) |

## Configuration

The managed block in `~/.zshrc` configures:

| Variable | Value | Purpose |
|---|---|---|
| `FZF_DEFAULT_COMMAND` | `fd --type f --hidden --follow --exclude .git` | Fast file search respecting .gitignore |
| `FZF_CTRL_T_COMMAND` | same as above | File picker source |
| `FZF_CTRL_T_OPTS` | bat preview + --select-1 --exit-0 | Syntax-highlighted file preview |
| `FZF_CTRL_R_COMMAND` | `""` (disabled) | Atuin handles history search |
| `FZF_ALT_C_COMMAND` | `fd --type d --hidden --follow --exclude .git` | Directory search |
| `FZF_ALT_C_OPTS` | eza tree preview | Directory tree preview |
| `FZF_DEFAULT_OPTS` | catppuccin colors + height/reverse/border/info | Theme + layout |

## Key bindings

- **Ctrl+T**: fuzzy file picker (with bat syntax-highlighted preview)
- **Ctrl+R**: handled by atuin (fzf Ctrl+R is disabled)
- **Alt+C**: fuzzy directory jump (with eza tree preview)

## Dependencies

- `cli-tools` module provides fd, bat, eza (must run before fzf)
- `atuin` module handles Ctrl+R history search (runs after fzf)
- Catppuccin theme cloned to `~/.local/share/fzf/catppuccin/`
- Update theme: `cd ~/.local/share/fzf/catppuccin && git pull`

## Notes

- The fzf package must be installed before the sheldon module runs because
  sheldon's `fzf-tab` plugin requires the `fzf` binary on PATH.
- `--preview` is NOT in FZF_DEFAULT_OPTS (fzf official recommendation: preview
  commands fail with non-file inputs like `ps -ef | fzf`).
- If catppuccin theme file is missing, fzf works normally with default colors.
- Ctrl+R is explicitly disabled via `FZF_CTRL_R_COMMAND=""` to avoid conflict
  with atuin's superior history search.
