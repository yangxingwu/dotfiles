# Shell 基础环境 + 别名（zsh-config 模块）

## 问题

安装完成后，用户进入 zsh 但没有 EDITOR、没有 PAGER、没有 locale、history 只有
默认 1000 行且无去重、也没有为刚安装的现代 CLI 工具设置任何别名。工具装了但用
起来不方便。

## 方案

新建模块 `modules/zsh-config.sh`，配置 shell 环境。

### 模块位置

模块列表最后（tmux 之后）。所有工具在此模块运行时已安装完毕，alias 可以安全
引用 eza、bat、nvim。

### 写入文件

一个 managed block 写入 `~/.zshrc`（block id: `zsh-config`）。

主流 dotfiles 项目（oh-my-zsh、prezto 等）把所有配置放 `.zshrc`。简单、好维护、
99% 的使用场景是交互式 shell。

### ~/.zshrc block 内容

```bash
# Environment
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less -R"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# History
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="${HOME}/.zsh_history"

# Options
setopt share_history          # share history across all open terminals
setopt hist_ignore_all_dups   # remove older duplicate from history
setopt hist_reduce_blanks     # trim unnecessary whitespace before storing
setopt hist_verify            # show expanded history command before executing
setopt extended_history       # record timestamp and duration in history
setopt auto_cd                # type a directory name to cd into it
setopt interactive_comments   # allow # comments in interactive shell

# Aliases (guarded: only defined if target command exists)
command -v eza >/dev/null && alias ls='eza --icons --group-directories-first'
command -v eza >/dev/null && alias ll='eza -l --icons --git --group-directories-first'
command -v eza >/dev/null && alias la='eza -la --icons --git --group-directories-first'
command -v eza >/dev/null && alias lt='eza --tree --level=2 --icons'
command -v bat >/dev/null && alias cat='bat --paging=never'
```

### Uninstall

移除 `~/.zshrc` 中的 `zsh-config` block。

### 不做的事

- **XDG base dirs** — 项目中的工具已默认使用 `~/.config` 等路径，显式设置无额外
  价值。
- **alias grep/find/diff** — rg/fd/delta 的参数语法与原始命令不兼容，强行替换会
  破坏兼容性。用户直接输入 `rg`/`fd` 即可。delta 已通过 git config 配置为 pager。
- **PAGER=bat** — bat 作为通用 pager 有兼容问题（man 页面颜色冲突、缺少 less
  快捷键）。`less -R` 是安全通用的选择。

### 测试

CI 断言：
- `~/.zshrc` 包含 `EDITOR="nvim"`
- `~/.zshrc` 包含 `setopt share_history`
- `~/.zshrc` 包含 `alias ls='eza --icons --group-directories-first'`
- uninstall 后：block 被移除
