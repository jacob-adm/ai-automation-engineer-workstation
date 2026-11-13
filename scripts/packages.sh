#!/usr/bin/env bash
# ==============================================================================
# File:        scripts/packages.sh
# Component:   Package Bootstrapping & Binary Supply Chain Substrate
# Description: Provisions distribution apt packages and installs cryptographic-pinned
#              external binaries (uv, pueue) for x86_64 and aarch64 architectures.
# Invariants:  - Zero unverified remote-to-shell pipelines: all external binaries are downloaded to
#                temp space and asserted against pinned SHA256 hashes before installation.
#              - Idempotent: checks command availability before initiating fetches.
#              - Enforces non-interactive debconf selection to prevent installation hangs.
# Dependencies: bash (>= 4.0), apt-get, curl, tar, sha256sum, coreutils
# Target OS:   Ubuntu 22.04+ / Debian 12+
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Section 1: Terminal Formatting & Logging
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Section 2: Installation Profile Selection
# ------------------------------------------------------------------------------
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

# Invariant: Must run on Debian/Ubuntu platforms when invoking apt-get
if [ ! -f /etc/debian_version ] && [ ! -f /etc/os-release ]; then
    log_warn "This system does not appear to be Debian or Ubuntu. Skipping apt package installation."
    exit 0
fi

# ------------------------------------------------------------------------------
# Section 3: Privilege Escalation & Non-Interactive Frontend Configuration
# ------------------------------------------------------------------------------
# Force DEBIAN_FRONTEND=noninteractive across all sudo boundaries to avoid terminal blockages
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

# Pre-seed debconf to avoid interactive tzdata geography prompts
if command -v debconf-set-selections >/dev/null 2>&1; then
    echo "tzdata tzdata/Areas select Etc" | $SUDO debconf-set-selections || true
    echo "tzdata tzdata/Zones/Etc select UTC" | $SUDO debconf-set-selections || true
fi

# ------------------------------------------------------------------------------
# Section 4: Package Lists Definition
# ------------------------------------------------------------------------------
# Base developer utilities (compilers, archivers, terminal multiplexers, search)
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

# AI agent, virtual environment, and modern CLI enhancements
AI_DEV_PACKAGES=(
    python3-venv
    python3-pip
    direnv
    zoxide
    bat
    fd-find
)

# Headless cloud GPU pod profile (RunPod, Lambda, Hetzner lean footprint)
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

# ------------------------------------------------------------------------------
# Section 5: APT Package Installation Pipeline
# ------------------------------------------------------------------------------
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

# Enforce confdef and confold to preserve existing configs without blocking prompts
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

# ------------------------------------------------------------------------------
# Section 6: Cryptographically Pinned Binary: Astral uv
# ------------------------------------------------------------------------------
# uv: High-performance Python package installer & environment resolver.
# Invariant: Pinned SHA256 checksums prevent supply-chain tampering.
if ! command -v uv >/dev/null 2>&1; then
    log_info "Installing pinned uv release with SHA256 verification..."
    UV_VER="0.13.7"
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)
            UV_TARGET="x86_64-unknown-linux-gnu"
            UV_SHA256="c5221ff41b7892bfc223543883600125f6a47fe845093e0f5bdff4f359196d83"
            ;;
        aarch64|arm64)
            UV_TARGET="aarch64-unknown-linux-gnu"
            UV_SHA256="71279f8d3c67241e807b9d8db872d1bf541579fb9f08b7d1eb1682196d1e57dc"
            ;;
        *)
            UV_TARGET=""
            UV_SHA256=""
            ;;
    esac

    if [ -n "$UV_TARGET" ]; then
        TEMP_DIR="$(mktemp -d)"
        TARBALL="${TEMP_DIR}/uv.tar.gz"
        URL="https://github.com/astral-sh/uv/releases/download/${UV_VER}/uv-${UV_TARGET}.tar.gz"
        if curl -fsSL "$URL" -o "$TARBALL"; then
            ACTUAL_SHA="$(sha256sum "$TARBALL" | awk '{print $1}')"
            if [ "$ACTUAL_SHA" = "$UV_SHA256" ]; then
                tar -xzf "$TARBALL" -C "$TEMP_DIR"
                $SUDO install -m 755 "${TEMP_DIR}/uv-${UV_TARGET}/uv" /usr/local/bin/uv
                $SUDO install -m 755 "${TEMP_DIR}/uv-${UV_TARGET}/uvx" /usr/local/bin/uvx
                log_success "uv and uvx verified and installed to /usr/local/bin."
            else
                log_error "SHA256 checksum verification failed for uv! Expected $UV_SHA256, got $ACTUAL_SHA"
                rm -rf "$TEMP_DIR"
                exit 1
            fi
        else
            log_error "Failed to download uv from $URL"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
        rm -rf "$TEMP_DIR"
    else
        log_warn "Unsupported architecture for uv: $ARCH"
    fi
fi

# ------------------------------------------------------------------------------
# Section 7: Cryptographically Pinned Binary: Pueue Task Queue Daemon
# ------------------------------------------------------------------------------
# pueue: Subprocess task queue manager for agent eval runs and background loops.
# First attempts distribution package; falls back to verified static musl binary.
if ! command -v pueue >/dev/null 2>&1; then
    log_info "Attempting to install pueue task queue..."
    if $SUDO apt-get install -y --no-install-recommends pueue >/dev/null 2>&1; then
        log_success "pueue installed via apt."
    else
        log_info "Installing official static pueue release binary with SHA256 verification..."
        ARCH="$(uname -m)"
        case "$ARCH" in
            x86_64)
                PUEUE_TARGET="x86_64-unknown-linux-musl"
                PUEUE_SHA256="c1b10d7e4e62211075ddd0e1dc3e8cbfc5a43d662cb3be7402a28504e23fcb51"
                PUEUED_SHA256="5afeff6adbafb909e8d54e2caff158e6966c2adffa2c09e60fd631cc51b60390"
                ;;
            aarch64|arm64)
                PUEUE_TARGET="aarch64-unknown-linux-musl"
                PUEUE_SHA256="759bf5100a51024997111c6913aaf3330a0cdfd893ff552dcf429ae9b5e01e09"
                PUEUED_SHA256="332c5ef74270b64aeaf04894c8c04826f3422eb7d50dbd1a8e0706d74a42f653"
                ;;
            *)
                PUEUE_TARGET=""
                ;;
        esac

        if [ -n "$PUEUE_TARGET" ]; then
            PUEUE_VER="v4.0.4"
            TEMP_DIR="$(mktemp -d)"
            PUEUE_BIN="${TEMP_DIR}/pueue"
            PUEUED_BIN="${TEMP_DIR}/pueued"
            PUEUE_URL="https://github.com/Nukesor/pueue/releases/download/${PUEUE_VER}/pueue-${PUEUE_TARGET}"
            PUEUED_URL="https://github.com/Nukesor/pueue/releases/download/${PUEUE_VER}/pueued-${PUEUE_TARGET}"

            if curl -fsSL "$PUEUE_URL" -o "$PUEUE_BIN" && curl -fsSL "$PUEUED_URL" -o "$PUEUED_BIN"; then
                ACTUAL_PUEUE_SHA="$(sha256sum "$PUEUE_BIN" | awk '{print $1}')"
                ACTUAL_PUEUED_SHA="$(sha256sum "$PUEUED_BIN" | awk '{print $1}')"

                if [ "$ACTUAL_PUEUE_SHA" = "$PUEUE_SHA256" ] && [ "$ACTUAL_PUEUED_SHA" = "$PUEUED_SHA256" ]; then
                    $SUDO install -m 755 "$PUEUE_BIN" /usr/local/bin/pueue
                    $SUDO install -m 755 "$PUEUED_BIN" /usr/local/bin/pueued
                    log_success "pueue and pueued verified and installed to /usr/local/bin."
                else
                    log_error "SHA256 checksum mismatch for pueue or pueued! Aborting."
                    rm -rf "$TEMP_DIR"
                    exit 1
                fi
            else
                log_error "Could not download static pueue release binaries."
                rm -rf "$TEMP_DIR"
                exit 1
            fi
            rm -rf "${TEMP_DIR}"
        fi
    fi
fi

log_success "Package setup completed for profile: $PROFILE."
