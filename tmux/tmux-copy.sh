#!/bin/sh
# tmux copy-pipe helper: copies selection to both the local system clipboard
# and the SSH client's clipboard (via OSC 52 escape sequence).
#
# Called by tmux copy-pipe, which pipes the selected text to stdin. The pane's
# TTY path is passed as $1 (via #{pane_tty} in .tmux.conf) so we can write
# the OSC 52 sequence back to the terminal.
#
# Flow:
#   1. Read selected text from stdin (provided by tmux copy-pipe)
#   2. Copy to local clipboard (xsel on Linux, pbcopy on macOS) when available
#   3. Base64-encode the text and emit an OSC 52 escape sequence to the pane TTY
#      - tmux sees the OSC 52 on the pane and (with set-clipboard on)
#        forwards it to the outer terminal AND sets the tmux paste buffer
#      - This uses tmux's built-in OSC 52 handling (set-clipboard), NOT
#        allow-passthrough - passthrough is for other escape sequences
#      - The outer terminal decodes the base64 and sets its own clipboard
#   4. If the base64 payload exceeds TMUX_OSC52_LIMIT, truncate and warn
#
# Requires:
#   - base64          (encode selection for OSC 52)
#   - tmux            (display-message for truncation warning)
#   - xsel OR pbcopy  (optional; local system clipboard)
#   - `set-clipboard on` or `external` in .tmux.conf (so tmux forwards
#     OSC 52 written to the pane TTY through to the outer terminal)
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
