# AI Automation Engineer Workstation: Ubuntu Baseline & Harness

A modular, robust, and security-hardened workstation repository designed for **AI Automation Engineers** and **AI Engineers** (developers running autonomous agents, local test harnesses, and model evals) on Ubuntu.

Includes automated package bootstrapping, supply chain quarantine, credential isolation, git worktree isolation for concurrent agents, task queue supervision, and full Docker container verification.

> 📚 **Complete Documentation Suite:**
> - 📖 **[The AI Automation Engineer's Field Manual](MANUAL.md)**: Deep architectural guide explaining agent runtime layers, threat models, supply chain defense, and systems engineering for autonomous agents.
> - 🚀 **[The Quick Start Guide](QUICK-START.md)**: Hands-on 30-minute walkthrough, interactive playground missions, and real-world recipes for controlling agents.
> - 🧪 **[Empirical Test Receipts](TEST_RECEIPTS.md)**: 16-stage container verification proofs and assertion records.

---

## Key Highlights for AI & Automation Engineers

### 1. Supply Chain Defense (PyPI & npm)
- **7-Day Package Quarantine**: Automatically sets `UV_EXCLUDE_NEWER` to 7 days prior in interactive shells. Zero-day compromised PyPI packages are held back before your local harness or environment downloads them.
- **Malware Checking**: `UV_MALWARE_CHECK=1` queries the OSV vulnerability database on every package addition.
- **Script Execution Guard**: `.npmrc` sets `ignore-scripts=true` to block arbitrary postinstall script execution and token exfiltration.

### 2. Credential Isolation (Zero Ambient API Keys)
- **No Ambient Secrets**: Secrets like `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `HF_TOKEN` are kept **out** of global `~/.bashrc` to prevent accidental exfiltration by untrusted subagents, prompt injections, or testing scripts.
- **`secret-run`**: CLI wrapper that executes a command with secrets loaded into a temporary subshell, keeping the parent shell clean:
  ```bash
  secret-run -- python eval_model.py
  secret-run --env-file ~/.secrets/custom.env -- pytest tests/
  ```
- **`direnv` Support**: Includes `.envrc.template` to automatically bind project-specific tokens strictly when `cd`-ing into that project.
- **Machine Overrides**: Use `~/.dotfiles.local` (mode `0600`) for private machine-local configurations.

### 3. Isolated Git Worktrees for Concurrent AI Agents
When running autonomous agents (Antigravity, Claude Code, Codex, Aider), running multiple instances simultaneously in the same working tree causes file and index corruption.
- **`agent-worktree` CLI** (`aw`):
  ```bash
  agent-worktree new auth-refactor       # Creates .worktrees/auth-refactor on branch agent/auth-refactor
  agent-worktree list                   # Lists active worktrees & branch states
  agent-worktree merge auth-refactor    # Merges back to current branch and removes worktree
  agent-worktree remove auth-refactor   # Deletes worktree safely
  agent-worktree clean                  # Prunes stale worktree references
  ```
- Fast aliases: `aw-new`, `aw-ls`, `aw-merge`, `aw-rm`.

### 4. Agent Guardrails, Circuit Breakers & Telemetry
Local agent loops can run amok with recursive subagent spawns or infinite retry loops.
- **Circuit Breaker Commands**:
  ```bash
  agent-status    # View active guardrail limits, rate limits, and trace counts
  agent-stop      # Emergency stop: touches ~/.agent_stop to halt all local agent loops
  agent-resume    # Clears circuit breaker to resume execution
  ```
- **`agent-guard-check`**: Pre-flight verification function for test harnesses. Rejects execution if the circuit breaker is tripped or if hourly limits (`AUTO_AGENT_MAX_PER_HOUR=30`) are exceeded.
- **Trace Logs**: Timestamped telemetry stored at `~/.local/state/agent-traces/traces.log`.

### 5. Local Harness Task Queue (`pueue`)
Run model evals, batch inferences, and agent test suites in the background with concurrency control:
- Pre-configured concurrency groups: `experiments` (max 2 parallel GPU/CPU jobs to prevent OOM) and `agents` (max 4 parallel tasks).
- Commands:
  ```bash
  jexp python eval.py        # Enqueue job to 'experiments' queue
  jagent bash run_harness.sh # Enqueue job to 'agents' queue
  jls                        # Check job queue status
  jfollow <id>               # Stream live output
  jlog <id>                  # View full log
  jkill <id>                 # Cancel job
  ```
- **Dynamic Group Management**: In Pueue v3/v4, group states are stored dynamically in the runtime state database rather than read from `pueue.yml`. The shell baseline automatically handles this on the fly: `.bashrc` and `jrun` auto-initialize the `experiments` (parallel: 2) and `agents` (parallel: 4) queues via `pueue group add` and `pueue parallel` on startup.


### 6. Self-Healing Environment Diagnostic (`doctor`)
Built on "The Spilled Coffee Principle"—if a laptop is destroyed or an environment drifts, you should be back to 100% operational state instantly with zero manual guesswork:
- **`doctor`**: Diagnostic suite verifying 20+ symlinks, core and AI packages, Docker daemon status, git identity, agent circuit breaker state, and modular alias directories.
- **`doctor --fix`**: Automatically repairs broken symlinks, launches self-healing sub-routines, and restores configuration integrity.

### 7. Model Context Protocol (MCP) Diagnostics & Configs
Canonical vendor-agnostic MCP configuration for AI harnesses (Antigravity, Claude Code, Cursor, Codex):
- **`config/mcp/mcp.json`**: Standard MCP server configurations (filesystem, git, web fetch).
- **`check-mcp-logs`** (`mcplogs`): Centralized viewer for MCP server logs across harnesses (`check-mcp-logs --tail`, `check-mcp-logs --clear`).

### 8. Developer Automation Workflows
- **`ensure-docker`** (`edocker`): Ubuntu/Debian native self-healing Docker service validator. Checks socket permissions, group memberships, and initiates systemd/service restart if unresponsive.
- **`pr-checkout`**: Fast PR fetcher with isolated worktree integration:
  ```bash
  pr-checkout 42             # Checkout PR #42 in current working tree
  pr-checkout --worktree 42  # Fetch and isolate PR #42 into .worktrees/pr-42
  ```
- **`gha-failed-logs`**: Fetches and inspects failed GitHub Actions step logs directly in the terminal without opening a browser.

### 9. Modular Shell Aliases (`~/.bash_aliases.d/`)
Organized by functional domains instead of a monolith:
- `ai.sh`: Agent worktree commands (`aw`, `aw-new`, `aw-merge`), pueue shortcuts (`jrun`, `jexp`, `jagent`, `jls`, `jfollow`), MCP log shortcuts (`mcplogs`).
- `containers.sh`: Docker table view, prune, logs, and self-healing (`dps`, `dstop`, `dprune`, `edocker`).
- `git.sh`: Git status, diff, log graphs, checkout, commit shortcuts (`gs`, `gd`, `gds`, `gl`, `gcm`, `gca`).
- `nav.sh`: Directory navigation (`..`, `...`, `mkcd`, `ll`, `lt`, `lsize`).
- `sys.sh`: System monitoring, safe file operations, archive extraction (`ports`, `path`, `reload`, `extract`, GPU & Slurm).
- Local overrides: Place machine-specific aliases in `~/.bash_aliases.local`.

### 10. Closed-Loop AI Agent Instructions & Boundaries
When you add local CLI tools to your dotfiles, teach your coding agents (Claude Code, OpenCode, Antigravity, Codex) about them in the **same repository**:
- **`config/agents/AGENTS.md`**: Master instructions symlinked to `~/.claude/CLAUDE.md` and referenced by `~/.config/opencode/opencode.json`. Teaches agents about `secret-run`, `agent-worktree`, `pueue`, `doctor`, and the 7-day `uv` quarantine.
- **`config/claude/settings.json`**: Global agent configuration enforcing `fileExclusions` to protect context windows and prevent credential leakage:
  ```json
  "fileExclusions": [
    ".worktrees/**",
    ".venv/**",
    "__pycache__/**",
    ".git/**",
    "node_modules/**",
    ".pueue/**",
    "~/.secrets/**",
    "**/*.env"
  ]
  ```
- **`config/opencode/opencode.json`**: Single source of truth referencing the shared `CLAUDE.md` and exclusions.

### 11. Living System Maintenance (`update.sh` / `dotfiles-update`)
Dotfiles drift over time. A single command keeps everything in sync:
```bash
dotfiles-update   # or ./update.sh
```
Executes:
1. `git pull --rebase` to fetch upstream updates.
2. `./scripts/links.sh` to refresh all symlinks.
3. `uv self update` to keep Python tooling current.
4. `doctor --fix` to verify all 20+ checks and heal any broken configurations automatically.

### 12. ML, GPU & Python Ergonomics
- **`activate_venv`**: Auto-detects and activates `.venv` in the current working directory or git repo root.
- **Linux RAM `tmpfs`**: Automatically maps `TMPDIR=/run/user/$(id -u)` for RAM-backed scratch disks, speeding up agent disk I/O and reducing SSD wear.
- **GPU & Slurm Monitoring**:
  - `gpu`: Live 1-second watcher for `nvidia-smi`.
  - `gpu-mem`: Formatted table of GPU memory and utilization.
  - Slurm cluster shortcuts: `q`, `qw`, `qq`, `qtest`, `qlogin`, `qdel`.

### 13. Modern CLI Toolchain
- `zoxide` (`z <dir>` smart navigation).
- `bat` / `batcat` (syntax-highlighted file viewing).
- `fd` / `fdfind` (fast directory & file discovery).
- `ripgrep` (`rg`) (blazing-fast regex code search).
- `direnv` (directory-scoped environment management).

---

## Directory Structure

```text
dot-files/
├── .gitignore
├── README.md
├── QUICK-START.md                 # Quick Start onboarding guide & walkthrough
├── install.sh                     # Modular installer (profiles: full, cloud, minimal)
├── update.sh                      # Automated updater and self-healing synchronizer
├── bin/
│   ├── agent-worktree             # Isolated git worktrees for concurrent agents
│   ├── check-mcp-logs             # MCP server log viewer and real-time tailer
│   ├── doctor                     # Self-healing environment verification & repair
│   ├── dotfiles-update            # CLI wrapper to update dotfiles and tools
│   ├── ensure-docker              # Linux Docker daemon validator and starter
│   ├── gha-failed-logs            # Terminal GitHub Actions failure log inspector
│   ├── pr-checkout                # Fast PR branch fetcher & worktree reviewer
│   ├── secret-run                 # Scoped credential executor
│   └── sysinfo                    # System overview & hardware diagnostics
├── config/
│   ├── agents/
│   │   └── AGENTS.md              # Master coding agent guidelines & harness tools
│   ├── ai_automation/
│   │   └── ai_automation.sh       # Guardrails, circuit breakers, rate limits & traces
│   ├── bash/
│   │   ├── .bashrc                # Interactive shell with supply chain defense & tools
│   │   ├── .bash_aliases          # Master aliases loader
│   │   ├── aliases.d/             # Modular alias domains
│   │   │   ├── ai.sh              # Worktree, task queue, and MCP aliases
│   │   │   ├── containers.sh      # Docker shortcuts and daemon helpers
│   │   │   ├── git.sh             # Git branch, commit, diff shortcuts
│   │   │   ├── nav.sh             # Directory traversal and listing helpers
│   │   │   └── sys.sh             # System stats, GPU, Slurm, archive extraction
│   │   ├── .bash_profile          # Login profile
│   │   └── .profile               # Fallback profile
│   ├── claude/
│   │   └── settings.json          # Claude Code global settings & file exclusions
│   ├── git/
│   │   ├── .gitconfig             # Git defaults and aliases
│   │   └── .gitignore_global      # Global ignores (.worktrees, .env, swap, OS files)
│   ├── mcp/
│   │   └── mcp.json               # Canonical Model Context Protocol server configuration
│   ├── npm/
│   │   └── .npmrc                 # ignore-scripts=true supply chain guard
│   ├── opencode/
│   │   └── opencode.json          # OpenCode configuration referencing shared instructions
│   ├── pueue/
│   │   └── pueue.yml              # Task queue config (experiments & agents groups)
│   ├── templates/
│   │   ├── .envrc.template        # Direnv template for per-repo API keys
│   │   └── .dotfiles.local.template # Template for machine-local private settings
│   ├── tmux/
│   │   └── .tmux.conf             # Ergonomic tmux setup with mouse mode & truecolor
│   ├── uv/
│   │   └── uv.toml                # uv package manager config
│   └── vim/
│       └── .vimrc                 # Vim settings with hybrid line numbers
├── scripts/
│   ├── packages.sh                # Automated apt package and pueue binary installer
│   └── links.sh                   # Symlink manager with automated timestamped backups
└── tests/
    ├── Dockerfile                 # Clean Ubuntu test container
    ├── run_tests.sh               # Test runner
    ├── sandbox.sh                 # Interactive zero-risk Docker sandbox test drive
    └── verify_container.sh        # 16-step automated verification suite
```

---

## Installation

### Standard Setup

```bash
# Clone via HTTPS:
git clone https://bitbucket.org/jadm11/ai-automation-engineer-workstation.git ~/ai-automation-engineer-workstation

# Or clone via SSH:
git clone git@bitbucket.org:jadm11/ai-automation-engineer-workstation.git ~/ai-automation-engineer-workstation

cd ~/ai-automation-engineer-workstation
./install.sh
```

### Installation Profiles

```bash
# Full installation (Core CLI + AI Dev packages + Pueue + Dotfiles)
./install.sh --profile full

# Headless Cloud GPU Pod (RunPod, Lambda Labs, Hetzner, etc.)
./install.sh --profile cloud

# Minimal (Symlinks dotfiles only without root/apt package installation)
./install.sh --profile minimal

# Non-interactive / Unattended
./install.sh -y --profile full
```

---

## 🌿 Branching Model & Pull Requests

This repository follows a **Trunk-Based Development** model enhanced with **Git Worktrees** for non-blocking agent concurrency:

* **`main`**: Protected, deployable, 100% verified trunk.
* **`feature/<name>`**: Human-engineered features and enhancements.
* **`agent/<task-name>`**: Autonomous agent workflows created via `agent-worktree new <task-name>`.
* **`fix/<name>`**: Bug repairs and security patches.
* **`docs/<name>`**: Documentation, manuals, and test receipts.

### Creating a PR:
1. Create an isolated worktree or branch: `agent-worktree new my-feature` (or `git checkout -b feature/my-feature`).
2. Run the test suite: `./tests/run_tests.sh`.
3. Push to remote: `git push -u origin feature/my-feature`.
4. Open a Pull Request on Bitbucket targeting `main`.

### Reviewing a PR in an Isolated Worktree:
Reviewers can test any open pull request without interrupting their current working branch:
```bash
pr-checkout --worktree <pr-number>
cd .worktrees/pr-<pr-number> && ./tests/run_tests.sh
```

For the complete guide on PR conventions, commit styles, and standards, see [**CONTRIBUTING.md**](CONTRIBUTING.md).

---

## Docker Test Suite & Interactive Sandbox

### 🧪 Interactive Sandbox Test Drive
Explore the dotfiles and all tools interactively in an isolated Ubuntu container without modifying your host machine:

```bash
./tests/sandbox.sh
```

### 📋 Full Verification Test Suite
Run the full end-to-end 16-stage verification suite in an isolated Ubuntu container:

```bash
./tests/run_tests.sh
```

The automated test verifies:
1. Non-interactive package installation across all toolchains (`build-essential`, `python3-pip`, `direnv`, etc.).
2. Availability of all tools (`git`, `tmux`, `vim`, `rg`, `fzf`, `direnv`, `zoxide`, `batcat`, `fdfind`, `uv`, `pueue`).
3. Symlink creation for all dotfiles, configurations, modular aliases, and `bin/` tools (20+ links).
4. Shell syntax and interactive bash startup without errors.
5. Supply chain quarantine environment variables (`UV_EXCLUDE_NEWER`, `UV_MALWARE_CHECK`).
6. Agent circuit breaker triggers (`agent-stop`, `agent-resume`, `agent-guard-check`).
7. Scoped secrets execution via `secret-run`.
8. Git worktree creation, commits, merging, and pruning via `agent-worktree`.
9. Task queue daemon operation and background job execution (`pueue`).
10. Full installer idempotency and timestamped backup restoration.
11. Modular aliases loading across git, container, ai, navigation, and system domains.
12. Self-healing environment diagnostic (`doctor`), drift detection, and automatic restoration (`doctor --fix`).
13. Model Context Protocol (`mcp.json` JSON validation, `check-mcp-logs`).
14. Pull request checkout interface (`pr-checkout --help`) and Docker validator (`ensure-docker`).
15. AI Coding Agent configurations (`CLAUDE.md`, `settings.json`, `opencode.json` schema validation & `fileExclusions` boundaries).
16. Automated update workflow (`update.sh` / `dotfiles-update` self-healing cycle).

---

## Acknowledgements & Credits

This repository draws inspiration from the following open-source dotfiles and AI tooling projects:

- **[yulonglin/dotfiles](https://github.com/yulonglin/dotfiles)** — Autonomous AI agent guardrails, circuit breakers, supply chain quarantine (`UV_EXCLUDE_NEWER`), credential isolation, and `pueue` background task queues.
- **[atxtechbro/dotfiles](https://github.com/atxtechbro/dotfiles)** — Vendor-agnostic Model Context Protocol (`mcp.json`) architecture, MCP log inspection, Docker daemon checking, and PR review workflows.
- **[jplhughes/dotfiles](https://github.com/jplhughes/dotfiles)** & **[drmowinckels/dotfiles](https://github.com/drmowinckels/dotfiles)** — Modular shell configuration structure and terminal ergonomics.

