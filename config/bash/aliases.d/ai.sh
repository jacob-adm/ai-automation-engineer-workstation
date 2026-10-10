# ~/.bash_aliases.d/ai.sh: AI Agent Worktrees, Task Queues, and Circuit Breakers

# -----------------------------------------------------------------------------
# Agent Worktrees
# -----------------------------------------------------------------------------
alias aw='agent-worktree'
alias aw-new='agent-worktree new'
alias aw-ls='agent-worktree list'
alias aw-merge='agent-worktree merge'
alias aw-rm='agent-worktree remove'

# -----------------------------------------------------------------------------
# Pueue Task Queue (Harness & Experiment Background Jobs)
# -----------------------------------------------------------------------------
jrun() {
    local group="${1:-default}"
    shift || true
    if command -v pueue >/dev/null 2>&1; then
        if ! pueue status >/dev/null 2>&1; then
            pueued --daemonize >/dev/null 2>&1 || true
        fi
        if ! pueue group 2>/dev/null | grep -q "^$group "; then
            pueue group add "$group" >/dev/null 2>&1 || true
            case "$group" in
                experiments) pueue parallel 2 -g "$group" >/dev/null 2>&1 || true ;;
                agents)      pueue parallel 4 -g "$group" >/dev/null 2>&1 || true ;;
            esac
        fi
        pueue add --group "$group" -- "$@"
    else
        echo "pueue not installed. Running directly: $*"
        "$@"
    fi
}

alias jexp='jrun experiments'
alias jagent='jrun agents'
alias jls='pueue status'
alias jfollow='pueue follow'
alias jlog='pueue log'
alias jkill='pueue kill'
alias jclean='pueue clean'
alias jpause='pueue pause'
alias jstart='pueue start'

# -----------------------------------------------------------------------------
# Model Context Protocol (MCP) Diagnostics
# -----------------------------------------------------------------------------
alias mcplogs='check-mcp-logs'
