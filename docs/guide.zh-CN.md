# dotfiles 用户指南

本指南面向已经运行过 `./install.sh` 的用户。你的开发环境已经配置完毕——本文档帮助你了解安装了什么、如何使用、以及配置文件在哪里。

---

## 目录

1. [Shell 环境](#1-shell-环境)
2. [模糊搜索与导航](#2-模糊搜索与导航)
3. [现代 CLI 工具](#3-现代-cli-工具)
4. [Git 与版本控制](#4-git-与版本控制)
5. [编程语言](#5-编程语言)
6. [终端与编辑器](#6-终端与编辑器)
7. [SSH](#7-ssh)
8. [主题](#8-主题)
9. [配置文件一览](#9-配置文件一览)
10. [日常使用](#10-日常使用)

---

## 1. Shell 环境

### zsh

**是什么**: zsh 是 macOS 的默认 shell，也是目前功能最丰富的交互式 shell。本项目以 zsh 为核心，所有模块的 shell 集成（init block、alias、函数）都写入 `~/.zshrc` 或 `~/.zprofile`。

**为什么选它**: macOS 默认 shell；插件生态成熟；补全系统强大；兼容 bash 大部分语法。

**配置文件位置**:

| 文件 | 用途 |
|---|---|
| `~/.zshrc` | 交互式 shell 配置（插件加载、别名、快捷键绑定） |
| `~/.zprofile` | 登录 shell 配置（PATH 环境变量） |

---

### Shell 环境与别名 (zsh-config)

`zsh-config` 模块配置基础 shell 环境，确保安装后开箱即用。它通过 managed block 向 `~/.zshrc` 写入环境变量、历史记录配置、zsh 选项和现代工具别名。

**环境变量**:

| 变量 | 值 | 用途 |
|---|---|---|
| `EDITOR` | `nvim` | 默认编辑器（git commit、crontab 等调用） |
| `VISUAL` | `nvim` | 可视编辑器 |
| `PAGER` | `less -R` | 分页器（-R 支持 ANSI 颜色） |
| `LANG` | `en_US.UTF-8` | 系统 locale |
| `LC_ALL` | `en_US.UTF-8` | 覆盖所有 locale 分类 |

**历史记录配置**:

| 设置 | 值 | 用途 |
|---|---|---|
| `HISTSIZE` | 100000 | 内存中保留的历史条目数 |
| `SAVEHIST` | 100000 | 写入文件的历史条目数 |
| `HISTFILE` | `~/.zsh_history` | 历史文件路径 |

历史选项：`share_history`（多终端共享）、`hist_ignore_all_dups`（自动去重）、`hist_reduce_blanks`（删除多余空格）、`hist_verify`（展开后确认再执行）、`extended_history`（记录时间戳）。

**别名**:

所有别名都有守卫检查——只在目标命令存在时才定义。部分安装（例如没装 cli-tools）时别名不会出现，不会报错。

| 别名 | 展开为 | 功能 |
|---|---|---|
| `ls` | `eza --icons --group-directories-first` | 彩色列表 + 图标 |
| `ll` | `eza -l --icons --git --group-directories-first` | 长格式 + Git 状态 |
| `la` | `eza -la --icons --git --group-directories-first` | 长格式含隐藏文件 |
| `lt` | `eza --tree --level=2 --icons` | 树形视图（2 层深度） |
| `cat` | `bat --paging=never` | 语法高亮文件查看 |

**提示**:

- 需要原始 `cat`（例如处理二进制文件）: `command cat` 或 `\cat`
- 需要原始 `ls`: `command ls` 或 `\ls`
- 虽然 atuin 接管了交互式历史搜索，`~/.zsh_history` 仍然正常写入，作为备份

**配置文件位置**:
- `~/.zshrc` 中的 `zsh-config` block

---

### sheldon (插件管理器)

**是什么**: [sheldon](https://github.com/rossmacarthur/sheldon) 是一个用 Rust 编写的 zsh 插件管理器，通过声明式 TOML 配置管理插件。

**为什么选它**: 启动速度快（Rust 实现）；配置简洁（单文件 TOML）；跨平台一致（通过 cargo 安装，不依赖系统包管理器）。

**已安装插件**:

| 插件 | 作用 |
|---|---|
| zsh-autosuggestions | 根据历史记录自动建议命令（灰色文字，按 → 接受） |
| zsh-syntax-highlighting | 输入时实时语法高亮（正确命令绿色，错误红色） |
| zsh-completions | 额外的补全定义（数百个命令的 tab 补全） |
| fzf-tab | 用 fzf 替代默认 tab 补全菜单（模糊搜索补全项） |
| zsh-safe-rm | `rm` 命令改为移至回收站，防止误删 |

**常用命令**:

```bash
# 查看当前插件列表
sheldon list

# 更新所有插件到最新版本
sheldon lock --update

# 插件配置文件
cat ~/.config/sheldon/plugins.toml
```

**配置文件位置**:
- `~/.config/sheldon/plugins.toml` — 插件声明
- `~/.local/share/sheldon/` — 插件下载缓存
- `~/.zshrc` 中的 `sheldon` block — `eval "$(sheldon source)"` + compinit

---

### atuin (历史搜索)

**是什么**: [atuin](https://github.com/atuinsh/atuin) 用 SQLite 数据库替代 zsh 的纯文本历史文件，提供全屏模糊搜索界面。

**为什么选它**: 搜索速度极快（SQLite 索引）；全屏 UI 比单行补全更直观；支持按目录、会话、时间过滤；可选同步（本项目默认关闭同步，纯本地使用）。

**常用操作**:

| 快捷键 | 动作 |
|---|---|
| `Ctrl+R` | 打开全屏历史搜索 |
| `↑` / `↓` | 全屏历史搜索 |

在搜索界面中：

```
# 输入关键词即可模糊匹配历史命令
# Tab 选择，Enter 执行
# Esc 退出
```

```bash
# 搜索包含 "docker" 的历史命令
atuin search docker

# 查看统计信息
atuin stats
```

**配置文件位置**:
- `~/.config/atuin/config.toml` — 配置（首次安装写入，后续不覆盖）
- `~/.local/share/atuin/` — SQLite 历史数据库

---

### starship (提示符)

**是什么**: [starship](https://starship.rs/) 是用 Rust 编写的跨 shell 提示符，显示当前目录、Git 分支状态、编程语言版本等上下文信息。

**为什么选它**: 极快的渲染速度（Rust 实现）；信息密度高（只在相关时显示模块）；Catppuccin Mocha 主题风格统一。

**使用的预设**: `catppuccin-powerline` — Catppuccin Mocha 配色 + Powerline 分隔符风格。

提示符会自动显示：
- 当前目录
- Git 分支 + 状态（modified/staged/untracked 等）
- 当前语言版本（进入含 `Cargo.toml` 的目录显示 Rust 版本，含 `go.mod` 显示 Go 版本，等等）
- 命令执行时间（超过 2 秒时显示）
- 上一条命令的退出状态

**配置文件位置**:
- `~/.config/starship.toml` — 完整配置（由 preset 生成，每次 install 重新写入）
- `~/.zshrc` 中的 `starship` block — `eval "$(starship init zsh)"`

---

## 2. 模糊搜索与导航

### fzf (模糊搜索)

**是什么**: [fzf](https://github.com/junegunn/fzf) 是一个通用的命令行模糊搜索工具。它能对任何文本列表进行交互式过滤，并与 shell 深度集成。

**为什么选它**: 业界标准的模糊搜索工具；与 fd/bat/eza/ripgrep 完美配合；快捷键绑定开箱即用。

**核心快捷键**:

| 快捷键 | 功能 | 预览 |
|---|---|---|
| `Ctrl+T` | 模糊搜索文件，选中后插入路径到命令行 | bat 语法高亮预览 |
| `Alt+C` | 模糊搜索目录，选中后直接 cd 进入 | eza 树形目录预览 |
| `Ctrl+G` | 交互式 ripgrep 内容搜索，Enter 在 nvim 中打开对应行 | bat 高亮预览匹配行 |

`Ctrl+R`（历史搜索）由 atuin 接管，fzf 不处理。

**使用示例**:

```bash
# Ctrl+T: 搜索文件
vim <Ctrl+T>
# 输入文件名片段，fzf 模糊匹配，选中后自动填入路径

# Alt+C: 跳转目录
<Alt+C>
# 输入目录名片段，选中后立即 cd 进入

# Ctrl+G: 搜索文件内容
<Ctrl+G>
# 输入搜索词，ripgrep 实时搜索所有文件内容
# Enter 选中后，在 nvim 中打开文件并跳到匹配行

# 管道模式: 对任意列表进行模糊过滤
ps aux | fzf
cat /etc/hosts | fzf
git log --oneline | fzf
```

**搜索源**: 所有文件搜索使用 fd（而非默认的 find），自动遵守 `.gitignore`，包含隐藏文件，排除 `.git` 目录。

**配置文件位置**:
- `~/.config/dotfiles/fzf.zsh` — fzf 完整配置（环境变量 + Ctrl+G 组件）
- `~/.local/share/fzf/catppuccin/` — Catppuccin Mocha 主题 (git clone)
- `~/.zshrc` 中的 `fzf` block — source fzf.zsh

---

### zoxide (智能目录跳转)

**是什么**: [zoxide](https://github.com/ajeetdsouza/zoxide) 是一个学习你访问频率的 `cd` 替代工具。它记录你去过的目录，之后只需输入目录名的片段就能跳转。

**为什么选它**: 比 `cd` 快得多（不需要输入完整路径）；比 autojump/z.sh 更快（Rust 实现）；数据库持久化，重启不丢失。

**常用命令**:

```bash
# z: 跳转到最匹配的目录
z dotfiles        # 跳转到包含 "dotfiles" 的最常访问目录
z proj rust       # 跳转到同时匹配 "proj" 和 "rust" 的目录

# zi: 交互式选择（使用 fzf 界面）
zi                # 列出所有记录的目录，fzf 模糊选择

# 正常的 cd 依然可用
cd /tmp           # 同时会被 zoxide 记录
```

**工作原理**: zoxide 维护一个数据库，记录每个目录的访问频率和最近访问时间。`z` 命令使用 "frecency"（频率 + 最近）算法排序候选项。使用越多，跳转越精准。

**配置文件位置**:
- `~/.local/share/zoxide/db.zo` — 目录数据库（自动维护，持久化）
- `~/.zshrc` 中的 `zoxide` block — `eval "$(zoxide init zsh)"`

---

## 3. 现代 CLI 工具

本项目用现代 Rust 工具替代传统 Unix 命令。这些工具更快、输出更美观、默认行为更合理。

### bat (cat 替代)

**是什么**: [bat](https://github.com/sharkdp/bat) 是带语法高亮和 Git 集成的 `cat` 替代品。

**为什么选它**: 自动语法高亮（支持数百种语言）；显示行号；标记 Git 修改行；内置 Catppuccin Mocha 主题。

**常用命令**:

```bash
# 查看文件（自动语法高亮 + 行号）
bat main.rs
bat config.toml

# 显示纯文本（无行号无装饰，用于管道）
bat --plain file.txt
bat -p file.txt

# 显示不可打印字符
bat --show-all file.txt

# 指定语言（当文件没有扩展名时）
bat --language json < api-response

# 对比两个文件的差异
bat --diff file1.txt file2.txt
```

**配置文件位置**:
- `~/.config/bat/config` — 设置默认主题为 `Catppuccin Mocha`

---

### eza (ls 替代)

**是什么**: [eza](https://github.com/eza-community/eza) 是现代化的 `ls` 替代品，支持 Git 状态显示、文件图标、树形视图。

**为什么选它**: 默认彩色输出；Git 状态一目了然（M/N/I 标记）；Nerd Font 图标；树形视图内置。

**常用命令**:

```bash
# 基本列表（彩色 + 图标）
eza

# 长格式（类似 ls -la）
eza -la

# 显示 Git 状态
eza -la --git

# 树形视图
eza --tree
eza --tree --level=2

# 按修改时间排序（最新的在前）
eza -la --sort=modified

# 只显示目录
eza -D
```

---

### ripgrep / rg (grep 替代)

**是什么**: [ripgrep](https://github.com/BurntSushi/ripgrep) 是极快的文件内容搜索工具，默认递归搜索、遵守 `.gitignore`。

**为什么选它**: 比 grep 快一个数量级；自动跳过 `.git`、`node_modules` 等目录；支持正则；输出带颜色和行号。

**常用命令**:

```bash
# 递归搜索当前目录下所有文件
rg "TODO"
rg "fn main"

# 指定文件类型
rg "import" --type rust
rg "SELECT" --type sql
rg "class" -t py

# 忽略大小写
rg -i "error"

# 只显示文件名
rg -l "TODO"

# 显示上下文（前后各 3 行）
rg -C 3 "panic"

# 正则搜索
rg "fn \w+\(" --type rust

# 搜索隐藏文件和被 gitignore 的文件
rg --hidden --no-ignore "SECRET"

# 替换（预览，不实际修改文件）
rg "old_name" --replace "new_name"
```

---

### fd (find 替代)

**是什么**: [fd](https://github.com/sharkdp/fd) 是更友好的 `find` 替代品，语法简单、速度快、默认遵守 `.gitignore`。

**为什么选它**: 语法直观（不需要 `-name`、`-type` 等繁琐选项）；自动彩色输出；尊重 `.gitignore`；作为 fzf 的搜索后端使用。

**常用命令**:

```bash
# 按名称搜索文件（模糊匹配）
fd main
fd "\.rs$"

# 指定类型
fd -t f "config"     # 只搜文件
fd -t d "src"        # 只搜目录

# 指定扩展名
fd -e py
fd -e rs -e toml

# 搜索隐藏文件
fd --hidden "\.env"

# 执行命令（类似 find -exec）
fd -e jpg -x convert {} {.}.png

# 排除目录
fd --exclude node_modules "index"
```

---

### jq (JSON 处理器)

**是什么**: [jq](https://github.com/jqlang/jq) 是命令行 JSON 处理器，类似于 JSON 的 `sed`/`awk`。

**为什么选它**: 处理 API 响应、配置文件的标准工具；表达式语言强大；管道友好。

**常用命令**:

```bash
# 格式化 JSON
echo '{"name":"test","value":42}' | jq '.'

# 提取字段
curl -s https://api.github.com/users/octocat | jq '.login, .id'

# 提取数组元素
echo '[1,2,3]' | jq '.[0]'

# 过滤数组
cat data.json | jq '.items[] | select(.status == "active")'

# 构造新对象
cat users.json | jq '.[] | {name: .login, url: .html_url}'

# 获取数组长度
cat list.json | jq '. | length'
```

---

### tldr (命令速查)

**是什么**: [tealdeer](https://github.com/dbrgn/tealdeer) 是 tldr-pages 的 Rust 客户端，为常用命令提供简洁的用法示例（比 man page 实用得多）。

**为什么选它**: 几秒内找到命令用法；Rust 实现启动快；离线可用（本地缓存）。

**常用命令**:

```bash
# 查看命令用法
tldr tar
tldr git-rebase
tldr docker-compose

# 更新本地缓存
tldr --update

# 列出所有可用页面
tldr --list
```

---

## 4. Git 与版本控制

### delta (diff pager)

**是什么**: [delta](https://github.com/dandavison/delta) 是 Git 的语法高亮 diff 查看器，替代默认的 less pager。

**为什么选它**: 语法高亮（diff 内容按语言着色）；行号显示；moved-code 检测（区分"代码移动"和"代码修改"）；与 Git 无缝集成（设置为 core.pager 后自动生效）。

安装后所有 git diff 输出自动使用 delta，无需额外操作：

```bash
# 以下命令自动使用 delta 渲染
git diff
git show
git log -p
git stash show -p
```

**配置**（写入 `~/.gitconfig`）:
- `core.pager = delta`
- `interactive.diffFilter = delta --color-only`
- `delta.navigate = true` — 按 `n`/`N` 跳转 diff hunk
- `delta.dark = true`

---

### lazygit (Git TUI)

**是什么**: [lazygit](https://github.com/jesseduffield/lazygit) 是终端中的 Git 图形界面，用键盘操作完成 stage、commit、push、rebase 等全部 Git 工作流。

**为什么选它**: 比纯命令行效率更高（批量 stage 文件、交互式 rebase、冲突解决）；Catppuccin Mocha 主题；Nerd Font 图标。

**启动**:

```bash
lazygit
```

注：`lazygit` 命令已配置为 alias，启动时自动加载 Catppuccin Mocha 主题。

**核心操作**:

| 面板 | 快捷键 | 动作 |
|---|---|---|
| Files | `空格` | stage/unstage 文件 |
| Files | `a` | stage all |
| Files | `c` | commit |
| Files | `p` | push |
| Files | `P` | pull |
| Commits | `s` | squash |
| Commits | `r` | reword |
| Branches | `n` | new branch |
| Branches | `空格` | checkout |
| 全局 | `?` | 查看所有快捷键 |
| 全局 | `q` | 退出 |

**配置文件位置**:
- `~/.config/lazygit/config.yml` — Nerd Font 图标设置
- `~/.local/share/lazygit/catppuccin/` — Catppuccin 主题仓库 (git clone)
- `~/.zshrc` 中的 `lazygit` block — alias（合并主题配置）

---

### SSH Commit Signing

**是什么**: 使用 SSH 密钥对 Git commit 和 tag 进行签名。GitHub 会在签名的 commit 旁显示 "Verified" 徽章。

**为什么用 SSH 而不是 GPG**: SSH 密钥已经存在（本项目自动生成）；配置更简单；GitHub 原生支持。

已自动配置：
- `commit.gpgsign = true` — 所有 commit 自动签名
- `tag.gpgsign = true` — 所有 tag 自动签名
- `gpg.format = ssh` — 使用 SSH 格式
- `user.signingkey = ~/.ssh/id_ed25519.pub` — 签名密钥

签名密钥在安装时自动上传到 GitHub（与认证密钥分开管理）。查看：

```bash
gh ssh-key list
# 输出中 type 为 "signing" 的就是签名密钥
```

---

### 全局 gitignore

位于 `~/.config/git/ignore`，自动忽略所有仓库中的 OS/编辑器临时文件：

- macOS: `.DS_Store`, `._*`, `.Spotlight-V100` 等
- Linux: `*~`, `.directory`
- Vim/Neovim: `*.swp`, `*.swo`, `Session.vim`, `tags`
- JetBrains: `.idea/`
- VS Code: `.vscode/`, `*.code-workspace`

---

### 工作流默认值

以下配置写入 `~/.gitconfig`，优化日常 Git 工作流：

| 配置项 | 值 | 效果 |
|---|---|---|
| `init.defaultBranch` | `main` | 新仓库默认分支名为 main |
| `pull.rebase` | `true` | `git pull` 使用 rebase 而非 merge（保持线性历史） |
| `rebase.autoStash` | `true` | rebase 前自动 stash 未提交更改，完成后 pop |
| `push.autoSetupRemote` | `true` | 首次 push 新分支时自动设置 upstream（不需要 `-u origin branch`） |
| `rerere.enabled` | `true` | 记住冲突解决方式，下次遇到相同冲突自动应用 |
| `merge.conflictstyle` | `zdiff3` | 冲突标记中显示 base 版本（更容易理解冲突） |
| `diff.algorithm` | `histogram` | 更可读的 diff 输出（比默认 myers 算法更准确） |
| `diff.colorMoved` | `default` | 用不同颜色区分"代码移动"和"代码修改" |
| `core.editor` | `nvim` | 默认编辑器为 Neovim |

---

## 5. 编程语言

### Rust

**是什么**: [Rust](https://www.rust-lang.org/) 系统编程语言工具链，通过 rustup 管理。

**为什么安装**: 本项目的多个工具（sheldon、atuin、bat、eza、ripgrep、fd、delta、tealdeer）都通过 `cargo install` 安装。Rust 工具链是整个环境的基础依赖。

**安装方式**: 通过 rustup 官方安装器（`https://sh.rustup.rs`）。

**常用命令**:

```bash
# 查看已安装的工具链
rustup show

# 更新 Rust 到最新稳定版
rustup update

# 查看已安装的 cargo 工具
cargo install --list

# 安装新的 Rust CLI 工具
cargo install <crate-name>

# 创建新项目
cargo new my-project
cargo init
```

**二进制位置**: `~/.cargo/bin/`（已加入 PATH）

**配置文件位置**:
- `~/.rustup/` — rustup 数据（工具链）
- `~/.cargo/` — cargo 数据（注册表缓存、已安装二进制）
- `~/.zprofile` 中的 `rust` block — `. "${HOME}/.cargo/env"`

---

### Go

**是什么**: [Go](https://go.dev/) 编程语言工具链，由 Google 开发，适合构建网络服务和 CLI 工具。

**为什么安装**: lazygit 通过 `go install` 安装；Go 也是后端开发的常用语言。

**安装方式**: 从 go.dev 下载官方 tarball，解压到 `/usr/local/go`。版本自动检测最新稳定版。

**常用命令**:

```bash
# 查看版本
go version

# 安装 Go 编写的工具
go install github.com/jesseduffield/lazygit@latest
go install golang.org/x/tools/gopls@latest

# 创建新模块
go mod init github.com/user/project

# 运行
go run main.go

# 构建
go build -o myapp .
```

**二进制位置**:
- Go 本身: `/usr/local/go/bin/go`
- `go install` 安装的工具: `~/go/bin/`

**配置文件位置**:
- `~/.zprofile` 中的 `golang` block — PATH 配置

---

### Python

**是什么**: Python 3 运行时 + pip 包管理器 + venv 虚拟环境 + pipx（隔离安装 CLI 工具）。

**为什么安装**: Python 是脚本编写、数据分析、Web 开发的基础语言。pipx 提供了安全安装全局 CLI 工具的方式（每个工具独立虚拟环境，不污染系统 Python）。

**常用命令**:

```bash
# pipx: 安装全局 CLI 工具（隔离环境，推荐方式）
pipx install httpie
pipx install ruff
pipx install black
pipx list           # 查看已安装工具
pipx upgrade-all    # 更新所有工具

# venv: 项目虚拟环境（项目依赖隔离）
python -m venv .venv
source .venv/bin/activate
pip install flask requests
deactivate

# pip: 包管理
pip install --user <package>   # 用户级安装（非项目）
pip list                       # 查看已安装包
```

**二进制位置**: `~/.local/bin/`（pipx 安装的工具 + pip --user 的二进制）

**配置文件位置**:
- `~/.zprofile` 中的 `python` block — `export PATH="${HOME}/.local/bin:${PATH}"`
- `~/.local/share/pipx/venvs/` — pipx 的隔离虚拟环境

---

## 6. 终端与编辑器

### Ghostty (终端模拟器, 仅 macOS)

**是什么**: [Ghostty](https://ghostty.org/) 是一个用 Zig 编写的现代终端模拟器，注重速度和正确性。

**为什么选它**: GPU 加速渲染；原生 macOS 体验；配置简洁；支持 Nerd Font。

**已配置**:
- 字体: Hack Nerd Font Mono, 大小 15
- 主题: Catppuccin Mocha
- macOS Option 键: 作为 Alt 使用（支持 Alt+C 等快捷键）

**配置文件位置**:
- `~/.config/ghostty/config`

---

### tmux (终端复用器)

**是什么**: [tmux](https://github.com/tmux/tmux) 让你在一个终端窗口中管理多个会话、窗口和面板。断开连接后会话保持运行。

**为什么选它**: SSH 远程工作必备；窗口分割；会话持久化；oh-my-tmux 提供开箱即用的美观配置。

**配置框架**: [oh-my-tmux](https://github.com/gpakosz/.tmux) — 美观的默认配置 + 易于自定义。

**常用操作**（前缀键默认 `Ctrl+b`）:

| 操作 | 快捷键 |
|---|---|
| 新建窗口 | `Ctrl+b c` |
| 切换窗口 | `Ctrl+b 0-9` |
| 水平分割 | `Ctrl+b "` |
| 垂直分割 | `Ctrl+b %` |
| 切换面板 | `Ctrl+b 方向键` |
| 断开会话 | `Ctrl+b d` |
| 查看所有会话 | `Ctrl+b s` |

```bash
# 新建命名会话
tmux new -s work

# 列出会话
tmux ls

# 重新连接
tmux attach -t work

# 终止会话
tmux kill-session -t work
```

**配置文件位置**:
- `~/.config/tmux/tmux.conf` — 指向 oh-my-tmux 的符号链接
- `~/.config/tmux/tmux.conf.local` — 个人覆盖配置（在此文件中自定义）
- `~/.local/share/tmux/oh-my-tmux/` — oh-my-tmux 仓库

---

### Neovim (编辑器)

**是什么**: [Neovim](https://neovim.io/) 是 Vim 的现代分支，使用 [LazyVim](https://www.lazyvim.org/) 发行版配置，提供 IDE 级别的编辑体验。

**为什么选它**: 启动极快；Lua 配置灵活；LSP 原生支持；LazyVim 开箱即用。

**LazyVim 配置**: 使用 `yangxingwu/neovim-lua-config` 仓库。首次启动后 Mason LSP 服务器会在后台自动安装（约 10-20 秒）。

**常用操作**:

```bash
# 打开文件
nvim file.rs

# 打开目录（文件树）
nvim .
```

LazyVim 核心快捷键（Leader 键 = 空格）:

| 快捷键 | 动作 |
|---|---|
| `空格 空格` | 搜索文件（fzf） |
| `空格 f f` | 查找文件 |
| `空格 f g` | 全局搜索文本 (grep) |
| `空格 e` | 文件资源管理器 |
| `空格 b d` | 关闭当前 buffer |
| `空格 l` | Lazy 插件管理器 |
| `g d` | 跳转到定义 |
| `g r` | 查找引用 |
| `K` | 显示悬浮文档 |
| `空格 c a` | 代码操作 |
| `空格 c f` | 格式化代码 |

**配置文件位置**:
- `~/.config/nvim/` — Lua 配置仓库
- `~/.local/share/nvim/` — 插件数据（lazy.nvim 下载）
- `~/.local/state/nvim/` — 状态（undo 历史）
- `~/.cache/nvim/` — 缓存（treesitter 编译产物）

---

## 7. SSH

### 密钥管理

安装时自动完成：
1. 生成 ed25519 密钥对（如果 `~/.ssh/id_ed25519` 不存在）
2. 将公钥上传到 GitHub（用于认证）
3. 将同一公钥作为签名密钥上传到 GitHub（用于 commit 签名）

密钥注释格式: `user@hostname-YYYYMMDD`，便于在多设备环境中识别。

### 连接复用 (ControlMaster)

已配置 SSH 连接复用，首次连接后后续连接复用同一 TCP 连接，大幅加快速度：

```
ControlMaster auto
ControlPath ~/.ssh/sockets/%r@%h-%p
ControlPersist 10m
```

效果：首次 SSH 连接后，10 分钟内对同一主机的后续连接（包括 git push/pull、scp）瞬间完成，无需重新认证。

### sshpass wrapper

`ssh` 命令已被 shell 函数包装。如果 `~/.ssh/passwords/<hostname>` 文件存在，会自动使用 sshpass 传递密码，实现免交互登录。

```bash
# 为主机设置密码登录
echo "my-password" > ~/.ssh/passwords/server1.example.com
chmod 600 ~/.ssh/passwords/server1.example.com

# 之后直接 ssh 即可，密码自动填入
ssh server1.example.com
```

无密码文件时，`ssh` 行为不变（使用密钥或交互式密码提示）。

### 配置文件位置

| 路径 | 用途 |
|---|---|
| `~/.ssh/id_ed25519` | 私钥 |
| `~/.ssh/id_ed25519.pub` | 公钥 |
| `~/.ssh/config` | SSH 客户端配置（顶部 Include 指向 defaults） |
| `~/.ssh/config.d/dotfiles-defaults` | 受管理的默认配置 |
| `~/.ssh/passwords/` | 主机密码文件目录 |
| `~/.ssh/sockets/` | 连接复用 socket 文件目录 |
| `~/.config/dotfiles/ssh-wrapper.sh` | ssh() wrapper 函数 |

---

## 8. 主题

所有工具统一使用 **Catppuccin Mocha** 配色方案（暖色调暗色主题），确保视觉一致性。

| 工具 | 主题应用方式 |
|---|---|
| bat | `~/.config/bat/config` 中 `--theme="Catppuccin Mocha"` |
| fzf | 加载 `~/.local/share/fzf/catppuccin/themes/catppuccin-fzf-mocha.sh` |
| lazygit | 启动时 `--use-config-file` 合并 `~/.local/share/lazygit/catppuccin/themes-mergable/mocha/blue.yml` |
| starship | `~/.config/starship.toml` 使用 `catppuccin-powerline` preset |
| ghostty | `~/.config/ghostty/config` 中 `theme = catppuccin-mocha` |

**更新主题**:

```bash
# 更新 fzf 主题
cd ~/.local/share/fzf/catppuccin && git pull

# 更新 lazygit 主题
cd ~/.local/share/lazygit/catppuccin && git pull

# starship 主题在每次 ./install.sh 运行时重新生成
```

---

## 9. 配置文件一览

### ~/.zshrc managed blocks

安装器通过 `core::ensure_block` 在 `~/.zshrc` 中插入受管理的代码块。每个 block 由注释标记分隔，可以安全地添加/删除/更新而不影响用户自己的配置。

| Block ID | 内容 |
|---|---|
| `sheldon` | `eval "$(sheldon source)"` + compinit |
| `fzf` | `source "${HOME}/.config/dotfiles/fzf.zsh"` |
| `zoxide` | `eval "$(zoxide init zsh)"` |
| `atuin` | atuin init zsh |
| `starship` | `eval "$(starship init zsh)"` |
| `lazygit` | lazygit alias（合并 catppuccin 主题） |
| `ssh` | `source "${HOME}/.config/dotfiles/ssh-wrapper.sh"` |
| `zsh-config` | 环境变量、历史记录、选项、别名 |

### ~/.zprofile managed blocks

| Block ID | 内容 |
|---|---|
| `homebrew` | Homebrew shellenv（仅 macOS） |
| `rust` | `. "${HOME}/.cargo/env"` |
| `golang` | Go PATH 配置 |
| `python` | `export PATH="${HOME}/.local/bin:${PATH}"` |

### ~/.config/ 文件

| 路径 | 模块 | 说明 |
|---|---|---|
| `~/.config/sheldon/plugins.toml` | sheldon | 插件声明 |
| `~/.config/atuin/config.toml` | atuin | atuin 配置（sync 关闭） |
| `~/.config/starship.toml` | starship | 提示符配置 |
| `~/.config/bat/config` | cli-tools | bat 主题配置 |
| `~/.config/ghostty/config` | ghostty | 终端配置（仅 macOS） |
| `~/.config/lazygit/config.yml` | git | lazygit 配置 |
| `~/.config/git/ignore` | git | 全局 gitignore |
| `~/.config/tmux/tmux.conf` | tmux | tmux 配置（符号链接） |
| `~/.config/tmux/tmux.conf.local` | tmux | tmux 个人覆盖 |
| `~/.config/nvim/` | nvim | Neovim 配置仓库 |
| `~/.config/dotfiles/fzf.zsh` | fzf | fzf 完整配置 |
| `~/.config/dotfiles/ssh-wrapper.sh` | ssh | ssh wrapper 函数 |

### ~/.gitconfig

由 git 模块写入，包含：identity、workflow defaults、delta integration、SSH signing、core.excludesFile。

### ~/.ssh/

| 路径 | 说明 |
|---|---|
| `~/.ssh/config` | SSH 客户端配置 |
| `~/.ssh/config.d/dotfiles-defaults` | 受管理的 Host * 默认值 |
| `~/.ssh/id_ed25519` | 私钥 |
| `~/.ssh/id_ed25519.pub` | 公钥 |
| `~/.ssh/passwords/` | sshpass 密码文件 |
| `~/.ssh/sockets/` | ControlMaster socket |

---

## 10. 日常使用

### 更新环境

```bash
# 拉取最新配置并重新安装
cd ~/path/to/dotfiles
git pull
./install.sh
```

`install.sh` 是幂等的——可以安全地反复运行。它会：
- 跳过已安装的工具
- 更新配置文件到最新状态
- 更新 git clone 的主题仓库
- 重新同步 sheldon 插件和 Neovim 插件

### 选择性安装/跳过

```bash
# 只安装指定模块
./install.sh --only git,ssh,rust

# 跳过指定模块
./install.sh --skip nvim,ghostty

# 查看所有可用模块
./install.sh --list
```

### 卸载

```bash
# 卸载所有模块的配置（二进制保留）
./uninstall.sh

# 只卸载特定模块
./uninstall.sh --only nvim,tmux

# 跳过特定模块的卸载
./uninstall.sh --skip ssh,git
```

注意：`uninstall.sh` 只清理配置文件和 clone 的仓库，不删除通过包管理器/cargo/go 安装的二进制。

### 模块顺序

模块按依赖关系排列，顺序固定：

```
homebrew → font-hack-nerd-font → ssh → rust → golang → git →
cli-tools → python → fzf → zoxide → sheldon → atuin →
starship → ghostty → nvim → tmux → zsh-config
```

`--only` 和 `--skip` 不改变执行顺序，只决定哪些模块参与运行。

### 常见问题

**Q: 更新后 shell 没有生效？**

```bash
# 重新加载 zsh 配置
exec zsh
```

**Q: 如何更新 cargo 安装的工具？**

```bash
# 更新单个工具
cargo install bat    # 重新编译到最新版

# 或者用 cargo-update (需要先安装)
cargo install cargo-update
cargo install-update -a
```

**Q: Neovim LSP 没有工作？**

首次打开 Neovim 时，Mason 会在后台自动安装 LSP 服务器（需要约 10-20 秒）。等待安装完成后重新打开文件即可。

```bash
# 在 nvim 中手动检查 Mason 状态
:Mason
```

**Q: fzf 的 Alt+C 在 macOS 默认终端不工作？**

macOS 默认终端不发送 Alt 键序列。使用 Ghostty（本项目已配置 Option-as-Alt）或 iTerm2（Preferences → Profiles → Keys → Option key → Esc+）。

**Q: 如何添加新的 SSH 密码文件？**

```bash
# 在 ~/.ssh/config 中配置用户名
echo -e "Host myserver\n    HostName 192.168.1.100\n    User admin" >> ~/.ssh/config

# 创建密码文件
echo "the-password" > ~/.ssh/passwords/192.168.1.100
chmod 600 ~/.ssh/passwords/192.168.1.100

# 直接连接（密码自动填入）
ssh myserver
```
