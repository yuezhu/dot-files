#!/bin/sh

# Parse Claude Code status JSON from stdin into shell variables.
# Example output:
#   MODEL='Opus 4.6 (1M context)'
#   DIR='/home/user/project'
#   COST=1.23
#   PCT=5
#   DURATION_MS=95000
#   USED_TOKENS=52198
#   CTX_SIZE=1000000
eval $(jq -r '
  "MODEL=" + (.model.display_name | @sh),
  "DIR=" + (.workspace.current_dir | @sh),
  "COST=" + (.cost.total_cost_usd // 0 | tostring),
  "PCT=" + ((.context_window.used_percentage // 0) | floor | tostring),
  "DURATION_MS=" + (.cost.total_duration_ms // 0 | tostring),
  "USED_TOKENS=" + (((.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.output_tokens // 0)) | tostring),
  "CTX_SIZE=" + ((.context_window.context_window_size // 0) | tostring)
')

# PCT = context window usage as a percentage (0-100). When
# current_usage data is available we compute it from raw tokens (sum
# of all input and output tokens / context window size); otherwise we
# fall back to used_percentage.
if [ "$CTX_SIZE" -gt 0 ] && [ "$USED_TOKENS" -gt 0 ]; then
  PCT=$((USED_TOKENS * 100 / CTX_SIZE))
  [ "$PCT" -gt 100 ] && PCT=100
fi

ESC=$(printf '\033')
CYAN="${ESC}[36m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
RED="${ESC}[31m"
RESET="${ESC}[0m"

# Render a 10-segment bar with color based on percentage.
# Resolution is 10% per segment; finer granularity (e.g. half-blocks)
# leaves visible gaps in terminal character cells. The exact
# percentage is shown as a number beside the bar.
# Usage: pct_bar <percentage>
# Output: colored "█░░░░░░░░░ 27%" string
pct_bar() {
  _pct=$1
  if [ "$_pct" -ge 90 ]; then _color="$RED"
  elif [ "$_pct" -ge 70 ]; then _color="$YELLOW"
  else _color="$GREEN"; fi

  _filled=$((_pct / 10))
  _i=0
  _bar=""
  while [ $_i -lt $_filled ]; do
    _bar="${_bar}█"
    _i=$((_i+1))
  done
  while [ $_i -lt 10 ]; do
    _bar="${_bar}░"
    _i=$((_i+1))
  done

  printf '%s' "${_color}${_bar}${RESET} ${_pct}%"
}

MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=$(git branch --show-current 2>/dev/null)
if [ -n "$BRANCH" ]; then
  BRANCH=" | 🌿 $BRANCH"
else
  BRANCH=""
fi

COST_FMT=$(printf '$%.2f' "$COST")
printf '%s\n' "${CYAN}${MODEL}${RESET} | 📁 ${DIR##*/}$BRANCH"
printf '%s\n' "$(pct_bar "$PCT") | 💰 ${YELLOW}${COST_FMT}${RESET} | ⏱ ${MINS}m ${SECS}s"
