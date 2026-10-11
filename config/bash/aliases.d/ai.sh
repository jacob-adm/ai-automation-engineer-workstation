# ==============================================================================
# File:        config/bash/aliases.d/ai.sh
# Component:   Modular Aliases: AI Automation & Task Orchestration
# Description: Provides shorthand shortcuts and helper functions for agent
#              worktrees, pueue queue management, and MCP diagnostics.
# Invariants:  - jrun enforces circuit breaker validation for 'agents' group.
#              - Pueue daemon auto-spawned on demand if stopped.
# Dependencies: pueue / pueued (optional), agent-worktree, check-mcp-logs
# Target OS:   POSIX Bash (Ubuntu 22.04+, Debian 12+, macOS)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Agent Worktrees
# ------------------------------------------------------------------------------
# Shorthand aliases for isolated git worktree lifecycle management
alias aw='agent-worktree'
alias aw-new='agent-worktree new'
alias aw-ls='agent-worktree list'
alias aw-merge='agent-worktree merge'
alias aw-rm='agent-worktree remove'

# ------------------------------------------------------------------------------
# 2. Pueue Task Queue (Harness & Experiment Background Jobs)
# ------------------------------------------------------------------------------
# Enqueues tasks into pueue with automatic pool management and guardrail validation
jrun() {
    local group="${1:-default}"
    shift || true

    # Step 1: Enforce circuit breaker check for automated agent executions
    if [ "$group" = "agents" ] && command -v agent-guard-check >/dev/null 2>&1; then
        if ! agent-guard-check "jrun:$group"; then
            echo -e "\033[01;31m[CIRCUIT BREAKER]\033[00m Job rejected for group '$group'." >&2
            return 1
        fi
    fi

    # Step 2: Ensure pueued daemon is active and initialize target execution group
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
        # Fallback to direct synchronous execution if pueue is unavailable
        echo "pueue not installed. Running directly: $*"
        "$@"
    fi
}

# Group dispatch wrappers
alias jexp='jrun experiments'
alias jagent='jrun agents'

# Pueue management shortcuts
alias jls='pueue status'
alias jfollow='pueue follow'
alias jlog='pueue log'
alias jkill='pueue kill'
alias jclean='pueue clean'
alias jpause='pueue pause'
alias jstart='pueue start'

# ------------------------------------------------------------------------------
# 3. Model Context Protocol (MCP) Diagnostics
# ------------------------------------------------------------------------------
alias mcplogs='check-mcp-logs'
