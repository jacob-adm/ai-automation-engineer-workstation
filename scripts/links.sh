#!/usr/bin/env bash
# ==============================================================================
# File:        scripts/links.sh
# Component:   Declarative Symlink Manifest & Backup Engine (Dispatcher)
# Description: Multi-call dispatch wrapper routing execution to 'workstation links'.
# ==============================================================================
set -euo pipefail

if command -v workstation >/dev/null 2>&1; then
    exec workstation links "$@"
fi

if [ -x "$HOME/.local/bin/workstation" ]; then
    exec "$HOME/.local/bin/workstation" links "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -x "${SCRIPT_DIR}/target/release/workstation" ]; then
    exec "${SCRIPT_DIR}/target/release/workstation" links "$@"
elif command -v cargo >/dev/null 2>&1 && [ -f "${SCRIPT_DIR}/Cargo.toml" ]; then
    echo "[workstation] Compiling workstation binary..." >&2
    cargo build --release --manifest-path "${SCRIPT_DIR}/Cargo.toml" --bin workstation >&2
    exec "${SCRIPT_DIR}/target/release/workstation" links "$@"
else
    echo "[ERROR] 'workstation' binary not found. Run ./bootstrap.sh or 'cargo build --release'." >&2
    exit 1
fi
