#!/usr/bin/env bash
# ==============================================================================
# File:        update.sh
# Component:   Workstation Lifecycle & Synchronization Substrate
# Description: Synchronizes dotfiles with remote git upstream, refreshes symlinks,
#              updates local tooling (uv), and runs self-healing doctor --fix.
# Invariants:  - Uses git rebase to avoid unnecessary merge bubbles on local tracking branches.
#              - Preserves local uncommitted state gracefully if git pull fails.
#              - Triggers doctor --fix to restore symlink drift automatically.
# Dependencies: bash (>= 4.0), git, coreutils
# Target OS:   Ubuntu 22.04+ / Debian 12+ (or POSIX Linux)
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Section 1: Terminal Palette & Logging
# ------------------------------------------------------------------------------
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

log_info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }

# ------------------------------------------------------------------------------
# Section 2: Canonical Repository Root Resolution
# ------------------------------------------------------------------------------
# Traverses symlinks to resolve the true physical repository location
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
DOTFILES_ROOT="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"

echo -e "${BOLD}${CYAN}=====================================================${RESET}"
echo -e "${BOLD}${CYAN}            UPDATING DOTFILES ENVIRONMENT            ${RESET}"
echo -e "${BOLD}${CYAN}=====================================================${RESET}"

# ------------------------------------------------------------------------------
# Section 3: Upstream Git Synchronization (Rebase Strategy)
# ------------------------------------------------------------------------------
if git -C "$DOTFILES_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$DOTFILES_ROOT" remote get-url origin >/dev/null 2>&1; then
        log_info "Pulling latest dotfiles from git repository..."
        current_branch="$(git -C "$DOTFILES_ROOT" branch --show-current 2>/dev/null || echo "main")"
        # Rebase ensures linear local commit history without generating empty merge commits
        git -C "$DOTFILES_ROOT" pull --rebase origin "$current_branch" || log_warn "Git pull encountered conflicts or offline state. Proceeding with local state."
    fi
fi

# ------------------------------------------------------------------------------
# Section 4: Declarative Symlink Refresh & Backup Preservation
# ------------------------------------------------------------------------------
log_info "Refreshing dotfile symlinks..."
"${DOTFILES_ROOT}/scripts/links.sh"

# ------------------------------------------------------------------------------
# Section 5: Toolchain Binary Updates (uv)
# ------------------------------------------------------------------------------
if command -v uv >/dev/null 2>&1; then
    log_info "Checking for uv tool updates..."
    uv self update >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# Section 6: Self-Healing Health Check & Drift Auto-Repair
# ------------------------------------------------------------------------------
log_info "Executing self-healing diagnostic check..."
"${DOTFILES_ROOT}/bin/doctor" --fix

echo -e "\n${BOLD}${GREEN}=====================================================${RESET}"
echo -e "${BOLD}${GREEN}  DOTFILES ENVIRONMENT SUCCESSFULLY UPDATED!         ${RESET}"
echo -e "${BOLD}${GREEN}=====================================================${RESET}\n"
