# Contributing to AI Automation Engineer Workstation

Thank you for your interest in contributing! This repository provides a security-hardened, modular execution substrate and workstation environment for AI Automation Engineers running autonomous agents and local harnesses.

We welcome pull requests, bug reports, and workflow enhancements from the community.

---

## 🛠️ Core Engineering Principles

Before contributing, keep these four core architectural rules in mind:

1. **Zero Ambient Secrets**:  
   Never introduce configurations or scripts that inject plaintext credentials into ambient shell environments (`~/.bashrc`). Always use ephemeral scoping via `secret-run` or directory-scoped `.envrc` via `direnv`.
2. **Supply Chain Defense First**:  
   Respect the 7-day PyPI quarantine (`UV_EXCLUDE_NEWER`), signature scanning (`UV_MALWARE_CHECK`), and npm script isolation (`ignore-scripts=true`).
3. **Idempotency & Non-Destructive Operations**:  
   Every script and installation routine must be strictly idempotent. Re-running `install.sh` or `update.sh` must perform zero redundant changes and never clobber existing user configurations without creating a timestamped backup in `~/.dotfiles_backup/`.
4. **The Spilled Coffee Principle**:  
   The workstation must be capable of self-healing. Any new symlink or dependency must be integrated into `bin/doctor` and auto-repaired by `bin/doctor --fix`.

---

## 🧪 Testing & Verification Suite

All modifications must pass the complete 16-stage container verification test suite before being merged:

```bash
# Execute the full verification suite in an isolated Ubuntu 24.04 container
./tests/run_tests.sh
```

### Local Interactive Testing Sandbox
To test changes interactively without modifying your host system:
```bash
./tests/sandbox.sh
```

### Static Syntax Checks
Ensure all bash scripts pass syntax checks:
```bash
for f in install.sh update.sh bin/* scripts/* tests/*.sh config/bash/aliases.d/*; do
  bash -n "$f"
done
```

---

## 📁 Repository Structure & Extension Points

* **CLI Utilities (`bin/`)**: Standalone, well-documented POSIX/bash scripts symlinked to `~/.local/bin/`.
* **Modular Aliases (`config/bash/aliases.d/`)**: Domain-separated bash aliases (`ai.sh`, `git.sh`, `containers.sh`, `nav.sh`, `sys.sh`).
* **Symlink Mapping (`scripts/links.sh`)**: The central manifest mapping dotfiles to user home directories.
* **Package Bootstrapping (`scripts/packages.sh`)**: Non-interactive package installation profiles (`full` vs `minimal`).
* **Diagnostic Medic (`bin/doctor`)**: Health check assertions and self-healing logic.

---

## 🌿 Branching Model: Trunk-Based with Worktree Extensions

This repository follows a **Trunk-Based Development** model enhanced with **Git Worktrees** for non-blocking agent concurrency:

```
main (Protected, stable, 100% verified)
 │
 ├──► feature/<name>       Human-driven enhancements (e.g., feature/add-zsh-support)
 ├──► fix/<issue-name>     Bug and security fixes (e.g., fix/pueue-group-socket)
 ├──► agent/<task-name>    Autonomous agent tasks (e.g., agent/refactor-mcp)
 └──► docs/<topic>         Documentation, manuals, and receipts (e.g., docs/branching-model)
```

### Branch Naming Conventions
* `feature/<description>`: New tools, configuration modules, or installation profiles.
* `fix/<description>`: Bug repairs, permission fixes, or broken symlink resolutions.
* `agent/<task-name>`: Automated agent worktrees created automatically via `agent-worktree new <task-name>`.
* `docs/<description>`: Documentation, manuals, or verification receipts.
* `chore/<description>`: Dependency bumps, tool updates, or formatting changes.

---

## 🚀 How to Create and Submit a Pull Request

Follow these steps to submit a PR from inception to merge:

### Step 1: Create an Isolated Branch or Worktree

Choose the method that fits your workflow:

#### Option A: Using the Worktree Manager (Recommended for AI & Multi-Tasking)
Keeps your primary checkout clean while you or an AI agent works in an isolated directory:
```bash
# 1. Create isolated worktree on a new branch
agent-worktree new my-feature

# 2. Enter the isolated environment
cd .worktrees/my-feature
```

#### Option B: Standard Git Branch Checkout
```bash
git checkout -b feature/my-feature
```

---

### Step 2: Implement Changes & Adhere to Standards

* Follow the **Core Engineering Principles** (Zero ambient secrets, Supply chain defense, Idempotency).
* Use [Conventional Commits](https://www.conventionalcommits.org/):
  ```bash
  git commit -m "feat(bin): add new network diagnostic tool"
  git commit -m "fix(doctor): resolve broken symlink check on macos"
  git commit -m "docs(manual): add section on branch models"
  ```

---

### Step 3: Run the Pre-Flight Verification Suite

**Every pull request must pass the test suite before submission:**
```bash
./tests/run_tests.sh
```
Verify that all 17 test stages pass with 100% success.

---

### Step 4: Push Branch to Remote

```bash
# If using standard branch:
git push -u origin feature/my-feature

# If using agent-worktree:
git -C .worktrees/my-feature push -u origin agent/my-feature
```

---

### Step 5: Open the Pull Request

* **On Bitbucket**:
  1. Open your repository in the browser: `https://bitbucket.org/jadm11/ai-automation-engineer-workstation/pull-requests/`
  2. Click **Create pull request**.
  3. Set **Source branch**: `feature/my-feature` (or `agent/my-feature`).
  4. Set **Destination branch**: `main`.
  5. Title your PR with your conventional commit summary.
  6. Fill out the PR template with:
     - **Summary of changes**
     - **Motivation / Problem solved**
     - **Test receipts confirmation** (e.g., "Verified via `./tests/run_tests.sh`")
  7. Click **Create pull request**.

* **On GitHub (if mirrored / forked)**:
  ```bash
  gh pr create --title "feat: my new feature" --body "Detailed description of changes"
  ```

---

### Step 6: Reviewing Pull Requests with `pr-checkout`

Reviewers (both humans and AI agents) can review and test PRs without interrupting their active local branch using [`bin/pr-checkout`](bin/pr-checkout):

```bash
# Reviews PR #12 in an isolated worktree at .worktrees/pr-12:
pr-checkout --worktree 12

# Run tests directly in the isolated PR environment:
cd .worktrees/pr-12 && ./tests/run_tests.sh

# When finished reviewing, clean up the worktree:
agent-worktree remove pr-12
```

---

### Step 7: Merge Strategy

* Maintainers use **Squash and Merge** (or **Rebase and Merge**) to maintain a clean, readable trunk history on `main`.

Thank you for helping build a safer, faster runtime for autonomous AI engineering!
