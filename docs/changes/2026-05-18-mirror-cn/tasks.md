# 国内镜像源配置 — 实施计划

基于 `docs/changes/2026-05-18-mirror-cn/design.md`。

## 任务列表

### 1. `lib/core.sh`：解析 `--mirror-cn` 参数

在 `core::parse_args` 中添加 `--mirror-cn` 分支，设置 `_CORE_MIRROR_CN=true`。

### 2. `bootstrap-macos.sh`：解析 `--mirror-cn` 并 export Homebrew 镜像

解析参数，在 Homebrew 安装之前 export：
- `HOMEBREW_BREW_GIT_REMOTE`
- `HOMEBREW_CORE_GIT_REMOTE`
- `HOMEBREW_BOTTLE_DOMAIN`
- `HOMEBREW_API_DOMAIN`

### 3. `modules/homebrew.sh`：镜像环境变量持久化

`install()` 中根据 `_CORE_MIRROR_CN` 决定写入 `~/.zprofile` 的 homebrew block
是否包含镜像环境变量。

### 4. `modules/rust.sh`：rustup 镜像 + cargo config.toml

`install()` 中：
- export `RUSTUP_DIST_SERVER` 和 `RUSTUP_UPDATE_ROOT`（安装时生效）
- 写入 `~/.zprofile` rust block（持久化 rustup 镜像变量）
- 写入 `~/.cargo/config.toml`（cargo registry 镜像）

`uninstall()` 中：
- 删除 `~/.cargo/config.toml`

### 5. `modules/golang.sh`：下载 URL 替换 + GOPROXY

`install()` 中：
- 根据 `_CORE_MIRROR_CN` 选择 `go.dev` 或 `golang.google.cn` 作为下载源
- 执行 `go env -w GO111MODULE=on` 和 `go env -w GOPROXY=https://goproxy.cn,direct`

`uninstall()` 中：
- 执行 `go env -u GO111MODULE` 和 `go env -u GOPROXY`

### 6. shellcheck + shfmt 验证

### 7. 提交（文档和代码分开）
