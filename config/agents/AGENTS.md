# AGENTS.md: Global AI Coding Agent System Guidelines & Harness Tools

You are operating inside a customized **Ubuntu Linux AI Engineering & Developer Automation** environment.
This machine is configured with security guardrails, scoped credential isolation, task queues, and isolated git worktrees. Adhere strictly to the guidelines and tooling conventions below.

---

## 1. System Harness Tooling & Capabilities

Always leverage the following local CLI tools instead of inventing ad-hoc alternatives:

### Scoped Secret Execution (`secret-run`)
- **NEVER** ask the user to paste raw API keys (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `HF_TOKEN`, etc.) into shell prompts or commit them to files.
- **NEVER** write plaintext keys into `.env` files in git repositories.
- Use `secret-run` to execute commands that require credentials in a sandboxed, temporary subshell:
  ```bash
  secret-run -- python eval_model.py
  secret-run --env-file ~/.secrets/custom.env -- pytest tests/
  ```

### Isolated Git Worktrees for Agents (`agent-worktree` / `aw`)
- When working on complex refactors, feature branches, or parallel subagent tasks, isolate your working directory:
  ```bash
  agent-worktree new <task-name>      # Creates .worktrees/<task-name> on branch agent/<task-name>
  agent-worktree list                 # Lists active worktrees
  agent-worktree merge <task-name>    # Safely merges changes and removes worktree
  agent-worktree remove <task-name>   # Discards worktree safely
  ```
- All `.worktrees/` directories are globally ignored by git.

### Background Task Queue (`pueue` / `jrun`)
- For long-running batch inference, model evaluations, data processing, or large test suites, do not block the interactive terminal:
  ```bash
  jexp python run_eval.py        # Enqueue in 'experiments' queue (max 2 parallel GPU/CPU jobs)
  jagent bash test_agent.sh      # Enqueue in 'agents' queue (max 4 parallel tasks)
  jls                            # Inspect task status
  jfollow <id>                   # Stream live logs
  jlog <id>                      # View finished task log
  jkill <id>                     # Cancel a running task
  ```

### Python & AI Package Management (`uv`)
- Always prefer `uv` over `pip` for Python operations:
  ```bash
  uv venv                        # Create virtual environment (.venv)
  uv pip install <pkg>           # Fast package installation
  uv run <script.py>             # Run script with virtual environment auto-loaded
  ```
- **Supply Chain Quarantine**: Note that `UV_EXCLUDE_NEWER` enforces a 7-day quarantine on newly published PyPI releases to prevent zero-day package takeovers. If a package published in the last 7 days is strictly required, understand that the system enforces this defense mechanism.

### Model Context Protocol (`mcp.json` / `check-mcp-logs`)
- Canonical MCP server configurations reside at `~/.config/mcp/mcp.json`.
- When diagnosing MCP communication errors or inspecting server outputs, use:
  ```bash
  check-mcp-logs                 # Show recent server logs
  check-mcp-logs --tail          # Follow logs in real time
  ```

### Docker & Container Daemon (`ensure-docker` / `edocker`)
- If a task requires Docker and the daemon is unresponsive or permissions are missing, run:
  ```bash
  ensure-docker                  # Validates socket permissions and starts Docker daemon
  ```

### System Health & Drift Verification (`doctor`)
- Verify the integrity of the environment at any time:
  ```bash
  doctor                         # Runs health check across 20+ tools and configs
  doctor --fix                   # Automatically restores missing symlinks and heals drift
  ```

---

## 2. File & Directory Privacy Boundaries

Do NOT attempt to read, scan, or index:
- `~/.secrets/**`, `*.env`, or `**/.env.*` (Credentials quarantine).
- `.worktrees/**` (Other concurrent agent workdirs).
- `.venv/**`, `__pycache__/**`, `node_modules/**` (Dependency caches).
- `.pueue/**` (Internal queue runtime database).

---

## 3. Engineering & Code Standards

- **Code Style**: Write clean, concise, self-documenting code. Avoid redundant explanatory comments for obvious logic; reserve comments for non-obvious design choices or workarounds.
- **Verification First**: Always run tests or validation scripts before claiming completion of a task.
- **Fail Fast & Safe**: If an operation fails, diagnose root causes rather than silently suppressing errors.
