#!/bin/sh

# Send a bell character (\a) to the controlling terminal so that tmux
# (or any terminal emulator that supports it) can flash its status line
# or trigger a visual/audible alert. This is used as a Claude Code
# notification hook to signal that user interaction is needed.
#
# The script tries two methods to discover the correct tty:
#
#   1. Ask tmux directly (requires being inside a tmux session).
#   2. Resolve the parent process's stderr fd via /proc (works outside
#      tmux on Linux).
#
# Both methods fail gracefully — errors are suppressed and the script
# always exits 0 so it never blocks Claude Code.

# Method 1: If we're inside tmux, query it for this pane's tty.
# $TMUX is set by tmux in all child processes; $TMUX_PANE identifies
# the specific pane. The guard avoids calling tmux when not in a
# tmux session.
[ -n "$TMUX" ] && TTY=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_tty}' 2>/dev/null)

# Method 2: Fall back to reading the parent process's stderr fd from
# procfs. This works on Linux even outside tmux, as long as stderr
# points to a real terminal device (e.g. /dev/pts/N).
[ -z "$TTY" ] && TTY=$(readlink "/proc/$PPID/fd/2" 2>/dev/null)

# Write the bell only if we resolved a valid character device, to
# avoid writing to pipes, regular files, or nonexistent paths.
[ -c "$TTY" ] && printf '\a' > "$TTY" 2>/dev/null

exit 0
