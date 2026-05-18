# 国内镜像源配置（--mirror-cn）

## 问题

在国内网络环境下，直接访问 Homebrew（GitHub）、crates.io、go.dev 等站点速度极慢
甚至超时，导致安装过程失败。需要一个机制让用户在国内时切换到镜像源。

## 触发方式

```bash
./install.sh --mirror-cn
```

解析后设置全局变量 `_CORE_MIRROR_CN=true`。bootstrap 脚本也支持：

```bash
./bootstrap-macos.sh --mirror-cn
```

## 各工具的镜像方案

### Homebrew

参考：https://mirrors.ustc.edu.cn/help/brew.git.html

**安装阶段**（bootstrap-macos.sh）：

Homebrew 官方安装脚本支持 `HOMEBREW_BREW_GIT_REMOTE` 等环境变量。在安装前 export
即可影响 Homebrew 自身的安装源。

```bash
if [[ "${MIRROR_CN:-}" == "true" ]]; then
  export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
  export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
fi
# 然后正常执行 Homebrew 安装脚本
```

**镜像源持久化**（homebrew 模块）：

将镜像环境变量写入 `~/.zprofile` 的 homebrew block 中，这样每次开 shell 都生效：

```bash
# ~/.zprofile homebrew block 内容（--mirror-cn 时）
eval "$(/opt/homebrew/bin/brew shellenv)"
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
```

### Rust

参考：https://rsproxy.cn/#getStarted

**安装阶段**（rust 模块）：

rustup 安装脚本从 `RUSTUP_DIST_SERVER` 和 `RUSTUP_UPDATE_ROOT` 读取下载地址。
在调用安装命令前 export：

```bash
if [[ "${_CORE_MIRROR_CN:-}" == "true" ]]; then
  export RUSTUP_DIST_SERVER="https://rsproxy.cn"
  export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
fi
# 然后正常执行 rustup 安装
```

**镜像源持久化**：

1. rustup 环境变量写入 `~/.zprofile` 的 rust block 中：

```bash
# ~/.zprofile rust block 内容（--mirror-cn 时）
. "${HOME}/.cargo/env"
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
```

2. cargo registry 写入 `~/.cargo/config.toml`：

```toml
[source.crates-io]
replace-with = 'rsproxy-sparse'

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[registries.rsproxy]
index = "https://rsproxy.cn/crate-index/"
```

注意：使用 `config.toml`（非 `config`），避免 cargo 的 deprecation warning。

### Golang

参考：https://goproxy.cn 、https://golang.google.cn

**安装阶段**（golang 模块）：

Go tarball 下载和版本查询的 URL 替换：

```bash
if [[ "${_CORE_MIRROR_CN:-}" == "true" ]]; then
  _GOLANG_BASE_URL="https://golang.google.cn"
else
  _GOLANG_BASE_URL="https://go.dev"
fi
# 版本查询：curl -fsSL "${_GOLANG_BASE_URL}/VERSION?m=text"
# 下载：    curl -fsSL "${_GOLANG_BASE_URL}/dl/${tarball}"
```

**镜像源持久化**：

```bash
if [[ "${_CORE_MIRROR_CN:-}" == "true" ]]; then
  go env -w GO111MODULE=on
  go env -w GOPROXY=https://goproxy.cn,direct
fi
```

`go env -w` 写入 `~/.config/go/env`，所有 go 命令自动读取，不需要写入 shell profile。

## 实现位置

不新增独立模块。改动分布在：

| 文件 | 改动 |
|------|------|
| `lib/core.sh` | `core::parse_args` 解析 `--mirror-cn`，设置 `_CORE_MIRROR_CN` |
| `bootstrap-macos.sh` | 解析 `--mirror-cn`，export Homebrew 镜像环境变量 |
| `modules/homebrew.sh` | `install()` 中根据 `_CORE_MIRROR_CN` 决定 block 内容 |
| `modules/rust.sh` | `install()` 中 export rustup 镜像 + 写 cargo config.toml |
| `modules/golang.sh` | `install()` 中替换下载 URL + 设置 GOPROXY |

## GitHub 访问

不处理。用户自行在运行脚本前设置代理：

```bash
export https_proxy=socks5://192.168.0.100:1080
export http_proxy=socks5://192.168.0.100:1080
./install.sh --mirror-cn
```

或通过 git config：

```bash
git config --global http.proxy socks5://192.168.0.100:1080
```

## uninstall 行为

不需要传 `--mirror-cn`。uninstall 无条件清理所有配置（包括镜像相关）：

- homebrew block 删除时镜像变量一起删
- rust block 删除时 rustup 镜像变量一起删
- `~/.cargo/config.toml` 由 rust uninstall 删除
- golang block 删除时 GOPROXY 一起删
- `go env -w GOPROXY` 由 golang uninstall 通过 `go env -u GOPROXY` 重置

## 不处理的内容

- GitHub 代理（用户自行解决）
- sheldon 的 socks5 兼容问题（libgit2 限制，与镜像无关）
- npm/pip 等其他包管理器的镜像（项目中未直接使用）
