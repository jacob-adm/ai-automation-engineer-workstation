# ~/.bashrc: executed by bash(1) for non-login interactive shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# -----------------------------------------------------------------------------
# Shell Options & History
# -----------------------------------------------------------------------------
shopt -s histappend
shopt -s checkwinsize
shopt -s globstar 2>/dev/null
shopt -s cdspell 2>/dev/null
shopt -s cmdhist 2>/dev/null

HISTCONTROL=ignoreboth:erasedups
HISTSIZE=50000
HISTFILESIZE=100000
HISTTIMEFORMAT="%F %T "

# -----------------------------------------------------------------------------
# Environment & Paths
# -----------------------------------------------------------------------------
export EDITOR="vim"
export VISUAL="vim"
export PAGER="less"
export LESS="-R -i -M"

# Linux tmpfs optimization: use RAM-backed filesystem for scratch data & agent runs
if [ -d "/run/user/$(id -u)" ]; then
    export TMPDIR="/run/user/$(id -u)"
fi

# Prepend user bin directories if present
for dir in "$HOME/bin" "$HOME/.local/bin" "$HOME/.dotfiles/bin"; do
    if [ -d "$dir" ] && [[ ":$PATH:" != *":$dir:"* ]]; then
        PATH="$dir:$PATH"
    fi
done
export PATH

# -----------------------------------------------------------------------------
# Supply Chain Defense for Python & AI Tooling
# -----------------------------------------------------------------------------
# 7-day release quarantine: prevent pulling zero-day compromised PyPI packages
UV_QUARANTINE_DATE="$(date -u -d "7 days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-7d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || true)"
if [ -n "$UV_QUARANTINE_DATE" ]; then
    export UV_EXCLUDE_NEWER="$UV_QUARANTINE_DATE"
fi
export UV_MALWARE_CHECK=1

# -----------------------------------------------------------------------------
# Python Virtualenv Automatic Helper
# -----------------------------------------------------------------------------
activate_venv() {
    if [ -f ".venv/bin/activate" ]; then
        # shellcheck disable=SC1091
        source .venv/bin/activate
        echo -e "\033[0;32m[venv]\033[0m Activated local .venv"
    elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local repo_root
        repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
        if [ -f "$repo_root/.venv/bin/activate" ]; then
            # shellcheck disable=SC1091
            source "$repo_root/.venv/bin/activate"
            echo -e "\033[0;32m[venv]\033[0m Activated repository .venv"
        fi
    else
        echo "No .venv found in current directory or repository root."
    fi
}

# -----------------------------------------------------------------------------
# Colors & Prompt
# -----------------------------------------------------------------------------
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

parse_git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        local git_status
        git_status=$(git status --porcelain 2>/dev/null | tail -n 1)
        if [ -n "$git_status" ]; then
            printf " \033[0;33m(%s*)\033[0m" "$branch"
        else
            printf " \033[0;32m(%s)\033[0m" "$branch"
        fi
    fi
}

prompt_command() {
    local exit_code=$?
    local exit_str=""
    if [ $exit_code -ne 0 ]; then
        exit_str=" \033[01;31m[exit $exit_code]\033[00m"
    fi

    local user_host="\033[01;32m\u@\h\033[00m"
    if [ "$EUID" -eq 0 ]; then
        user_host="\033[01;31m\u@\h\033[00m"
    fi

    local dir="\033[01;34m\w\033[00m"
    local git_info='$(parse_git_branch)'

    PS1="${user_host}:${dir}${git_info}${exit_str}\n\$ "
}
PROMPT_COMMAND=prompt_command

# -----------------------------------------------------------------------------
# Bash Completion & CLI Integrations
# -----------------------------------------------------------------------------
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Direnv integration for scoped credentials
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook bash)"
fi

# Zoxide smart navigation
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

# Pueue daemon auto-start for experiment and harness task queues
if command -v pueued >/dev/null 2>&1; then
    if ! pueue status >/dev/null 2>&1; then
        pueued --daemonize >/dev/null 2>&1 || true
    fi
    pueue group add experiments 2>/dev/null && pueue parallel 2 -g experiments 2>/dev/null || true
    pueue group add agents 2>/dev/null && pueue parallel 4 -g agents 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# Aliases & External Configurations
# -----------------------------------------------------------------------------
if [ -f "$HOME/.bash_aliases" ]; then
    . "$HOME/.bash_aliases"
fi

# AI Agent Automation policy & circuit breaker
if [ -f "$HOME/.ai_automation.sh" ]; then
    . "$HOME/.ai_automation.sh"
elif [ -f "$HOME/.dotfiles/config/ai_automation/ai_automation.sh" ]; then
    . "$HOME/.dotfiles/config/ai_automation/ai_automation.sh"
fi

# Local machine-specific overrides
if [ -f "$HOME/.dotfiles.local" ]; then
    . "$HOME/.dotfiles.local"
fi
if [ -f "$HOME/.bashrc.local" ]; then
    . "$HOME/.bashrc.local"
fi
