#!/usr/bin/env bash
# ==============================================================================
# File:        scripts/update-checksums.sh
# Component:   Supply Chain Verification & Cryptographic Audit
# Description: Verifies or computes SHA256 checksums for pinned binary releases
#              (uv and pueue) across x86_64 and aarch64 architectures.
# Invariants:  - Upstream release artifacts downloaded to isolated temp directory.
#              - Fail-closed verification: any hash mismatch exits non-zero.
#              - Temporary staging directories guaranteed purged via EXIT trap.
# Dependencies: curl, awk, sha256sum (or shasum), grep
# Target OS:   Ubuntu 22.04+ / Debian 12+ / macOS (Bash 4.0+)
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Terminal Formatting & Logging
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
# 2. Path Resolution & Cryptographic Hash Engine
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_SH="${SCRIPT_DIR}/packages.sh"

# Compute SHA256 using platform-available utility (coreutils sha256sum or BSD shasum)
compute_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        log_error "Neither 'sha256sum' nor 'shasum' is available."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# 3. CLI Interface & Argument Parsing
# ------------------------------------------------------------------------------
usage() {
    echo -e "${BOLD}update-checksums.sh${RESET} - Audit and maintain cryptographic checksums for pinned binaries

${BOLD}Usage:${RESET}
  ./scripts/update-checksums.sh [options]

${BOLD}Options:${RESET}
  --check                    Verify that current pinned checksums in packages.sh match upstream
  --uv-version <version>     Version of uv to fetch/verify (default: version in packages.sh)
  --pueue-version <version>  Version of pueue to fetch/verify (default: version in packages.sh)
  -h, --help                 Show this help message

${BOLD}Examples:${RESET}
  ./scripts/update-checksums.sh --check
  ./scripts/update-checksums.sh --uv-version 0.6.5 --pueue-version v4.0.4"
}

CHECK_MODE=false
CLI_UV_VER=""
CLI_PUEUE_VER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            CHECK_MODE=true
            shift
            ;;
        --uv-version)
            CLI_UV_VER="$2"
            shift 2
            ;;
        --pueue-version)
            CLI_PUEUE_VER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 4. Target Version Discovery & Sandbox Initialization
# ------------------------------------------------------------------------------
# Extract default pinned versions directly from scripts/packages.sh declarations
PINNED_UV_VER="$(grep -E 'UV_VER=' "$PACKAGES_SH" | head -n1 | cut -d'"' -f2 || echo "0.6.5")"
PINNED_PUEUE_VER="$(grep -E 'PUEUE_VER=' "$PACKAGES_SH" | head -n1 | cut -d'"' -f2 || echo "v4.0.4")"

UV_VER="${CLI_UV_VER:-$PINNED_UV_VER}"
PUEUE_VER="${CLI_PUEUE_VER:-$PINNED_PUEUE_VER}"

# Isolate all downloaded binaries in temporary directory purged on script exit
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

log_info "Querying upstream releases (uv: ${UV_VER}, pueue: ${PUEUE_VER})..."

# ------------------------------------------------------------------------------
# 5. Upstream Checksum Retrieval & Binary Hashing
# ------------------------------------------------------------------------------
# Step 1: astral-sh/uv publishes pre-computed SHA256 files alongside GitHub release assets
log_info "Fetching uv release checksums for version ${UV_VER}..."
UV_X86_URL="https://github.com/astral-sh/uv/releases/download/${UV_VER}/uv-x86_64-unknown-linux-gnu.tar.gz.sha256"
UV_ARM_URL="https://github.com/astral-sh/uv/releases/download/${UV_VER}/uv-aarch64-unknown-linux-gnu.tar.gz.sha256"

UV_X86_SHA="$(curl -fsSL "$UV_X86_URL" | awk '{print $1}')"
UV_ARM_SHA="$(curl -fsSL "$UV_ARM_URL" | awk '{print $1}')"

# Step 2: Nukesor/pueue does not publish standalone .sha256 files; fetch binaries and calculate local hash
log_info "Fetching pueue release binaries for version ${PUEUE_VER}..."
curl -fsSL "https://github.com/Nukesor/pueue/releases/download/${PUEUE_VER}/pueue-x86_64-unknown-linux-musl" -o "${TEMP_DIR}/pueue-x86"
curl -fsSL "https://github.com/Nukesor/pueue/releases/download/${PUEUE_VER}/pueued-x86_64-unknown-linux-musl" -o "${TEMP_DIR}/pueued-x86"
curl -fsSL "https://github.com/Nukesor/pueue/releases/download/${PUEUE_VER}/pueue-aarch64-unknown-linux-musl" -o "${TEMP_DIR}/pueue-arm"
curl -fsSL "https://github.com/Nukesor/pueue/releases/download/${PUEUE_VER}/pueued-aarch64-unknown-linux-musl" -o "${TEMP_DIR}/pueued-arm"

PUEUE_X86_SHA="$(compute_sha256 "${TEMP_DIR}/pueue-x86")"
PUEUED_X86_SHA="$(compute_sha256 "${TEMP_DIR}/pueued-x86")"
PUEUE_ARM_SHA="$(compute_sha256 "${TEMP_DIR}/pueue-arm")"
PUEUED_ARM_SHA="$(compute_sha256 "${TEMP_DIR}/pueued-arm")"

# ------------------------------------------------------------------------------
# 6. Audit Mode / Output Generation
# ------------------------------------------------------------------------------
if [ "$CHECK_MODE" = true ]; then
    log_info "Verifying against pinned checksums in scripts/packages.sh..."
    MISMATCH=0

    # Fail-closed comparator: ensure computed hash exists within packages.sh definition
    check_hash() {
        local name="$1"
        local expected="$2"
        if grep -q "$expected" "$PACKAGES_SH"; then
            log_success "$name SHA256 matches: $expected"
        else
            log_error "$name SHA256 mismatch or not found in packages.sh! Upstream: $expected"
            MISMATCH=1
        fi
    }

    check_hash "uv (x86_64)" "$UV_X86_SHA"
    check_hash "uv (aarch64)" "$UV_ARM_SHA"
    check_hash "pueue (x86_64)" "$PUEUE_X86_SHA"
    check_hash "pueued (x86_64)" "$PUEUED_X86_SHA"
    check_hash "pueue (aarch64)" "$PUEUE_ARM_SHA"
    check_hash "pueued (aarch64)" "$PUEUED_ARM_SHA"

    if [ "$MISMATCH" -eq 0 ]; then
        echo ""
        log_success "All pinned binary checksums in scripts/packages.sh are 100% verified against upstream releases!"
        exit 0
    else
        echo ""
        log_error "Verification failed! One or more pinned checksums diverge from upstream releases."
        exit 1
    fi
else
    # Emit structured assignment blocks ready for copy-paste or automated patching
    echo -e "
${BOLD}${GREEN}========================================================================${RESET}
${BOLD}Calculated Cryptographic Checksums (Upstream Release Ground Truth)${RESET}
${BOLD}${GREEN}========================================================================${RESET}

# uv (version: ${UV_VER})
x86_64-unknown-linux-gnu:
  UV_SHA256=\"${UV_X86_SHA}\"
aarch64-unknown-linux-gnu:
  UV_SHA256=\"${UV_ARM_SHA}\"

# pueue / pueued (version: ${PUEUE_VER})
x86_64-unknown-linux-musl:
  PUEUE_SHA256=\"${PUEUE_X86_SHA}\"
  PUEUED_SHA256=\"${PUEUED_X86_SHA}\"
aarch64-unknown-linux-musl:
  PUEUE_SHA256=\"${PUEUE_ARM_SHA}\"
  PUEUED_SHA256=\"${PUEUED_ARM_SHA}\"

To update scripts/packages.sh, update UV_VER / PUEUE_VER and paste the respective SHA256 variables."
fi
