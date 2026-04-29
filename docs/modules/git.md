# Module: git

Git global configuration via `git config --global`. Cross-platform.
git is already installed by bootstrap (CLT on macOS, dev_tools on Linux).

## Module hooks

| Hook | Action |
|---|---|
| `install` | sets `user.name`, `user.email` via `git config --global` |
| `uninstall` | removes `user.name`, `user.email` from `~/.gitconfig` |
