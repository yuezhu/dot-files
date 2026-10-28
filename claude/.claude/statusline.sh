#!/bin/sh

# Claude Code statusline renderer.
#
# Reads Claude Code status JSON from stdin (produced by `claude status`)
# and prints two ANSI-colored lines suitable for embedding in a terminal
# statusline (e.g. tmux status-right).
#
#   Line 1: model · version · project dir (git branch) [› cwd]
#   Line 2: context-window usage bar · session cost · elapsed time
#
# Example:
#   Opus 4.6 (v1.0.20) | 📁 ~/my-project (main) › src/lib
#   ███░░░░░░░ 30% | 💰 $1.23 | ⏱️ 4m 12s

# --- Parse status JSON --------------------------------------------------------
# Capture stdin first, then emit shell assignments from the JSON so `eval`
# sets our variables in one pass.

INPUT=$(cat)

eval "$(echo "$INPUT" | jq -r '
  "MODEL=" + (.model.display_name | @sh),
  "VERSION=" + (.version // "" | @sh),
  "DIR=" + (.workspace.current_dir // .cwd // .workspace.project_dir // "." | @sh),
  "PROJECT=" + (.workspace.project_dir // "" | @sh),
  "COST=" + (.cost.total_cost_usd // 0 | tostring),
  "PCT=" + ((.context_window.used_percentage // 0) | ceil | tostring),
  "DURATION_MS=" + (.cost.total_duration_ms // 0 | floor | tostring)
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
  [ "$_pct" -gt 100 ] && _pct=100
  if [ "$_pct" -ge 90 ]; then
    _color="$RED"
  elif [ "$_pct" -ge 70 ]; then
    _color="$YELLOW"
  else _color="$GREEN"; fi

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

# human_duration <milliseconds>
#   Print elapsed time using the most natural unit pair:
#     < 1 min  → "5s"
#     < 1 hr   → "4m 12s"
#     < 1 day  → "1h 23m"
#     ≥ 1 day  → "2d 5h"
human_duration() {
  _total_secs=$(($1 / 1000))
  if [ "$_total_secs" -lt 60 ]; then
    printf '%ds' "$_total_secs"
  elif [ "$_total_secs" -lt 3600 ]; then
    printf '%dm %ds' "$((_total_secs / 60))" "$((_total_secs % 60))"
  elif [ "$_total_secs" -lt 86400 ]; then
    printf '%dh %dm' "$((_total_secs / 3600))" "$((_total_secs % 3600 / 60))"
  else
    printf '%dd %dh' "$((_total_secs / 86400))" "$((_total_secs % 86400 / 3600))"
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

# jq always emits a dot decimal; pin the locale so printf parses it.
COST_FMT=$(LC_NUMERIC=C printf '$%.2f' "$COST")

LOCATION=$(location "$PROJECT" "$DIR")

# Line 1: identity & location
printf '%s\n' "${CYAN}${MODEL}${RESET} (v${VERSION}) | 📁 ${LOCATION}"
# Line 2: resource gauges
printf '%s\n' "$(pct_bar "$PCT") | 💰 ${YELLOW}${COST_FMT}${RESET} | ⏱️ $(human_duration "$DURATION_MS")"
