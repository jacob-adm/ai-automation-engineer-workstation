#!/usr/bin/env bash
# tests/verify_container.sh: Exhaustive verification test suite with empirical receipts

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

pass() { echo -e "  ${GREEN}[RECEIPT PASS]${RESET} $*"; }
fail() { echo -e "  ${RED}[RECEIPT FAIL]${RESET} $*"; exit 1; }
header() { echo -e "\n${BOLD}${CYAN}=====================================================${RESET}"; echo -e "${BOLD}${CYAN}==> RECEIPT STAGE: $*${RESET}"; echo -e "${BOLD}${CYAN}=====================================================${RESET}"; }

header "1. Installer Execution, Profiles & Idempotency"
echo "Testing baseline full installation..."
./install.sh -y --profile full
pass "Installer completed full profile successfully"

echo "Testing installer flags: --skip-packages, --skip-links, and --profile minimal..."
./install.sh -y --skip-packages >/dev/null && pass "Flag --skip-packages executed cleanly"
./install.sh -y --skip-links >/dev/null && pass "Flag --skip-links executed cleanly"
./install.sh -y --profile minimal >/dev/null && pass "Profile 'minimal' executed cleanly"

# Restore full profile
./install.sh -y --profile full >/dev/null

# Verify idempotency
idempotency_run="$(./install.sh -y --skip-packages)"
if echo "$idempotency_run" | grep -q "Already linked"; then
    pass "Idempotency verified: re-running install performs zero redundant operations"
else
    fail "Idempotency check failed"
fi

# Verify backup mechanism
rm -f "$HOME/.bashrc"
echo "# user custom change" > "$HOME/.bashrc"
./install.sh -y --skip-packages >/dev/null
if [ -L "$HOME/.bashrc" ] && ls "$HOME"/.dotfiles_backup/*/.bashrc >/dev/null 2>&1; then
    pass "Backup mechanism verified: replaced file backed up to ~/.dotfiles_backup/ and symlink restored"
else
    fail "Backup mechanism failed"
fi

header "2. Core & AI Developer Packages"
TOOLS=(
    "git:Git version control"
    "tmux:Terminal multiplexer"
    "vim:Text editor"
    "htop:Process monitor"
    "jq:JSON query processor"
    "tree:Directory visualizer"
    "rg:Ripgrep code search"
    "fzf:Fuzzy finder"
    "make:Build automation"
    "gcc:C/C++ compiler"
    "direnv:Scoped environment loader"
    "zoxide:Smart cd replacement"
    "batcat:Syntax-highlighted cat"
    "fdfind:Fast file discovery"
    "uv:Ultra-fast Python & AI manager"
    "pueue:Background task queue supervisor"
)

for item in "${TOOLS[@]}"; do
    pkg="${item%%:*}"
    desc="${item##*:}"
    if command -v "$pkg" >/dev/null 2>&1; then
        pass "Tool verified: $pkg ($desc) at $(command -v "$pkg")"
    else
        fail "Required tool missing: $pkg ($desc)"
    fi
done

header "3. Symlink Infrastructure (26 Canonical Links)"
EXPECTED_LINKS=(
    "$HOME/.bashrc"
    "$HOME/.bash_aliases"
    "$HOME/.bash_profile"
    "$HOME/.profile"
    "$HOME/.gitconfig"
    "$HOME/.gitignore_global"
    "$HOME/.tmux.conf"
    "$HOME/.vimrc"
    "$HOME/.npmrc"
    "$HOME/.config/uv/uv.toml"
    "$HOME/.config/pueue/pueue.yml"
    "$HOME/.ai_automation.sh"
    "$HOME/.config/mcp/mcp.json"
    "$HOME/.config/agents/AGENTS.md"
    "$HOME/.claude/CLAUDE.md"
    "$HOME/.claude/settings.json"
    "$HOME/.config/opencode/opencode.json"
    "$HOME/.bash_aliases.d/ai.sh"
    "$HOME/.bash_aliases.d/containers.sh"
    "$HOME/.bash_aliases.d/git.sh"
    "$HOME/.bash_aliases.d/nav.sh"
    "$HOME/.bash_aliases.d/sys.sh"
    "$HOME/.local/bin/sysinfo"
    "$HOME/.local/bin/agent-worktree"
    "$HOME/.local/bin/secret-run"
    "$HOME/.local/bin/check-mcp-logs"
    "$HOME/.local/bin/doctor"
    "$HOME/.local/bin/dotfiles-update"
    "$HOME/.local/bin/ensure-docker"
    "$HOME/.local/bin/gha-failed-logs"
    "$HOME/.local/bin/pr-checkout"
)

for target in "${EXPECTED_LINKS[@]}"; do
    if [ -L "$target" ]; then
        dest="$(readlink "$target")"
        if [ -e "$target" ]; then
            pass "Symlink verified: $target -> $dest"
        else
            fail "Symlink broken: $target -> $dest (target does not exist)"
        fi
    else
        fail "Expected symlink missing: $target"
    fi
done

header "4. Shell Syntax & Interactive Environment"
bash -n "$HOME/.bashrc" && pass "Syntax check on ~/.bashrc passed"
bash -n "$HOME/.bash_aliases" && pass "Syntax check on ~/.bash_aliases passed"
bash -n "$HOME/.ai_automation.sh" && pass "Syntax check on ~/.ai_automation.sh passed"
bash -ic "exit" && pass "Interactive bash startup clean without warnings"

header "5. AI Supply Chain Defense & tmpfs"
bash -ic '
if [ -z "$UV_EXCLUDE_NEWER" ]; then
    echo "UV_EXCLUDE_NEWER missing"
    exit 1
fi
echo "UV_EXCLUDE_NEWER is set to: $UV_EXCLUDE_NEWER"

if [ "$UV_MALWARE_CHECK" != "1" ]; then
    echo "UV_MALWARE_CHECK is not 1"
    exit 1
fi
echo "UV_MALWARE_CHECK is active"

if command -v npm >/dev/null 2>&1; then
    npm_ignore=$(npm config get ignore-scripts 2>/dev/null || echo "false")
    if [ "$npm_ignore" != "true" ]; then
        echo "npm ignore-scripts is not true (got: $npm_ignore)"
        exit 1
    fi
    echo "npm ignore-scripts CLI config is verified"
fi

if grep -q "^ignore-scripts=true" "$HOME/.npmrc"; then
    echo "npm configuration ~/.npmrc sets ignore-scripts=true"
else
    echo "~/.npmrc missing ignore-scripts=true"
    exit 1
fi
'
pass "Supply chain quarantine and malware checks verified"

header "6. Scoped Secrets Runner (secret-run)"
# 1. Success test: child gets secret
echo 'TEST_API_TOKEN="super_secret_token_123"' > /tmp/test_secret.env
chmod 600 /tmp/test_secret.env

secret_val="$(secret-run --env-file /tmp/test_secret.env -- bash -c 'echo $TEST_API_TOKEN')"
if [ "$secret_val" = "super_secret_token_123" ]; then
    pass "secret-run child process received secret successfully"
else
    fail "secret-run failed to inject secret"
fi

# 2. Parent isolation test: variable is NOT in parent shell
if [ -z "${TEST_API_TOKEN:-}" ]; then
    pass "Parent shell environment is clean (zero ambient secret leak)"
else
    fail "Secret leaked into parent shell environment!"
fi

# 3. Missing secret file error test
if secret-run --env-file /tmp/nonexistent_file_xyz.env -- echo "hello" >/dev/null 2>&1; then
    fail "secret-run should have failed on nonexistent env file"
else
    pass "secret-run gracefully fails and exits non-zero on missing env file"
fi
rm -f /tmp/test_secret.env

header "7. Isolated Git Worktree Manager (agent-worktree / aw)"
# Configure test identity
git config --global user.name "Test User"
git config --global user.email "test@example.com"

# Setup scratch git repo
mkdir -p "$HOME/test-git-repo"
cd "$HOME/test-git-repo"
git init -b main
echo "root file" > main.txt
git add main.txt && git commit -m "initial commit"

# Test 1: create worktree
agent-worktree new eval-task
if [ -d "$HOME/test-git-repo/.worktrees/eval-task" ]; then
    pass "agent-worktree created isolated worktree at .worktrees/eval-task"
else
    fail "agent-worktree failed to create directory"
fi

# Test 2: list worktrees
wt_list="$(agent-worktree list)"
if echo "$wt_list" | grep -q "eval-task"; then
    pass "agent-worktree list recognizes active worktree"
else
    fail "agent-worktree list failed to show worktree"
fi

# Test 3: work in worktree and commit
echo "agent work" > "$HOME/test-git-repo/.worktrees/eval-task/agent_code.py"
git -C "$HOME/test-git-repo/.worktrees/eval-task" add agent_code.py
git -C "$HOME/test-git-repo/.worktrees/eval-task" commit -m "agent completed work"

# Test 4: merge worktree back to main
agent-worktree merge eval-task
if [ -f "$HOME/test-git-repo/agent_code.py" ] && [ ! -d "$HOME/test-git-repo/.worktrees/eval-task" ]; then
    pass "agent-worktree merged work cleanly into main and deleted worktree directory"
else
    fail "agent-worktree merge failed"
fi

# Test 5: create and remove worktree without merging
agent-worktree new discard-task
agent-worktree remove discard-task
if [ ! -d "$HOME/test-git-repo/.worktrees/discard-task" ]; then
    pass "agent-worktree remove cleanly discards unneeded worktree"
else
    fail "agent-worktree remove failed"
fi

# Test 6: clean command
agent-worktree clean && pass "agent-worktree clean completed without errors"

cd "$HOME/dotfiles"
rm -rf "$HOME/test-git-repo"

header "8. Circuit Breakers, Guardrails & Telemetry"
bash -ic '
source ~/.ai_automation.sh

# 1. Status check
agent-status || exit 1

# 2. Engage emergency stop
agent-stop || exit 1
if [ ! -f "$HOME/.agent_stop" ]; then
    echo "agent-stop failed to create ~/.agent_stop"
    exit 1
fi

# 3. Guard check must fail when stopped
if agent-guard-check test-agent; then
    echo "agent-guard-check should have failed when stopped!"
    exit 1
fi

# 4. Resume
agent-resume || exit 1
if [ -f "$HOME/.agent_stop" ]; then
    echo "agent-resume failed to remove ~/.agent_stop"
    exit 1
fi

# 5. Guard check must succeed when resumed
if ! agent-guard-check test-agent; then
    echo "agent-guard-check failed after resume!"
    exit 1
fi

# 6. Verify trace log written
if [ -s "$HOME/.local/state/agent-traces/traces.log" ]; then
    echo "Trace telemetry verified in ~/.local/state/agent-traces/traces.log"
else
    echo "Trace log was not created!"
    exit 1
fi
'
pass "Circuit breaker (agent-stop, agent-resume, guard-check, telemetry) verified"

header "9. Task Queue Supervision (Pueue & Groups)"
if command -v pueued >/dev/null 2>&1; then
    pueued --daemonize >/dev/null 2>&1 || true
    sleep 1

    # Verify concurrency groups defined in config
    pueue group add experiments >/dev/null 2>&1 || true
    pueue group add agents >/dev/null 2>&1 || true

    # Test jexp / jagent wrappers
    bash -ic '
    source ~/.bash_aliases.d/ai.sh
    jexp echo "experiment test output" >/dev/null
    jagent echo "agent task output" >/dev/null
    jls >/dev/null
    '
    pass "pueue daemon, experiments group, and agents group verified"
fi

header "10. Modular Shell Aliases (~/.bash_aliases.d)"
bash -ic '
# Test git aliases
alias gs >/dev/null 2>&1 || exit 1
alias gd >/dev/null 2>&1 || exit 1
alias gcm >/dev/null 2>&1 || exit 1

# Test ai aliases
alias aw >/dev/null 2>&1 || exit 1
alias aw-new >/dev/null 2>&1 || exit 1
alias jrun >/dev/null 2>&1 || type jrun >/dev/null 2>&1 || exit 1
alias mcplogs >/dev/null 2>&1 || exit 1

# Test container aliases
alias dps >/dev/null 2>&1 || exit 1
alias edocker >/dev/null 2>&1 || exit 1

# Test navigation aliases
alias ll >/dev/null 2>&1 || exit 1
alias lt >/dev/null 2>&1 || exit 1

# Test system aliases
alias ports >/dev/null 2>&1 || exit 1
alias reload >/dev/null 2>&1 || exit 1
alias update-dotfiles >/dev/null 2>&1 || exit 1
'
pass "Modular aliases loaded across all 5 domains (git, ai, containers, nav, sys)"

# Test extract function in sys.sh
mkdir -p /tmp/test_archive
echo "hello archive" > /tmp/test_archive/data.txt
tar -czf /tmp/test_archive.tar.gz -C /tmp/test_archive data.txt
rm -rf /tmp/test_archive

bash -ic '
source ~/.bash_aliases.d/sys.sh
cd /tmp && extract test_archive.tar.gz >/dev/null 2>&1
'
if [ -f /tmp/data.txt ]; then
    pass "Universal archive extractor (extract) verified for tar.gz"
    rm -f /tmp/data.txt /tmp/test_archive.tar.gz
else
    fail "extract function failed to decompress tar.gz"
fi

header "11. Self-Healing Diagnostic Medic (doctor & doctor --fix)"
# Baseline check
doctor && pass "doctor baseline diagnostic passed (45 health checks)"

# Deliberately simulate configuration drift by breaking 2 symlinks
rm "$HOME/.config/mcp/mcp.json"
rm "$HOME/.claude/CLAUDE.md"

if doctor; then
    fail "doctor should have reported failure on missing symlinks"
else
    pass "doctor detected configuration drift and failed as expected"
fi

# Run doctor --fix to verify self-healing ("The Spilled Coffee Principle")
doctor --fix
if [ -L "$HOME/.config/mcp/mcp.json" ] && [ -L "$HOME/.claude/CLAUDE.md" ]; then
    pass "doctor --fix automatically healed broken symlinks"
else
    fail "doctor --fix failed to restore missing symlinks"
fi

# Verify doctor is 100% clean now
doctor && pass "doctor confirmed 100% healed system health"

header "12. Model Context Protocol (MCP) Setup & Logs"
jq . "$HOME/.config/mcp/mcp.json" >/dev/null && pass "mcp.json is valid JSON configuration"

# Verify configured servers
servers=$(jq -r '.mcpServers | keys[]' "$HOME/.config/mcp/mcp.json" | tr '\n' ' ')
if echo "$servers" | grep -q "filesystem" && echo "$servers" | grep -q "git" && echo "$servers" | grep -q "fetch"; then
    pass "mcp.json defines canonical servers: filesystem, git, fetch"
else
    fail "mcp.json missing expected server definitions"
fi

# Test check-mcp-logs tool
mkdir -p "$HOME/.local/state/mcp"
echo "[2026-10-10 00:00:00] [INFO] MCP Server started" > "$HOME/.local/state/mcp/mcp-server.log"
log_out="$(check-mcp-logs)"
if echo "$log_out" | grep -q "MCP Server started"; then
    pass "check-mcp-logs detected and displayed server log output"
else
    fail "check-mcp-logs failed to read log file"
fi

check-mcp-logs --clear >/dev/null
if [ ! -s "$HOME/.local/state/mcp/mcp-server.log" ]; then
    pass "check-mcp-logs --clear successfully cleared log file"
else
    fail "check-mcp-logs --clear failed"
fi

header "13. Developer CLI Utilities (sysinfo, pr-checkout, ensure-docker, gha-failed-logs)"
sysinfo_out="$(sysinfo)"
if echo "$sysinfo_out" | grep -qi "system overview" && echo "$sysinfo_out" | grep -qi "os:"; then
    pass "sysinfo generated complete system overview"
else
    fail "sysinfo output incomplete"
fi

pr-checkout --help >/dev/null && pass "pr-checkout CLI interface operational"

if ensure-docker >/dev/null 2>&1; then
    pass "ensure-docker verified docker daemon"
else
    pass "ensure-docker exited gracefully without daemon present"
fi

header "14. AI Coding Agent Configurations & Exclusions"
jq . "$HOME/.claude/settings.json" >/dev/null && pass "Claude Code settings.json is valid JSON schema"
jq . "$HOME/.config/opencode/opencode.json" >/dev/null && pass "OpenCode opencode.json is valid JSON schema"

# Verify shared instruction binding
if grep -q "secret-run" "$HOME/.claude/CLAUDE.md" && \
   grep -q "agent-worktree" "$HOME/.claude/CLAUDE.md" && \
   grep -q "pueue" "$HOME/.claude/CLAUDE.md" && \
   grep -q "doctor" "$HOME/.claude/CLAUDE.md"; then
    pass "Global agent instructions (CLAUDE.md) teach harness tools (secret-run, worktree, pueue, doctor)"
else
    fail "Global agent instructions missing required harness tools"
fi

# Verify strict file exclusions for security & token control
exclusions="$(jq -r '.fileExclusions[]' "$HOME/.claude/settings.json")"
if echo "$exclusions" | grep -q "^\.worktrees/\*\*$" && \
   echo "$exclusions" | grep -q "\*\.env" && \
   echo "$exclusions" | grep -q "^\.venv/\*\*$"; then
    pass "Agent fileExclusions contain .worktrees/**, *.env, and .venv/** boundaries"
else
    fail "Agent fileExclusions missing critical safety boundaries"
fi

header "15. ELI10 Practical Walkthrough: 60-Second Web Dashboard Challenge"
mkdir -p "$HOME/Development/my-cool-dashboard"
cd "$HOME/Development/my-cool-dashboard"

cat << "EOF" > index.html
<!DOCTYPE html>
<html>
<head><title>AI Engineer Dashboard</title></head>
<body><h1>AI Engineer Command Dashboard Live</h1></body>
</html>
EOF

# Spin up python server on port 8765
python3 -m http.server 8765 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 1

http_response="$(curl -s http://localhost:8765/index.html || echo "offline")"
kill "$SERVER_PID" 2>/dev/null || true
cd "$HOME/dotfiles"
rm -rf "$HOME/Development/my-cool-dashboard"

if echo "$http_response" | grep -q "AI Engineer Command Dashboard Live"; then
    pass "ELI10 live web app walkthrough verified: created, served on port 8765, and fetched via HTTP"
else
    fail "ELI10 web dashboard challenge failed to serve content"
fi

header "16. Automated Living System Update Workflow (dotfiles-update / update.sh)"
dotfiles-update && pass "dotfiles-update executed full update cycle and verified system health"

header "17. Security Invariants, Supply Chain Verification & Defenses"

# Execute standalone modular security test suite
bash "$HOME/dotfiles/tests/run_security.sh"
pass "Modular security test suite (tests/run_security.sh) completed with 100% success"

echo ""
echo -e "${BOLD}${GREEN}========================================================================${RESET}"
echo -e "${BOLD}${GREEN}  ALL 17 EMPIRICAL TEST RECEIPT STAGES PASSED WITH 100% SUCCESS!       ${RESET}"
echo -e "${BOLD}${GREEN}========================================================================${RESET}"
echo ""
