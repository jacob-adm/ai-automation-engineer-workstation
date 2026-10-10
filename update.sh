#!/usr/bin/env bash
# update.sh: Pulls latest dotfiles, refreshes symlinks, updates tools, and runs self-healing doctor

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

log_info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }

# Resolve canonical physical directory of dotfiles
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

# 1. Pull latest dotfiles changes if inside a git repository with remote
if git -C "$DOTFILES_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$DOTFILES_ROOT" remote get-url origin >/dev/null 2>&1; then
        log_info "Pulling latest dotfiles from git repository..."
        current_branch="$(git -C "$DOTFILES_ROOT" branch --show-current 2>/dev/null || echo "main")"
        git -C "$DOTFILES_ROOT" pull --rebase origin "$current_branch" || log_warn "Git pull encountered conflicts or offline state. Proceeding with local state."
    fi
fi

# 2. Refresh dotfiles symlinks
log_info "Refreshing dotfile symlinks..."
"${DOTFILES_ROOT}/scripts/links.sh"

# 3. Update UV package manager if installed
if command -v uv >/dev/null 2>&1; then
    log_info "Checking for uv tool updates..."
    uv self update >/dev/null 2>&1 || true
fi

# 4. Run self-healing doctor
log_info "Executing self-healing diagnostic check..."
"${DOTFILES_ROOT}/bin/doctor" --fix

echo -e "\n${BOLD}${GREEN}=====================================================${RESET}"
echo -e "${BOLD}${GREEN}  DOTFILES ENVIRONMENT SUCCESSFULLY UPDATED!         ${RESET}"
echo -e "${BOLD}${GREEN}=====================================================${RESET}\n"
