# agnoster's Theme - https://gist.github.com/3712874
# modifyed by mxkrsv - https://github.com/mxkrsv/agnoster-multiline

# Fix sourcing
setopt prompt_subst

### Segments of the prompt, default order declaration

typeset -aHg AGNOSTER_PROMPT_SEGMENTS=(
	prompt_virtualenv
	prompt_dir
	prompt_git
	prompt_end

	prompt_newline

	prompt_status
	prompt_context
	prompt_end
)

typeset -aHg AGNOSTER_PROMPT_SEGMENTS_SHORT=(
	prompt_status
	prompt_context
	prompt_end
)

## Colors (8-bit palette)
local black=0
local red=1
local green=2
local yellow=3
local blue=4
local purple=5
local aqua=6
local gray=7
local brgray=8
local brred=9
local brgreen=10
local bryellow=11
local brblue=12
local brpurple=13
local braqua=14
local white=15

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'
if [[ -z "$PRIMARY_FG" ]]; then
	PRIMARY_FG=black
fi

# Characters
case "$TERM" in
	linux)
		SEGMENT_SEPARATOR=""
		BRANCH=on
		;;
	*)
		SEGMENT_SEPARATOR="\ue0b0"
		BRANCH="\ue0a0"
		;;
esac
UNSTAGED="±"
STAGED="+"
UNTRACKED="?"
DETACHED="detached"
CROSS="X"
LIGHTNING="#"
GEAR="&"

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
	local bg fg
	[[ -n $1 ]] && bg="%K{$1}" || bg="%k"
	[[ -n $2 ]] && fg="%F{$2}" || fg="%f"
	if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
		print -n "%{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%}"
	else
		print -n "%{$bg%}%{$fg%}"
	fi
	CURRENT_BG=$1
	[[ -n $3 ]] && print -n "$3"
}

# End the prompt, closing any open segments
prompt_end() {
	# beautiful fallback color (useful in empty prompt)
	[ "$CURRENT_BG" != NONE ] || CURRENT_BG="$braqua"

	if [[ -n $CURRENT_BG ]]; then
		print -n "%{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
	else
		print -n "%{%k%}"
	fi
	print -n "%{%f%}"
	CURRENT_BG=''
}

### Cursor stuff
set_block_cursor() { printf '\e[2 q' }
set_beam_cursor() { printf '\e[6 q' }

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
	local user=`whoami`

	if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CONNECTION" ]]; then
		prompt_segment "$aqua" $PRIMARY_FG " %(!.%{%F{default}%}.)$user@%m "
	fi
}

# Git: branch/detached head, dirty status
prompt_git() {
	local color ref
	ref="$vcs_info_msg_0_"
	if [[ -n "$ref" ]]; then
		color="$brgreen"
		ref="$ref "

		if echo "$ref" | grep -q "$STAGED\|$UNSTAGED\|$UNTRACKED"; then
			color="$bryellow"
		fi

		if [[ "${ref/.../}" == "$ref" ]]; then
			ref="$BRANCH $ref"
		else
			ref="$DETACHED ${ref/.../}"
		fi

		prompt_segment $color $PRIMARY_FG
		print -n " $ref"
	fi
}

# Git: check for untracked files in repo
+vi-git-untracked(){
	if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
			&& [[ "$(git ls-files --others --exclude-standard)" ]]
	then
		hook_com[staged]+=" $UNTRACKED"
	fi
}

# Dir: current working directory plus current vi mode
prompt_dir() {
	local color
	case "$VI_KEYMAP" in
		vicmd) color="$brred";; # 9 is bright red
		*) color="$blue";;
	esac

	prompt_segment "$color" $PRIMARY_FG ' %~ '
}

# Time: current time
prompt_time() {
	prompt_segment cyan $PRIMARY_FG " $(date '+%R') "
}

# Newline: printf \n
prompt_newline() {
	printf '\n'
	CURRENT_BG=NONE
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
	local symbols
	symbols=()
	[[ $RETVAL -ne 0 ]] && symbols+="%{%F{$red}%}$CROSS $RETVAL"
	[[ $UID -eq 0 ]] && symbols+="%{%F{default}%}$LIGHTNING"
	[[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{$PRIMARY_FG}%}$GEAR"

	[[ -n "$symbols" ]] && prompt_segment "$white" default " $symbols "
}

# Display current virtual environment
prompt_virtualenv() {
	if [[ -n $VIRTUAL_ENV ]]; then
		color=cyan
		prompt_segment $color $PRIMARY_FG
		print -Pn " $(basename $VIRTUAL_ENV) "
	fi
}

## Main prompt
prompt_agnoster_main() {
	RETVAL=$?
	CURRENT_BG='NONE'
	for prompt_segment in "${AGNOSTER_PROMPT_SEGMENTS[@]}"; do
		[[ -n $prompt_segment ]] && $prompt_segment
	done
}

prompt_agnoster_precmd() {
	vcs_info
	PROMPT='%{%f%b%k%}$(prompt_agnoster_main) '
}

## Short prompt
prompt_agnoster_short() {
	RETVAL=$?
	CURRENT_BG='NONE'
	for prompt_segment in "${AGNOSTER_PROMPT_SEGMENTS_SHORT[@]}"; do
		[[ -n $prompt_segment ]] && $prompt_segment
	done
}

# Replace long prompt with short on line finish (transient prompt)
zle-line-finish() {
	PROMPT='%{%f%b%k%}$(prompt_agnoster_short) '
	zle .reset-prompt 2>/dev/null
}

## Update vi mode indicator when the keymap changes
zle-keymap-select() {
	if [[ "$KEYMAP" = vicmd ]]; then
		set_block_cursor
	else
		set_beam_cursor
	fi

	VI_KEYMAP="$KEYMAP"
	zle .reset-prompt 2>/dev/null
}

# Start every prompt in insert mode
zle-line-init() {
	zle -K viins
}

prompt_agnoster_setup() {
	autoload -Uz add-zsh-hook
	autoload -Uz vcs_info

	prompt_opts=(cr subst percent)

	add-zsh-hook precmd prompt_agnoster_precmd

	# Restore block cursor when giving control to a program
	add-zsh-hook preexec set_block_cursor

	zle -N zle-line-finish
	zle -N zle-keymap-select
	zle -N zle-line-init
	trap 'zle-line-finish; return 130' INT

	zstyle ':vcs_info:*' enable git
	zstyle ':vcs_info:*' check-for-changes true
	zstyle ':vcs_info:*' use-simple true
	zstyle ':vcs_info:*' stagedstr " $STAGED"
	zstyle ':vcs_info:*' unstagedstr " $UNSTAGED"
	zstyle ':vcs_info:git*' formats '%b%u%c'
	zstyle ':vcs_info:git*' actionformats '%b (%a)%u%c'
	zstyle ':vcs_info:git*+set-message:*' hooks git-untracked
}

prompt_agnoster_setup "$@"
