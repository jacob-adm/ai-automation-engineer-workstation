#!/usr/bin/env bash
# ==============================================================================
# File:        config/ai_automation/ai_automation.sh
# Component:   AI Guardrails & Autonomous Execution Governance
# Description: Defines global circuit breakers, sliding-window rate limiters,
#              and telemetry hooks for autonomous AI agent harnesses.
# Invariants:  - Sentinel existence ($HOME/.agent_stop) unconditionally halts agents.
#              - Sentinel clearance requires matching EUID ownership to prevent bypass.
#              - Trace log files are restricted to 0600 permissions.
# Dependencies: bash, date, wc, stat
# Target OS:   POSIX Bash (Ubuntu 22.04+, Debian 12+, macOS)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Environment Configuration & Tunable Guardrails
# ------------------------------------------------------------------------------
# Maximum depth of autonomous sub-agent invocation chains
: "${AUTO_AGENT_MAX_DEPTH:=2}"

# Sliding window rate limit: maximum allowed agent executions per rolling hour
: "${AUTO_AGENT_MAX_PER_HOUR:=30}"

# Minimum required cooldown between back-to-back automated loops
: "${AUTO_AGENT_COOLDOWN_SEC:=60}"

# Maximum lines retained in trace log before auto-compaction (prevents unbounded disk bloat)
: "${AUTO_AGENT_TRACE_MAX_LINES:=10000}"

# ------------------------------------------------------------------------------
# 2. Paths & State Sentinels
# ------------------------------------------------------------------------------
# Sentinel file whose presence triggers an immediate halt across all harnesses
: "${AUTO_AGENT_DISABLED_SENTINEL:=$HOME/.agent_stop}"

# Persistent directory for structured audit logs and invocation traces
: "${AUTO_AGENT_TRACE_DIR:=$HOME/.local/state/agent-traces}"
: "${AUTO_AGENT_LOG_DIR:=$HOME/.local/state/agent-logs}"

# Ensure telemetry state directories exist with fail-safe error suppression
mkdir -p "$AUTO_AGENT_TRACE_DIR" "$AUTO_AGENT_LOG_DIR" 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. Emergency Circuit Breaker (Halt Execution)
# ------------------------------------------------------------------------------
# Instantly creates the sentinel file to halt all active and queued agent runs
agent-stop() {
    touch "$AUTO_AGENT_DISABLED_SENTINEL"
    chmod 600 "$AUTO_AGENT_DISABLED_SENTINEL" 2>/dev/null || true
    echo -e "\033[01;31m[CIRCUIT BREAKER ENGAGED]\033[00m Emergency stop active: $AUTO_AGENT_DISABLED_SENTINEL"
    echo "All local agent harnesses and automated loops will immediately abort."
}

# ------------------------------------------------------------------------------
# 4. Circuit Breaker Clearance (Resume Execution)
# ------------------------------------------------------------------------------
# Safely clears the sentinel file after verifying process ownership
agent-resume() {
    if [ -f "$AUTO_AGENT_DISABLED_SENTINEL" ]; then
        local sentinel_owner
        # Resolve owner UID across Linux coreutils stat and BSD/macOS stat
        sentinel_owner="$(stat -c "%u" "$AUTO_AGENT_DISABLED_SENTINEL" 2>/dev/null || stat -f "%u" "$AUTO_AGENT_DISABLED_SENTINEL" 2>/dev/null || echo "")"
        if [ -n "$sentinel_owner" ] && [ "$sentinel_owner" -ne "$EUID" ]; then
            echo -e "\033[01;31m[ERROR]\033[00m Cannot resume: Sentinel owned by UID $sentinel_owner, not current user ($EUID)." >&2
            return 1
        fi
        rm -f "$AUTO_AGENT_DISABLED_SENTINEL"
        echo -e "\033[01;32m[CIRCUIT BREAKER CLEARED]\033[00m Agent execution resumed."
    else
        echo "Agent execution is already active (sentinel file not present)."
    fi
}

# ------------------------------------------------------------------------------
# 5. Telemetry & Harness Diagnostics
# ------------------------------------------------------------------------------
# Prints operational metrics, guardrail limits, and historical execution counts
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

        # Calculate active runs within the trailing 3600 seconds
        local now
        if [ -n "${EPOCHSECONDS:-}" ]; then
            now="$EPOCHSECONDS"
        elif printf -v now '%(%s)T' -1 2>/dev/null; then
            :
        else
            now=$(date +%s)
        fi
        local one_hour_ago=$(( now - 3600 ))
        local recent_runs=0
        while IFS= read -r line; do
            local ts="${line%% *}"
            if [[ "$ts" =~ ^[0-9]+$ ]] && [ "$ts" -ge "$one_hour_ago" ]; then
                recent_runs=$(( recent_runs + 1 ))
            fi
        done < <(tail -n "$AUTO_AGENT_MAX_PER_HOUR" "$log_file" 2>/dev/null)
        echo "Runs in Last Hour: $recent_runs / $AUTO_AGENT_MAX_PER_HOUR"
    fi
    echo -e "\033[1;36m==================================\033[0m"
}

# ------------------------------------------------------------------------------
# 6. Trace Telemetry Log Maintenance & Compaction
# ------------------------------------------------------------------------------
# Prunes historical trace records exceeding retention limits while preserving 0600 mode
agent-traces-compact() {
    local max_lines="${1:-${AUTO_AGENT_TRACE_MAX_LINES:-10000}}"
    local log_file="$AUTO_AGENT_TRACE_DIR/traces.log"

    if [ -f "$log_file" ] && [ "$max_lines" -gt 0 ]; then
        local total_lines
        total_lines=$(wc -l < "$log_file" 2>/dev/null || echo 0)
        if [ "$total_lines" -gt "$max_lines" ]; then
            local keep_lines=$(( max_lines / 2 ))
            local tmp_log="${log_file}.tmp.$$"
            if tail -n "$keep_lines" "$log_file" > "$tmp_log" 2>/dev/null; then
                chmod 600 "$tmp_log" 2>/dev/null || true
                mv -f "$tmp_log" "$log_file" 2>/dev/null || rm -f "$tmp_log"
                echo "Compacted $log_file: retained $keep_lines of $total_lines records."
            else
                rm -f "$tmp_log" 2>/dev/null || true
            fi
        fi
    fi
}

# ------------------------------------------------------------------------------
# 7. Pre-flight Guard Check & Sliding Window Rate Limiting
# ------------------------------------------------------------------------------
# Validates whether a requested execution turn is authorized under active policies
agent-guard-check() {
    local caller="${1:-agent-harness}"

    # Step 1: Reject execution if emergency stop sentinel exists
    if [ -f "$AUTO_AGENT_DISABLED_SENTINEL" ]; then
        echo -e "\033[01;31m[GUARD REJECTED]\033[00m Execution blocked by sentinel: $AUTO_AGENT_DISABLED_SENTINEL" >&2
        return 1
    fi

    local log_file="$AUTO_AGENT_TRACE_DIR/traces.log"

    # High-performance in-process timestamp resolution (Bash builtins when available)
    local now
    if [ -n "${EPOCHSECONDS:-}" ]; then
        now="$EPOCHSECONDS"
    elif printf -v now '%(%s)T' -1 2>/dev/null; then
        :
    else
        now=$(date +%s)
    fi
    local one_hour_ago=$(( now - 3600 ))

    # Ensure telemetry trace file exists with strict 0600 permissions
    if [ ! -f "$log_file" ]; then
        touch "$log_file"
        chmod 600 "$log_file" 2>/dev/null || true
    fi

    # Step 2: Atomic concurrency protection via flock (when available on Linux)
    local lock_fd=0
    if command -v flock >/dev/null 2>&1; then
        exec 200>>"$log_file"
        if flock -x -w 2 200 2>/dev/null; then
            lock_fd=200
        fi
    fi

    # Step 3: High-Performance O(1) Bounded Tail Scan
    # Traces are ordered chronologically; inspecting at most AUTO_AGENT_MAX_PER_HOUR
    # records from the tail guarantees constant-time validation regardless of log file size.
    local recent_runs=0
    while IFS= read -r line; do
        local ts="${line%% *}"
        if [[ "$ts" =~ ^[0-9]+$ ]] && [ "$ts" -ge "$one_hour_ago" ]; then
            recent_runs=$(( recent_runs + 1 ))
        fi
    done < <(tail -n "$AUTO_AGENT_MAX_PER_HOUR" "$log_file" 2>/dev/null)

    # Step 4: Enforce hourly quota ceiling
    if [ "$recent_runs" -ge "$AUTO_AGENT_MAX_PER_HOUR" ]; then
        if [ "$lock_fd" -eq 200 ]; then
            flock -u 200 2>/dev/null || true
            exec 200>&-
        fi
        echo -e "\033[01;31m[GUARD REJECTED]\033[00m Rate limit exceeded: $recent_runs runs in last hour (max $AUTO_AGENT_MAX_PER_HOUR)." >&2
        return 2
    fi

    # Step 5: Record timestamped execution trace with strict 0600 permissions
    local iso_ts
    if printf -v iso_ts '%(%Y-%m-%dT%H:%M:%SZ)T' -1 2>/dev/null; then
        :
    else
        iso_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi
    echo "$now $iso_ts $caller" >> "$log_file"

    # Step 6: Periodic automatic trace compaction to prevent unbounded disk bloat
    if [ "${AUTO_AGENT_TRACE_MAX_LINES:-0}" -gt 0 ]; then
        : "${_AGENT_TURN_INVOCATION_COUNT:=0}"
        _AGENT_TURN_INVOCATION_COUNT=$(( _AGENT_TURN_INVOCATION_COUNT + 1 ))
        if [ $(( _AGENT_TURN_INVOCATION_COUNT % 50 )) -eq 0 ]; then
            agent-traces-compact "$AUTO_AGENT_TRACE_MAX_LINES" >/dev/null 2>&1 || true
        fi
    fi

    # Release file lock if acquired
    if [ "$lock_fd" -eq 200 ]; then
        flock -u 200 2>/dev/null || true
        exec 200>&-
    fi

    return 0
}

# ------------------------------------------------------------------------------
# 7. Local Overrides
# ------------------------------------------------------------------------------
# Ingest developer-specific machine overrides without modifying tracked source
if [ -f "$HOME/.ai_automation.local.sh" ]; then
    . "$HOME/.ai_automation.local.sh"
fi
