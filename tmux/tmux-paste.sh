#!/bin/sh
# tmux paste helper: send the local system clipboard into the active pane
# via a named buffer.
#
# - Run by the paste bindings' run-shell in .tmux.conf.
# - Reads the system clipboard with xsel (Linux, when $DISPLAY is set) or
#   pbpaste (macOS), loads it into a named buffer, and pastes that buffer.
#   Falls back to pasting tmux's default buffer when neither tool is present.
# - Pastes with bracketed paste (-p) so apps like IPython skip auto-indent.
# - Uses a pinned named buffer (-b _clip) so a concurrent buffer push (e.g.
#   OSC 52 from another pane) can't slip in and get pasted instead.
#
# Usage (in .tmux.conf):
#   run-shell "~/dot-files/tmux/tmux-paste.sh"

# -p wraps the paste in bracketed paste sequences so apps like IPython skip
#  auto-indent (otherwise indented code snowballs on each newline).
#
# -b _clip pins load and paste to a named buffer slot, so a concurrent buffer
#  push (e.g. OSC 52 from another pane) can't slip in and get pasted instead.
if command -v xsel >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
  xsel -o -b | tmux load-buffer -b _clip - && tmux paste-buffer -p -b _clip -d
elif command -v pbpaste >/dev/null 2>&1; then
  pbpaste | tmux load-buffer -b _clip - && tmux paste-buffer -p -b _clip -d
else
  tmux paste-buffer -p
fi
