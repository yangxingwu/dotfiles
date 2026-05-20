# Node.js 模块设计

## 问题

Ubuntu 22.04 apt 源的 Node.js 版本是 12，太老了：
- neovim 的 npm provider 包（`neovim`）需要 node >= 18
- Claude Code agent skills 等日常开发工具也依赖现代 Node.js

macOS（brew `node`）和 Fedora（dnf `nodejs`）已经提供新版，但项目需要一个跨平台统一的策略。

## 决策

使用 **fnm**（Fast Node Manager）在所有平台管理 Node.js。

### 为什么选 fnm

| 方案 | 放弃原因 |
|------|---------|
| apt/dnf/brew 原生包 | Ubuntu 22.04 只有 Node 12（太老）；各发行版版本不一致 |
| NodeSource PPA | 仅解决 Ubuntu 问题；无版本管理能力 |
| nvm | shell 启动开销大（50-200ms）；bash 脚本实现，非二进制 |
| `n`（基于 npm） | 需要已有 Node.js + npm + sudo；裸机上鸡生蛋问题 |
| fnm | **选定** — 单个 Rust 二进制，shell init < 1ms，跨平台 |

### 工具之间的关系

```
fnm          → 安装/管理 Node.js 版本（类似 pyenv 之于 Python）
  └── Node.js  → JS 运行时
        └── npm  → 包管理器（随 Node.js 自带，不需要单独安装）
```

通过 fnm 安装的 Node.js 自带 npm，不需要 `apt install npm`。

## 模块接口

```bash
MODULE_NAME="nodejs"
MODULE_DESC="Node.js runtime via fnm (Fast Node Manager)"
MODULE_PLATFORM="all"
MODULE_DEPS=("rust")

install() {
  # 1. 安装 fnm 二进制（cargo install fnm）
  # 2. 通过 fnm 安装 Node.js LTS
  # 3. 写 shell init block（eval "$(fnm env)"）
}

**uninstall() 步骤**：

1. 移除 shell init block
2. `rm -rf "${HOME}/.local/share/fnm"`（fnm 安装的 Node 版本及全局包）
3. 不删除 fnm 二进制（与其他模块保持一致：uninstall 只清理配置和数据，不删二进制）
```

## 安装策略

### fnm 安装

- **所有平台**：`cargo install fnm`（rust module 是依赖，cargo 始终可用）。
  跨平台一致，无平台特定逻辑。

### Node.js 安装

```bash
fnm install --lts
fnm default lts-latest
```

安装最新 LTS 版本并设为默认。

### Shell 集成

通过 `core::ensure_block` 写入 shell init block：

```bash
# fnm (Node.js version manager)
eval "$(fnm env --use-on-cd)"
```

`--use-on-cd` 启用目录自动切换：进入含 `.node-version` 或 `.nvmrc` 的目录时自动切换版本。

### 幂等性

- 安装 fnm 前检查 `command -v fnm`
- Node.js 不做版本检查：每次直接 `fnm install --lts`（已有则秒完，新版则安装）
- shell block 使用 `core::ensure_block`（天然幂等）

## 对 nvim 模块的影响

1. nvim 的 `MODULE_DEPS` 添加 `"nodejs"`
2. 删除 `_nvim::install_deps` 中的 `core::pkg_install node`（macOS）和
   `core::pkg_install nodejs npm`（Linux）
3. 保留 `npm install -g neovim`（nvim 特有需求）
4. 删除 `sudo npm install -g neovim` 路径 — fnm 安装在用户空间，
   `npm install -g` 在所有平台都不需要 sudo

## 文件变更

```
modules/nodejs.sh    — 新增模块
modules/nvim.sh      — 修改（删除 nodejs 安装，添加依赖）
```

## 测试

CI 测试脚本验证：
- `node --version` 输出 >= 18
- `npm --version` 有输出
- `fnm --version` 可用
