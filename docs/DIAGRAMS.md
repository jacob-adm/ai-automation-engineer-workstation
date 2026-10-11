# AI Automation Engineer Workstation — Architectural Diagrams & Visual Reference

> 📚 **Navigation:** [README.md](../README.md) | [Field Manual (MANUAL.md)](MANUAL.md) | [Quick Start (QUICK-START.md)](QUICK-START.md) | [Test Receipts (TEST_RECEIPTS.md)](TEST_RECEIPTS.md)

This document provides a visual and operational breakdown of the **AI Automation Engineer Workstation** architecture, illustrating how autonomous coding agents (e.g., Claude Code, OpenCode) are safely contained, governed, and observed while executing on an Ubuntu host.

---

## Table of Contents
1. [Architecture Overview & Containment Strategy](#architecture-overview--containment-strategy)
2. [Diagram 1: System Containment Architecture (Macro View)](#diagram-1-system-containment-architecture-macro-view)
   - [Rendered Macro Diagram](#rendered-macro-diagram)
   - [Live Mermaid Diagram](#live-mermaid-diagram-macro)
   - [Raw Mermaid Source](#raw-mermaid-source-macro)
   - [Architectural Narrative](#architectural-narrative)
3. [Diagram 2: Runtime Turn Interception & Execution Sequence (Micro View)](#diagram-2-runtime-turn-interception--execution-sequence-micro-view)
   - [Rendered Micro Diagram](#rendered-micro-diagram)
   - [Visual Reference & Color Legend](#visual-reference--color-legend)
   - [Live Mermaid Sequence](#live-mermaid-sequence-micro)
   - [Raw Mermaid Source](#raw-mermaid-source-micro)
   - [Execution Lifecycle Walkthrough](#execution-lifecycle-walkthrough)
4. [Component & File Mapping Matrix](#component--file-mapping-matrix)

---

## Architecture Overview & Containment Strategy

Autonomous AI coding agents operating directly on a developer workstation pose distinct systems challenges:
- **Ambient Credential Exfiltration**: Agents reading `.env` files in parent environments or command histories.
- **Runaway Autonomous Loops**: Agents consuming excessive API tokens or thrashing compute in unmonitored cycles.
- **Working Tree Collision**: Agents mutating the primary checkout, breaking developer flow, or making destructive git commits.
- **Supply Chain Poisoning**: Agents installing unpinned, zero-day compromised PyPI or npm packages.

To solve this, the workstation places a dedicated **Harness & Governance Substrate** between the agent and the host operating system. The harness acts as a strict interception gateway:

```
[ Operators / Autonomous Agents ]
               │
               ▼
 ╔═══════════════════════════════════════════════════════════════════════╗
 ║        🛡️ AI AGENT HARNESS & GOVERNANCE SUBSTRATE (CONTAINMENT)       ║
 ║                                                                       ║
 ║  • Pillar 1: Turn Governance & Circuit Breakers (ai_automation.sh)    ║
 ║  • Pillar 2: Zero-Ambient Secret Isolation (secret-run)               ║
 ║  • Pillar 3: Git Worktree Sandboxing (agent-worktree / aw)            ║
 ║  • Pillar 4: Supervised Task Queuing (pueue / jrun)                   ║
 ║  • Pillar 5: Model Context Protocol Governance (mcp.json)             ║
 ╚═══════════════════════════════════════════════════════════════════════╝
               │
               ▼
[ Hardened Host Substrate: RAM tmpfs, 7-Day PyPI Quarantine, doctor Medic ]
```

---

## Diagram 1: System Containment Architecture (Macro View)

### Rendered Macro Diagram

![Diagram 1: System Containment Architecture (Macro View)](assets/architecture-containment-macro.svg)

### Live Mermaid Diagram (Macro)

```mermaid
flowchart TB
    %% -------------------------------------------------------------------------
    %% Operators & Autonomous Agents
    %% -------------------------------------------------------------------------
    subgraph ACTORS ["👤 OPERATORS & AUTONOMOUS AGENTS"]
        direction LR
        HUMAN["👨‍💻 Human Engineer<br/>config/bash/.bashrc<br/>config/tmux/.tmux.conf"]
        AGENT["🤖 Autonomous Coding Agent<br/>config/claude/CLAUDE.md<br/>config/claude/settings.json"]
    end

    %% -------------------------------------------------------------------------
    %% THE HARNESS (PRIMARY STANDOUT CONTAINER)
    %% -------------------------------------------------------------------------
    subgraph HARNESS ["🛡️  AI AGENT HARNESS & GOVERNANCE SUBSTRATE (CONTAINMENT LAYER)  "]
        direction TB

        subgraph GOVERNANCE ["Pillar 1: Turn Governance & Circuit Breakers (config/ai_automation/ai_automation.sh)"]
            direction TB
            GUARD{"agent-guard-check<br/>config/ai_automation/ai_automation.sh"}
            SENTINEL{"~/.agent_stop<br/>Sentinel Exists?"}
            HALT["🚨 EMERGENCY HALT<br/>agent-stop engaged<br/>Blocks all harness turns"]
            RATE{"O(1) Tail Rate Limiter<br/>AUTO_AGENT_MAX_PER_HOUR (30)<br/>Atomic flock Concurrency"}
            RATE_REJECT["⏳ RATE LIMITED<br/>Enforces cooldown delay"]
            TRACE[("📝 Audit Telemetry<br/>~/.local/state/agent-traces/traces.log<br/>(Enforced 0600 Permissions)")]
            COMPACT["🧹 Auto-Compactor<br/>agent-traces-compact<br/>AUTO_AGENT_TRACE_MAX_LINES (10000)"]
        end

        subgraph SECRETS ["Pillar 2: Zero-Ambient Secret Isolation (bin/secret-run)"]
            direction TB
            SECRUN["🔐 CLI: bin/secret-run"]
            CHMOD{"Verify Permissions<br/>Mode 0600 or 0400?"}
            SEC_REJECT["🛑 REJECT INJECTION<br/>Fail-Closed Exit (Code 1)"]
            AST["Safe Subshell AST Parser<br/>bin/secret-run<br/>(Blocks Command Substitution)"]
            CHILD["Ephemeral Subshell<br/>Injects secrets into child process only<br/>Zero ambient leak in parent env"]
        end

        subgraph WORKTREE ["Pillar 3: Git Worktree Sandboxing (bin/agent-worktree)"]
            direction TB
            AW["🌿 CLI: bin/agent-worktree<br/>Alias: config/bash/aliases.d/ai.sh (aw)"]
            SANDBOX["Sandboxed Git Worktree<br/>.worktrees/task-name/<br/>(Protected main branch)"]
            MERGE["Atomic Merge & Cleanup<br/>agent-worktree merge<br/>Deletes worktree upon success"]
        end

        subgraph QUEUE ["Pillar 4: Task Queue Supervision (config/pueue/pueue.yml)"]
            direction TB
            JRUN["⚡ Wrapper: jrun / jagent / jexp<br/>config/bash/aliases.d/ai.sh"]
            DAEMON["pueue Daemon<br/>config/pueue/pueue.yml"]
            Q_AGENTS["Agents Pool<br/>Parallel Limit: 4"]
            Q_EXP["Experiments Pool<br/>Parallel Limit: 2"]
        end

        subgraph MCP ["Pillar 5: Model Context Protocol Governance (config/mcp/mcp.json)"]
            direction TB
            MCP_CONF["Bounded Server Registry<br/>config/mcp/mcp.json"]
            MCP_LOGS["Log Inspector & Truncator<br/>bin/check-mcp-logs<br/>~/.local/state/mcp/*.log"]
        end
    end

    %% -------------------------------------------------------------------------
    %% Host Substrate & Execution Targets
    %% -------------------------------------------------------------------------
    subgraph HOST ["💻 HARDENED UBUNTU HOST SUBSTRATE"]
        direction LR
        RAM["⚡ RAM tmpfs Scratch<br/>/run/user/$UID<br/>(Set in config/bash/.bashrc)"]
        PYPI["📦 Supply Chain Shield<br/>config/uv/uv.toml<br/>config/npm/.npmrc<br/>(7-day quarantine & OSV checks)"]
        REPO[("📁 Git Repository Root<br/>config/git/.gitconfig")]
        DOCTOR["🩺 Self-Healing Medic<br/>bin/doctor (48 checks)<br/>Auto-Repair: doctor --fix"]
        UPDATE["🔄 Living System Updater<br/>bin/dotfiles-update<br/>update.sh & scripts/links.sh"]
    end

    %% -------------------------------------------------------------------------
    %% Interconnection Flows
    %% -------------------------------------------------------------------------
    HUMAN --> JRUN
    HUMAN --> AW
    HUMAN --> DOCTOR
    HUMAN --> UPDATE

    AGENT ==> GUARD
    AGENT ==> SECRUN
    AGENT ==> AW
    AGENT ==> MCP_CONF

    %% Governance Interception Flow
    GUARD --> SENTINEL
    SENTINEL -- "Yes (Stopped)" --> HALT
    SENTINEL -- "No (Active)" --> RATE
    RATE -- "Quota Exceeded" --> RATE_REJECT
    RATE -- "Turn Allowed" --> TRACE
    TRACE --> COMPACT

    %% Secret Isolation Interception Flow
    SECRUN --> CHMOD
    CHMOD -- "Insecure (over 0600)" --> SEC_REJECT
    CHMOD -- "Valid (0600/0400)" --> AST
    AST --> CHILD

    %% Worktree Interception Flow
    AW --> SANDBOX
    SANDBOX -.->|"Completed Work"| MERGE
    MERGE --> REPO

    %% Task Queue Interception Flow
    JRUN --> DAEMON
    DAEMON -.->|"Guard Verified"| Q_AGENTS
    DAEMON --> Q_EXP

    %% MCP Flow
    MCP_CONF --> MCP_LOGS

    %% Substrate Outputs
    TRACE -.-> RAM
    CHILD -.-> PYPI
    Q_AGENTS -.-> RAM

    %% -------------------------------------------------------------------------
    %% Styling Directives (Subgraphs use style, nodes use class/style)
    %% -------------------------------------------------------------------------
    style HARNESS fill:#0b1329,stroke:#00f0ff,stroke-width:3px,color:#ffffff
    style GOVERNANCE fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
    style SECRETS fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
    style WORKTREE fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
    style QUEUE fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
    style MCP fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
    style ACTORS fill:#2e1065,stroke:#a855f7,stroke-width:2px,color:#f3e8ff
    style HOST fill:#18181b,stroke:#71717a,stroke-width:1.5px,color:#e4e4e7

    style HALT fill:#450a0a,stroke:#ef4444,stroke-width:2px,color:#fecaca
    style SEC_REJECT fill:#450a0a,stroke:#ef4444,stroke-width:2px,color:#fecaca
    style RATE_REJECT fill:#450a0a,stroke:#ef4444,stroke-width:2px,color:#fecaca

    style CHILD fill:#064e3b,stroke:#10b981,stroke-width:2px,color:#d1fae5
    style SANDBOX fill:#064e3b,stroke:#10b981,stroke-width:2px,color:#d1fae5
    style MERGE fill:#064e3b,stroke:#10b981,stroke-width:2px,color:#d1fae5
    style COMPACT fill:#0b1329,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
```

### Raw Mermaid Source (Macro)

````markdown
```mermaid
flowchart TB
    %% -------------------------------------------------------------------------
    %% Operators & Autonomous Agents
    %% -------------------------------------------------------------------------
    subgraph ACTORS ["👤 OPERATORS & AUTONOMOUS AGENTS"]
        direction LR
        HUMAN["👨‍💻 Human Engineer<br/>config/bash/.bashrc<br/>config/tmux/.tmux.conf"]
        AGENT["🤖 Autonomous Coding Agent<br/>config/claude/CLAUDE.md<br/>config/claude/settings.json"]
    end

    %% -------------------------------------------------------------------------
    %% THE HARNESS (PRIMARY STANDOUT CONTAINER)
    %% -------------------------------------------------------------------------
    subgraph HARNESS ["🛡️  AI AGENT HARNESS & GOVERNANCE SUBSTRATE (CONTAINMENT LAYER)  "]
        direction TB

        subgraph GOVERNANCE ["Pillar 1: Turn Governance & Circuit Breakers (config/ai_automation/ai_automation.sh)"]
            direction TB
            GUARD{"agent-guard-check<br/>config/ai_automation/ai_automation.sh"}
            SENTINEL{"~/.agent_stop<br/>Sentinel Exists?"}
            HALT["🚨 EMERGENCY HALT<br/>agent-stop engaged<br/>Blocks all harness turns"]
            RATE{"O(1) Tail Rate Limiter<br/>AUTO_AGENT_MAX_PER_HOUR (30)<br/>Atomic flock Concurrency"}
            RATE_REJECT["⏳ RATE LIMITED<br/>Enforces cooldown delay"]
            TRACE[("📝 Audit Telemetry<br/>~/.local/state/agent-traces/traces.log<br/>(Enforced 0600 Permissions)")]
            COMPACT["🧹 Auto-Compactor<br/>agent-traces-compact<br/>AUTO_AGENT_TRACE_MAX_LINES (10000)"]
        end

        subgraph SECRETS ["Pillar 2: Zero-Ambient Secret Isolation (bin/secret-run)"]
            direction TB
            SECRUN["🔐 CLI: bin/secret-run"]
            CHMOD{"Verify Permissions<br/>Mode 0600 or 0400?"}
            SEC_REJECT["🛑 REJECT INJECTION<br/>Fail-Closed Exit (Code 1)"]
            AST["Safe Subshell AST Parser<br/>bin/secret-run<br/>(Blocks Command Substitution)"]
            CHILD["Ephemeral Subshell<br/>Injects secrets into child process only<br/>Zero ambient leak in parent env"]
        end

        subgraph WORKTREE ["Pillar 3: Git Worktree Sandboxing (bin/agent-worktree)"]
            direction TB
            AW["🌿 CLI: bin/agent-worktree<br/>Alias: config/bash/aliases.d/ai.sh (aw)"]
            SANDBOX["Sandboxed Git Worktree<br/>.worktrees/task-name/<br/>(Protected main branch)"]
            MERGE["Atomic Merge & Cleanup<br/>agent-worktree merge<br/>Deletes worktree upon success"]
        end

        subgraph QUEUE ["Pillar 4: Task Queue Supervision (config/pueue/pueue.yml)"]
            direction TB
            JRUN["⚡ Wrapper: jrun / jagent / jexp<br/>config/bash/aliases.d/ai.sh"]
            DAEMON["pueue Daemon<br/>config/pueue/pueue.yml"]
            Q_AGENTS["Agents Pool<br/>Parallel Limit: 4"]
            Q_EXP["Experiments Pool<br/>Parallel Limit: 2"]
        end

        subgraph MCP ["Pillar 5: Model Context Protocol Governance (config/mcp/mcp.json)"]
            direction TB
            MCP_CONF["Bounded Server Registry<br/>config/mcp/mcp.json"]
            MCP_LOGS["Log Inspector & Truncator<br/>bin/check-mcp-logs<br/>~/.local/state/mcp/*.log"]
        end
    end

    %% -------------------------------------------------------------------------
    %% Host Substrate & Execution Targets
    %% -------------------------------------------------------------------------
    subgraph HOST ["💻 HARDENED UBUNTU HOST SUBSTRATE"]
        direction LR
        RAM["⚡ RAM tmpfs Scratch<br/>/run/user/$UID<br/>(Set in config/bash/.bashrc)"]
        PYPI["📦 Supply Chain Shield<br/>config/uv/uv.toml<br/>config/npm/.npmrc<br/>(7-day quarantine & OSV checks)"]
        REPO[("📁 Git Repository Root<br/>config/git/.gitconfig")]
        DOCTOR["🩺 Self-Healing Medic<br/>bin/doctor (48 checks)<br/>Auto-Repair: doctor --fix"]
        UPDATE["🔄 Living System Updater<br/>bin/dotfiles-update<br/>update.sh & scripts/links.sh"]
    end

    %% -------------------------------------------------------------------------
    %% Interconnection Flows
    %% -------------------------------------------------------------------------
    HUMAN --> JRUN
    HUMAN --> AW
    HUMAN --> DOCTOR
    HUMAN --> UPDATE

    AGENT ==> GUARD
    AGENT ==> SECRUN
    AGENT ==> AW
    AGENT ==> MCP_CONF

    %% Governance Interception Flow
    GUARD --> SENTINEL
    SENTINEL -- "Yes (Stopped)" --> HALT
    SENTINEL -- "No (Active)" --> RATE
    RATE -- "Quota Exceeded" --> RATE_REJECT
    RATE -- "Turn Allowed" --> TRACE
    TRACE --> COMPACT

    %% Secret Isolation Interception Flow
    SECRUN --> CHMOD
    CHMOD -- "Insecure (over 0600)" --> SEC_REJECT
    CHMOD -- "Valid (0600/0400)" --> AST
    AST --> CHILD

    %% Worktree Interception Flow
    AW --> SANDBOX
    SANDBOX -.->|"Completed Work"| MERGE
    MERGE --> REPO

    %% Task Queue Interception Flow
    JRUN --> DAEMON
    DAEMON -.->|"Guard Verified"| Q_AGENTS
    DAEMON --> Q_EXP

    %% MCP Flow
    MCP_CONF --> MCP_LOGS

    %% Substrate Outputs
    TRACE -.-> RAM
    CHILD -.-> PYPI
    Q_AGENTS -.-> RAM

    %% -------------------------------------------------------------------------
    %% Styling Directives
    %% -------------------------------------------------------------------------
    style HARNESS fill:#0b1329,stroke:#00f0ff,stroke-width:3px,color:#ffffff
    style GOVERNANCE fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
    style SECRETS fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
    style WORKTREE fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
    style QUEUE fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
    style MCP fill:#1e293b,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
    style ACTORS fill:#2e1065,stroke:#a855f7,stroke-width:2px,color:#f3e8ff
    style HOST fill:#18181b,stroke:#71717a,stroke-width:1.5px,color:#e4e4e7

    style HALT fill:#450a0a,stroke:#ef4444,stroke-width:2px,color:#fecaca
    style SEC_REJECT fill:#450a0a,stroke:#ef4444,stroke-width:2px,color:#fecaca
    style RATE_REJECT fill:#450a0a,stroke:#ef4444,stroke-width:2px,color:#fecaca

    style CHILD fill:#064e3b,stroke:#10b981,stroke-width:2px,color:#d1fae5
    style SANDBOX fill:#064e3b,stroke:#10b981,stroke-width:2px,color:#d1fae5
    style MERGE fill:#064e3b,stroke:#10b981,stroke-width:2px,color:#d1fae5
    style COMPACT fill:#0b1329,stroke:#38bdf8,stroke-width:1.5px,color:#e2e8f0
```
````

### Architectural Narrative

1. **The Containment Layer (`HARNESS`)**:
   Enclosed in a prominent dark navy container with an electric cyan border (`#00f0ff`), the Harness intercepts every agent command. Agents cannot execute arbitrary bash commands against production state; they must operate through the sandboxes provided by the five pillars.
2. **Pillar 1: Turn Governance (`config/ai_automation/ai_automation.sh`)**:
   Enforces pre-flight checks before each turn. If a human engineer runs `agent-stop`, the `~/.agent_stop` sentinel file is created, causing all agent loops to instantly abort. If allowed, invocations are audited to `~/.local/state/agent-traces/traces.log` (mode `0600`).
3. **Pillar 2: Zero-Ambient Secrets (`bin/secret-run`)**:
   Replaces persistent `.env` files in parent shells with ephemeral child process injection. It validates file permissions (`0600`/`0400`), sanitizes values via AST parsing to prevent command execution, and discards secrets upon process exit.
4. **Pillar 3: Worktree Sandboxing (`bin/agent-worktree`)**:
   Isolates agent code generations in separate git worktrees located at `.worktrees/<task>`. The main branch remains pristine until an explicit merge is approved.
5. **Pillar 4: Task Queue Supervision (`config/pueue/pueue.yml`)**:
   Pueue manages background compute pools (`agents` capped at concurrency 4, `experiments` capped at 2), preventing autonomous agents from exhausting host CPU/RAM resources.
6. **Pillar 5: Model Context Protocol Governance (`config/mcp/mcp.json`)**:
   Constrains MCP tool integrations to explicit paths and auditable command wrappers with automated log inspection (`bin/check-mcp-logs`).

---

## Diagram 2: Runtime Turn Interception & Execution Sequence (Micro View)

### Rendered Micro Diagram

![Diagram 2: Runtime Turn Interception & Execution Sequence (Micro View)](assets/runtime-turn-interception-micro.svg)

### Visual Reference & Color Legend

The micro sequence diagram utilizes a standardized semantic color hierarchy and shaded decision zones to make turn routing, feedback loops, and early-exit abort paths instantly readable:

| Phase / Sequence Badge | Accent Color | Visual Role | Subsystem & File Reference |
| :--- | :--- | :--- | :--- |
| **Phase 1: Steps 1, 2, 5, 7, 8** | Sky Blue (`#0284c7`) | Pre-flight turn governance & audit trace | `config/ai_automation/ai_automation.sh` |
| **Alert Exits: Steps 3, 4, 6** | Crimson Red (`#dc2626`) | Fail-closed circuit breaker & quota aborts | Sentinel Halt (Exit 1), Quota Exhaustion (Exit 2) |
| **Phase 2: Steps 9, 10, 11** | Emerald Green (`#059669`) | Ephemeral Git worktree isolation | `bin/agent-worktree` (`.worktrees/`) |
| **Phase 3: Steps 12–17** | Violet (`#7c3aed`) | Ephemeral subshell secret injection & AST validation | `bin/secret-run` (`~/.secrets/ai.env`) |
| **Phase 4: Steps 18–22** | Indigo (`#4f46e5`) | Supervised background queuing & concurrency capping | `pueue` daemon (`config/pueue/pueue.yml`) |

#### Shaded Decision Zones & Loop Conventions
- 🔴 **Crimson Shaded Panels (`rgba(220, 38, 38, 0.08)`)**: Early rejection abort paths returning directly to `Agent` (Exit 1 sentinel trip, Exit 2 hourly rate limit exceeded).
- 🔵 **Dark Slate Shaded Panel (`rgba(15, 23, 42, 0.35)`)**: Gated continuation when sentinel is clear (`flock` concurrency gating and tail scan).
- 🟢 **Emerald Shaded Panel (`rgba(5, 150, 105, 0.12)`)**: Authorized execution branch where trace is recorded and `Turn Authorized` is returned.
- 🔄 **Curved Accent Self-Loops (Steps 5, 13, 14)**: Local self-execution checks (atomic flock tail scan, file mode verification, AST backtick validation) executing within the component before calling external services.
- 🌿 **Phase Container Panels (Phases 2, 3, 4)**: Themed background panels providing clear visual boundaries for worktree isolation, secret subshells, and pueue queues.

### Live Mermaid Sequence (Micro)

```mermaid
sequenceDiagram
    autonumber
    actor Agent as "🤖 Autonomous Agent<br/>(config/claude/CLAUDE.md)"
    box rgb(11, 19, 41) 🛡️ AI Agent Harness & Governance Core
        participant Guard as "agent-guard-check<br/>(config/ai_automation/ai_automation.sh)"
        participant Breaker as "Circuit Breaker (~/.agent_stop)<br/>(config/ai_automation/ai_automation.sh)"
        participant Worktree as "agent-worktree / aw<br/>(bin/agent-worktree)"
        participant SecRun as "secret-run<br/>(bin/secret-run)"
        participant Queue as "pueue / jrun()<br/>(config/bash/aliases.d/ai.sh)"
    end
    participant Host as "💻 Hardened Ubuntu Host<br/>(config/bash/.bashrc)"

    Note over Agent,Guard: Phase 1: Turn Governance & Circuit Breakers
    Agent->>Guard: Request Turn Execution (caller: agent-loop)
    Guard->>Breaker: Check existence of ~/.agent_stop sentinel & EUID
    alt Sentinel Exists (~/.agent_stop)
        Breaker-->>Guard: Circuit Breaker ENGAGED (agent-stop)
        Guard-->>Agent: 🚨 REJECT: Turn blocked by sentinel (Exit 1)
    else Circuit Clear
        Guard->>Guard: O(1) Bounded Tail Scan (last M entries) & atomic flock
        alt Rate Limit Exceeded
            Guard-->>Agent: ⏳ REJECT: Hourly limit exceeded (Exit 2)
        else Under Rate Quota
            Guard->>Host: Append zero-fork UTC trace (chmod 0600) & sample compact
            Guard-->>Agent: ✅ Turn Authorized
        end
    end

    Note over Agent,Worktree: Phase 2: Workspace Isolation (Zero Collision on Main)
    Agent->>Worktree: agent-worktree new eval-task
    Worktree->>Host: git worktree add .worktrees/eval-task -b agent/eval-task
    Worktree-->>Agent: Working Directory Ready at .worktrees/eval-task/

    Note over Agent,SecRun: Phase 3: Ephemeral Secret Injection (Zero Ambient Leak)
    Agent->>SecRun: secret-run --env-file ~/.secrets/ai.env -- python eval.py
    SecRun->>SecRun: Check ~/.secrets/ai.env permissions (Must be 0600 or 0400)
    SecRun->>SecRun: AST Parse file: Reject command substitution and backticks
    SecRun->>Host: Fork ephemeral child subshell with exported env vars
    Host-->>SecRun: Command finishes, child subshell terminates
    SecRun-->>Agent: Stdout/Stderr returned (Parent environment retains zero secrets)

    Note over Agent,Queue: Phase 4: Supervised Task Queuing & Concurrency
    Agent->>Queue: jagent python long_training_run.py
    Queue->>Guard: Validate agent-guard-check for group 'agents'
    Queue->>Host: pueue add --group agents (concurrency capped at 4)
    Host-->>Queue: Task running asynchronously in background
    Queue-->>Agent: Task ID dispatched (Monitored via jls / jfollow)
```

### Raw Mermaid Source (Micro)

````markdown
```mermaid
sequenceDiagram
    autonumber
    actor Agent as "🤖 Autonomous Agent<br/>(config/claude/CLAUDE.md)"
    box rgb(11, 19, 41) 🛡️ AI Agent Harness & Governance Core
        participant Guard as "agent-guard-check<br/>(config/ai_automation/ai_automation.sh)"
        participant Breaker as "Circuit Breaker (~/.agent_stop)<br/>(config/ai_automation/ai_automation.sh)"
        participant Worktree as "agent-worktree / aw<br/>(bin/agent-worktree)"
        participant SecRun as "secret-run<br/>(bin/secret-run)"
        participant Queue as "pueue / jrun()<br/>(config/bash/aliases.d/ai.sh)"
    end
    participant Host as "💻 Hardened Ubuntu Host<br/>(config/bash/.bashrc)"

    Note over Agent,Guard: Phase 1: Turn Governance & Circuit Breakers
    Agent->>Guard: Request Turn Execution (caller: agent-loop)
    Guard->>Breaker: Check existence of ~/.agent_stop sentinel & EUID
    alt Sentinel Exists (~/.agent_stop)
        Breaker-->>Guard: Circuit Breaker ENGAGED (agent-stop)
        Guard-->>Agent: 🚨 REJECT: Turn blocked by sentinel (Exit 1)
    else Circuit Clear
        Guard->>Guard: O(1) Bounded Tail Scan (last M entries) & atomic flock
        alt Rate Limit Exceeded
            Guard-->>Agent: ⏳ REJECT: Hourly limit exceeded (Exit 2)
        else Under Rate Quota
            Guard->>Host: Append zero-fork UTC trace (chmod 0600) & sample compact
            Guard-->>Agent: ✅ Turn Authorized
        end
    end

    Note over Agent,Worktree: Phase 2: Workspace Isolation (Zero Collision on Main)
    Agent->>Worktree: agent-worktree new eval-task
    Worktree->>Host: git worktree add .worktrees/eval-task -b agent/eval-task
    Worktree-->>Agent: Working Directory Ready at .worktrees/eval-task/

    Note over Agent,SecRun: Phase 3: Ephemeral Secret Injection (Zero Ambient Leak)
    Agent->>SecRun: secret-run --env-file ~/.secrets/ai.env -- python eval.py
    SecRun->>SecRun: Check ~/.secrets/ai.env permissions (Must be 0600 or 0400)
    SecRun->>SecRun: AST Parse file: Reject command substitution and backticks
    SecRun->>Host: Fork ephemeral child subshell with exported env vars
    Host-->>SecRun: Command finishes, child subshell terminates
    SecRun-->>Agent: Stdout/Stderr returned (Parent environment retains zero secrets)

    Note over Agent,Queue: Phase 4: Supervised Task Queuing & Concurrency
    Agent->>Queue: jagent python long_training_run.py
    Queue->>Guard: Validate agent-guard-check for group 'agents'
    Queue->>Host: pueue add --group agents (concurrency capped at 4)
    Host-->>Queue: Task running asynchronously in background
    Queue-->>Agent: Task ID dispatched (Monitored via jls / jfollow)
```
````

### Execution Lifecycle Walkthrough

The runtime interception sequence executes across four strictly ordered phases:

#### Phase 1: Turn Governance & Circuit Breakers (Steps 1–8)
1. **Pre-flight Turn Request (Step 1)**: The autonomous agent requests turn execution through `agent-guard-check`.
2. **Sentinel Verification (Step 2)**: The guard checks for the presence of the `~/.agent_stop` sentinel file and verifies calling EUID.
3. **Emergency Halt Exit (Steps 3–4)**: If the sentinel exists, the circuit breaker engages, aborting execution immediately with exit code `1` (`Turn blocked by sentinel`).
4. **Atomic Tail Rate Scan (Step 5)**: If clear, the guard acquires an atomic non-blocking lock (`flock -x -w 2 fd 200`) and runs an $O(1)$ bounded tail scan of `traces.log` (evaluating at most `AUTO_AGENT_MAX_PER_HOUR=30` records).
5. **Rate Quota Abort (Step 6)**: If the hourly limit is exceeded, the guard releases the lock and aborts with exit code `2` (`Hourly limit exceeded`).
6. **Telemetry & Authorization (Steps 7–8)**: If under quota, an audit record with an in-process zero-fork ISO-8601 UTC timestamp is appended (mode `0600`), compaction is sampled, and `Turn Authorized (Exit 0)` is returned.

#### Phase 2: Workspace Isolation via Git Worktrees (Steps 9–11)
7. **Worktree Provisioning (Step 9)**: To prevent working tree collisions on `main`, the agent invokes `agent-worktree new <task>`.
8. **Host Branch Creation (Step 10)**: The CLI triggers `git worktree add .worktrees/<task> -b agent/<task>` on the host.
9. **Isolated Sandbox Ready (Step 11)**: The isolated checkout is verified, allowing the agent to mutate, build, and test code without dirtying the root repository.

#### Phase 3: Ephemeral Secret Injection (Steps 12–17)
10. **Targeted Invocation (Step 12)**: Whenever API tokens or sensitive credentials are required, the agent calls `secret-run --env-file ~/.secrets/ai.env -- <command>`.
11. **Permission Validation (Step 13)**: `secret-run` inspects secret file permissions, failing closed if permissions exceed `0600` or `0400`.
12. **Safe AST Parsing (Step 14)**: The file is parsed via bash AST inspection, rejecting command substitution (`$()`), backticks, and subshell escapes.
13. **Ephemeral Subshell Execution (Steps 15–16)**: Secrets are exported strictly within a short-lived child subshell that terminates immediately upon command completion.
14. **Clean Exit (Step 17)**: Output is returned to the agent while the host parent environment retains zero ambient secrets.

#### Phase 4: Supervised Task Queuing & Concurrency (Steps 18–22)
15. **Job Dispatch (Step 18)**: Long-running or heavy workloads are submitted via `jagent <command>`.
16. **Guard Verification (Step 19)**: The wrapper validates `agent-guard-check` for pool group `agents`.
17. **Host Scheduling (Step 20)**: The task is queued into the `pueue` daemon, capped at concurrency 4 for agents (or 2 for experiments).
18. **Asynchronous Execution (Steps 21–22)**: The task runs in the background while the task ID is returned to the agent for non-blocking monitoring via `jls` and `jfollow`.

---

## Component & File Mapping Matrix

| Subsystem | Key Files | Invariants Enforced | Operational Role |
| :--- | :--- | :--- | :--- |
| **Circuit Breaker** | `config/ai_automation/ai_automation.sh` | Sentinel file presence immediately aborts all harnesses. Resumption requires matching EUID. $O(1)$ bounded tail scan & atomic `flock` concurrency gating. | Emergency stop & hourly execution limits |
| **Telemetry** | `~/.local/state/agent-traces/traces.log` | File permissions strictly constrained to `0600`. Auto-compacted via `AUTO_AGENT_TRACE_MAX_LINES`. | Immutable invocation logs & rate metrics |
| **Secret Runner** | `bin/secret-run` | Zero ambient secrets in parent shell. Insecure permissions (`>0600`) rejected. | Ephemeral child subshell injection |
| **Worktree Manager** | `bin/agent-worktree`, `config/bash/aliases.d/ai.sh` | Main branch protected; all agent branches isolated to `.worktrees/`. | Non-destructive filesystem sandboxing |
| **Task Queue** | `config/pueue/pueue.yml`, `config/bash/aliases.d/ai.sh` | Concurrency capped at 4 for agents, 2 for experiments. | Background execution & resource budgeting |
| **MCP Boundaries** | `config/mcp/mcp.json`, `bin/check-mcp-logs` | Filesystem server prevents bare `.` mounts; logs audited in `~/.local/state/mcp/`. | Model Context Protocol scoping |
| **Medic Diagnostics** | `bin/doctor`, `update.sh` | 48 automated checks across symlinks, packages, Docker, Git, guardrails, and secrets. | Configuration drift detection & self-healing |
| **Supply Chain** | `config/bash/.bashrc`, `config/uv/uv.toml`, `config/npm/.npmrc` | 7-day PyPI quarantine (`UV_EXCLUDE_NEWER`), OSV malware scanning, npm scripts disabled. | Supply chain attack immunity |
| **Memory Filesystem** | `config/bash/.bashrc` | `TMPDIR` redirected to `/run/user/$UID` (RAM tmpfs). | High-speed scratch I/O & SSD endurance |
| **Living Updater** | `bin/dotfiles-update`, `update.sh`, `scripts/links.sh` | Rebase sync, symlink refresh, and `doctor --fix` self-healing pipeline. | Automated workstation maintenance |
