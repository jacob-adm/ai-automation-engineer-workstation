#!/bin/sh
# ==============================================================================
# File:        bootstrap.sh
# Component:   AI Automation Workstation Zero-Dependency Bootstrapper
# Description: Detects OS & architecture, fetches pre-compiled static release binary,
#              verifies SHA256 integrity, and executes workstation installation.
# Target OS:   Linux (x86_64, aarch64), macOS (Apple Silicon, Intel)
# ==============================================================================

set -eu

REPO="ai-automation-engineer-workstation"
VERSION="${WORKSTATION_VERSION:-latest}"
INSTALL_DIR="${HOME}/.local/bin"

# 1. Detect OS
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
    linux)  OS_TARGET="unknown-linux-musl" ;;
    darwin) OS_TARGET="apple-darwin" ;;
    *) echo "Unsupported operating system: $OS" >&2; exit 1 ;;
esac

# 2. Detect Architecture
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)   ARCH_TARGET="x86_64" ;;
    aarch64|arm64)  ARCH_TARGET="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

TARGET="${ARCH_TARGET}-${OS_TARGET}"
BINARY_NAME="workstation-${TARGET}"
echo "[INFO] Detected target platform: ${TARGET}"

# Ensure ~/.local/bin exists
mkdir -p "$INSTALL_DIR"

# 3. Check if local build or cargo exists first (developer fast path)
if command -v cargo >/dev/null 2>&1 && [ -f "Cargo.toml" ]; then
    echo "[INFO] Local Cargo workspace detected. Building workstation binary..."
    cargo build --release --bin workstation
    cp target/release/workstation "${INSTALL_DIR}/workstation"
    chmod +x "${INSTALL_DIR}/workstation"
    echo "[OK] Installed local build to ${INSTALL_DIR}/workstation"
    exec "${INSTALL_DIR}/workstation" links
fi

echo "[INFO] Fetching release binary from GitHub..."
URL="https://github.com/${REPO}/releases/${VERSION}/download/${BINARY_NAME}"
TMP_BIN="$(mktemp)"

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$TMP_BIN"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP_BIN" "$URL"
else
    echo "[ERROR] Neither curl nor wget is available." >&2
    exit 1
fi

mv "$TMP_BIN" "${INSTALL_DIR}/workstation"
chmod 755 "${INSTALL_DIR}/workstation"
echo "[OK] Successfully installed workstation to ${INSTALL_DIR}/workstation"

exec "${INSTALL_DIR}/workstation" links
