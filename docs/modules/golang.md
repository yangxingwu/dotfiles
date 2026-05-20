# Module: golang

[Go](https://go.dev/) programming language toolchain. Cross-platform.

## Module hooks

| Hook | Action |
|---|---|
| `install` | download and extract Go tarball from go.dev to `/usr/local/go`; write PATH block to `~/.zprofile` |
| `uninstall` | remove block from `~/.zprofile`; reset GOPROXY/GO111MODULE env vars. Does NOT remove the Go binary |

## `--mirror-cn` flag

When `./install.sh --mirror-cn` is used, the golang module:
- Downloads the Go tarball from `golang.google.cn` instead of `go.dev`
- Configures `GOPROXY=https://goproxy.cn,direct` for faster module downloads in China

## Notes

- Installed from official tarball (`https://go.dev/dl/`), not package managers.
  This ensures the latest version on all platforms.
- Version is auto-detected via `https://go.dev/VERSION?m=text`.
- Go binary lives at `/usr/local/go/bin/go`.
