# dotfiles

> [English](README.md) | **中文**

面向 macOS 与 Linux 开发环境的全自动安装器。

## 概述

它不只是配置文件的归档——还会安装软件包、写入配置、管理 shell 初始化块。重复运行是安全的:安装器完全幂等。

## 平台支持

| 平台 | 支持程度 |
|---|---|
| macOS | 完整（所有模块，含 GUI 终端配置） |
| Linux | 精简（核心开发工具，适合服务器/SSH，无 GUI 终端） |

架构:`x86_64` 与 `arm64`——Apple Silicon 与 Intel Mac，以及 `x86_64`/`arm64` 的 Linux（Ubuntu/Debian 走 `apt`，Fedora/RHEL 走 `dnf`）。

## 快速开始

```bash
git clone https://github.com/yangxingwu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# 第 1 步:Bootstrap（一次性环境准备）
./bootstrap-macos.sh   # macOS
./bootstrap-linux.sh   # Linux（Ubuntu/Fedora）

# 第 2 步:安装模块
./install.sh
```

## Bootstrap

Bootstrap 脚本在全新机器上一次性准备好环境。它们是幂等的——可安全重复运行。

**macOS**（`./bootstrap-macos.sh`）:
- Xcode Command Line Tools
- Homebrew
- 现代 bash（>= 4.3）
- 确认 zsh 并设为登录 shell
- 开发工具（cmake、meson、ninja、gettext）
- shell 骨架文件（~/.zshrc、~/.zprofile、~/.zshenv）

**Linux**（`./bootstrap-linux.sh`）:
- zsh 并设为登录 shell
- 开发工具（git、curl、cmake、meson、ninja-build、build-essential 等）
- shell 骨架文件

Bootstrap 完成后，运行 `./install.sh` 安装模块。

## 模块

| 模块 | 平台 | 依赖 | 管理内容 |
|---|---|---|---|
| `homebrew` | macOS | — | Homebrew shell 环境（.zshrc 块） |
| `font-hack-nerd-font` | macOS | — | Hack Nerd Font（Homebrew cask） |
| `ssh` | all | — | SSH 客户端配置、密钥生成、sshpass 包装、GitHub 公钥 |
| `rust` | all | — | 经 rustup 安装的 Rust 工具链 |
| `golang` | all | — | 来自 go.dev 的 Go 工具链（含 sha256 校验） |
| `git` | all | ssh, rust, golang | Git 配置、delta、lazygit、SSH 签名、全局 gitignore |
| `cli-tools` | all | rust | 现代 CLI 工具:bat、eza、rg、fd、jq、tldr（catppuccin 主题） |
| `python` | all | — | Python 3、pip、venv、pipx、~/.local/bin 加入 PATH |
| `nodejs` | all | rust | 经 fnm（Fast Node Manager）安装的 Node.js |
| `fzf` | all | cli-tools | fzf 模糊查找，集成 fd/bat/eza（catppuccin 主题） |
| `zoxide` | all | — | zoxide 智能 cd |
| `sheldon` | all | rust | zsh 插件管理器 + 精选插件 |
| `atuin` | all | rust | Atuin shell 历史记录（模糊搜索） |
| `starship` | all | rust | Starship 提示符（catppuccin macchiato） |
| `ghostty` | macOS | — | Ghostty 终端模拟器 + 配置 |
| `nvim` | all | rust, golang, git, cli-tools, python, nodejs | Neovim + LazyVim 配置 |
| `zellij` | all | rust | Zellij 终端复用器（catppuccin） |
| `zsh-config` | all | cli-tools | shell 环境、历史、选项、eza/bat 别名 |

模块按上表顺序运行。平台受限的模块（仅 macOS）在 Linux 上会自动跳过。

## 模块顺序与依赖

[`lib/modules.sh`](lib/modules.sh) 里的安装顺序是唯一真源，且并非随意排列——靠后的模块建立在靠前模块所装工具之上。分层如下:

1. **基础层** —— `homebrew`（brew 必须最先进入 PATH）、字体、`ssh`。
2. **语言工具链** —— 先 `rust`，再 `golang`。`rust` 是大多数工具的基石:`cli-tools`、`sheldon`、`atuin`、`starship`、`zellij`、`nodejs` 里用的 `fnm`、以及 `nvim` 里的 `tree-sitter-cli` 都由 cargo 构建。
3. **核心工具** —— `git`（需要 ssh + rust + golang）、`cli-tools`、`python`、`nodejs`。
4. **Shell 体验** —— `fzf`、`zoxide`、`sheldon`、`atuin`、`starship`。
5. **编辑器 / 终端** —— `ghostty`、`nvim`（最重——依赖 rust、golang、git、cli-tools、python、nodejs）、`zellij`。
6. **Shell 收尾** —— `zsh-config`（其别名假设已有 `eza`/`bat`，其 `EDITOR` 假设已有 `nvim`，故放最后）。

上表「依赖」列列出的是**安装时会检查的硬依赖**（通过每个模块的 `MODULE_DEPS`）。如果所需模块尚未安装，依赖它的模块会被跳过并报错。这一点在使用 `--only` 时尤其重要:记得把依赖一并带上，例如

```bash
# fzf 需要 cli-tools，cli-tools 需要 rust —— 把整条链一起装
./install.sh --only rust,cli-tools,fzf
```

完整运行 `./install.sh` 总能满足依赖，因为它按正确顺序运行每一个模块。

## 用法

```bash
# 安装所有模块
./install.sh

# 仅安装指定模块
./install.sh --only ssh,git,rust

# 跳过指定模块
./install.sh --skip ghostty,font-hack-nerd-font

# 显示完整命令输出（包管理器、编译器等）
./install.sh --verbose

# 使用中国镜像（Homebrew USTC、Rust rsproxy.cn、Go goproxy.cn、npm npmmirror.com）
./bootstrap-macos.sh --mirror-cn
./install.sh --mirror-cn

# 完成后显示详细汇总
./install.sh --summary

# 组合使用
./install.sh --verbose --summary --only nvim

# 列出模块及平台、安装状态
./install.sh --list

# 卸载所有模块配置
./uninstall.sh

# 仅卸载指定模块
./uninstall.sh --only zellij,nvim
```

### Git 身份

Git 身份（`user.name` / `user.email`）优先从现有的 `git config --global` 读取。若未配置，安装器会交互式询问。对于无人值守安装（CI），请在运行前用 `git config --global` 预先配置。

### 中国镜像（`--mirror-cn`）

中国大陆用户可在 bootstrap 与 install 时都传 `--mirror-cn`:

```bash
./bootstrap-macos.sh --mirror-cn   # Homebrew 安装使用 USTC 镜像
./install.sh --mirror-cn           # cargo、Go、brew bottles 使用镜像
```

它会配置:
- **Homebrew**:USTC 镜像（`mirrors.ustc.edu.cn`）
- **Rust/cargo**:rsproxy.cn（安装脚本 + sparse registry）
- **Go**:`golang.google.cn`（tarball 下载）+ `goproxy.cn`（模块代理）
- **npm**:npmmirror.com（阿里/淘宝团队，每 10 分钟同步一次）

GitHub 访问不在处理范围内——若 GitHub 较慢，请在运行前设置 `https_proxy` 或 `git config --global http.proxy`。

### 输出行为

默认情况下，`install.sh` 显示简洁进度:

```
[INFO] ▶ [1/18] homebrew — Homebrew shell environment
[INFO] ✓ homebrew
[INFO] ▶ [6/18] git — Git configuration, delta, lazygit, SSH signing
[INFO] ✓ git (1s)
...
[INFO] Install complete: 18 modules (120s). Log: /tmp/dotfiles-install-20260513.log
```

- `--verbose` —— 显示包管理器、编译器、git clone 的完整输出
- `--summary` —— 完成后显示一个逐模块结果的详细方框
- 日志文件 —— 所有命令输出始终记录到 `/tmp/dotfiles-install-*.log`

## 幂等性

安装器是幂等的——重复运行始终安全。配置通过 **managed block**（托管块）管理，由 `# BEGIN dotfiles:<id>` / `# END dotfiles:<id>` 标记界定。这些块会被自动更新或移除，不影响周围内容。

## 更新

要拉取最新配置，更新仓库并重跑安装器即可:

```bash
cd ~/.dotfiles
git pull
./install.sh
```

重跑 `install.sh` 是幂等的，会把**所有受管配置**刷新为仓库当前的版本:

- 受管 shell 块（`# BEGIN/END dotfiles:*`）会被重写
- 配置文件（starship、bat、fzf、lazygit、ghostty、zellij、git、SSH 默认项……）会被覆盖
- 外部配置会拉取到最新:Neovim 配置仓库、catppuccin 主题、sheldon 插件

用 `--only` 可只刷新单个模块，例如 `./install.sh --only starship`。

**二进制不会自动升级。** 通过 cargo / go / rustup / 包管理器安装的工具会停留在已安装的版本（重跑会跳过已安装的工具）。需要升级时用它们各自的原生命令——例如 `rustup update`、`cargo install --force <工具>`、`brew upgrade`，或在 Neovim 里 `:Lazy update`。

## 故障排查

**`error: bash >= 4.3 required`** —— 系统 bash 太旧（macOS 自带 3.2）。先运行 `./bootstrap-macos.sh`，然后在当前终端执行 `eval "$(brew shellenv)"` 或直接新开一个终端，再运行 `./install.sh`。

**模块安装的工具在当前 shell 里找不到**（如 `cargo`、`go`、`nvim`）。`install.sh` 在子进程中运行，因此它对 PATH 的修改不会影响你启动它的那个 shell。新开一个终端，或执行 `source ~/.zshenv` 即可加载。

**macOS:bootstrap 后 `brew: command not found`** —— 当前 shell 还没加载 brew 环境。执行 `eval "$(/opt/homebrew/bin/brew shellenv)"`（Intel Mac 为 `/usr/local/bin/brew`）。`homebrew` 模块会把这条写入 `~/.zshrc`，之后的终端会自动加载。

**Linux:登录 shell 没有变成 zsh** —— 对于不在本地 `/etc/passwd` 的账户（LDAP/SSSD），`chsh` 可能失败。变通方法:在 SSH 客户端配置里加 `RemoteCommand /usr/bin/zsh -l`，或请管理员修改登录 shell。

**macOS:Xcode Command Line Tools 安装卡住或超时** —— 用 `xcode-select --install` 手动安装，等它装完，再重新运行 `./bootstrap-macos.sh`。

**`<module> requires: … — not installed`** —— 你用了 `--only` 却跳过了依赖。把依赖一起带上（见[模块顺序与依赖](#模块顺序与依赖)），或直接运行完整的 `./install.sh`。

**`git status` 很慢 / Starship 提示符偶尔超时** —— **不要**全局启用 `fsmonitor`;它会为每个仓库常驻一个守护进程。只在大型代码库里按仓库启用:`git -C /path/to/large-repo config core.fsmonitor true`。

**CI / 非交互:git 身份或 SSH 签名密钥被跳过** —— 身份询问和 GitHub 签名密钥上传都需要 TTY。请预先配置 `git config --global user.name` / `user.email`;签名密钥的推送在非交互环境下按设计会被跳过。

## 卸载后的手动清理

`./uninstall.sh` 会移除配置文件、托管块以及模块的副作用。以下内容**不会**被移除——如需清理请手动操作:

- Rust 工具链:`rustup self uninstall`
- SSH 密钥:`rm -rf ~/.ssh/`（谨慎:会销毁所有密钥）
- 已安装的软件包:通过你的包管理器卸载
- Go 工具链:`sudo rm -rf /usr/local/go`

## 文档

- [用户指南（English）](docs/guide.md) —— 同一份指南的英文版
- [用户指南（中文）](docs/guide.zh-CN.md) —— 安装后你得到了什么、每个工具怎么用
