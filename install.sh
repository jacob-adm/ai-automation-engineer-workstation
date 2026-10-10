#!/usr/bin/env bash
# install.sh: Baseline installer & bootstrapper for AI Automation Engineer Workstation

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ANSI Colors
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
RESET="\033[0m"

print_banner() {
    cat << "EOF"
=============================================================
         AI Automation Engineer Workstation Setup            
=============================================================
EOF
}

usage() {
    echo -e "${BOLD}Usage:${RESET} $0 [options]"
    echo ""
    echo -e "${BOLD}Options:${RESET}"
    echo "  -y, --yes          Assume yes to prompts and run non-interactively"
    echo "  --profile <name>   Profile to deploy: full (default), cloud (headless GPU pod), minimal"
    echo "  --skip-packages    Skip apt package installation (only link dotfiles)"
    echo "  --only-packages    Only install apt packages without linking dotfiles"
    echo "  --skip-links       Skip symlink creation"
    echo "  --target <dir>     Target home directory (default: $HOME)"
    echo "  -h, --help         Show this help message"
    echo ""
}

ASSUME_YES=0
SKIP_PACKAGES=0
ONLY_PACKAGES=0
SKIP_LINKS=0
PROFILE="full"
TARGET_DIR="${HOME}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            ASSUME_YES=1
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --skip-packages)
            SKIP_PACKAGES=1
            shift
            ;;
        --only-packages)
            ONLY_PACKAGES=1
            SKIP_LINKS=1
            shift
            ;;
        --skip-links)
            SKIP_LINKS=1
            shift
            ;;
        --target)
            TARGET_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [ "$PROFILE" = "minimal" ]; then
    SKIP_PACKAGES=1
fi

print_banner

if [ "$ASSUME_YES" -eq 0 ]; then
    echo -e "Bootstrapping system for profile: ${BOLD}${CYAN}${PROFILE}${RESET}"
    echo -e "Target directory: ${BOLD}${TARGET_DIR}${RESET}"
    echo ""
    read -rp "Do you wish to continue? [y/N]: " confirm
    case "$confirm" in
        [yY]|[yY][eE][sS]) ;;
        *)
            echo "Installation cancelled."
            exit 0
            ;;
    esac
fi

# Ensure all helper scripts and custom binaries are executable
chmod +x "${DOTFILES_ROOT}/scripts/packages.sh"
chmod +x "${DOTFILES_ROOT}/scripts/links.sh"
if [ -d "${DOTFILES_ROOT}/bin" ]; then
    chmod +x "${DOTFILES_ROOT}/bin"/* 2>/dev/null || true
fi

# Step 1: Install packages
if [ "$SKIP_PACKAGES" -eq 0 ]; then
    echo ""
    echo -e "${BLUE}==>${RESET} ${BOLD}Step 1: Installing system packages (profile: ${PROFILE})...${RESET}"
    "${DOTFILES_ROOT}/scripts/packages.sh" --profile "$PROFILE"
else
    echo ""
    echo -e "${YELLOW}==>${RESET} Skipping system package installation."
fi

# Step 2: Link dotfiles
if [ "$SKIP_LINKS" -eq 0 ]; then
    echo ""
    echo -e "${BLUE}==>${RESET} ${BOLD}Step 2: Linking dotfiles and AI automation tools...${RESET}"
    "${DOTFILES_ROOT}/scripts/links.sh" --target "$TARGET_DIR"
else
    echo ""
    echo -e "${YELLOW}==>${RESET} Skipping dotfile symlinks."
fi

# Summary
echo ""
echo -e "${GREEN}=============================================================${RESET}"
echo -e "${BOLD}${GREEN}               Setup Completed Successfully!                 ${RESET}"
echo -e "${GREEN}=============================================================${RESET}"
echo ""
echo -e "Next steps:"
echo -e " 1. Reload shell:          ${CYAN}source ~/.bashrc${RESET}"
echo -e " 2. AI Worktrees:          ${CYAN}agent-worktree new <task-name>${RESET}"
echo -e " 3. Circuit Breaker:       ${CYAN}agent-status${RESET} (or ${CYAN}agent-stop${RESET} / ${CYAN}agent-resume${RESET})"
echo -e " 4. Task Queue (Pueue):    ${CYAN}jexp python -m run_eval${RESET} (inspect with ${CYAN}jls${RESET})"
echo -e " 5. Scoped Secrets:        ${CYAN}secret-run -- python eval.py${RESET}"
echo -e " 6. System overview:       ${CYAN}sysinfo${RESET}"
echo ""
