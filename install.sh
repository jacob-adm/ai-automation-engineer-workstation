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
    echo "  -n, --dry-run      Preview actions without modifying the filesystem"
    echo "  --force-root       Allow running installer directly as root"
    echo "  -h, --help         Show this help message"
    echo ""
}

ASSUME_YES=0
SKIP_PACKAGES=0
ONLY_PACKAGES=0
SKIP_LINKS=0
DRY_RUN=0
FORCE_ROOT=0
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
        -n|--dry-run|--preview)
            DRY_RUN=1
            SKIP_PACKAGES=1
            shift
            ;;
        --force-root)
            FORCE_ROOT=1
            shift
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

# Root execution safety check
if [ "$EUID" -eq 0 ] && [ "$PROFILE" != "cloud" ] && [ "$FORCE_ROOT" -eq 0 ]; then
    if [ "$ASSUME_YES" -eq 1 ]; then
        echo -e "${RED}[ERROR]${RESET} Refusing to run as root without --force-root (would install dotfiles into /root)."
        echo -e "Run as a regular user with sudo privileges, or pass --force-root if intentional."
        exit 1
    else
        echo -e "${YELLOW}[WARN]${RESET} Running as root (EUID=0) will install dotfiles into /root rather than a user home."
        read -rp "Are you sure you want to proceed as root? [y/N]: " confirm_root
        case "$confirm_root" in
            [yY]|[yY][eE][sS]) ;;
            *)
                echo "Installation cancelled."
                exit 0
                ;;
        esac
    fi
fi

if [ "$ASSUME_YES" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
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
if [ "$DRY_RUN" -eq 0 ]; then
    chmod +x "${DOTFILES_ROOT}/scripts/packages.sh"
    chmod +x "${DOTFILES_ROOT}/scripts/links.sh"
    if [ -d "${DOTFILES_ROOT}/bin" ]; then
        chmod +x "${DOTFILES_ROOT}/bin"/* 2>/dev/null || true
    fi
fi

# Handle dry-run preview mode
if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo -e "${BLUE}==>${RESET} ${BOLD}[DRY-RUN] Previewing dotfile symlinks and backups (target: ${TARGET_DIR})...${RESET}"
    "${DOTFILES_ROOT}/scripts/links.sh" --target "$TARGET_DIR" --dry-run
    echo ""
    echo -e "${GREEN}=============================================================${RESET}"
    echo -e "${BOLD}${GREEN}        [DRY-RUN] Preview Complete (Zero Changes)           ${RESET}"
    echo -e "${GREEN}=============================================================${RESET}"
    exit 0
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
