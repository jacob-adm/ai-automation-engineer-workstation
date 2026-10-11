#!/usr/bin/env bash
# ==============================================================================
# File:        tests/sandbox.sh
# Component:   Interactive Development Sandbox Launcher
# Description: Builds and launches an interactive Ubuntu 24.04 Docker sandbox
#              with the AI Automation Engineer Workstation dotfiles installed.
# Invariants:  - Ephemeral container execution: container pruned (--rm) on terminal exit.
#              - Spawns interactive login shell (-l) with full workstation environment.
# Dependencies: docker
# Target OS:   Host system with Docker daemon (macOS / Linux)
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Environment & Container Configuration
# ------------------------------------------------------------------------------
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="ai-automation-engineer-workstation-sandbox"

# ------------------------------------------------------------------------------
# 2. Image Build & Interactive Launch
# ------------------------------------------------------------------------------
echo "Building / verifying Ubuntu 24.04 sandbox image..."
docker build -t "${IMAGE_NAME}" -f "${DOTFILES_ROOT}/tests/Dockerfile" "${DOTFILES_ROOT}"

echo ""
echo "=========================================================="
echo "  Entering Interactive AI Automation Workstation Sandbox  "
echo "  All workstation tools are installed and ready!          "
echo "  Type 'exit' when you want to return to macOS.           "
echo "=========================================================="
echo ""

# Launch container with pseudo-TTY and install dotfiles before presenting login shell
docker run --rm -it \
    -e TERM=xterm-256color \
    "${IMAGE_NAME}" \
    /bin/bash -c "cd /home/testuser/ai-automation-engineer-workstation && ./install.sh -y >/dev/null 2>&1 && exec /bin/bash -l"
