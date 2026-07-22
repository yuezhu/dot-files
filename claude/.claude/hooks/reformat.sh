#!/bin/sh

# Claude Code PostToolUse hook: auto-format a file after Claude edits it.
#
# Reads the hook payload as JSON on stdin, pulls out the edited file path,
# and runs the matching formatter. Wire it in settings.json under PostToolUse
# with matcher "Write|Edit|NotebookEdit".

# have TOOL -> success if TOOL is on PATH.
have() {
  command -v "$1" >/dev/null 2>&1
}

# shebang_interp FILE -> prints the interpreter named in FILE's shebang
# (basename, resolving `env INTERP`), or nothing if there is no shebang.
# Reads only the first line, capped at the kernel's 256-byte shebang limit,
# so a huge single-line file is not slurped whole. Meant to be called in a
# command substitution, whose subshell confines the `set` changes below.
shebang_interp() {
  first_line=$(head -c 256 "$1" 2>/dev/null | head -n 1)
  case "$first_line" in
  '#!'*) ;;
  *) return ;;
  esac
  rest=${first_line#\#!}
  set -f
  # shellcheck disable=SC2086 # intentional word splitting
  set -- $rest
  set +f
  interp=${1##*/}
  [ "$interp" = env ] && interp=${2##*/}
  printf '%s' "$interp"
}

# file_kind FILE -> dispatch token: the lowercased extension when the basename
# has one, else the shebang interpreter. A pure detector; it knows the
# formatters only through the token the dispatch below matches on.
file_kind() {
  base=${1##*/}
  case "$base" in
  *.*) printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]' ;;
  *) shebang_interp "$1" ;;
  esac
}

json_input=$(cat)

# Edit/Write pass the path as .tool_input.file_path; NotebookEdit uses
# .tool_input.notebook_path. Prefer jq; fall back to a best-effort grep
# (single match only) when jq is unavailable.
if have jq; then
  file_path=$(printf '%s' "$json_input" |
    jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
else
  file_path=$(printf '%s' "$json_input" |
    grep -oE '"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"[^"]*"' |
    head -n1 |
    sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')
fi

# Nothing to do without a path to an existing file.
if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
  exit 0
fi

# Dispatch on the file's kind. Each arm lists every token (extension or shebang
# interpreter) that routes to its formatter, so extensionless scripts and
# extensioned files share one table. Add new types as arms; e.g. Python by
# shebang would extend the ruff arm to `py | ipynb | python | python3`.
case "$(file_kind "$file_path")" in
js | jsx | ts | tsx | md)
  have prettier && prettier --write "$file_path" >/dev/null 2>&1
  ;;

py | ipynb)
  # check --fix applies lint autofixes (e.g. unused-import removal, import
  # sorting); format then handles layout.
  if have ruff; then
    ruff check --fix "$file_path" >/dev/null 2>&1
    ruff format "$file_path" >/dev/null 2>&1
  fi
  ;;

java)
  # --replace: in place; --aosp: AOSP (4-space) style.
  have google-java-format &&
    google-java-format --skip-reflowing-long-strings --replace --aosp "$file_path" >/dev/null 2>&1
  ;;

cc | hh)
  have clang-format && clang-format -i "$file_path" >/dev/null 2>&1
  ;;

go)
  # goimports already applies gofmt formatting, so no separate go fmt.
  have goimports && goimports -w "$file_path" >/dev/null 2>&1
  ;;

sh | bash | dash | mksh)
  # shfmt honors .editorconfig for indentation; handles sh/bash/dash/mksh.
  have shfmt && shfmt -w "$file_path" >/dev/null 2>&1
  ;;
esac

# Always succeed so formatting never blocks Claude's operations.
exit 0
