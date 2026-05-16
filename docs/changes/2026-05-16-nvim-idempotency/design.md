# nvim 模块幂等性修复 + headless 初始化设计

日期: 2026-05-16

## 概述

修复 nvim 模块的幂等性问题（二次安装崩溃/备份累积），并在 install 阶段
通过 headless 模式预装插件和 treesitter parsers，使首次启动 nvim 即可使用。

同时新增 `core::backup` 通用备份函数到 lib/core.sh，供所有模块复用。

## 问题

### 幂等性

`_nvim::clone_config()` 每次无条件执行 `mv ~/.config/nvim{,.bak}`：
- 第二次运行时把第一次 clone 好的配置移走，再重新 clone（浪费时间）
- 如果 `.bak` 已存在，`mv` 会把当前配置移进 `.bak` 覆盖原有备份

### 首次启动体验

clone 完 nvim 配置后，用户第一次打开 nvim 需要等待：
1. lazy.nvim 自身 bootstrap（git clone）
2. 所有插件下载（~100 个插件）
3. treesitter parsers 编译（~20 个 parser）
4. Mason LSP servers 安装（~10 个 server）

前三项耗时 1-3 分钟，阻塞用户使用。

## 变更范围

| 文件 | 动作 | 说明 |
|------|------|------|
| `lib/core.sh` | 新增 | `core::backup` 通用备份函数 |
| `modules/nvim.sh` | 修改 | 幂等性守卫 + headless 初始化 |
| `tests/test_install.sh` | 更新 | 验证幂等性 |
| `docs/modules/nvim.md` | 更新 | 文档同步（含恢复说明） |

---

## 设计

### 通用备份函数：`core::backup`

新增到 `lib/core.sh`：

```bash
# core::backup <path>
# Backs up a file or directory by appending a timestamp suffix.
# Creates: <path>.bak.<YYYYMMDD-HHMMSS>
# No-op if <path> does not exist.
# Logs the backup path so the user knows where to find it for restoration.
#
# Restore example:
#   rm -rf <path>
#   mv <path>.bak.<timestamp> <path>
core::backup() {
  local path="${1}"
  [[ -e "${path}" ]] || return 0

  local backup="${path}.bak.$(date +%Y%m%d-%H%M%S)"
  mv "${path}" "${backup}"
  core::log INFO "Backed up ${path} → ${backup}"
  core::summary "    ✓ backed up → ${backup}"
}
```

所有模块都可使用此函数。备份带时间戳，永不覆盖之前的备份。

---

### 幂等性修复：`_nvim::clone_config()`

逻辑：
1. 如果 `~/.config/nvim/.git` 存在且 remote 是正确的仓库 → **pull 更新**
2. 如果需要 clone → 用 `core::backup` 备份四个目录（带时间戳）

```bash
_nvim::clone_config() {
  local repo="https://github.com/yangxingwu/neovim-lua-config.git"
  local branch="LazyVimV2"
  local nvim_dir="${HOME}/.config/nvim"

  # Already cloned with correct remote — pull latest (idempotent).
  if [[ -d "${nvim_dir}/.git" ]]; then
    local current_remote
    current_remote="$(git -C "${nvim_dir}" remote get-url origin 2>/dev/null)"
    if [[ "${current_remote}" == "${repo}" ]]; then
      core::run_cmd "Updating neovim config" git -C "${nvim_dir}" pull --quiet
      core::summary "    ✓ config updated: ~/.config/nvim"
      return 0
    fi
  fi

  # Back up existing nvim directories (timestamped, never overwrites previous backups).
  # All four directories form a set — restore them together using the same timestamp.
  # To restore:
  #   rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
  #   mv ~/.config/nvim.bak.<timestamp> ~/.config/nvim
  #   mv ~/.local/share/nvim.bak.<timestamp> ~/.local/share/nvim
  #   mv ~/.local/state/nvim.bak.<timestamp> ~/.local/state/nvim
  #   mv ~/.cache/nvim.bak.<timestamp> ~/.cache/nvim
  core::backup "${HOME}/.config/nvim"
  core::backup "${HOME}/.local/share/nvim"
  core::backup "${HOME}/.local/state/nvim"
  core::backup "${HOME}/.cache/nvim"

  core::run_cmd "Cloning neovim config" git clone --branch "${branch}" "${repo}" "${nvim_dir}"
  core::summary "    ✓ config → ~/.config/nvim (cloned)"
}
```

---

### Headless 初始化：`_nvim::headless_init()`

在 clone 完成后，运行 headless nvim 预装插件和 treesitter parsers：

```bash
_nvim::headless_init() {
  # Install all plugins declared in lazy.nvim config (includes extras from lazyvim.json).
  # The "!" makes Lazy wait until sync completes before proceeding.
  # See: https://lazy.folke.io/usage
  #
  # IMPORTANT: lazyvim.json must be committed to the nvim config repo (not gitignored).
  # This file declares which LazyVim extras are enabled (lang.python, lang.go, etc.).
  # Without it, Lazy! sync only installs base plugins — extras and their associated
  # Mason LSP servers won't be configured. The LazyVim starter template does NOT
  # gitignore this file by default; committing it is the intended workflow.
  # See: https://github.com/LazyVim/starter/blob/main/.gitignore
  core::run_cmd "Installing nvim plugins (headless)" nvim --headless "+Lazy! sync" +qa

  # Compile treesitter parsers declared in ensure_installed.
  # See: https://github.com/nvim-treesitter/nvim-treesitter#commands
  core::run_cmd "Compiling treesitter parsers" nvim --headless "+TSUpdate" +qa

  # NOTE: Mason LSP servers are NOT installed here.
  # Mason's headless behavior is unreliable — MasonInstall requires the full
  # plugin event loop, and there's no synchronous "install all and exit" command.
  # Instead, mason-lspconfig auto-installs missing servers on first real nvim
  # startup (takes ~10-20s depending on how many servers are needed).
  # This is acceptable because:
  #   - lazyvim.json (committed to nvim config repo) declares which extras are
  #     enabled, so mason-lspconfig knows what to install on first launch
  #   - Lazy! sync already downloaded mason-lspconfig itself
  #   - The user gets a fully functional editor immediately (LSP installs in background)
  core::summary "    ✓ plugins and treesitter parsers installed (headless)"
}
```

---

### install() 变更

```bash
install() {
  _nvim::install_deps
  _nvim::install_nvim
  _nvim::clone_config
  _nvim::headless_init
}
```

---

### 幂等性考虑

- `_nvim::clone_config()` 二次运行 → pull 更新（不重新 clone，不触发备份）
- `_nvim::headless_init()` 二次运行 → `Lazy! sync` 检查已有插件并跳过未变更的；
  `TSUpdate` 只重编译有更新的 parser。两者天然幂等。
- `core::backup` 不会被触发（因为 clone_config 走了 pull 分支）

---

## 恢复说明

install 过程中的备份带有时间戳（如 `.bak.20260516-143022`），可在安装日志
或 `--summary` 输出中看到具体路径。

四个目录是一套，恢复时必须一起操作：

```bash
# 查看备份（找到时间戳）
ls ~/.config/nvim.bak.* ~/.local/share/nvim.bak.* 2>/dev/null

# 恢复（替换 <TS> 为实际时间戳，如 20260516-143022）
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
mv ~/.config/nvim.bak.<TS> ~/.config/nvim
mv ~/.local/share/nvim.bak.<TS> ~/.local/share/nvim
mv ~/.local/state/nvim.bak.<TS> ~/.local/state/nvim
mv ~/.cache/nvim.bak.<TS> ~/.cache/nvim
```

---

## 测试

### Phase 2 新增

```bash
# nvim headless init
assert_dir_exists "${HOME}/.local/share/nvim/lazy"
```

### 幂等性验证（Phase 1b — 二次安装）

现有 CI 未测幂等性。此模块修复后，后续的"CI 幂等性测试"任务可验证：
- 二次运行 install.sh → nvim 模块 pull 更新，不报错
- 备份不会被触发（因为走了 pull 分支）

---

## 前置条件

- **lazyvim.json 需要提交到 nvim 配置仓库**（由用户手动操作）。
  LazyVim starter template 默认不 gitignore 此文件，提交它是官方预期行为。
  该文件声明启用的 extras，使 `Lazy! sync` 能下载对应插件，mason-lspconfig
  在首次启动时知道需要安装哪些 LSP servers。

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| headless Lazy! sync 网络失败 | core::run_cmd 会捕获失败并打印日志；用户可 --verbose 排查 |
| TSUpdate 编译失败（缺编译器） | bootstrap 已装 build-essential/Xcode CLT |
| lazyvim.json 未提交到 nvim 配置仓库 | Lazy! sync 仍能装基础插件，只是 extras 缺失；首次启动仍可手动启用 |
| 新机器首次启动 Mason 安装慢 | 可接受（~10-20s 后台安装，不阻塞编辑） |
| 备份占磁盘空间 | 时间戳备份可手动清理；uninstall 不自动删备份（用户数据） |
