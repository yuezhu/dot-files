#!/bin/sh

# Claude Code statusline renderer.
#
# Reads Claude Code status JSON from stdin (produced by `claude status`)
# and prints two ANSI-colored lines suitable for embedding in a terminal
# statusline (e.g. tmux status-right).
#
#   Line 1: model · version · project dir (git branch) [› cwd]
#   Line 2: context-window usage bar · elapsed time · session cost · plan usage
#
# Plan usage (5-hour and weekly rate limits) only exists on a Claude.ai
# subscription, and only after the first API response; on Vertex or an API
# key it is absent and the segment is left out.
#
# Example:
#   Opus 4.6 (v1.0.20) | 📁 ~/my-project (main) › src/lib
#   ███░░░░░░░ 30% | ⏱️ 4m 12s | 💰 $1.23 | ⏳ 5h 42% ↻ 2:30 PM · 7d 18% ↻ Fri 9:00 AM

# --- Parse status JSON --------------------------------------------------------
# Capture stdin first, then emit shell assignments from the JSON so `eval`
# sets our variables in one pass.
#
# jq also does all the value formatting, so the shell below only lays out and
# colors the pieces. Doing it here needs no extra processes, and jq behaves
# the same on macOS and Linux and in any locale, unlike `date` and `printf`:
#   - cost: two decimals, always with a dot
#   - elapsed time: the most natural unit pair, "5s" · "4m 12s" · "1h 23m" ·
#     "2d 5h"
#   - plan reset times: local time zone via strflocaltime. LC_ALL=C keeps %p
#     as AM/PM; a 24-hour locale would print nothing for it.
#
# A window whose reset time has already passed is dropped: its numbers are
# from before the reset, and stay that way until the next API response
# refreshes them.

INPUT=$(cat)

eval "$(echo "$INPUT" | LC_ALL=C jq -r '
  # Guard on type: a non-number would make jq abort mid-output and silently
  # drop every assignment after it.
  def pct: if type == "number" then ceil | tostring else "" end;
  def usd:
    if type == "number" then . else 0 end
    | . * 100 | round
    | "$\(. / 100 | floor).\(. % 100 | tostring | if length < 2 then "0" + . else . end)";
  def duration:
    (if type == "number" then . / 1000 | floor else 0 end) as $s
    | if   $s < 60    then "\($s)s"
      elif $s < 3600  then "\($s / 60 | floor)m \($s % 60)s"
      elif $s < 86400 then "\($s / 3600 | floor)h \($s % 3600 / 60 | floor)m"
      else "\($s / 86400 | floor)d \($s % 86400 / 3600 | floor)h" end;
  def window($fmt):
    if (.resets_at | type) == "number" and .resets_at <= now then
      { pct: "", reset: "" }
    else
      { pct: (.used_percentage | pct),
        reset: (.resets_at
                | if type == "number" then
                    floor | strflocaltime($fmt)
                  else "" end) }
    end;
  (.rate_limits.five_hour | window("%-I:%M %p")) as $five |
  (.rate_limits.seven_day | window("%a %-I:%M %p")) as $week |
  "MODEL=" + (.model.display_name | @sh),
  "VERSION=" + (.version // "" | @sh),
  "DIR=" + (.workspace.current_dir // .cwd // .workspace.project_dir // "." | @sh),
  "PROJECT=" + (.workspace.project_dir // "" | @sh),
  "COST=" + (.cost.total_cost_usd | usd | @sh),
  "PCT=" + ((.context_window.used_percentage // 0) | ceil | tostring),
  "DURATION=" + (.cost.total_duration_ms | duration | @sh),
  "FIVE_H=" + $five.pct,
  "FIVE_H_RESET=" + ($five.reset | @sh),
  "WEEK=" + $week.pct,
  "WEEK_RESET=" + ($week.reset | @sh)
')"

# --- ANSI colors --------------------------------------------------------------

ESC=$(printf '\033')
CYAN="${ESC}[36m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
RED="${ESC}[31m"
DIM="${ESC}[2m"
RESET="${ESC}[0m"

# --- Helpers ------------------------------------------------------------------

# pct_color <percentage>
#   Set _color for a usage percentage:
#     green (< 70%)  ·  yellow (70–89%)  ·  red (≥ 90%)
#   Sets a variable rather than printing, so callers avoid a $(...) fork.
pct_color() {
  if [ "$1" -ge 90 ]; then
    _color="$RED"
  elif [ "$1" -ge 70 ]; then
    _color="$YELLOW"
  else _color="$GREEN"; fi
}

# pct_bar <percentage>
#   Print a 10-segment bar (█/░) colored by pct_color.
pct_bar() {
  _pct=$1
  [ "$_pct" -gt 100 ] && _pct=100
  pct_color "$_pct"

  _filled=$((_pct / 10))
  _i=0
  _bar=""
  while [ $_i -lt $_filled ]; do
    _bar="${_bar}█"
    _i=$((_i + 1))
  done
  while [ $_i -lt 10 ]; do
    _bar="${_bar}░"
    _i=$((_i + 1))
  done

  printf '%s' "${_color}${_bar}${RESET} ${_pct}%"
}

# rate_window <label> <percentage> <reset-time>
#   Print one rate-limit window, e.g. "5h 42% ↻ 2:30 PM": the percentage
#   colored by pct_color, then the local reset time, dimmed. A wall-clock time
#   rather than a countdown, since the statusline only redraws on session
#   activity and a countdown would go stale while idle. Prints nothing
#   without a percentage; the reset time is skipped when empty.
rate_window() {
  [ -n "$2" ] || return 0
  pct_color "$2"
  printf '%s' "$1 ${_color}$2%${RESET}"
  [ -n "$3" ] && printf '%s' " ${DIM}↻ $3${RESET}"
}

# plan_usage <5h-pct> <5h-reset> <weekly-pct> <weekly-reset>
#   Print the plan rate-limit usage, e.g.
#   "5h 42% ↻ 2:30 PM · 7d 18% ↻ Fri 9:00 AM".
#   Either window may be empty and is then skipped; prints nothing when both
#   are.
plan_usage() {
  _five=$(rate_window 5h "$1" "$2")
  _week=$(rate_window 7d "$3" "$4")
  if [ -n "$_five" ] && [ -n "$_week" ]; then
    printf '%s' "$_five · $_week"
  else
    printf '%s' "$_five$_week"
  fi
}

# git_ref <dir>
#   Print the checked-out branch of the repo containing <dir>, or the short
#   commit hash when HEAD is detached with no branch to inherit. Prints
#   nothing outside a repo.
git_ref() {
  _dir=$1
  _hops=0

  # A submodule is normally checked out detached at the commit its parent
  # pins, so it has no branch of its own — the branch being worked on lives
  # in the superproject. Walk up until one reports a branch; the loop repeats
  # for submodules nested inside submodules, and the cap stops a malformed
  # setup from spinning.
  while [ -n "$_dir" ] && [ "$_hops" -lt 8 ]; do
    # symbolic-ref reports the branch even in a repo with no commits yet,
    # where `git branch --show-current` and rev-parse both come up empty.
    git -C "$_dir" symbolic-ref --quiet --short HEAD 2>/dev/null && return 0

    _dir=$(git -C "$_dir" rev-parse --show-superproject-working-tree 2>/dev/null)
    _hops=$((_hops + 1))
  done

  # Genuinely detached: mid-rebase or bisect, or a tag or commit checked out.
  _sha=$(git -C "$1" rev-parse --short HEAD 2>/dev/null) || return 0
  printf '%s' "@$_sha"
}

# pretty_path <path>
#   Abbreviate $HOME to ~ and drop control characters, so a hostile directory
#   name can't inject terminal escapes or break the line.
pretty_path() {
  case "$1" in
  "$HOME" | "$HOME"/*) _p="~${1#"$HOME"}" ;;
  *) _p=$1 ;;
  esac
  printf '%s' "$_p" | tr -d '\000-\037\177'
}

# location <project> <cwd>
#   Print the location segment: the Claude project (the directory the session
#   was launched in) with its branch, then the cwd only when it has moved
#   away, relative inside the project and absolute outside it. The cwd gets
#   its own branch only when that differs, e.g. a separate repo outside the
#   project. An empty <project> falls back to <cwd>.
#
#     ~/dot-files (master)
#     ~/dot-files (master) › claude/.claude
#     ~/dot-files (master) › ~/other (main)
#
#   Branches are resolved against the given directories rather than this
#   script's own working directory: Claude Code spawns the statusline command
#   from the session cwd, which falls back to the project root if that
#   directory has gone away.
location() {
  _project=${1:-$2}
  _cwd=$2

  _project_branch=$(git_ref "$_project")
  _loc=$(pretty_path "$_project")
  [ -n "$_project_branch" ] && _loc="$_loc ($_project_branch)"

  if [ "$_cwd" != "$_project" ]; then
    case "$_cwd" in
    "$_project"/*) _loc="$_loc › $(pretty_path "${_cwd#"$_project"/}")" ;;
    *) _loc="$_loc › $(pretty_path "$_cwd")" ;;
    esac
    _cwd_branch=$(git_ref "$_cwd")
    if [ -n "$_cwd_branch" ] && [ "$_cwd_branch" != "$_project_branch" ]; then
      _loc="$_loc ($_cwd_branch)"
    fi
  fi

  printf '%s' "$_loc"
}

# --- Render -------------------------------------------------------------------

LOCATION=$(location "$PROJECT" "$DIR")

USAGE=$(plan_usage "$FIVE_H" "$FIVE_H_RESET" "$WEEK" "$WEEK_RESET")
[ -n "$USAGE" ] && USAGE=" | ⏳ $USAGE"

# Line 1: identity & location
printf '%s\n' "${CYAN}${MODEL}${RESET} (v${VERSION}) | 📁 ${LOCATION}"
# Line 2: resource gauges, session-scoped first, then account-wide plan usage
printf '%s\n' "$(pct_bar "$PCT") | ⏱️ ${DURATION} | 💰 ${YELLOW}${COST}${RESET}${USAGE}"
