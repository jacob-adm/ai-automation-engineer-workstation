#!/usr/bin/env bash
# config/ai_automation/ai_automation.sh: Guardrails, circuit breakers, and telemetry for AI agent harnesses

# Recursion and rate-limit guardrails
: "${AUTO_AGENT_MAX_DEPTH:=2}"
: "${AUTO_AGENT_MAX_PER_HOUR:=30}"
: "${AUTO_AGENT_COOLDOWN_SEC:=60}"

# Paths and state sentinels
: "${AUTO_AGENT_DISABLED_SENTINEL:=$HOME/.agent_stop}"
: "${AUTO_AGENT_TRACE_DIR:=$HOME/.local/state/agent-traces}"
: "${AUTO_AGENT_LOG_DIR:=$HOME/.local/state/agent-logs}"

mkdir -p "$AUTO_AGENT_TRACE_DIR" "$AUTO_AGENT_LOG_DIR" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Circuit Breaker Commands
# -----------------------------------------------------------------------------

# Emergency halt: stops all autonomous agent loops
agent-stop() {
    touch "$AUTO_AGENT_DISABLED_SENTINEL"
    echo -e "\033[01;31m[CIRCUIT BREAKER ENGAGED]\033[00m Emergency stop active: $AUTO_AGENT_DISABLED_SENTINEL"
    echo "All local agent harnesses and automated loops will immediately abort."
}

# Resume agent execution
agent-resume() {
    if [ -f "$AUTO_AGENT_DISABLED_SENTINEL" ]; then
        rm -f "$AUTO_AGENT_DISABLED_SENTINEL"
        echo -e "\033[01;32m[CIRCUIT BREAKER CLEARED]\033[00m Agent execution resumed."
    else
        echo "Agent execution is already active (sentinel file not present)."
    fi
}

# Inspect agent harness status and telemetry
agent-status() {
    echo -e "\033[1;36m=== AI Agent Automation Status ===\033[0m"
    if [ -f "$AUTO_AGENT_DISABLED_SENTINEL" ]; then
        echo -e "Circuit Breaker: \033[1;31mSTOPPED (Triggered at $(date -r "$AUTO_AGENT_DISABLED_SENTINEL" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$AUTO_AGENT_DISABLED_SENTINEL" 2>/dev/null || echo "active"))\033[0m"
    else
        echo -e "Circuit Breaker: \033[1;32mACTIVE / READY\033[0m"
    fi

    echo "Max Depth:       $AUTO_AGENT_MAX_DEPTH"
    echo "Max Runs/Hour:   $AUTO_AGENT_MAX_PER_HOUR"
    echo "Trace Dir:       $AUTO_AGENT_TRACE_DIR"

    local log_file="$AUTO_AGENT_TRACE_DIR/traces.log"
    if [ -f "$log_file" ]; then
        local count
        count=$(wc -l < "$log_file" 2>/dev/null || echo 0)
        echo "Total Logged Runs: $count"
    fi
    echo -e "\033[1;36m==================================\033[0m"
}

# Pre-flight check: Harnesses should call this before every agent turn
agent-guard-check() {
    local caller="${1:-agent-harness}"

    if [ -f "$AUTO_AGENT_DISABLED_SENTINEL" ]; then
        echo -e "\033[01;31m[GUARD REJECTED]\033[00m Execution blocked by sentinel: $AUTO_AGENT_DISABLED_SENTINEL" >&2
        return 1
    fi

    local log_file="$AUTO_AGENT_TRACE_DIR/traces.log"
    local now
    now=$(date +%s)
    local one_hour_ago=$(( now - 3600 ))

    # Count runs within the last hour
    if [ -f "$log_file" ]; then
        local recent_runs=0
        while IFS= read -r line; do
            local ts="${line%% *}"
            if [[ "$ts" =~ ^[0-9]+$ ]] && [ "$ts" -ge "$one_hour_ago" ]; then
                recent_runs=$(( recent_runs + 1 ))
            fi
        done < "$log_file"

        if [ "$recent_runs" -ge "$AUTO_AGENT_MAX_PER_HOUR" ]; then
            echo -e "\033[01;31m[GUARD REJECTED]\033[00m Rate limit exceeded: $recent_runs runs in last hour (max $AUTO_AGENT_MAX_PER_HOUR)." >&2
            return 2
        fi
    fi

    # Record trace
    echo "$now $(date -u +"%Y-%m-%dT%H:%M:%SZ") $caller" >> "$log_file"
    return 0
}

# Load local overrides if present
if [ -f "$HOME/.ai_automation.local.sh" ]; then
    . "$HOME/.ai_automation.local.sh"
fi
