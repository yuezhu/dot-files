#!/bin/sh

# Claude Code statusline renderer.
#
# Reads Claude Code status JSON from stdin (produced by `claude status`)
# and prints two ANSI-colored lines suitable for embedding in a terminal
# statusline (e.g. tmux status-right).
#
#   Line 1: model · version · project dir · git branch
#   Line 2: context-window usage bar · session cost · elapsed time
#
# Example:
#   Opus 4.6 (v1.0.20) | 📁 my-project | 🌿 main
#   ███░░░░░░░ 30% | 💰 $1.23 | ⏱️ 4m 12s

# --- Parse status JSON --------------------------------------------------------
# Capture stdin first, then emit shell assignments from the JSON so `eval`
# sets our variables in one pass.

INPUT=$(cat)

eval "$(echo "$INPUT" | jq -r '
  "MODEL=" + (.model.display_name | @sh),
  "VERSION=" + (.version // "" | @sh),
  "DIR=" + (.workspace.current_dir | @sh),
  "COST=" + (.cost.total_cost_usd // 0 | tostring),
  "PCT=" + ((.context_window.used_percentage // 0) | ceil | tostring),
  "DURATION_MS=" + (.cost.total_duration_ms // 0 | tostring)
')"

# --- ANSI colors --------------------------------------------------------------

ESC=$(printf '\033')
CYAN="${ESC}[36m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
RED="${ESC}[31m"
RESET="${ESC}[0m"

# --- Helpers ------------------------------------------------------------------

# pct_bar <percentage>
#   Print a 10-segment bar (█/░) colored by threshold:
#     green (< 70%)  ·  yellow (70–89%)  ·  red (≥ 90%)
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

# human_duration <milliseconds>
#   Print elapsed time using the most natural unit pair:
#     < 1 min → "5s"  ·  < 1 hr → "4m 12s"  ·  ≥ 1 hr → "1h 23m"
human_duration() {
  _total_secs=$(($1 / 1000))
  if [ "$_total_secs" -lt 60 ]; then
    printf '%ds' "$_total_secs"
  elif [ "$_total_secs" -lt 3600 ]; then
    printf '%dm %ds' "$((_total_secs / 60))" "$((_total_secs % 60))"
  else
    printf '%dh %dm' "$((_total_secs / 3600))" "$((_total_secs % 3600 / 60))"
  fi
}

# --- Render -------------------------------------------------------------------

BRANCH=$(git branch --show-current 2>/dev/null)
[ -n "$BRANCH" ] && BRANCH=" | 🌿 $BRANCH"

COST_FMT=$(printf '$%.2f' "$COST")

# Line 1: identity & location
printf '%s\n' "${CYAN}${MODEL}${RESET} (v${VERSION}) | 📁 ${DIR##*/}$BRANCH"
# Line 2: resource gauges
printf '%s\n' "$(pct_bar "$PCT") | 💰 ${YELLOW}${COST_FMT}${RESET} | ⏱️ $(human_duration "$DURATION_MS")"
