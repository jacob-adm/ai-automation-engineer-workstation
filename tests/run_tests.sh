#!/usr/bin/env bash
# ==============================================================================
# File:        tests/run_tests.sh
# Component:   Containerized Test Runner
# Description: Builds the clean Ubuntu 24.04 test image and triggers the complete
#              17-stage verification test harness in an ephemeral container.
# Invariants:  - Ephemeral container execution: container pruned (--rm) on completion.
#              - Fail-closed execution: non-zero exit code propagated if any test fails.
# Dependencies: docker
# Target OS:   Host system with Docker daemon (macOS / Linux)
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Environment & Container Configuration
# ------------------------------------------------------------------------------
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="ai-automation-engineer-workstation-test"

# ------------------------------------------------------------------------------
# 2. Container Build & Test Execution
# ------------------------------------------------------------------------------
# Build reproducible Ubuntu test environment from repository root context
echo "==> Building Docker test image: ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" -f "${DOTFILES_ROOT}/tests/Dockerfile" "${DOTFILES_ROOT}"

# Execute 17-stage test suite inside ephemeral container
echo "==> Running verification tests inside container..."
docker run --rm -t "${IMAGE_NAME}"
