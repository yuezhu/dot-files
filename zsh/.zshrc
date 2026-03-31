## Ensure uniqueness for path and fpath arrays
typeset -U path
typeset -U fpath

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

## Export homebrew environment variables
if brew=$(_first_exec /usr/local/bin/brew /opt/homebrew/bin/brew); then
  eval "$($brew shellenv)"
fi
# Default to empty string so ${HOMEBREW_PREFIX}/... expansions are safe on
# systems without homebrew (e.g. Linux), and set -u won't error on unbound variable
: "${HOMEBREW_PREFIX:=}"

## Use binaries from homebrew
_prepend_path \
  "${HOMEBREW_PREFIX}/opt/gawk/libexec/gnubin" \
  "${HOMEBREW_PREFIX}/opt/gnu-sed/libexec/gnubin" \
  "${HOMEBREW_PREFIX}/opt/findutils/libexec/gnubin" \
  "${HOMEBREW_PREFIX}/opt/curl/bin"

## Override with my own binaries
_prepend_path \
  "${HOME}/bin" \
  "${HOME}/Library/Mobile Documents/com~apple~CloudDocs/bin"

## zsh-autosuggestions
if dir=$(_first_dir \
           "${HOME}/.nix-profile/share/zsh-autosuggestions" \
           "${HOMEBREW_PREFIX}/share/zsh-autosuggestions"); then
  source "${dir}/zsh-autosuggestions.zsh"
fi


## zsh-fast-syntax-highlighting
if dir=$(_first_dir \
           "${HOME}/.nix-profile/share/zsh-fast-syntax-highlighting" \
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

## zsh-completions
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
--bind \
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

  source <("$exe" --zsh)
fi

# Export LS_COLORS
if exe=$(_first_exec "${HOMEBREW_PREFIX}/bin/gdircolors" /usr/bin/dircolors); then
  eval "$($exe -b)"
fi

# Enable colored menu and scrolling completion in completion listings
# This needs to be loaded before calling compinit.
# http://zsh.sourceforge.net/Doc/Release/Zsh-Modules.html#The-zsh_002fcomplist-Module
zmodload -i zsh/complist

## Completion
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

if dir=$(_first_dir \
           "${HOME}/.nix-profile/share/fzf-tab" \
           "${HOMEBREW_PREFIX}/share/fzf-tab"); then
  source "${dir}/fzf-tab.zsh"

  # To make fzf-tab follow FZF_DEFAULT_OPTS.
  # NOTE: This may lead to unexpected behavior since some flags break this plugin. See Aloxaf/fzf-tab#455.
  zstyle ':fzf-tab:*' use-fzf-default-opts yes

  # force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
  zstyle ':completion:*' menu no

else
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

fi

# Display lists of matches for files in different colours depending on the file
# type
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Enable completion for `.' and `..' special directories
zstyle ':completion:*' special-dirs true

# Increase the number of errors based on the length of the typed word
# zstyle -e ':completion:*:approximate:*' max-errors 'reply=($((($#PREFIX+$#SUFFIX)/3))numeric)'
zstyle ':completion:*' max-errors 0

# Ignore shell functions that should not be used individually
zstyle ':completion:*:functions' ignored-patterns '_*'

# Ignore completion for uninterested users
zstyle ':completion:*:*:*:users' ignored-patterns '_*'

# Ignore backup files when completing commands
zstyle ':completion:*:complete:-command-::commands' ignored-patterns '*\~'

# Kill command completion
zstyle ':completion:*:*:kill:*:processes' command 'ps -U ${USERNAME} -o pid,user,command | sed "/ps -U '${USERNAME}'/d"'

# Colorize kill completion menu
zstyle ':completion:*:*:*:*:processes' list-colors '=(#b) #([0-9]##) ([0-9a-z_-]##) *=0=31=36'

## History
HISTSIZE=1000000
SAVEHIST="$HISTSIZE"
HISTFILE="${HOME}/.zsh_history"

# This option both imports new commands from the history file, and also causes
# your typed commands to be appended to the history file (the latter is like
# specifying INC_APPEND_HISTORY, which should be turned off if this option is in
# effect). The history lines are also output with timestamps ala
# EXTENDED_HISTORY (which makes it easier to find the spot where we left off
# reading the file after it gets re-written).
setopt SHARE_HISTORY

# If a new command line being added to the history list duplicates an older one,
# the older command is removed from the list (even if it is not the previous
# event).
setopt HIST_IGNORE_ALL_DUPS

# Remove superfluous blanks from each command line being added to the history
# list.
setopt HIST_REDUCE_BLANKS

# Save each command's beginning timestamp (in seconds since the epoch) and the
# duration (in seconds) to the history file.
setopt EXTENDED_HISTORY

## Prompt
autoload -Uz colors
colors

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
PROMPT='%B%F{green}%m%f %F{blue}%~%f${vcs_info_msg_0_} %(!.#.$)%b '
#RPROMPT=' %B%D{%H:%M:%S.%.}%b'

## MISC
# Report command running time if its user/system takes longer than 10 seconds
# REPORTTIME=10

# Try to correct the spelling of all arguments in a line.
# The shell variable CORRECT_IGNORE_FILE may be set to a pattern to match file
# names that will never be offered as corrections.
# setopt CORRECT_ALL
setopt NO_CORRECT_ALL

# Disable flow control so that the keybindings ^S/^Q can be assigned.
setopt NO_FLOW_CONTROL

# Allow comments even in interactive shells
setopt INTERACTIVE_COMMENTS

## Terminal titles
# https://wiki.archlinux.org/title/zsh#xterm_title
# For expansion definition:
# https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html#Prompt-Expansion
function xterm_title {
  print -Pn -- '\e]2;%m: %~\a'
}

add-zsh-hook precmd xterm_title

## Use less as terminal pager
export PAGER=less
export LESS='--ignore-case --LONG-PROMPT --RAW-CONTROL-CHARS --window=-4'
export LESS_TERMCAP_so=$'\e[33m\e[7m'
export LESS_TERMCAP_se=$'\e[0m'

# Configure pinentry to use the correct TTY
export GPG_TTY=$TTY

## Aliases
case $OSTYPE in
  *linux*)
    alias ls='ls --color=auto --group-directories-first' ;;
  *darwin*)
    case $(which ls 2> /dev/null) in
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
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

alias history='history -i 0'

## Additional customization
if [[ -f ~/.zsh_custom ]]; then
  . ~/.zsh_custom
fi
