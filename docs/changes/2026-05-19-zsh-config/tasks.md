# Shell 基础环境 + 别名 — 实施计划

基于 `docs/changes/2026-05-19-zsh-config/design.md`。

## 提交 1：文档

提交设计文档。

## 提交 2：新增 zsh-config 模块

### 任务 1：创建 `modules/zsh-config.sh`

按标准模块接口编写：
- `MODULE_NAME="zsh-config"`
- `MODULE_DESC="Shell environment, history, options, and aliases"`
- `MODULE_PLATFORM="all"`
- `MODULE_DEPS=("cli-tools")` — alias 依赖 eza/bat

`install()`：用 `core::ensure_block` 将内容写入 `~/.zshrc`（block id: `zsh-config`）。

`uninstall()`：用 `core::remove_block` 移除。

### 任务 2：在 `lib/modules.sh` 中添加模块

在 tmux 之后添加 `zsh-config`。

### 任务 3：添加测试断言

在 `tests/test_install.sh` 中：
- install 后检查 `~/.zshrc` 包含 `EDITOR="nvim"` 和 `setopt share_history`
- uninstall 后检查 block 被移除

### 任务 4：shellcheck 验证

## 提交 3：atuin 禁用向上箭头

修改 `modules/atuin.sh`，将 `atuin init zsh` 改为 `atuin init zsh --disable-up-arrow`。
