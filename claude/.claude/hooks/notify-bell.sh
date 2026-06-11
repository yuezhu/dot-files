#!/bin/sh

# Send a bell character (\a) to the controlling terminal so that tmux
# (or any terminal emulator that supports it) can flash its status line
# or trigger a visual/audible alert. This is used as a Claude Code
# notification hook to signal that user interaction is needed.
#
# The script tries two methods to discover the correct tty:
#
#   1. Ask tmux directly (requires being inside a tmux session).
#   2. Fall back to /dev/tty, the process's controlling terminal
#      (works outside tmux on both Linux and macOS).
#
# Both methods fail gracefully — errors are suppressed and the script
# always exits 0 so it never blocks Claude Code.

# Method 1: If we're inside tmux, query it for this pane's tty.
# $TMUX is set by tmux in all child processes; $TMUX_PANE identifies
# the specific pane. The guard avoids calling tmux when not in a
# tmux session.
[ -n "$TMUX" ] && TTY=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_tty}' 2>/dev/null)

# Method 2: Fall back to /dev/tty, which always refers to the process's
# controlling terminal regardless of how stdin/stdout/stderr were
# redirected (Claude Code pipes JSON over stdin). A child of Claude Code
# inherits its controlling terminal, so this works outside tmux on both
# Linux and macOS. If the hook has no controlling terminal, the device
# check below fails and the bell is silently skipped.
[ -z "$TTY" ] && [ -c /dev/tty ] && TTY=/dev/tty

# Write the bell only if we resolved a valid character device, to
# avoid writing to pipes, regular files, or nonexistent paths.
[ -c "$TTY" ] && printf '\a' > "$TTY" 2>/dev/null

exit 0
