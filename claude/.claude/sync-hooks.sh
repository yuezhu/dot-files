#!/bin/sh
# Sync Claude Code hooks and statusLine into the per-user config.
# Edit the OVERLAY block below, then run this script to propagate
# changes to ~/.claude/settings.json.
#
# Merge behavior:
#   - Hook events not in the overlay are kept as-is.
#   - For hook events in the overlay, overlay entries are appended to
#     existing ones. Duplicate entries (exact match) are skipped.
#   - statusLine is replaced outright.
#   - All other keys (permissions, model, etc.) are preserved.
set -eu

TARGET="$HOME/.claude/settings.json"

# --- Edit hooks and statusLine here ---
OVERLAY=$(cat <<'JSON'
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt|auth_success|elicitation_dialog",
        "hooks": [
          {
            "type": "command",
            "command": "sh ~/.claude/hooks/notify-bell.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh ~/.claude/hooks/notify-bell.sh"
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "sh ~/.claude/statusline.sh",
    "padding": 0
  }
}
JSON
)
# --- End of hooks/statusLine definition ---

# Require jq for JSON merging
if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 1
fi

# Merge overlay into target, preserving existing hook entries.
# For each hook event, append overlay entries that are not already
# present in the target. Other keys (statusLine) are replaced outright.
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
jq -s '
  # Helper: append entries from $new to $base, skipping exact duplicates
  def merge_arrays($base; $new):
    $base + [$new[] | select(. as $e | $base | any(. == $e) | not)];

  # Helper: merge two hook objects, combining arrays per event key
  def merge_hooks($base; $new):
    ($base | keys) + ($new | keys) | unique |
    reduce .[] as $k ({}; . + { ($k): merge_arrays($base[$k] // []; $new[$k] // []) });

  . as [$target, $overlay] |
  $target
  * ($overlay | del(.hooks))
  * { hooks: merge_hooks($target.hooks // {}; $overlay.hooks // {}) }
' "$TARGET" - <<EOF > "$TMPFILE"
$OVERLAY
EOF
mv -f "$TMPFILE" "$TARGET"

# Print summary of what was synced
echo "Synced to $TARGET:"
echo "$OVERLAY" | jq -r '
  (if .hooks then "  hooks: " + (.hooks | keys | join(", ")) else empty end),
  (if .statusLine then "  statusLine: \(.statusLine.type // "unknown")" else empty end)
'
