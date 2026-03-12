#!/bin/sh

# Claude Code statusline renderer.
#
# Reads the Claude Code status JSON from stdin and renders a two-line
# summary for use in a terminal statusline (e.g. tmux status-right).
#
# Line 1: model name, version, working directory, git branch
# Line 2: context window bar, session cost, elapsed time
#
# Example output:
#   Opus 4.6 (1M context) (v1.0.20) | 📁 my-project | 🌿 main
#   ███░░░░░░░ 30% | 💰 $1.23 | ⏱️ 4m 12s

# --- Extract fields from JSON -----------------------------------------------

eval "$(jq -r '
  "MODEL=" + (.model.display_name | @sh),
  "VERSION=" + (.version // "" | @sh),
  "DIR=" + (.workspace.current_dir | @sh),
  "COST=" + (.cost.total_cost_usd // 0 | tostring),
  "PCT=" + ((.context_window.used_percentage // 0) | ceil | tostring),
  "DURATION_MS=" + (.cost.total_duration_ms // 0 | tostring),
  "USED_TOKENS=" + (((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)) | tostring),
  "CTX_SIZE=" + ((.context_window.context_window_size // 0) | tostring)
')"

# --- Compute context window percentage --------------------------------------

# Prefer raw token counts over the pre-computed used_percentage, since
# the latter may be stale or rounded.  Cap at 100%.
if [ "$CTX_SIZE" -gt 0 ] && [ "$USED_TOKENS" -gt 0 ]; then
  PCT=$((USED_TOKENS * 100 / CTX_SIZE))
  [ "$PCT" -gt 100 ] && PCT=100
fi

# --- ANSI colors -------------------------------------------------------------

ESC=$(printf '\033')
CYAN="${ESC}[36m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
RED="${ESC}[31m"
RESET="${ESC}[0m"

# --- Helpers -----------------------------------------------------------------

# pct_bar <percentage>
#   Render a 10-segment progress bar colored by severity:
#     green (<70%)  yellow (70-89%)  red (>=90%)
#   Example: "███░░░░░░░ 27%"
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

# --- Render ------------------------------------------------------------------

MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=$(git branch --show-current 2>/dev/null)
if [ -n "$BRANCH" ]; then
  BRANCH=" | 🌿 $BRANCH"
else
  BRANCH=""
fi

COST_FMT=$(printf '$%.2f' "$COST")
printf '%s\n' "${CYAN}${MODEL}${RESET} (v${VERSION}) | 📁 ${DIR##*/}$BRANCH"
printf '%s\n' "$(pct_bar "$PCT") | 💰 ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s"
