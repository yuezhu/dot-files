#!/bin/sh
# tmux paste helper: reads the system clipboard and pastes it into the
# active tmux pane via a named buffer.
#
# Uses xsel on Linux (when $DISPLAY is set) or pbpaste on macOS.
# Falls back to pasting from the default tmux buffer when no system
# clipboard tool is available.
#
# Usage (in .tmux.conf):
#   run-shell "~/dot-files/tmux/tmux-paste.sh"

if command -v xsel >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
  xsel -o -b | tmux load-buffer -b _clip - && tmux paste-buffer -b _clip -d
elif command -v pbpaste >/dev/null 2>&1; then
  pbpaste | tmux load-buffer -b _clip - && tmux paste-buffer -b _clip -d
else
  tmux paste-buffer
fi
