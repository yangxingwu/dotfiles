# 设计：用 Zellij 替换 tmux

## 动机

tmux 模块使用率极低，主要有三个痛点：

1. **Bell 通知被拦截** — tmux 默认截获终端 bell，导致 Claude Code 完成任务后的通知无法到达 Ghostty。
2. **跨 pane 复制混乱** — 鼠标选择会跨越 pane 边界，需要借助 tmux copy mode 或 Shift+点击等 workaround。
3. **配置复杂** — oh-my-tmux 降低了门槛，但底层仍然晦涩。

Zellij（Rust 编写，2023 年稳定，2026 年已广泛采用）解决了以上所有问题：
- Bell 默认透传到外层终端。
- 鼠标选择默认 pane-aware，不会跨 pane。
- 自带可发现的快捷键提示栏，开箱即用。

## 变更范围

| 动作 | 目标 |
|------|------|
| 新增 | `modules/zellij.sh` |
| 删除 | `modules/tmux.sh`、`docs/modules/tmux.md` |
| 修改 | `lib/modules.sh`（tmux → zellij） |
| 新增 | `docs/modules/zellij.md` |
| 修改 | `docs/guide.zh-CN.md`（tmux 章节 → Zellij 新手指南） |
| 修改 | `docs/guide.md`（英文版对应更新） |
| 修改 | `README.md`（模块表 + 示例命令） |

## 模块设计：`modules/zellij.sh`

### 接口声明

```bash
MODULE_NAME="zellij"
MODULE_DESC="Zellij terminal multiplexer (catppuccin theme)"
MODULE_PLATFORM="all"
MODULE_DEPS=("rust")
```

### install()

1. 通过 cargo 安装：
   ```bash
   cargo install zellij
   ```

2. 写入最小化配置到 `~/.config/zellij/config.kdl`：
   ```kdl
   // Zellij configuration — managed by dotfiles
   theme "catppuccin-mocha"
   mouse_mode true
   copy_on_select true
   pane_frames true
   simplified_ui false
   ```

   保持配置极简 — Zellij 默认值已经很好。只设置我们明确需要的（主题 + 鼠标行为）。

### uninstall()

```bash
rm -rf "${HOME}/.config/zellij"
```

## 配置选项说明

| 选项 | 值 | 理由 |
|------|-----|------|
| `theme` | `"catppuccin-mocha"` | 与所有其他模块保持一致（Zellij 内置，无需额外下载） |
| `mouse_mode` | `true` | 启用鼠标选择 pane、滚动、调整大小 |
| `copy_on_select` | `true` | 选中即复制到剪贴板（类似 iTerm2 行为） |
| `pane_frames` | `true` | 显示 pane 边框（视觉清晰，避免复制混淆） |
| `simplified_ui` | `false` | 显示快捷键提示栏（新手必备） |

## 指南内容：Zellij 新手指南（docs/guide.zh-CN.md）

替换原 tmux 章节。面向两类读者：从未使用过终端复用器的开发者，以及从 tmux 迁移过来的人。

### 结构

1. **Zellij 是什么 / 为什么选它** — 简短（3-4 句话），对比 tmux 的优势
2. **核心概念** — Session > Tab > Pane 层级结构，配 ASCII 图解
3. **模式系统** — Zellij 使用模式（Normal、Pane、Tab、Resize、Scroll、Session、
   Move、Search）。底部状态栏实时显示当前模式可用的快捷键。
4. **常用快捷键表** — 按任务分组：
   - Pane 操作（新建、关闭、导航、调整大小、浮动、全屏）
   - Tab 操作（新建、关闭、切换、重命名）
   - Session 操作（断开、重命名）
   - 滚动/复制（进入滚动模式、选中、复制）
   - 浮动面板（开关、移动）
5. **典型工作流**（每个配有逐步说明 + ASCII 布局图）：

   **A. 日常开发三板斧：**
   ```
   ┌──────────────────────┬─────────────────┐
   │                      │   terminal      │
   │   editor (nvim)      ├─────────────────┤
   │                      │   Claude Code   │
   └──────────────────────┴─────────────────┘
   ```
   - 创建 session：`zellij --session myproject`
   - 向右分屏：`Ctrl+p` → `r`
   - 右侧 pane 内向下分屏：`Ctrl+p` → `d`
   - 左侧跑 nvim，右上跑终端，右下跑 Claude Code
   - Claude Code 完成任务时 bell 会正常传递到 Ghostty 通知

   **B. SSH 远程开发：**
   - SSH 到服务器后：`zellij --session work`
   - 正常工作；如果连接断开，session 继续运行
   - 重连后：`ssh server` → `zellij attach work`
   - 所有 pane、滚动历史、运行中的进程完整恢复

   **C. 浮动窗口快速查阅：**
   - 正在写代码，需要临时查文档或跑个命令
   - `Ctrl+p` → `w` — 弹出浮动面板覆盖在当前布局之上
   - 做你需要做的（man page、git log、curl 等）
   - `Ctrl+p` → `w` 再按一次 — 关闭浮动面板，主布局纹丝不动
   - 不需要重新排列你精心调好的分屏

   **D. 多项目并行切换：**
   ```bash
   zellij --session dotfiles    # 项目 1
   # Ctrl+o → d（断开当前 session）
   zellij --session linux       # 项目 2
   # Ctrl+o → d（断开当前 session）
   zellij ls                    # 查看所有 session
   zellij attach dotfiles       # 跳回项目 1
   ```
   - 每个 session 有独立的 tab、pane、工作目录
   - 断开/连接是瞬间完成的 — 不需要切窗口
   - `zellij kill-session <name>` 结束一个项目的 session

6. **CLI 命令速查** — `zellij`、`zellij ls`、`zellij attach`、`zellij kill-session`
7. **配置文件位置** — `~/.config/zellij/config.kdl`
8. **tmux 迁移对照表** — 并排对比 tmux 和 Zellij 的操作方式

### 重点特性

- **浮动面板**：`Ctrl+p` → `w` 切换浮动面板。适合临时命令，不破坏主布局。
- **会话持久化**：关闭终端后 session 继续存在；`zellij attach <name>` 恢复。
- **可发现式 UI**：底部状态栏始终显示当前模式的可用快捷键，无需背。
- **Pane-aware 鼠标**：鼠标选择文本自动限制在单个 pane 内，不会跨 pane。

## 文件变更明细

### 新增：`modules/zellij.sh`

完整模块，遵循标准接口契约（install/uninstall hooks）。

### 新增：`docs/modules/zellij.md`

模块技术文档（安装内容、配置文件路径、注意事项）。

### 修改：`lib/modules.sh`

DOTFILES_MODULES 数组中 `tmux` 替换为 `zellij`。位置不变（在 starship 之后，无顺序依赖）。

### 修改：`tests/test_install.sh`

替换所有 tmux 相关断言为 zellij 断言：

**安装验证（Phase 2）：**
```bash
# 原 tmux 断言（删除）：
assert_command tmux
assert_dir_exists "${HOME}/.local/share/tmux/oh-my-tmux"
assert "tmux.conf is a symlink" test -L "${HOME}/.config/tmux/tmux.conf"

# 新 zellij 断言：
assert_command zellij
assert_file_exists "${HOME}/.config/zellij/config.kdl"
assert_file_contains "${HOME}/.config/zellij/config.kdl" "catppuccin-mocha"
```

**卸载验证（Phase 4）：**
```bash
# 原 tmux 断言（删除）：
assert_dir_missing "${HOME}/.local/share/tmux/oh-my-tmux"
assert "tmux.conf symlink removed" test ! -L "${HOME}/.config/tmux/tmux.conf"
assert_file_missing "${HOME}/.config/tmux/tmux.conf.local"

# 新 zellij 断言：
assert_dir_missing "${HOME}/.config/zellij"
```

### 修改：`README.md`

- 模块表：`tmux | all | tmux + oh-my-tmux` → `zellij | all | Zellij terminal multiplexer (catppuccin)`
- 示例命令：`--only tmux,nvim` → `--only zellij,nvim`

### 修改：`docs/guide.zh-CN.md`

用上述 Zellij 新手指南替换 tmux 章节（约第 739-776 行）。

### 修改：`docs/guide.md`

英文版对应更新。

### 删除：`modules/tmux.sh`、`docs/modules/tmux.md`

彻底删除。
