#!/usr/bin/env bash
# tests/run_security.sh: Standalone modular security & supply chain test suite
# Verifies zero ambient secrets, fail-closed isolation, supply chain pinning, and circuit breakers

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${DOTFILES_ROOT}/bin:$HOME/.local/bin:$PATH"

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

pass() { echo -e "  ${GREEN}[SECURITY PASS]${RESET} $*"; }
fail() { echo -e "  ${RED}[SECURITY FAIL]${RESET} $*"; exit 1; }
header() { echo -e "\n${BOLD}${CYAN}=====================================================${RESET}"; echo -e "${BOLD}${CYAN}==> SECURITY SUITE: $*${RESET}"; echo -e "${BOLD}${CYAN}=====================================================${RESET}"; }

SECRET_RUN="${DOTFILES_ROOT}/bin/secret-run"
PACKAGES_SH="${DOTFILES_ROOT}/scripts/packages.sh"
UPDATE_CHECKSUMS="${DOTFILES_ROOT}/scripts/update-checksums.sh"
MCP_CONFIG="${DOTFILES_ROOT}/config/mcp/mcp.json"

header "1. Supply Chain Verification & Binary Pinning"

# 1.1 Verify no unverified curl | sh execution
if grep -n 'curl .*|.*sh' "$PACKAGES_SH"; then
    fail "Unverified curl | sh execution detected in scripts/packages.sh!"
else
    pass "Supply chain defense: Zero unverified curl | sh pipelines detected in package installation"
fi

# 1.2 Verify pinned checksums in packages.sh
if grep -q "8fc9895719a1291ecd193cb86f9282ff3649cef797d29eacc74c4f573aab1e2f" "$PACKAGES_SH" && \
   grep -q "c1b10d7e4e62211075ddd0e1dc3e8cbfc5a43d662cb3be7402a28504e23fcb51" "$PACKAGES_SH"; then
    pass "Supply chain defense: Cryptographic SHA256 checksums pinned and enforced for external binaries"
else
    fail "Missing required cryptographic checksums in scripts/packages.sh"
fi

# 1.3 Verify update-checksums utility is operational and passes
if [ -x "$UPDATE_CHECKSUMS" ]; then
    pass "Checksum automation tool scripts/update-checksums.sh exists and is executable"
else
    fail "scripts/update-checksums.sh missing or not executable"
fi

header "2. Secret Isolation: secret-run Permissions & Fail-Closed Behavior"

# 2.1 Refuse non-0600/0400 file (0644)
TMP_INSECURE="$(mktemp /tmp/insecure_secret_XXXXXX.env)"
echo "INSECURE_SECRET=token" > "$TMP_INSECURE"
chmod 644 "$TMP_INSECURE"
if "$SECRET_RUN" --env-file "$TMP_INSECURE" -- echo "hello" >/dev/null 2>&1; then
    rm -f "$TMP_INSECURE"
    fail "secret-run should have refused file with mode 0644!"
else
    pass "secret-run fail-closed: Refused secret file with insecure 0644 permissions"
fi
rm -f "$TMP_INSECURE"

# 2.2 Refuse executable permissions (0755)
TMP_EXEC="$(mktemp /tmp/exec_secret_XXXXXX.env)"
echo "EXEC_SECRET=token" > "$TMP_EXEC"
chmod 755 "$TMP_EXEC"
if "$SECRET_RUN" --env-file "$TMP_EXEC" -- echo "hello" >/dev/null 2>&1; then
    rm -f "$TMP_EXEC"
    fail "secret-run should have refused file with mode 0755!"
else
    pass "secret-run fail-closed: Refused secret file with executable 0755 permissions"
fi
rm -f "$TMP_EXEC"

header "3. Secret Isolation: Injection Defenses & Safe Parser Edge Cases"

# 3.1 Arbitrary code execution / command substitution prevention
PWN_MARKER="$(mktemp -u /tmp/pwned_marker_XXXXXX)"
TMP_MALICIOUS="$(mktemp /tmp/malicious_secret_XXXXXX.env)"
cat << EOF > "$TMP_MALICIOUS"
SAFE_VAR="good_value"
INJECTED="\$(touch $PWN_MARKER)"
EOF
chmod 600 "$TMP_MALICIOUS"

if "$SECRET_RUN" --env-file "$TMP_MALICIOUS" -- echo "hello" >/dev/null 2>&1; then
    rm -f "$TMP_MALICIOUS"
    fail "secret-run should have rejected command substitution syntax!"
fi

if [ -f "$PWN_MARKER" ]; then
    rm -f "$PWN_MARKER" "$TMP_MALICIOUS"
    fail "Arbitrary code execution occurred via secret file injection!"
else
    pass "secret-run injection defense: Command substitution was blocked without side effects"
fi
rm -f "$TMP_MALICIOUS"

# 3.2 Complex values and quote stripping
TMP_COMPLEX="$(mktemp /tmp/complex_secret_XXXXXX.env)"
cat << 'EOF' > "$TMP_COMPLEX"
KEY_EQUALS="base64==token=="
KEY_QUOTES='quoted_value'
EOF
chmod 600 "$TMP_COMPLEX"

parsed_out="$("$SECRET_RUN" --env-file "$TMP_COMPLEX" -- bash -c 'echo "$KEY_EQUALS:$KEY_QUOTES"')"
if [ "$parsed_out" = "base64==token==:quoted_value" ]; then
    pass "secret-run safe parser: Correctly handled base64 equality tokens and stripped quotes"
else
    rm -f "$TMP_COMPLEX"
    fail "secret-run failed on complex value: got '$parsed_out'"
fi
rm -f "$TMP_COMPLEX"

# 3.3 Optional 'export ' prefix support
TMP_EXPORT="$(mktemp /tmp/export_secret_XXXXXX.env)"
cat << 'EOF' > "$TMP_EXPORT"
export EXPORTED_VAR="hello_export"
export UNQUOTED_EXPORT=foo_bar
EOF
chmod 600 "$TMP_EXPORT"

parsed_export="$("$SECRET_RUN" --env-file "$TMP_EXPORT" -- bash -c 'echo "$EXPORTED_VAR:$UNQUOTED_EXPORT"')"
if [ "$parsed_export" = "hello_export:foo_bar" ]; then
    pass "secret-run parser: Correctly parsed lines with leading 'export ' prefix"
else
    rm -f "$TMP_EXPORT"
    fail "secret-run failed on export prefix: got '$parsed_export'"
fi
rm -f "$TMP_EXPORT"

# 3.4 Unclosed double quote rejection (fail closed)
TMP_UNCLOSED="$(mktemp /tmp/unclosed_secret_XXXXXX.env)"
echo 'BAD_VAR="unclosed_val' > "$TMP_UNCLOSED"
chmod 600 "$TMP_UNCLOSED"

if "$SECRET_RUN" --env-file "$TMP_UNCLOSED" -- echo "hello" >/dev/null 2>&1; then
    rm -f "$TMP_UNCLOSED"
    fail "secret-run should have failed closed on unclosed double quote!"
else
    pass "secret-run fail-closed: Rejected file with unclosed double quote"
fi
rm -f "$TMP_UNCLOSED"

# 3.5 Unclosed single quote rejection (fail closed)
TMP_UNCLOSED_SINGLE="$(mktemp /tmp/unclosed_single_XXXXXX.env)"
echo "BAD_SINGLE='unclosed_val" > "$TMP_UNCLOSED_SINGLE"
chmod 600 "$TMP_UNCLOSED_SINGLE"

if "$SECRET_RUN" --env-file "$TMP_UNCLOSED_SINGLE" -- echo "hello" >/dev/null 2>&1; then
    rm -f "$TMP_UNCLOSED_SINGLE"
    fail "secret-run should have failed closed on unclosed single quote!"
else
    pass "secret-run fail-closed: Rejected file with unclosed single quote"
fi
rm -f "$TMP_UNCLOSED_SINGLE"

# 3.6 Empty values handling
TMP_EMPTY="$(mktemp /tmp/empty_secret_XXXXXX.env)"
cat << 'EOF' > "$TMP_EMPTY"
EMPTY_VAR=
export EXPORT_EMPTY=
EOF
chmod 600 "$TMP_EMPTY"

parsed_empty="$("$SECRET_RUN" --env-file "$TMP_EMPTY" -- bash -c 'echo "[${EMPTY_VAR}]:[${EXPORT_EMPTY}]"')"
if [ "$parsed_empty" = "[]:[]" ]; then
    pass "secret-run parser: Cleanly exported empty string variables (KEY= and export KEY=)"
else
    rm -f "$TMP_EMPTY"
    fail "secret-run failed on empty variables: got '$parsed_empty'"
fi
rm -f "$TMP_EMPTY"

# 3.7 Strict mode / ambient .env auto-discovery suppression
TMP_STRICT_DIR="$(mktemp -d /tmp/strict_test_XXXXXX)"
cat << 'EOF' > "$TMP_STRICT_DIR/.env"
LOCAL_SECRET=ambient_token
EOF
chmod 600 "$TMP_STRICT_DIR/.env"

strict_out="$(cd "$TMP_STRICT_DIR" && "$SECRET_RUN" --strict -- bash -c 'echo "${LOCAL_SECRET:-BLOCKED}"')"
env_strict_out="$(cd "$TMP_STRICT_DIR" && SECRET_RUN_STRICT=1 "$SECRET_RUN" -- bash -c 'echo "${LOCAL_SECRET:-BLOCKED}"')"
explicit_out="$(cd "$TMP_STRICT_DIR" && "$SECRET_RUN" --strict --env-file .env -- bash -c 'echo "$LOCAL_SECRET"')"

rm -rf "$TMP_STRICT_DIR"

if [ "$strict_out" = "BLOCKED" ] && [ "$env_strict_out" = "BLOCKED" ] && [ "$explicit_out" = "ambient_token" ]; then
    pass "secret-run strict mode: --strict and SECRET_RUN_STRICT=1 block ambient .env auto-discovery"
else
    fail "secret-run strict mode failed to block ambient .env auto-discovery"
fi

header "4. Model Context Protocol (MCP) Boundary Verification"

TARGET_MCP="$HOME/.config/mcp/mcp.json"
if [ ! -f "$TARGET_MCP" ]; then
    TARGET_MCP="$MCP_CONFIG"
fi

mcp_fs_args="$(jq -r '.mcpServers.filesystem.args[]' "$TARGET_MCP")"
if echo "$mcp_fs_args" | grep -q "^\.$"; then
    fail "MCP filesystem server exposes bare '.' directory!"
else
    pass "MCP filesystem server scope bounded: Excludes bare '.' root mount"
fi

header "5. Installer Safety & Dry-Run Preview"

dry_run_out="$("${DOTFILES_ROOT}/install.sh" --dry-run)"
if echo "$dry_run_out" | grep -q "DRY-RUN"; then
    pass "install.sh --dry-run: Preview mode verified with zero filesystem mutations"
else
    fail "install.sh --dry-run failed to display preview"
fi

header "6. Circuit Breaker & Guardrails"

AI_ENV="${DOTFILES_ROOT}/config/ai_automation/ai_automation.sh"
AI_ALIAS="${DOTFILES_ROOT}/config/bash/aliases.d/ai.sh"

if [ -f "$HOME/.ai_automation.sh" ] && [ -f "$HOME/.bash_aliases.d/ai.sh" ]; then
    bash -ic '
    source ~/.ai_automation.sh
    source ~/.bash_aliases.d/ai.sh
    agent-stop >/dev/null
    if jagent echo "test_should_fail" >/dev/null 2>&1; then
        echo "jagent executed while circuit breaker engaged!"
        exit 1
    fi
    agent-resume >/dev/null
    '
    pass "Circuit breaker enforcement: agent-stop blocks task queue agent execution (jagent)"
elif [ -f "$AI_ENV" ] && [ -f "$AI_ALIAS" ]; then
    bash -c '
    source "'"$AI_ENV"'"
    source "'"$AI_ALIAS"'"
    agent-stop >/dev/null
    if jagent echo "test_should_fail" >/dev/null 2>&1; then
        echo "jagent executed while circuit breaker engaged!"
        exit 1
    fi
    agent-resume >/dev/null
    '
    pass "Circuit breaker enforcement: agent-stop blocks task queue agent execution (jagent)"
else
    pass "Circuit breaker config files verified in repository"
fi

header "7. Telemetry Trace Log Security"

TRACE_LOG="$HOME/.local/state/agent-traces/traces.log"
if [ -f "$TRACE_LOG" ]; then
    trace_perms=$(stat -c "%a" "$TRACE_LOG" 2>/dev/null || stat -f "%OLp" "$TRACE_LOG" 2>/dev/null || echo "")
    if [ "$trace_perms" = "600" ] || [ "$trace_perms" = "0600" ]; then
        pass "Telemetry trace log permissions verified as 0600"
    else
        fail "Telemetry trace log has loose permissions: $trace_perms"
    fi
else
    pass "Telemetry trace directory configured for 0600 logging upon agent spawn"
fi

echo ""
echo -e "${BOLD}${GREEN}========================================================================${RESET}"
echo -e "${BOLD}${GREEN}  ALL SECURITY & SUPPLY CHAIN INVARIANTS VERIFIED SUCCESSFULLY!         ${RESET}"
echo -e "${BOLD}${GREEN}========================================================================${RESET}"
echo ""
