# nvim 模块幂等性修复 + headless 初始化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 修复 nvim 模块幂等性（二次安装不崩溃），新增 `core::backup` 通用备份函数，添加 headless 插件/treesitter 初始化。

**架构：** `core::backup` 放 lib/core.sh（带时间戳、通用复用）；nvim.sh 增加 remote 检查守卫 + pull 更新 + headless init 步骤。

**技术栈：** Bash、git、nvim --headless。

**提交策略：** design.md + tasks.md 一个 commit；代码改动另一个 commit。

---

### 任务 1: 新增 core::backup 函数

**文件：**
- 修改: `lib/core.sh`

- [ ] **步骤 1: 在 core::remove_block 函数之后添加 core::backup**

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

---

### 任务 2: 重写 _nvim::clone_config()

**文件：**
- 修改: `modules/nvim.sh:103-120`

- [ ] **步骤 1: 替换 _nvim::clone_config 函数**

将当前的：

```bash
_nvim::clone_config() {
  local repo="https://github.com/yangxingwu/neovim-lua-config.git"
  local branch="LazyVimV2"

  # Back up existing nvim dirs per LazyVim installation guide.
  # https://www.lazyvim.org/installation
  mv ~/.config/nvim{,.bak} 2>/dev/null || true
  mv ~/.local/share/nvim{,.bak} 2>/dev/null || true
  mv ~/.local/state/nvim{,.bak} 2>/dev/null || true
  mv ~/.cache/nvim{,.bak} 2>/dev/null || true

  core::run_cmd "Cloning neovim config" git clone --branch "${branch}" "${repo}" ~/.config/nvim
  core::summary "    ✓ config → ~/.config/nvim (cloned)"
}
```

改为：

```bash
# Clone or update the LazyVim config repo to ~/.config/nvim.
# Idempotent: if already cloned with correct remote, pulls latest.
# Otherwise backs up existing dirs (timestamped) and clones fresh.
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

### 任务 3: 新增 _nvim::headless_init()

**文件：**
- 修改: `modules/nvim.sh`

- [ ] **步骤 1: 在 _nvim::clone_config 之后添加 _nvim::headless_init 函数**

```bash
# Pre-install plugins and treesitter parsers in headless mode.
# This makes the first interactive nvim launch fast (no waiting for downloads).
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
  # LazyVim uses mason-lspconfig which triggers async installation during normal
  # nvim startup (in the config function via pkg:install()). There is no official
  # synchronous headless command in the Mason/LazyVim ecosystem.
  # Mason auto-installs missing servers on first real nvim launch (~10-20s background).
  # This is acceptable because:
  #   - lazyvim.json (committed to nvim config repo) declares which extras are
  #     enabled, so mason-lspconfig knows what to install on first launch
  #   - Lazy! sync already downloaded mason-lspconfig itself
  #   - The user gets a fully functional editor immediately (LSP installs in background)
  core::summary "    ✓ plugins and treesitter parsers installed (headless)"
}
```

- [ ] **步骤 2: 更新 install() 函数**

将当前的：

```bash
install() {
  _nvim::install_deps
  _nvim::install_nvim
  _nvim::clone_config
}
```

改为：

```bash
install() {
  _nvim::install_deps
  _nvim::install_nvim
  _nvim::clone_config
  _nvim::headless_init
}
```

---

### 任务 4: 更新测试

**文件：**
- 修改: `tests/test_install.sh`

- [ ] **步骤 1: 在 Phase 2 中添加 headless init 断言**

在现有的 `assert_dir_exists "${HOME}/.config/nvim/.git"` 行之后添加：

```bash
# nvim headless init
assert_dir_exists "${HOME}/.local/share/nvim/lazy"
```

---

### 任务 5: 更新文档

**文件：**
- 修改: `docs/modules/nvim.md`

- [ ] **步骤 1: 重写 docs/modules/nvim.md**

```markdown
# Module: nvim

[Neovim](https://github.com/neovim/neovim) editor with
[LazyVim](https://www.lazyvim.org) configuration
(yangxingwu/neovim-lua-config).

## Module hooks

| Hook | Action |
|---|---|
| `install` | install deps (node, shfmt, shellcheck, tree-sitter-cli); install nvim (brew or pkg/source); clone/update config repo; headless plugin sync + treesitter compile |
| `uninstall` | remove source-built nvim (if applicable); remove ~/.config/nvim |

## Install behavior

**First run:** backs up existing nvim directories (timestamped), clones config
repo, runs headless initialization.

**Subsequent runs (idempotent):** pulls latest config from repo, re-syncs
plugins and treesitter parsers. No backup triggered.

## Headless initialization

After cloning the config, the module runs:
1. `nvim --headless "+Lazy! sync" +qa` — downloads all plugins
2. `nvim --headless "+TSUpdate" +qa` — compiles treesitter parsers

Mason LSP servers are NOT installed in headless mode (LazyVim's mason-lspconfig
uses async installation with no official synchronous headless command). They
auto-install on first real nvim launch (~10-20s in background).

## Backup and restore

Backups are timestamped (e.g. `~/.config/nvim.bak.20260516-143022`) and logged
during install. Four directories form a set:

- `~/.config/nvim` — configuration (lua files)
- `~/.local/share/nvim` — plugin data (lazy.nvim downloads)
- `~/.local/state/nvim` — state (shada, undo history)
- `~/.cache/nvim` — cache (treesitter compiled parsers)

To restore:
\`\`\`bash
# Replace <TS> with timestamp shown in install log
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
mv ~/.config/nvim.bak.<TS> ~/.config/nvim
mv ~/.local/share/nvim.bak.<TS> ~/.local/share/nvim
mv ~/.local/state/nvim.bak.<TS> ~/.local/state/nvim
mv ~/.cache/nvim.bak.<TS> ~/.cache/nvim
\`\`\`

## Prerequisites

- `lazyvim.json` must be committed to the nvim config repo (not gitignored).
  It declares enabled LazyVim extras. Without it, only base plugins are synced.
  See: https://github.com/LazyVim/starter/blob/main/.gitignore

## Notes

- On Linux, offers interactive choice between package manager and source build.
  Non-interactive (CI) defaults to package manager.
- tree-sitter-cli remains in this module (nvim-specific dependency, not a
  general CLI tool).
- rg, fd provided by cli-tools module; lazygit provided by git module.
```

---

### 任务 6: 验证与提交

- [ ] **步骤 1: 运行 shellcheck**

运行: `shellcheck modules/nvim.sh lib/core.sh`
预期: 无错误。

- [ ] **步骤 2: 运行 shfmt**

运行: `shfmt -w modules/nvim.sh lib/core.sh`

- [ ] **步骤 3: 提交 design.md + tasks.md**

```bash
git add docs/changes/2026-05-16-nvim-idempotency/design.md \
        docs/changes/2026-05-16-nvim-idempotency/tasks.md
git commit -m "docs: add nvim idempotency + headless init design and plan

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

- [ ] **步骤 4: 提交代码改动**

```bash
git add lib/core.sh modules/nvim.sh tests/test_install.sh docs/modules/nvim.md
git commit -m "feat(nvim): fix idempotency + add headless plugin initialization

Fix clone_config to be idempotent:
- If config repo already cloned (correct remote) → git pull (update)
- Otherwise → timestamped backup via core::backup + fresh clone
- Backup never overwrites previous backups (timestamp-based)

Add headless initialization after clone:
- nvim --headless '+Lazy! sync' +qa (all plugins)
- nvim --headless '+TSUpdate' +qa (treesitter parsers)
- Mason LSP servers left to first interactive launch (LazyVim's
  mason-lspconfig has no synchronous headless install command)

New lib function: core::backup <path>
- Appends .bak.<YYYYMMDD-HHMMSS> timestamp
- No-op if path doesn't exist
- Logs backup location for user reference

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```
