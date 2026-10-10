#!/usr/bin/env bash
# tests/run_tests.sh: Build the Docker test image and execute verification

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="ai-automation-engineer-workstation-test"

echo "==> Building Docker test image: ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" -f "${DOTFILES_ROOT}/tests/Dockerfile" "${DOTFILES_ROOT}"

echo "==> Running verification tests inside container..."
docker run --rm -t "${IMAGE_NAME}"
