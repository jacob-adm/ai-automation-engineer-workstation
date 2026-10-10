#!/usr/bin/env bash
# scripts/packages.sh: Installs baseline and AI engineering packages on Ubuntu/Debian

set -euo pipefail

# ANSI Colors
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

log_info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*"; }

PROFILE="full"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Check for Debian/Ubuntu
if [ ! -f /etc/debian_version ] && [ ! -f /etc/os-release ]; then
    log_warn "This system does not appear to be Debian or Ubuntu. Skipping apt package installation."
    exit 0
fi

# Detect privilege escalation command and enforce non-interactive environment across sudo
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC"
    else
        log_error "Non-root user and 'sudo' is not available. Cannot install system packages."
        exit 1
    fi
else
    SUDO="env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC"
fi

# Pre-configure debconf for tzdata non-interactive mode
if command -v debconf-set-selections >/dev/null 2>&1; then
    echo "tzdata tzdata/Areas select Etc" | $SUDO debconf-set-selections || true
    echo "tzdata tzdata/Zones/Etc select UTC" | $SUDO debconf-set-selections || true
fi

# Core baseline packages
CORE_PACKAGES=(
    build-essential
    ca-certificates
    curl
    wget
    git
    software-properties-common
    bash-completion
    tmux
    vim
    htop
    jq
    tree
    unzip
    zip
    ripgrep
    fzf
)

# AI & Developer Automation packages
AI_DEV_PACKAGES=(
    python3-venv
    python3-pip
    direnv
    zoxide
    bat
    fd-find
)

# Cloud / GPU Pod packages (lean headless set)
CLOUD_PACKAGES=(
    ca-certificates
    curl
    wget
    git
    tmux
    vim
    htop
    jq
    ripgrep
    fzf
    python3-venv
    direnv
    zoxide
)

log_info "Updating package lists..."
$SUDO apt-get update -y

TARGET_PACKAGES=()
if [ "$PROFILE" = "cloud" ]; then
    log_info "Installing Cloud / GPU Pod profile packages..."
    TARGET_PACKAGES=("${CLOUD_PACKAGES[@]}")
else
    log_info "Installing Full AI Engineering & Developer Automation profile..."
    TARGET_PACKAGES=("${CORE_PACKAGES[@]}" "${AI_DEV_PACKAGES[@]}")
fi

$SUDO apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    --no-install-recommends \
    "${TARGET_PACKAGES[@]}" || {
        log_warn "Some packages failed to install in bulk. Retrying essential packages individually..."
        for pkg in "${TARGET_PACKAGES[@]}"; do
            $SUDO apt-get install -y --no-install-recommends "$pkg" || log_warn "Could not install $pkg"
        done
    }

# Install uv (Blazing fast Python & AI package manager)
if ! command -v uv >/dev/null 2>&1; then
    log_info "Installing uv (fast Python package manager for AI)..."
    curl -fsSL https://astral.sh/uv/install.sh | $SUDO env UV_INSTALL_DIR="/usr/local/bin" sh || true
    if [ ! -f /usr/local/bin/uv ] && [ -f /root/.local/bin/uv ]; then
        $SUDO cp /root/.local/bin/uv /root/.local/bin/uvx /usr/local/bin/ 2>/dev/null || true
    fi
    if command -v uv >/dev/null 2>&1; then
        log_success "uv installed to /usr/local/bin."
    else
        log_warn "uv automated installation skipped."
    fi
fi

# Install pueue (Task queue / process manager for experiment harness)
if ! command -v pueue >/dev/null 2>&1; then
    log_info "Attempting to install pueue task queue..."
    if $SUDO apt-get install -y --no-install-recommends pueue >/dev/null 2>&1; then
        log_success "pueue installed via apt."
    else
        log_info "Installing official static pueue release binary..."
        ARCH="$(uname -m)"
        case "$ARCH" in
            x86_64)  PUEUE_TARGET="x86_64-unknown-linux-musl" ;;
            aarch64|arm64) PUEUE_TARGET="aarch64-unknown-linux-musl" ;;
            *) PUEUE_TARGET="" ;;
        esac

        if [ -n "$PUEUE_TARGET" ]; then
            PUEUE_VER="v4.0.4"
            TEMP_DIR="$(mktemp -d)"
            curl -fsSL "https://github.com/Nukesor/pueue/releases/download/${PUEUE_VER}/pueue-${PUEUE_TARGET}" -o "${TEMP_DIR}/pueue" || true
            curl -fsSL "https://github.com/Nukesor/pueue/releases/download/${PUEUE_VER}/pueued-${PUEUE_TARGET}" -o "${TEMP_DIR}/pueued" || true
            if [ -s "${TEMP_DIR}/pueue" ] && [ -s "${TEMP_DIR}/pueued" ]; then
                chmod +x "${TEMP_DIR}/pueue" "${TEMP_DIR}/pueued"
                $SUDO mv "${TEMP_DIR}/pueue" /usr/local/bin/pueue
                $SUDO mv "${TEMP_DIR}/pueued" /usr/local/bin/pueued
                log_success "pueue and pueued installed to /usr/local/bin."
            else
                log_warn "Could not download static pueue binary; skipping pueue install."
            fi
            rm -rf "${TEMP_DIR}"
        fi
    fi
fi

log_success "Package setup completed for profile: $PROFILE."
