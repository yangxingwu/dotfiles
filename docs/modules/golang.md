# Module: golang

[Go](https://go.dev/) programming language toolchain. Cross-platform.

## Module hooks

| Hook | Action |
|---|---|
| `install` | download and extract Go tarball from go.dev to `/usr/local/go`; write PATH block to `~/.zprofile` |
| `uninstall` | `sudo rm -rf /usr/local/go`; remove block from `~/.zprofile` |

## Notes

- Installed from official tarball (`https://go.dev/dl/`), not package managers.
  This ensures the latest version on all platforms.
- Version is auto-detected via `https://go.dev/VERSION?m=text`.
- Go binary lives at `/usr/local/go/bin/go`.
