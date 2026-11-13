# ==============================================================================
# File:        config/bash/.bashrc
# Component:   Interactive Shell Substrate & Development Environment
# Description: Configures interactive Bash sessions for AI automation engineers,
#              incorporating supply-chain defense, temporary RAM filesystems,
#              task queue orchestration (pueue), and Git-aware prompt telemetry.
# Invariants:  - Non-interactive shells return immediately to prevent subshell side-effects.
#              - PyPI packages quarantined by 7-day exclusion date via UV_EXCLUDE_NEWER.
#              - Temporary files mapped to Linux RAM-backed tmpfs (/run/user/$UID).
# Dependencies: bash 4+, git (optional), uv (optional), pueue (optional)
# Target OS:   Ubuntu 22.04+ / Debian 12+ (POSIX Bash fallback)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Interactive Shell Guard
# ------------------------------------------------------------------------------
# Abort processing immediately if invoked by non-interactive subshells or scripts
case $- in
    *i*) ;;
      *) return;;
esac

# ------------------------------------------------------------------------------
# 2. Shell Options & Command History
# ------------------------------------------------------------------------------
# Append history entries rather than overwriting on terminal exit
shopt -s histappend

# Recalculate terminal geometry on window resize
shopt -s checkwinsize

# Enable recursive globbing (**/*) and minor spelling correction
shopt -s globstar 2>/dev/null
shopt -s cdspell 2>/dev/null
shopt -s cmdhist 2>/dev/null

# Deduplicate adjacent commands and erase duplicate history entries across sessions
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=50000
HISTFILESIZE=100000
HISTTIMEFORMAT="%F %T "

# ------------------------------------------------------------------------------
# 3. Environment & Paths
# ------------------------------------------------------------------------------
export EDITOR="vim"
export VISUAL="vim"
export PAGER="less"
export LESS="-R -i -M"

# Linux tmpfs optimization: map scratch directories to RAM filesystem for speed & flash preservation
if [ -d "/run/user/$(id -u)" ]; then
    export TMPDIR="/run/user/$(id -u)"
fi

# Prepend user bin directories to PATH without introducing duplicate entries
for dir in "$HOME/bin" "$HOME/.local/bin" "$HOME/.dotfiles/bin"; do
    if [ -d "$dir" ] && [[ ":$PATH:" != *":$dir:"* ]]; then
        PATH="$dir:$PATH"
    fi
done
export PATH

# ------------------------------------------------------------------------------
# 4. Supply Chain Defense for Python & AI Tooling
# ------------------------------------------------------------------------------
# 7-day release quarantine: prevent automatic pulls of freshly published/compromised PyPI packages
UV_QUARANTINE_DATE="$(date -u -d "7 days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-7d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || true)"
if [ -n "$UV_QUARANTINE_DATE" ]; then
    export UV_EXCLUDE_NEWER="$UV_QUARANTINE_DATE"
fi

# uv >= 0.11.16 (preview): after each lockfile sync (uv add, uv sync, ...), ask OSV for
# known-malware (MAL) advisories on the locked packages and stop the sync on a match.
# Malware only, not CVEs (that is `uv audit`). Older uv ignores this variable.
export UV_MALWARE_CHECK=1

# ------------------------------------------------------------------------------
# 5. Python Virtual Environment Automatic Helper
# ------------------------------------------------------------------------------
# Contextually activates virtualenv from current directory or Git repository root
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

# ------------------------------------------------------------------------------
# 6. Colors & Prompt Telemetry
# ------------------------------------------------------------------------------
# Initialize color database if dircolors utility is installed
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# Extract short branch name and dirty indicator (* flag)
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

# Construct two-line prompt showing user/host (red for root), cwd, git state, and non-zero exit status
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

# ------------------------------------------------------------------------------
# 7. Bash Completion & Modern CLI Integrations
# ------------------------------------------------------------------------------
# System-wide programmable completion
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Direnv integration for scoped environment variables and directory credential boundaries
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook bash)"
fi

# Zoxide smart directory jumping
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

# Pueue daemon auto-start for background task and agent harness queuing
if command -v pueued >/dev/null 2>&1; then
    if ! pueue status >/dev/null 2>&1; then
        pueued --daemonize >/dev/null 2>&1 || true
    fi
    # Configure dedicated parallel execution pools
    pueue group add experiments 2>/dev/null && pueue parallel 2 -g experiments 2>/dev/null || true
    pueue group add agents 2>/dev/null && pueue parallel 4 -g agents 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 8. Aliases & External Configurations
# ------------------------------------------------------------------------------
# Ingest root alias loader
if [ -f "$HOME/.bash_aliases" ]; then
    . "$HOME/.bash_aliases"
fi

# Ingest AI Agent automation circuit breaker and rate limiting engine
if [ -f "$HOME/.ai_automation.sh" ]; then
    . "$HOME/.ai_automation.sh"
elif [ -f "$HOME/.dotfiles/config/ai_automation/ai_automation.sh" ]; then
    . "$HOME/.dotfiles/config/ai_automation/ai_automation.sh"
fi

# Ingest local machine overrides without modifying dotfiles repository
if [ -f "$HOME/.dotfiles.local" ]; then
    . "$HOME/.dotfiles.local"
fi
if [ -f "$HOME/.bashrc.local" ]; then
    . "$HOME/.bashrc.local"
fi
