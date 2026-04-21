Run shfmt on all shell scripts in this project to auto-format them in place.

```bash
shfmt -w lib/*.sh modules/*.sh install.sh uninstall.sh .claude/hooks/*.sh
```

After formatting, run `git diff --stat` to show which files changed. Report a summary
of what was reformatted.
