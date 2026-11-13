# AI Automation Engineer Workstation — Architecture Diagrams

> 📚 **Navigation:** [README.md](../README.md) | [Field Manual (MANUAL.md)](MANUAL.md) | [Quick Start (QUICK-START.md)](QUICK-START.md) | [Test Receipts (TEST_RECEIPTS.md)](TEST_RECEIPTS.md)

How the workstation keeps a coding agent (for example Claude Code) away from your secrets, your working branch and your machine's capacity. Each diagram is written in Mermaid and rendered by GitHub, so there is one source and it follows your light or dark theme.

---

## Table of Contents
1. [What is enforced and what is opt-in](#what-is-enforced-and-what-is-opt-in)
2. [Diagram 1: Architecture](#diagram-1-architecture)
3. [Diagram 2: One agent task, step by step](#diagram-2-one-agent-task-step-by-step)
4. [Component and file map](#component-and-file-map)

---

## What is enforced and what is opt-in

Read this first. It decides how much each box below protects you.

| Layer | Enforced by | Covers | Does not cover |
| :--- | :--- | :--- | :--- |
| **Claude Code permission rules** (`config/claude/settings.json`, installed to `~/.claude/settings.json`) | Claude Code itself, on every call to its file tools | Reading secret files, `.env` files, `.worktrees/`, `.git/` and other denied paths; editing outside the allowed patterns | Shell commands the agent runs; other agents that don't read this file |
| **Circuit breaker and rate limit** (`agent-guard-check`) | Nothing calls it automatically. `jagent` (`jrun agents`) calls it before queuing; agent loops must call it themselves | Stopping agent loops (`agent-stop`); at most 30 guarded runs per hour | Any command that doesn't go through the guard |
| **`secret-run`, `agent-worktree`, `pueue` queues** | Used when you or the agent run them | Scoped secrets, branch isolation, concurrency limits | Work done without them |
| **Host settings** (`.bashrc`, `.npmrc`) | Your shell and package managers | 7-day PyPI cut-off, uv malware check on syncs, npm install scripts off, RAM scratch on Linux | Packages installed outside `uv` / `npm` |

---

## Diagram 1: Architecture

### 1a · Overview

```mermaid
flowchart TB
    classDef enforced stroke:#16a34a,stroke-width:3px
    classDef optin stroke-dasharray:5 4

    AGENT["Coding agent (Claude Code)<br/>instructions: ~/.claude/CLAUDE.md ← config/agents/AGENTS.md"]
    HUMAN["Human SysOp"]

    RULES["Claude Code permission rules · ~/.claude/settings.json<br/>Read denied: secret files, .env files, .worktrees, .git and 6 more paths<br/>Edit allowed without asking: Markdown, text and test files"]:::enforced

    subgraph TOOLS["Opt-in tools · protect only the work that goes through them"]
        GUARD["1 · agent-guard-check<br/>stop switch + 30 runs/hour"]:::optin
        SR["2 · secret-run<br/>secrets for one command"]:::optin
        AW["3 · agent-worktree<br/>own folder and branch"]:::optin
        Q["4 · jagent / jexp<br/>pueue queues, 4 / 2 at a time"]:::optin
        MCP["5 · MCP servers<br/>filesystem · git · fetch"]:::optin
    end

    HOST["Host · Ubuntu or macOS<br/>PyPI 7-day cut-off · uv malware check · npm scripts off · RAM TMPDIR on Linux · doctor · dotfiles-update"]

    AGENT ==>|"every Read / Edit tool call"| RULES
    AGENT -.->|"may call"| TOOLS
    HUMAN -->|"agent-stop / agent-resume · merges · doctor"| TOOLS
    Q -.->|"jagent runs the guard first"| GUARD
    TOOLS --> HOST
```

### 1b · Circuit breaker and rate limit (`config/ai_automation/ai_automation.sh`)

```mermaid
flowchart LR
    classDef reject stroke:#dc2626,stroke-width:2px
    classDef ok stroke:#0d9488,stroke-width:2px

    CALL["agent-guard-check<br/>(called by an agent loop or by jagent)"] --> STOP{"~/.agent_stop<br/>exists?"}
    STOP -->|"yes"| R1["Refused · return 1"]:::reject
    STOP -->|"no"| COUNT{"30 or more runs<br/>in the last hour?"}
    COUNT -->|"yes"| R2["Refused · return 2"]:::reject
    COUNT -->|"no"| LOG[("Append to traces.log<br/>mode 0600 · keep 10,000 lines")]:::ok
    LOG --> OK["Allowed · return 0"]:::ok
```

### 1c · Scoped secrets (`secret-run`, Rust)

```mermaid
flowchart LR
    classDef reject stroke:#dc2626,stroke-width:2px
    classDef ok stroke:#0d9488,stroke-width:2px

    RUN["secret-run -- cmd"] --> FIND["Pick the secret file<br/>--env-file, else .env.local → .env →<br/>~/.secrets/ai.env → ~/.dotfiles.local<br/>(--strict skips .env.local and .env)"]
    FIND --> PERM{"Mode 0600 or 0400<br/>and owned by you?"}
    PERM -->|"no"| X["Refused"]:::reject
    PERM -->|"yes"| LINES{"Any line with $( ,<br/>backticks, ;; or function?"}
    LINES -->|"yes"| X
    LINES -->|"no"| EXEC["exec cmd with the secrets<br/>in its environment only"]:::ok
```

**How to read it**

- **Thick green border:** enforced by Claude Code, whatever the agent intends. It applies to Claude Code's file tools only. A shell command the agent runs (for example `cat .env`) is not covered by these rules.
- **Dashed boxes and dotted arrows:** tools the agent *may* call. If it doesn't, they do nothing.
- **Red border:** a refusal. **Teal border:** allowed.
- **Circuit breaker:** `agent-stop` creates `~/.agent_stop`, and every later `agent-guard-check` refuses with return code 1. `agent-resume` removes it, and refuses if the stop file belongs to another user. The guard counts the last 30 entries of `traces.log`; it takes a `flock` lock (waiting up to 2 seconds) only where `flock` is installed, which stock macOS doesn't have.
- **`secret-run`:** replaces itself with your command (`exec`), so the secrets exist only in that command's environment and never in your shell. It reads a plaintext secret file; it does not remove the need for one.
- **Worktrees:** isolation comes from the separate branch. Nothing locks `main`; merging is your decision.

---

## Diagram 2: One agent task, step by step

```mermaid
sequenceDiagram
    autonumber
    actor Agent as Coding agent
    participant Guard as agent-guard-check
    participant WT as agent-worktree
    participant SR as secret-run
    participant Q as jagent / pueue
    participant Host as Host

    Note over Agent,Guard: 1 · Circuit breaker and rate limit (only if the agent loop calls it)
    Agent->>Guard: agent-guard-check
    alt ~/.agent_stop exists
        Guard-->>Agent: refused, return 1
    else not stopped
        Guard->>Guard: count runs in the last hour (last 30 trace lines, under flock where available)
        alt 30 or more
            Guard-->>Agent: refused, return 2
        else under the limit
            Guard->>Host: append a trace line (traces.log, mode 0600), trim to 10,000 lines
            Guard-->>Agent: allowed, return 0
        end
    end

    Note over Agent,WT: 2 · Branch isolation
    Agent->>WT: agent-worktree new eval-task
    WT->>Host: git worktree add .worktrees/eval-task -b agent/eval-task
    WT-->>Agent: work in .worktrees/eval-task

    Note over Agent,SR: 3 · Scoped secrets
    Agent->>SR: secret-run --strict -- python eval.py
    SR->>SR: find ~/.secrets/ai.env (strict skips .env.local and .env)
    SR->>SR: mode 0600 or 0400, owned by you, no $( or backticks
    SR->>Host: exec python eval.py with the secrets in its environment
    Host-->>Agent: output (the agent's shell never had the secrets)

    Note over Agent,Q: 4 · Queued work
    Agent->>Q: jagent python long_run.py
    Q->>Guard: agent-guard-check (jrun:agents)
    Guard-->>Q: allowed
    Q->>Host: pueue add --group agents (4 run at a time)
    Q-->>Agent: task id (follow with jls / jfollow)
```

**What each phase guarantees**

1. **Circuit breaker:** a stopped workstation refuses guarded runs, and the hourly limit caps them. Runs that skip the guard aren't counted or stopped.
2. **Branch isolation:** the agent's changes sit on `agent/<task>` in their own folder, so your checkout stays clean until you merge.
3. **Scoped secrets:** the secret file must be private to you, and its lines can't contain command substitution. The secrets reach only the command that `secret-run` starts.
4. **Queued work:** `jagent` checks the guard before queuing, and pueue runs at most 4 agent tasks (and 2 experiments) at a time.

---

## Component and file map

| Subsystem | Files | What the code does | Limits |
| :--- | :--- | :--- | :--- |
| **Permission rules** | `config/claude/settings.json` → `~/.claude/settings.json` | Denies reading `~/.secrets/**`, `**/*.env`, `**/*.env.*`, `**/.dotfiles.local`, `./.worktrees/**`, `**/.venv/**`, `**/__pycache__/**`, `**/.git/**`, `**/node_modules/**`, `**/.pueue/**`; allows editing `**/*.md`, `**/*.txt`, `**/tests/**`, `**/test_*.py` without asking | Claude Code file tools only, not shell commands |
| **Agent instructions** | `config/agents/AGENTS.md` → `~/.claude/CLAUDE.md`, `~/.config/agents/AGENTS.md` | Shared instructions for agents | Instructions, not enforcement |
| **Circuit breaker** | `config/ai_automation/ai_automation.sh` | `agent-stop` / `agent-resume` / `agent-guard-check`; refuses when `~/.agent_stop` exists | Applies only to callers of `agent-guard-check` |
| **Rate limit and traces** | `~/.local/state/agent-traces/traces.log` | 30 guarded runs per hour (`AUTO_AGENT_MAX_PER_HOUR`); log mode 0600, trimmed to 10,000 lines (`AUTO_AGENT_TRACE_MAX_LINES`) | The log is user-writable and trimmed, so it is a record, not tamper-proof |
| **Secrets** | `bin/secret-run` → `workstation secret-run` (Rust) | Finds the secret file, checks mode 0600/0400 and ownership, rejects `$(`, backticks, `;;`, `function`, then `exec`s the command | Secrets still live in a plaintext file on disk |
| **Worktrees** | `bin/agent-worktree` → `workstation worktree`, `config/bash/aliases.d/ai.sh` (`aw`) | `.worktrees/<task>` on `agent/<task>`; merge removes the worktree and branch | Nothing prevents direct commits to `main` |
| **Queues** | `config/pueue/pueue.yml`, `config/bash/aliases.d/ai.sh` | `agents` group 4 parallel (guarded); `experiments` 2 parallel (not guarded) | Only work submitted through `jrun` |
| **MCP servers** | `config/mcp/mcp.json`, `bin/check-mcp-logs` | filesystem server on `~/Development`, plus git and fetch; log viewer | Server packages are fetched unpinned (`npx -y`, `uvx`) |
| **Supply chain** | `config/bash/.bashrc`, `config/npm/.npmrc` | PyPI releases newer than 7 days are ignored (`UV_EXCLUDE_NEWER`); OSV malware check on uv syncs; npm install scripts off, `audit` on, exact versions saved | `UV_MALWARE_CHECK=1` makes uv (0.11.16+, pinned 0.13.7) check locked packages against OSV known-malware advisories on each sync; a uv preview feature, malware only, not CVEs. npm has no age cut-off |
| **RAM scratch** | `config/bash/.bashrc` | `TMPDIR=/run/user/$UID` when that folder exists | Linux only |
| **Health and updates** | `bin/doctor` (`doctor --fix`), `bin/dotfiles-update`, `update.sh` | Checks links, packages, Docker, git, guardrails and secrets; repairs links; pulls updates | — |
