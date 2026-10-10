#!/usr/bin/env bash
# tests/sandbox.sh: Drops into an interactive Ubuntu 24.04 sandbox with AI Automation Engineer Workstation installed

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="ai-automation-engineer-workstation-sandbox"

echo "Building / verifying Ubuntu 24.04 sandbox image..."
docker build -t "${IMAGE_NAME}" -f "${DOTFILES_ROOT}/tests/Dockerfile" "${DOTFILES_ROOT}"

echo ""
echo "=========================================================="
echo "  Entering Interactive AI Automation Workstation Sandbox  "
echo "  All workstation tools are installed and ready!          "
echo "  Type 'exit' when you want to return to macOS.           "
echo "=========================================================="
echo ""

docker run --rm -it \
    -e TERM=xterm-256color \
    "${IMAGE_NAME}" \
    /bin/bash -c "cd /home/testuser/ai-automation-engineer-workstation && ./install.sh -y >/dev/null 2>&1 && exec /bin/bash -l"
