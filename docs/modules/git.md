# Module: git

Git global configuration via `git config --global`. Cross-platform.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install git`; sets `core.quotepath`, `user.name`, `user.email` |
| `uninstall` | no-op |

## Notes

Config is written via `git config --global` — the idiomatic way to manage
`~/.gitconfig`. The installer sets:

- `core.quotepath = false` — show non-ASCII filenames as-is
- `user.name` / `user.email` — commit identity
