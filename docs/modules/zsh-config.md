# Module: zsh-config

Shell environment foundation: environment variables, history configuration,
zsh options, and aliases for modern CLI tools.

Runs last in the module list so all target commands (eza, bat, nvim) are
already installed.

## Module hooks

| Hook | Action |
|---|---|
| `install` | Write managed block to ~/.zshrc with environment, history, options, aliases |
| `uninstall` | Remove managed block from ~/.zshrc |

## Configuration written

| Section | Content |
|---|---|
| Environment | EDITOR=nvim, VISUAL=nvim, PAGER=less -R, LANG/LC_ALL=en_US.UTF-8 |
| History | HISTSIZE=100000, SAVEHIST=100000, HISTFILE=~/.zsh_history |
| Options | share_history, hist_ignore_all_dups, hist_reduce_blanks, hist_verify, extended_history, auto_cd, interactive_comments |
| Aliases | ls/ll/la/lt → eza (with --icons --group-directories-first), cat → bat --paging=never |

## Aliases

All aliases are guarded with `command -v` — only defined if the target command
exists. This makes the module safe on partial installs.

| Alias | Expands to |
|---|---|
| `ls` | `eza --icons --group-directories-first` |
| `ll` | `eza -l --icons --git --group-directories-first` |
| `la` | `eza -la --icons --git --group-directories-first` |
| `lt` | `eza --tree --level=2 --icons` |
| `cat` | `bat --paging=never` |

## Notes

- If you need the original `cat` (e.g. for binary output), use `command cat`
  or `\cat`.
- History config is kept even though atuin manages search — zsh still writes
  ~/.zsh_history which serves as a fallback and is read by the up-arrow
  (atuin's up-arrow binding is disabled).
