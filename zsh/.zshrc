## Helpers

# Print the first existing directory from the given candidates
function _first_dir {
  local d
  for d in "$@"; do
    [[ -d "$d" ]] && { print -r -- "$d"; return; }
  done
  return 1
}

# Print the first executable file from the given candidates
function _first_exec {
  local f
  for f in "$@"; do
    [[ -x "$f" ]] && { print -r -- "$f"; return; }
  done
  return 1
}

# Prepend each existing directory to path
function _prepend_path {
  local d
  for d in "$@"; do
    [[ -d "$d" ]] && path=("$d" $path)
  done
}

# Prepend each existing directory to fpath
function _prepend_fpath {
  local d
  for d in "$@"; do
    [[ -d "$d" ]] && fpath=("$d" $fpath)
  done
}

## Environment & Path

# Ensure uniqueness for path and fpath arrays
typeset -U path
typeset -U fpath

# Homebrew
if brew=$(_first_exec /usr/local/bin/brew /opt/homebrew/bin/brew); then
  eval "$($brew shellenv)"
fi

# Default to empty string so ${HOMEBREW_PREFIX}/... expansions are safe on
# systems without homebrew (e.g. Linux), and set -u won't error on unbound variable
: "${HOMEBREW_PREFIX:=}"

# Homebrew binaries
_prepend_path \
  "${HOMEBREW_PREFIX}/opt/gawk/libexec/gnubin" \
  "${HOMEBREW_PREFIX}/opt/gnu-sed/libexec/gnubin" \
  "${HOMEBREW_PREFIX}/opt/findutils/libexec/gnubin" \
  "${HOMEBREW_PREFIX}/opt/curl/bin"

# Personal binaries
_prepend_path \
  "${HOME}/bin" \
  "${HOME}/Library/Mobile Documents/com~apple~CloudDocs/bin"

# Additional completion functions
_prepend_fpath \
  "${HOME}/.nix-profile/share/zsh/site-functions" \
  "${HOMEBREW_PREFIX}/share/zsh-completions"

## fzf

if exe=$(_first_exec \
           "${HOME}/.nix-profile/bin/fzf" \
           "${HOMEBREW_PREFIX}/bin/fzf"); then

  export FZF_DEFAULT_OPTS="--height 40% \
    --layout reverse \
    --border top \
    --wrap \
    --highlight-line \
    --preview 'printf \"%s\\n\" {}' \
    --preview-window hidden,wrap \
    --color 'hl:underline:yellow,hl+:underline:yellow:bold' \
    --bind \
alt-.:toggle-preview,\
ctrl-a:beginning-of-line,\
ctrl-e:end-of-line,\
ctrl-f:forward-char,\
ctrl-b:backward-char,\
ctrl-d:delete-char,\
ctrl-h:backward-delete-char,\
ctrl-k:kill-line,\
ctrl-u:unix-line-discard,\
ctrl-w:unix-word-rubout,\
alt-v:page-up,\
ctrl-v:page-down,\
alt-f:forward-word,\
alt-b:backward-word,\
alt-d:kill-word,\
alt-bs:backward-kill-word"

  export FZF_CTRL_R_OPTS="--wrap-sign '"$'\t'"↳ ' \
    --exact \
    --no-sort"

  source <("$exe" --zsh)
fi

## Completion

# Export LS_COLORS (used by completion list-colors below)
if exe=$(_first_exec "${HOMEBREW_PREFIX}/bin/gdircolors" /usr/bin/dircolors); then
  eval "$($exe -b)"
fi

autoload -Uz compinit

# Speed up zsh compinit by only checking cache once a day
#
# The option -u makes compinit skip security check and all files found be
# used.
#
# The option -C skips the check performed to see if there are new functions
# can be omitted. In this case the dump file will only be created if there
# isn't one already.
#
# Use an anonymous function that takes a file name as an argument using glob
# qualifiers (N.mh+24) when EXTENDED_GLOB is not enabled. In contrast, if
# EXTENDED_GLOB is enabled, globbing will be performed for [[ -n
# ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]:
#
# - '#q' is an explicit glob qualifier that makes globbing work within zsh's
#   [[ ]] construct.
# - 'N' makes the glob pattern evaluate to nothing when it doesn't match
#   (rather than throw a globbing error)
# - '.' matches "regular files"
# - 'mh+24' matches files (or directories or whatever) that are older than 24
#   hours.
# https://gist.github.com/ctechols/ca1035271ad134841284#gistcomment-3109177
ZSH_COMPDUMP=${ZDOTDIR:-$HOME}/.zcompdump

# `() { }` is a zsh anonymous function, not a subshell. shellcheck does not
# support zsh and misparses it as bash, triggering SC1072/SC1073.
# shellcheck disable=SC1072,SC1073
() {
  if [[ $# -gt 0 ]]; then
    compinit -u
  else
    compinit -C
  fi
} ${ZSH_COMPDUMP}(N.mh+24)

# http://zsh.sourceforge.net/Doc/Release/Options.html
# If a completion is performed with the cursor within a word, and a full
# completion is inserted, the cursor is moved to the end of the word. That is,
# the cursor is moved to the end of the word if either a single match is
# inserted or menu completion is performed.
setopt ALWAYS_TO_END

# If unset, the cursor is set to the end of the word if completion is
# started. Otherwise it stays there and completion is done from both ends.
setopt COMPLETE_IN_WORD

# Do not require a leading '.' in a filename to be matched explicitly.
setopt GLOB_DOTS

if dir=$(_first_dir \
           "${HOME}/.nix-profile/share/fzf-tab" \
           "${HOMEBREW_PREFIX}/share/fzf-tab"); then

  source "${dir}/fzf-tab.zsh"

  # force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
  zstyle ':completion:*' menu no

else
  # Native zsh completion UI — only needed when fzf-tab is absent.
  # complist provides menuselect keymap and colored completion listings.
  zmodload -i zsh/complist

  # When listing files that are possible completions, show the type of each file
  # with a trailing identifying mark, like the -F option to ls.
  setopt LIST_TYPES

  # Lay out the matches in completion lists sorted horizontally, that is, the
  # second match is to the right of the first one, not under it as usual.
  setopt LIST_ROWS_FIRST

  # On an ambiguous completion, instead of listing possibilities or beeping,
  # insert the first match immediately.
  # This causes the current candidate to be selected and inserted immediately
  # without having to press TAB.
  setopt MENU_COMPLETE

  # Try to make the completion list smaller (occupying less lines) by printing
  # the matches in columns with different widths.
  setopt LIST_PACKED

  # Incremental completion searching
  bindkey -M menuselect '^s' history-incremental-search-forward

  # Enable menu selection
  # Display a list of candidates for an ambiguous completion when hitting TAB
  zstyle ':completion:*' menu select

  # Highlight the first ambiguous character in completion lists
  zstyle ':completion:*' show-ambiguity true

  # Enable scrolling through a completion list
  zstyle ':completion:*:default' list-prompt ''

  # Colorize kill completion menu (pid=red, user=cyan, etime=yellow, command=default)
  zstyle ':completion:*:*:*:*:processes' list-colors '=(#b) #([0-9]##) ([0-9a-z_-]##) #([^ ]##) *=0=31=36=33'
fi

# Display lists of matches for files in different colours depending on the file
# type
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Disable completion for `.' and `..' special directories
zstyle ':completion:*' special-dirs false

# Allow up to 1 typo for approximate completion
zstyle ':completion:*' max-errors 1

# Ignore shell functions that should not be used individually
zstyle ':completion:*:functions' ignored-patterns '_*'

# Ignore completion for uninterested users
zstyle ':completion:*:*:*:users' ignored-patterns '_*'

# Ignore backup files when completing commands
zstyle ':completion:*:complete:-command-::commands' ignored-patterns '*~'

# Kill command completion
zstyle ':completion:*:*:kill:*:processes' command 'ps -U ${USERNAME} -o pid,user,etime,command | sed "/ps -U '\''${USERNAME}'\''/d"'

## History

# This option both imports new commands from the history file, and also causes
# your typed commands to be appended to the history file (the latter is like
# specifying INC_APPEND_HISTORY, which should be turned off if this option is in
# effect). The history lines are also output with timestamps ala
# EXTENDED_HISTORY (which makes it easier to find the spot where we left off
# reading the file after it gets re-written).
setopt SHARE_HISTORY

# If a new command line being added to the history list duplicates an older one,
# the older command is removed from the list (even if it is not the previous
# event). This is a superset of HIST_IGNORE_DUPS, so the latter is not needed.
setopt HIST_IGNORE_ALL_DUPS

# Remove command lines from the history list when the first character on the
# line is a space, or when one of the expanded aliases contains a leading space.
setopt HIST_IGNORE_SPACE

# Remove superfluous blanks from each command line being added to the history
# list.
setopt HIST_REDUCE_BLANKS

# If the internal history needs to be trimmed to add the current command line,
# setting this option will cause the oldest history event that has a duplicate to
# be lost before losing a unique event from the list.
setopt HIST_EXPIRE_DUPS_FIRST

# Save each command's beginning timestamp (in seconds since the epoch) and the
# duration (in seconds) to the history file.
setopt EXTENDED_HISTORY

# Exclude some commands from history.
zshaddhistory() {
  # Strip trailing newline that zsh always appends to $1
  local cmd="${1%%$'\n'}"

  # Strip leading whitespace to normalize before checks.
  # Note: HIST_IGNORE_SPACE will also discard space-prefixed commands at write
  # time, but we need clean input for accurate length and pattern matching here.
  local cmd_trim="${cmd##[[:space:]]#}"

  # Discard commands that are too short to be meaningful
  (( ${#cmd_trim} >= 4 )) || return 1

  # Discard noisy commands not worth keeping
  [[ $cmd_trim != (ls|ll|la|exa|eza)(\ *)# ]] || return 1
  [[ $cmd_trim != (cd|pwd|exit|clear|reset|fg|bg|jobs|make-all) ]] || return 1

  # Discard lookup commands — easy to re-type, clutter history
  [[ $cmd_trim != (man|which|type|where|whence)\ * ]] || return 1

  return 0
}

# The value of HISTSIZE needs to be a larger number than SAVEHIST for
# HIST_EXPIRE_DUPS_FIRST to work properly.
HISTSIZE=2000000
SAVEHIST=1000000
HISTFILE="${HOME}/.zsh_history"

## Prompt

# Allow dynamic command prompt
# Substitutions within prompts do not affect the command status.
setopt PROMPT_SUBST

autoload -Uz add-zsh-hook

# Enable VCS info
autoload -Uz vcs_info

# Only enable for a few frequently used VCS tools
zstyle ':vcs_info:*' enable git

# Update each time new prompt is rendered
add-zsh-hook precmd vcs_info

# Minimal VCS information in prompt
# https://zsh.sourceforge.io/Doc/Release/User-Contributions.html#Version-Control-Information
zstyle ':vcs_info:git:*' formats ' %F{cyan}%b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{cyan}%b|%a%f'

# zstyle ':vcs_info:git:*' check-for-changes true
# zstyle ':vcs_info:git:*' stagedstr '+'
# zstyle ':vcs_info:git:*' unstagedstr '*'
# zstyle ':vcs_info:git:*' formats ' %F{cyan}%b%u%c%f'
# zstyle ':vcs_info:git:*' actionformats ' %F{cyan}%b|%a%u%c%f'

# https://github.com/ohmyzsh/ohmyzsh/tree/master/themes
# https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html
PROMPT='%B%F{green}%m%f %F{blue}%~%f${vcs_info_msg_0_} %#%b '
#RPROMPT=' %B%D{%H:%M:%S.%.}%b'

## Shell Options

# Characters considered part of a word for word-based movement and deletion
# Default is *?_-.[]~=/&;!#$%^(){}<>
WORDCHARS='*?_.[]~&;!#$%^(){}<>'

# Try to correct the spelling of all arguments in a line.
# The shell variable CORRECT_IGNORE_FILE may be set to a pattern to match file
# names that will never be offered as corrections.
# setopt CORRECT_ALL
setopt NO_CORRECT_ALL

# Disable flow control so that the keybindings ^S/^Q can be assigned.
setopt NO_FLOW_CONTROL

# Allow comments even in interactive shells
setopt INTERACTIVE_COMMENTS

## Terminal

# Terminal titles
# https://wiki.archlinux.org/title/zsh#xterm_title
# For expansion definition:
# https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html#Prompt-Expansion
function xterm_title { print -Pn -- '\e]2;%m: %~\a' }
add-zsh-hook precmd xterm_title

# Use steady block cursor with default color, and restore it after programs
# that change cursor shape or color (e.g. vim with mode-dependent cursors).
function reset_cursor { print -Pn -- '\e[2 q\e]112\a' }
add-zsh-hook precmd reset_cursor

# Disable the suspend keybinding (Ctrl-Z)
# stty susp undef

# Configure pinentry to use the correct TTY
export GPG_TTY=$TTY

## Plugins

# zsh-autosuggestions
if dir=$(_first_dir \
           "${HOME}/.nix-profile/share/zsh-autosuggestions" \
           "${HOMEBREW_PREFIX}/share/zsh-autosuggestions"); then
  source "${dir}/zsh-autosuggestions.zsh"
fi

# zsh-fast-syntax-highlighting
if dir=$(_first_dir \
           "${HOME}/.nix-profile/share/zsh/plugins/fast-syntax-highlighting" \
           "${HOMEBREW_PREFIX}/share/zsh-fast-syntax-highlighting"); then
  source "${dir}/fast-syntax-highlighting.plugin.zsh"
elif dir=$(_first_dir \
             "${HOME}/.nix-profile/share/zsh-syntax-highlighting" \
             "${HOMEBREW_PREFIX}/share/zsh-syntax-highlighting"); then
  # Or try zsh-syntax-highlighting
  export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR="${dir}/highlighters"
  source "${dir}/zsh-syntax-highlighting.zsh"
  export ZSH_HIGHLIGHT_STYLES[comment]='fg=245'
fi

## Pager

export PAGER=less
export LESS='--ignore-case --LONG-PROMPT --RAW-CONTROL-CHARS --window=-4'
export LESS_TERMCAP_so=$'\e[33m\e[7m'
export LESS_TERMCAP_se=$'\e[0m'

## Aliases

case $OSTYPE in
  *linux*)
    alias ls='ls --color=auto --group-directories-first' ;;
  *darwin*)
    # Use `command -v` instead of `which` — POSIX-compliant and faster
    case $(command -v ls) in
      *gnubin*)
        alias ls='ls --color=auto --group-directories-first' ;;
      *)
        alias ls='ls -GT'
        export CLICOLOR=1
        export LSCOLORS='ExGxbxdxCxegedabagacad' ;;
    esac
    alias htop="sudo ${HOMEBREW_PREFIX}/bin/htop" ;;
esac

alias l='ls -CF'
alias ll='ls -lahF'
alias lt='ll -rt'

alias grep='grep --color=auto'
# fgrep/egrep are deprecated; use grep -F/-E instead
alias fgrep='grep -F --color=auto'
alias egrep='grep -E --color=auto'

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias history='history -i 0'

## Custom

if [[ -f ~/.zsh_custom ]]; then
  . ~/.zsh_custom
fi
