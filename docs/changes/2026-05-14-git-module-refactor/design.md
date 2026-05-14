# git 模块重构设计

日期: 2026-05-14

## 概述

重构现有 `modules/git.sh`，从一个只配 user.name/email 的最小模块，扩展为
完整的现代 Git 体验模块：安装 delta + lazygit，配置 SSH commit signing，
设置全局 gitignore，写入现代工作流 git config。同步精简 nvim 模块中的
lazygit 安装逻辑。

## 动机

当前 git 模块只有 2 行配置（user.name/email），不符合"开箱即用现代开发
体验"的定位：

- `git diff` 输出裸文本（缺 delta）
- `git log` 没有 TUI（lazygit 藏在 nvim 模块里）
- commit 没有签名（GitHub 不显示 Verified）
- 缺少 pull.rebase、push.autoSetupRemote 等现代工作流配置
- 没有全局 gitignore（.DS_Store、.idea/ 等污染每个项目）

## 变更范围

| 文件 | 动作 | 说明 |
|------|------|------|
| `modules/git.sh` | 重构 | 完整 git 体验模块 |
| `modules/nvim.sh` | 精简 | 移除 lazygit 安装 |
| `lib/modules.sh` | 调整 | git 移到 rust/golang 之后 |
| `tests/test_install.sh` | 更新 | 新增断言 |
| `docs/modules/git.md` | 更新 | 文档同步 |
| `README.md` | 更新 | 模块描述 |

## 模块顺序变更

```
之前: homebrew → font → git → ssh → rust → golang → cli-tools → fzf → ...
之后: homebrew → font → ssh → rust → golang → git → cli-tools → fzf → ...
```

git 移到 rust/golang 之后（delta 需要 cargo，lazygit 需要 go）。
ssh 提前到 git 之前（git signing 需要 SSH key 已生成）。

---

## git.sh 重构设计

### 内部结构

```bash
_git::configure_identity()      # user.name, user.email
_git::install_tools()           # delta (cargo), lazygit (go install)
_git::configure_lazygit()       # clone catppuccin theme, write config.yml, write .zshrc alias
_git::write_global_gitignore()  # ~/.config/git/ignore
_git::configure_workflow()      # git config --global（全部工作流配置）
```

### 工具安装

| 工具 | 安装方式 | 守卫 |
|------|---------|------|
| delta | `cargo install git-delta` | `core::check_installed delta` |
| lazygit | `go install github.com/jesseduffield/lazygit@latest` | `core::check_installed lazygit` |

### git config 完整清单

每项配置附带注释说明用途：

```bash
# ── 工作流 ──────────────────────────────────────────────────────────────
# 新建仓库默认分支名为 main（取代 master）
git config --global init.defaultBranch main
# pull 时使用 rebase 而非 merge（保持线性历史）
git config --global pull.rebase true
# rebase 前自动 stash 未提交的改动，完成后自动 pop
git config --global rebase.autoStash true
# push 时自动设置上游跟踪分支（省去 -u origin branch）
git config --global push.autoSetupRemote true
# 合并冲突显示 base + ours + theirs 三方对比（比默认两方更清晰）
git config --global merge.conflictstyle zdiff3
# 记住冲突解决方式，下次遇到相同冲突自动应用
git config --global rerere.enabled true

# ── diff 增强 ───────────────────────────────────────────────────────────
# 使用 histogram 算法生成更可读的 diff（比默认 myers 更好）
git config --global diff.algorithm histogram
# 移动的代码块用不同颜色标注（区分"移动"和"修改"）
git config --global diff.colorMoved default

# ── delta 集成 ──────────────────────────────────────────────────────────
# 使用 delta 作为 pager（语法高亮 + 行号 + 侧边对比）
git config --global core.pager delta
# interactive rebase 时也使用 delta 着色
git config --global interactive.diffFilter "delta --color-only"
# delta: 启用 n/N 快捷键在 diff 块间跳转
git config --global delta.navigate true
# delta: 并排对比模式
git config --global delta.side-by-side true
# delta: 显示行号
git config --global delta.line-numbers true

# ── SSH 签名 ────────────────────────────────────────────────────────────
# 对所有 commit 和 tag 进行签名（GitHub 显示 Verified 标志）
git config --global commit.gpgsign true
git config --global tag.gpgsign true
# 使用 SSH key 签名（Git 2.34+，无需安装 GPG）
git config --global gpg.format ssh
# 使用 ed25519 SSH key 作为签名密钥
git config --global user.signingkey "~/.ssh/id_ed25519.pub"

# ── 全局 gitignore ─────────────────────────────────────────────────────
# 所有仓库共享的忽略规则（IDE、OS、语言通用垃圾文件）
git config --global core.excludesFile "~/.config/git/ignore"
```

### 全局 gitignore 文件（~/.config/git/ignore）

```gitignore
# Global gitignore — OS and editor artifacts only.
# Project-specific ignores (node_modules, .env, etc.) belong in each project's .gitignore.
#
# Sources:
#   https://github.com/github/gitignore/blob/main/Global/macOS.gitignore
#   https://github.com/github/gitignore/blob/main/Global/Linux.gitignore
#   https://github.com/github/gitignore/blob/main/Global/Vim.gitignore
#   https://github.com/github/gitignore/blob/main/Global/JetBrains.gitignore

# --- macOS ---
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes

# --- Linux ---
*~
.directory

# --- Vim / Neovim ---
*.swp
*.swo
[._]*.un~
Session.vim
Sessionx.vim
.netrwhist
tags

# --- JetBrains IDEs ---
.idea/

# --- Visual Studio Code ---
.vscode/
*.code-workspace
```

### lazygit 配置

**方案：** 使用 `--use-config-file` 合并外部主题文件，保证始终使用最新主题。

**步骤：**

1. 克隆 catppuccin/lazygit 主题仓库到 `~/.local/share/lazygit/catppuccin/`
   （已有则 git pull 更新）
2. 写 `~/.config/lazygit/config.yml`（只含非主题配置）：

```yaml
gui:
  # Use Nerd Font v3 icons in lazygit UI (pairs with Hack Nerd Font installed by font module)
  nerdFontsVersion: "3"
```

3. 在 `~/.zshrc` 写 managed block `lazygit`，定义 alias 自动合并主题：

```bash
# Merge catppuccin mocha theme at launch via --use-config-file.
# See: https://github.com/catppuccin/lazygit#usage
alias lazygit='lazygit --use-config-file="$HOME/.config/lazygit/config.yml,$HOME/.local/share/lazygit/catppuccin/themes-mergable/mocha/blue.yml"'
```

**效果：**
- `lazygit` 命令自动加载 catppuccin mocha 主题
- nvim 内的 lazygit 也受益（LazyVim 调用的就是 `lazygit` 命令）
- 更新主题：`cd ~/.local/share/lazygit/catppuccin && git pull`

**查看方式：**
- 主题仓库来源：https://github.com/catppuccin/lazygit
- 使用的主题文件：`themes-mergable/mocha/blue.yml`

### SSH signing key 推送到 GitHub

ssh 模块已经把公钥推送到 GitHub 作为 authentication key。但 SSH signing
需要同一把 key 也注册为 **signing key**（GitHub 区分两种用途）。

注册后可在以下位置查看：
- **命令行**：`gh ssh-key list`（type 列显示 `signing`）
- **网页**：GitHub → Settings → SSH and GPG keys（`https://github.com/settings/keys`），
  页面分两个区域："Authentication Keys" 和 "Signing Keys"

在 `_git::configure_workflow()` 末尾：

```bash
# 将 SSH 公钥注册为 GitHub signing key（commit 验证需要）
local pub_key="${HOME}/.ssh/id_ed25519.pub"
local key_body
key_body="$(awk '{print $2}' "${pub_key}")"

if gh ssh-key list --json key,type --jq '.[] | select(.type=="signing") | .key' 2>/dev/null | grep -qF "${key_body}"; then
  core::log INFO "SSH signing key already registered on GitHub"
  core::summary "    ✓ SSH signing key already on GitHub"
else
  gh ssh-key add "${pub_key}" --title "$(awk '{print $3}' "${pub_key}")" --type signing
  core::log INFO "Pushed SSH signing key to GitHub"
  core::summary "    ✓ SSH signing key pushed to GitHub"
fi
```

注意：这段逻辑与 ssh 模块的 `_ssh::push_key_to_github()` 类似，但 type
不同（signing vs authentication）。需要 gh 已认证——如果未认证则跳过
（与 ssh 模块同样的 TTY 检查逻辑）。

---

## nvim 模块精简

从 `_nvim::install_deps()` 中移除 lazygit 安装：

```bash
# 删除这两行（lazygit 由 git 模块安装）：
core::run_cmd "Installing lazygit" go install github.com/jesseduffield/lazygit@latest
core::summary "    ✓ lazygit installed via go"
```

---

## uninstall()

```bash
uninstall() {
  # 身份
  git config --global --unset user.name 2>/dev/null || true
  git config --global --unset user.email 2>/dev/null || true

  # 工作流
  git config --global --unset init.defaultBranch 2>/dev/null || true
  git config --global --unset pull.rebase 2>/dev/null || true
  git config --global --unset rebase.autoStash 2>/dev/null || true
  git config --global --unset push.autoSetupRemote 2>/dev/null || true
  git config --global --unset merge.conflictstyle 2>/dev/null || true
  git config --global --unset rerere.enabled 2>/dev/null || true

  # diff
  git config --global --unset diff.algorithm 2>/dev/null || true
  git config --global --unset diff.colorMoved 2>/dev/null || true

  # delta
  git config --global --unset core.pager 2>/dev/null || true
  git config --global --unset interactive.diffFilter 2>/dev/null || true
  git config --global --remove-section delta 2>/dev/null || true

  # signing
  git config --global --unset commit.gpgsign 2>/dev/null || true
  git config --global --unset tag.gpgsign 2>/dev/null || true
  git config --global --unset gpg.format 2>/dev/null || true
  git config --global --unset user.signingkey 2>/dev/null || true

  # gitignore
  git config --global --unset core.excludesFile 2>/dev/null || true
  rm -f "${HOME}/.config/git/ignore"

  # lazygit config and theme
  rm -f "${HOME}/.config/lazygit/config.yml"
  rm -rf "${HOME}/.local/share/lazygit/catppuccin"
  core::remove_block "${HOME}/.zshrc" "lazygit"

  # 二进制保留：delta, lazygit 不卸载
  core::log INFO "Retained binaries: delta, lazygit"
  core::summary "    — retained binaries: delta, lazygit"
}
```

---

## 测试断言

### Phase 2（安装验证）

```bash
# git module
assert_command delta
assert_command lazygit
assert_file_exists "${HOME}/.config/lazygit/config.yml"
assert_file_contains "${HOME}/.config/lazygit/config.yml" "nerdFontsVersion"
assert_dir_exists "${HOME}/.local/share/lazygit/catppuccin"
assert_file_contains "${HOME}/.zshrc" "BEGIN dotfiles:lazygit"
assert_file_exists "${HOME}/.config/git/ignore"
assert_file_contains "${HOME}/.config/git/ignore" ".DS_Store"
assert "git core.pager is delta" test "$(git config --global core.pager)" = "delta"
assert "git pull.rebase is true" test "$(git config --global pull.rebase)" = "true"
assert "git commit.gpgsign is true" test "$(git config --global commit.gpgsign)" = "true"
assert "git gpg.format is ssh" test "$(git config --global gpg.format)" = "ssh"
```

### Phase 4（卸载验证）

```bash
# git uninstall
assert_file_missing "${HOME}/.config/lazygit/config.yml"
assert_dir_missing "${HOME}/.local/share/lazygit/catppuccin"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:lazygit"
assert_file_missing "${HOME}/.config/git/ignore"
assert_file_not_contains "${HOME}/.gitconfig" "yangxingwu"
assert_file_not_contains "${HOME}/.gitconfig" "defaultBranch"
# binaries retained
assert_command delta
assert_command lazygit
```

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| git 模块位置移动后 ssh 的 comment 提到 "after git" | 更新注释 |
| cargo install git-delta 编译耗时 | CI cargo cache（后续任务） |
| gh 未认证时推 signing key 失败 | 跳过，跟 ssh 模块同样逻辑 |
| 用户已有 ~/.gitconfig 自定义配置 | git config --global 是覆写式幂等 |
| core.excludesFile 已被用户自定义 | 覆写（项目接管；uninstall 还原） |
