# git 模块重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 重构 `modules/git.sh` 为完整 Git 体验模块：安装 delta + lazygit，配置 SSH signing、全局 gitignore、现代工作流 git config，精简 nvim 模块。

**架构：** 扩展现有 git.sh，拆为 5 个内部函数（identity、tools、lazygit config、gitignore、workflow config）。模块位置移到 rust/golang 之后。nvim 模块删除 lazygit 安装。

**技术栈：** Bash（模块接口）、cargo（delta）、go install（lazygit）、git config --global。

**提交策略：** design.md + tasks.md 一个 commit；代码改动另一个 commit。

---

### 任务 1: 调整模块顺序

**文件：**
- 修改: `lib/modules.sh:8-25`

- [ ] **步骤 1: 移动 git 位置，更新注释**

将 `lib/modules.sh` 中的 DOTFILES_MODULES 数组改为：

```bash
DOTFILES_MODULES=(
  homebrew             # mac only: .zprofile shellenv (must be first for brew PATH)
  font-hack-nerd-font
  ssh              # before git: SSH key needed for git commit signing
  rust             # before git/nvim: cargo for delta, tree-sitter-cli
  golang           # before git/nvim: go install lazygit
  git              # after ssh/rust/golang: needs SSH key, cargo, go
  cli-tools        # after rust/golang: cargo tools; before fzf: fzf preview uses bat/fd
  fzf              # before zoxide: zi interactive mode uses fzf
                   # before sheldon: sheldon's fzf-tab plugin requires the fzf binary
  zoxide
  sheldon
  atuin            # after rust (cargo), after sheldon (replaces its history-substring-search)
  starship
  ghostty          # after font/sheldon/zoxide/starship: config assumes these are installed
  nvim             # after rust (cargo), golang, git (lazygit), cli-tools (rg, fd)
  tmux
)
```

---

### 任务 2: 重写 modules/git.sh

**文件：**
- 修改: `modules/git.sh`（完全重写）

- [ ] **步骤 1: 编写完整模块文件**

```bash
#!/usr/bin/env bash
# modules/git.sh — Git configuration, tools, and workflow defaults
# Platform: all
#
# Configures:
#   - User identity (name, email)
#   - delta (syntax-highlighted diff pager) via cargo
#   - lazygit (git TUI) via go install
#   - SSH commit signing (reuses key from ssh module)
#   - Global gitignore (~/.config/git/ignore)
#   - Modern workflow defaults (rebase, autostash, histogram diff, etc.)
#   - lazygit catppuccin-mocha theme
#
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="git"
MODULE_DESC="Git configuration, delta, lazygit, SSH signing"
MODULE_PLATFORM="all"

_GIT_GLOBAL_IGNORE="${HOME}/.config/git/ignore"
_GIT_LAZYGIT_CONFIG="${HOME}/.config/lazygit/config.yml"
_GIT_LAZYGIT_THEME_REPO="https://github.com/catppuccin/lazygit.git"
_GIT_LAZYGIT_THEME_DIR="${HOME}/.local/share/lazygit/catppuccin"
_GIT_LAZYGIT_THEME_FILE="${_GIT_LAZYGIT_THEME_DIR}/themes-mergable/mocha/blue.yml"

# Set git user identity.
_git::configure_identity() {
  git config --global user.name "yangxingwu"
  git config --global user.email "xingwu.yang@gmail.com"
  core::log INFO "Configured git identity"
  core::summary "    ✓ config → ~/.gitconfig (user.name, user.email)"
}

# Install delta (diff pager) and lazygit (git TUI).
_git::install_tools() {
  if core::check_installed delta; then
    core::log INFO "Already installed: delta"
    core::summary "    ✓ delta already installed"
  else
    core::run_cmd "Installing git-delta" cargo install git-delta
    core::summary "    ✓ delta installed via cargo"
  fi

  if core::check_installed lazygit; then
    core::log INFO "Already installed: lazygit"
    core::summary "    ✓ lazygit already installed"
  else
    core::run_cmd "Installing lazygit" go install github.com/jesseduffield/lazygit@latest
    core::summary "    ✓ lazygit installed via go"
  fi
}

# Clone catppuccin theme repo, write lazygit config, and set up shell alias.
_git::configure_lazygit() {
  # Clone or update catppuccin/lazygit theme repository.
  if [[ -d "${_GIT_LAZYGIT_THEME_DIR}" ]]; then
    core::run_cmd "Updating lazygit catppuccin theme" git -C "${_GIT_LAZYGIT_THEME_DIR}" pull --quiet
  else
    mkdir -p "$(dirname "${_GIT_LAZYGIT_THEME_DIR}")"
    core::run_cmd "Cloning lazygit catppuccin theme" git clone --quiet "${_GIT_LAZYGIT_THEME_REPO}" "${_GIT_LAZYGIT_THEME_DIR}"
  fi
  core::summary "    ✓ catppuccin theme → ~/.local/share/lazygit/catppuccin"

  # Write minimal lazygit config (theme is merged via --use-config-file).
  mkdir -p "$(dirname "${_GIT_LAZYGIT_CONFIG}")"
  cat >"${_GIT_LAZYGIT_CONFIG}" <<'YAML'
gui:
  # Use Nerd Font v3 icons in lazygit UI (pairs with Hack Nerd Font installed by font module)
  nerdFontsVersion: "3"
YAML
  core::log INFO "Wrote lazygit config: ${_GIT_LAZYGIT_CONFIG}"
  core::summary "    ✓ config → ~/.config/lazygit/config.yml"

  # Shell alias to merge catppuccin theme at launch.
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "lazygit" \
    '# Merge catppuccin mocha theme at launch via --use-config-file.
# See: https://github.com/catppuccin/lazygit#usage
alias lazygit='\''lazygit --use-config-file="$HOME/.config/lazygit/config.yml,$HOME/.local/share/lazygit/catppuccin/themes-mergable/mocha/blue.yml"'\'''
  core::summary "    ✓ config → ~/.zshrc (lazygit alias with catppuccin theme)"
}

# Write global gitignore for common OS/editor/language junk files.
_git::write_global_gitignore() {
  mkdir -p "$(dirname "${_GIT_GLOBAL_IGNORE}")"
  cat >"${_GIT_GLOBAL_IGNORE}" <<'GITIGNORE'
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
GITIGNORE
  core::log INFO "Wrote global gitignore: ${_GIT_GLOBAL_IGNORE}"
  core::summary "    ✓ config → ~/.config/git/ignore (global gitignore)"
}

# Configure modern git workflow defaults, delta integration, and SSH signing.
_git::configure_workflow() {
  # -- Workflow --
  # Default branch name for new repos
  git config --global init.defaultBranch main
  # Use rebase instead of merge on pull (linear history)
  git config --global pull.rebase true
  # Auto-stash before rebase, auto-pop after
  git config --global rebase.autoStash true
  # Auto-set upstream tracking branch on push (no more -u origin branch)
  git config --global push.autoSetupRemote true
  # Show base + ours + theirs in merge conflicts (clearer than 2-way)
  git config --global merge.conflictstyle zdiff3
  # Remember conflict resolutions and auto-apply next time
  git config --global rerere.enabled true
  # Use nvim as default editor for commit messages, rebase, etc.
  git config --global core.editor nvim

  # -- Diff --
  # Histogram diff algorithm (more readable output than default myers)
  git config --global diff.algorithm histogram
  # Color moved code blocks differently (distinguish moves from changes)
  git config --global diff.colorMoved default

  # -- Delta integration --
  # Use delta as pager (syntax highlighting + line numbers + side-by-side)
  git config --global core.pager delta
  # Use delta for interactive rebase coloring
  git config --global interactive.diffFilter "delta --color-only"
  # Enable n/N navigation between diff hunks in delta
  git config --global delta.navigate true
  # Side-by-side diff view
  git config --global delta.side-by-side true
  # Show line numbers
  git config --global delta.line-numbers true

  # -- SSH commit signing (Git 2.34+, no GPG needed) --
  # Sign all commits and tags (GitHub shows Verified badge)
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true
  # Use SSH key format instead of GPG
  git config --global gpg.format ssh
  # Use the ed25519 SSH key as signing key
  git config --global user.signingkey "${HOME}/.ssh/id_ed25519.pub"

  # -- Global gitignore --
  # Shared ignore rules for OS/editor/language junk across all repos
  git config --global core.excludesFile "${_GIT_GLOBAL_IGNORE}"

  core::log INFO "Configured git workflow defaults"
  core::summary "    ✓ config → ~/.gitconfig (workflow, delta, signing, gitignore)"
}

# Push SSH public key to GitHub as a signing key (separate from authentication key).
# Skipped in non-interactive environments (no TTY).
_git::push_signing_key_to_github() {
  local pub_key="${HOME}/.ssh/id_ed25519.pub"
  local key_title
  key_title="$(awk '{print $3}' "${pub_key}")"

  # Require gh to be authenticated; skip if not (same pattern as ssh module).
  if ! gh auth status >/dev/null 2>&1; then
    if [[ ! -t 0 ]]; then
      core::log INFO "gh not authenticated and no TTY — skipping signing key push"
      core::summary "    — skipped signing key push (non-interactive)"
      return 0
    fi
    core::log INFO "gh not authenticated — starting interactive login"
    if ! gh auth login; then
      core::log WARN "GitHub authentication failed — skipping signing key push"
      core::summary "    — skipped signing key push (auth failed)"
      return 0
    fi
  fi

  # Check if this key is already registered as a signing key on GitHub.
  local key_body
  key_body="$(awk '{print $2}' "${pub_key}")"
  if gh ssh-key list --json key,type --jq '.[] | select(.type=="signing") | .key' 2>/dev/null | grep -qF "${key_body}"; then
    core::log INFO "SSH signing key already registered on GitHub"
    core::summary "    ✓ SSH signing key already on GitHub"
  else
    gh ssh-key add "${pub_key}" --title "${key_title}" --type signing
    core::log INFO "Pushed SSH signing key to GitHub"
    core::summary "    ✓ SSH signing key pushed to GitHub"
  fi
}

install() {
  _git::configure_identity
  _git::install_tools
  _git::configure_lazygit
  _git::write_global_gitignore
  _git::configure_workflow
  _git::push_signing_key_to_github
}

uninstall() {
  # Identity
  git config --global --unset user.name 2>/dev/null || true
  git config --global --unset user.email 2>/dev/null || true

  # Workflow
  git config --global --unset init.defaultBranch 2>/dev/null || true
  git config --global --unset pull.rebase 2>/dev/null || true
  git config --global --unset rebase.autoStash 2>/dev/null || true
  git config --global --unset push.autoSetupRemote 2>/dev/null || true
  git config --global --unset merge.conflictstyle 2>/dev/null || true
  git config --global --unset rerere.enabled 2>/dev/null || true
  git config --global --unset core.editor 2>/dev/null || true

  # Diff
  git config --global --unset diff.algorithm 2>/dev/null || true
  git config --global --unset diff.colorMoved 2>/dev/null || true

  # Delta
  git config --global --unset core.pager 2>/dev/null || true
  git config --global --unset interactive.diffFilter 2>/dev/null || true
  git config --global --remove-section delta 2>/dev/null || true

  # Signing
  git config --global --unset commit.gpgsign 2>/dev/null || true
  git config --global --unset tag.gpgsign 2>/dev/null || true
  git config --global --unset gpg.format 2>/dev/null || true
  git config --global --unset user.signingkey 2>/dev/null || true

  # Gitignore
  git config --global --unset core.excludesFile 2>/dev/null || true
  rm -f "${_GIT_GLOBAL_IGNORE}"

  # Lazygit config, theme, and alias
  rm -f "${_GIT_LAZYGIT_CONFIG}"
  rm -rf "${_GIT_LAZYGIT_THEME_DIR}"
  core::remove_block "${HOME}/.zshrc" "lazygit"

  core::log INFO "Removed git config, lazygit config/theme, global gitignore"
  core::summary "    ✓ removed git config entries"
  core::summary "    ✓ removed ~/.config/lazygit/config.yml"
  core::summary "    ✓ removed ~/.local/share/lazygit/catppuccin"
  core::summary "    ✓ removed lazygit alias from ~/.zshrc"
  core::summary "    ✓ removed ~/.config/git/ignore"

  # Binaries intentionally NOT removed: delta, lazygit
  core::log INFO "Retained binaries: delta, lazygit"
  core::summary "    — retained binaries: delta, lazygit"
}
```

---

### 任务 3: 精简 nvim 模块

**文件：**
- 修改: `modules/nvim.sh:27-30`

- [ ] **步骤 1: 从 _nvim::install_deps() 中移除 lazygit 安装**

将当前的：

```bash
  # lazygit and tree-sitter-cli are not in apt/dnf.
  # golang and rust modules run before nvim, so go and cargo are on PATH.
  core::run_cmd "Installing lazygit" go install github.com/jesseduffield/lazygit@latest
  core::summary "    ✓ lazygit installed via go"
  core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli
  core::summary "    ✓ tree-sitter-cli installed via cargo"
```

改为：

```bash
  # lazygit is provided by the git module (runs before nvim).
  # tree-sitter-cli is not in apt/dnf; rust module ensures cargo is on PATH.
  core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli
  core::summary "    ✓ tree-sitter-cli installed via cargo"
```

---

### 任务 4: 更新集成测试

**文件：**
- 修改: `tests/test_install.sh`

- [ ] **步骤 1: 在 Phase 2 中添加 git 增强断言**

在现有的 `assert_file_contains "${HOME}/.gitconfig" "yangxingwu"` 行之后添加：

```bash
# git module — tools and config
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

- [ ] **步骤 2: 在 Phase 4 中更新 git 卸载断言**

将现有的：

```bash
# Git config entries removed
assert_file_not_contains "${HOME}/.gitconfig" "yangxingwu"
```

替换为：

```bash
# Git config entries removed
assert_file_not_contains "${HOME}/.gitconfig" "yangxingwu"
assert_file_not_contains "${HOME}/.gitconfig" "defaultBranch"
assert_file_missing "${HOME}/.config/lazygit/config.yml"
assert_dir_missing "${HOME}/.local/share/lazygit/catppuccin"
assert_file_not_contains "${HOME}/.zshrc" "BEGIN dotfiles:lazygit"
assert_file_missing "${HOME}/.config/git/ignore"
# git binaries retained
assert_command delta
assert_command lazygit
```

---

### 任务 5: 更新文档

**文件：**
- 修改: `docs/modules/git.md`
- 修改: `README.md`

- [ ] **步骤 1: 重写 docs/modules/git.md**

```markdown
# Module: git

Complete Git configuration: identity, modern workflow defaults, delta diff pager,
lazygit TUI, SSH commit signing, and global gitignore.

git itself is already installed by bootstrap (CLT on macOS, dev_tools on Linux).

## Module hooks

| Hook | Action |
|---|---|
| `install` | configure identity; install delta (cargo) + lazygit (go); write lazygit catppuccin config; write global gitignore; set workflow/delta/signing git config; push SSH signing key to GitHub |
| `uninstall` | remove all git config entries; remove lazygit config + global gitignore; retain delta/lazygit binaries |

## Tools installed

| Tool | Install method | Purpose |
|---|---|---|
| delta | `cargo install git-delta` | Syntax-highlighted, side-by-side diff pager |
| lazygit | `go install lazygit@latest` | Terminal UI for git |

## Configuration files

| File | Content |
|---|---|
| `~/.gitconfig` | Identity, workflow, delta, signing config |
| `~/.config/lazygit/config.yml` | Catppuccin Mocha theme + Nerd Font icons |
| `~/.config/git/ignore` | Global gitignore (OS/editor/language junk) |

## Git config summary

**Workflow:** init.defaultBranch=main, pull.rebase, rebase.autoStash,
push.autoSetupRemote, merge.conflictstyle=zdiff3, rerere.enabled, core.editor=nvim

**Diff:** diff.algorithm=histogram, diff.colorMoved=default

**Delta:** core.pager=delta, interactive.diffFilter, delta.navigate,
delta.side-by-side, delta.line-numbers

**Signing:** commit.gpgsign, tag.gpgsign, gpg.format=ssh,
user.signingkey=~/.ssh/id_ed25519.pub

**Gitignore:** core.excludesFile=~/.config/git/ignore

## Notes

- Module runs after ssh (needs SSH key for signing), rust (needs cargo for
  delta), and golang (needs go for lazygit).
- SSH signing key is pushed to GitHub as type "signing" (separate from the
  authentication key pushed by the ssh module). View at:
  - CLI: `gh ssh-key list` (type column shows `signing`)
  - Web: https://github.com/settings/keys → "Signing Keys" section
- lazygit was previously installed by the nvim module; ownership moved here.
```

- [ ] **步骤 2: 更新 README.md 模块表格**

将 git 行从：

```markdown
| `git` | all | Git global config (user.name, user.email) |
```

改为：

```markdown
| `git` | all | Git config, delta, lazygit, SSH signing, global gitignore |
```

---

### 任务 6: 验证与提交

- [ ] **步骤 1: 运行 shellcheck**

运行: `shellcheck modules/git.sh`
预期: 无错误。

- [ ] **步骤 2: 运行 shfmt**

运行: `shfmt -w modules/git.sh`

- [ ] **步骤 3: 验证模块列表**

运行: `./install.sh --list`
预期: git 出现在 golang 和 cli-tools 之间。

- [ ] **步骤 4: 提交 design.md + tasks.md**

```bash
git add docs/changes/2026-05-14-git-module-refactor/design.md \
        docs/changes/2026-05-14-git-module-refactor/tasks.md
git commit -m "docs: add git module refactor design and implementation plan

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

- [ ] **步骤 5: 提交代码改动**

```bash
git add lib/modules.sh modules/git.sh modules/nvim.sh \
        tests/test_install.sh docs/modules/git.md README.md
git commit -m "feat(git): refactor into full Git experience module

Expand git.sh from identity-only config into a complete module:
- Install delta (cargo) and lazygit (go install)
- Configure SSH commit signing (reuses key from ssh module)
- Write global gitignore (~/.config/git/ignore)
- Set modern workflow defaults (pull.rebase, push.autoSetupRemote,
  histogram diff, rerere, zdiff3 conflict style, nvim as editor)
- Write lazygit catppuccin-mocha theme config
- Push SSH signing key to GitHub

Move git module after rust/golang in install order (needs cargo + go).
Move lazygit installation from nvim module to git module.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```
