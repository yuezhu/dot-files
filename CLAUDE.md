# dot-files

Personal configuration files managed with GNU Stow.

## Structure

Each top-level directory is a stow package targeting `$HOME`. Files within each package mirror the home directory layout (e.g., `zsh/.zshrc` deploys to `~/.zshrc`).

- `claude/` — Claude Code hooks and statusline script
- `emacs/` — Emacs config (`early-init.el`, `init.el`)
- `ghostty/` — Ghostty terminal config
- `git/` — gitconfig, gitignore_global, gitattributes
- `mpv/` — mpv media player config and keybindings
- `tmux/` — tmux.conf, clipboard helper scripts (tmux-copy.sh, tmux-paste.sh)
- `vim/` — .vimrc
- `yamllint/` — yamllint config
- `zsh/` — .zshrc

## Comments

- Write comments that are understandable without domain-specific knowledge.
- When a config key or value uses specific terminology (e.g. "bracketed paste", "shell integration"), mention that term in the comment so readers can look it up.
- Do not explain what is already obvious from context.

## Style

- Use `#!/bin/sh` for shell scripts unless specific shell features are needed.
- Normalize line endings to LF (enforced by `.gitattributes`).
