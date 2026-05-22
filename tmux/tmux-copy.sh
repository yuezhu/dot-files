#!/bin/sh
# tmux copy helper: push the selection to the clipboard by two independent
# paths — the local system clipboard (xsel/pbcopy), and the outer terminal's
# clipboard via OSC 52 (which also works across SSH).
#
# - Run by the copy bindings' copy-pipe in .tmux.conf, which feeds the
#   selected text to this script's stdin. The pane's TTY path is passed as $1
#   (#{pane_tty}) so the script can write the OSC 52 sequence back to it.
# - Local system clipboard: the text is piped to xsel (Linux, when $DISPLAY is
#   set) or pbcopy (macOS) when available. Covers terminals without OSC 52.
# - OSC 52: the text is base64-encoded and written to the pane TTY as the
#   sequence ESC ] 52 ; c ; <base64> BEL. With `set-clipboard on`, tmux
#   intercepts it, sets its own paste buffer, and forwards it to the outer
#   terminal, which decodes the base64 and sets its clipboard. This rides
#   tmux's built-in OSC 52 handling, NOT allow-passthrough (passthrough is
#   for sequences tmux has no handler for).
# - Oversized payloads are truncated to TMUX_OSC52_LIMIT before encoding
#   (some terminals silently drop sequences past their limit) and a warning
#   is shown.
# - Requires base64; xsel or pbcopy are optional (local clipboard only).
#
# Usage (in .tmux.conf):
#   send-keys -FX copy-pipe "~/dot-files/tmux/tmux-copy.sh #{pane_tty}"

PANE_TTY="$1"

# Max base64 bytes to send via OSC 52 (default 100000 ≈ 75KB of raw data).
# Some terminals silently drop sequences beyond their limit.
LIMIT="${TMUX_OSC52_LIMIT:-100000}"

# Read the selected text from stdin (tmux copy-pipe feeds it here)
DATA="$(cat)"

# Set the local system clipboard if a clipboard tool is available.
# This is separate from OSC 52 - it handles the local X11/macOS clipboard.
if command -v xsel >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
  printf '%s' "$DATA" | xsel -i -p
  printf '%s' "$DATA" | xsel -i -b
elif command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$DATA" | pbcopy
fi

# Truncate raw data before encoding if it would exceed the OSC 52 limit.
# Truncating raw bytes (instead of the base64 output) keeps the encoding valid.
RAW_LIMIT=$(( LIMIT * 3 / 4 ))
DATA_LEN="${#DATA}"
if [ "$DATA_LEN" -gt "$RAW_LIMIT" ]; then
  DATA_KB=$(( DATA_LEN / 1024 ))
  LIMIT_KB=$(( RAW_LIMIT / 1024 ))
  DATA="$(printf '%s' "$DATA" | head -c "$RAW_LIMIT")"
  tmux display-message "OSC 52: selection truncated (${DATA_KB}KB > ${LIMIT_KB}KB)"
fi

# Base64-encode the text for embedding in the OSC 52 escape sequence.
# tr -d '\n' strips line breaks that base64 adds every 76 characters.
B64="$(printf '%s' "$DATA" | base64 | tr -d '\n')"

# Write the OSC 52 sequence to the pane's TTY. The sequence format is:
#   ESC ] 52 ; c ; <base64> BEL
# where "c" specifies the system clipboard. Writing to the pane TTY causes
# tmux to intercept the sequence and forward it to the attached client terminal.
if [ -n "$PANE_TTY" ] && [ -w "$PANE_TTY" ]; then
  printf '\033]52;c;%s\a' "$B64" > "$PANE_TTY"
fi
