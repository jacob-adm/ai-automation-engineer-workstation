#!/usr/bin/env bash
# scripts/links.sh: Safely symlinks dotfiles to the target home directory with backups

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

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${HOME}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${HOME}/.dotfiles_backup/${TIMESTAMP}"
BACKUP_CREATED=0
DRY_RUN=0

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET_DIR="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -n|--dry-run|--preview)
            DRY_RUN=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

backup_file() {
    local file="$1"
    local base
    base="$(basename "$file")"
    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY-RUN] Would backup: $file -> $BACKUP_DIR/$base"
        return 0
    fi
    if [ "$BACKUP_CREATED" -eq 0 ]; then
        mkdir -p "$BACKUP_DIR"
        BACKUP_CREATED=1
        log_info "Backup directory initialized at: $BACKUP_DIR"
    fi
    mv "$file" "$BACKUP_DIR/$base"
    log_warn "Existing file backed up: $file -> $BACKUP_DIR/$base"
}

link_file() {
    local src="$1"
    local dest="$2"

    if [ "$DRY_RUN" -eq 1 ]; then
        if [ -L "$dest" ] && [ "$(readlink -f "$dest" 2>/dev/null || readlink "$dest")" = "$src" ]; then
            log_info "[DRY-RUN] Already linked: $dest -> $src"
        elif [ -e "$dest" ] || [ -L "$dest" ]; then
            backup_file "$dest"
            log_info "[DRY-RUN] Would link: $dest -> $src"
        else
            log_info "[DRY-RUN] Would link: $dest -> $src"
        fi
        return 0
    fi

    mkdir -p "$(dirname "$dest")"

    # Check if destination exists or is a broken symlink
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # If it's already a symlink pointing to the same file, do nothing
        if [ -L "$dest" ] && [ "$(readlink -f "$dest" 2>/dev/null || readlink "$dest")" = "$src" ]; then
            log_info "Already linked: $dest -> $src"
            return 0
        fi
        backup_file "$dest"
    fi

    ln -s "$src" "$dest"
    log_success "Linked: $dest -> $src"
}

log_info "Starting dotfiles symlink process to: $TARGET_DIR"

# Define configurations to link (Format: relative_source:relative_dest)
CONFIG_PAIRS=(
    # Shell
    "config/bash/.bashrc:.bashrc"
    "config/bash/.bash_aliases:.bash_aliases"
    "config/bash/.bash_profile:.bash_profile"
    "config/bash/.profile:.profile"
    # Git
    "config/git/.gitconfig:.gitconfig"
    "config/git/.gitignore_global:.gitignore_global"
    # Multiplexer & Editor
    "config/tmux/.tmux.conf:.tmux.conf"
    "config/vim/.vimrc:.vimrc"
    # AI & Automation Configurations
    "config/npm/.npmrc:.npmrc"
    "config/uv/uv.toml:.config/uv/uv.toml"
    "config/pueue/pueue.yml:.config/pueue/pueue.yml"
    "config/ai_automation/ai_automation.sh:.ai_automation.sh"
    "config/mcp/mcp.json:.config/mcp/mcp.json"
    # Coding Agent Instructions and Exclusions
    "config/agents/AGENTS.md:.config/agents/AGENTS.md"
    "config/agents/AGENTS.md:.claude/CLAUDE.md"
    "config/claude/settings.json:.claude/settings.json"
    "config/opencode/opencode.json:.config/opencode/opencode.json"
)

for pair in "${CONFIG_PAIRS[@]}"; do
    rel_src="${pair%%:*}"
    rel_dest="${pair##*:}"
    src="${DOTFILES_ROOT}/${rel_src}"
    dest="${TARGET_DIR}/${rel_dest}"

    if [ -f "$src" ]; then
        link_file "$src" "$dest"
    else
        log_warn "Source file not found, skipping: $src"
    fi
done

# Link modular aliases in ~/.bash_aliases.d/
if [ -d "${DOTFILES_ROOT}/config/bash/aliases.d" ]; then
    [ "$DRY_RUN" -eq 0 ] && mkdir -p "${TARGET_DIR}/.bash_aliases.d"
    for mod in "${DOTFILES_ROOT}/config/bash/aliases.d"/*.sh; do
        if [ -f "$mod" ]; then
            mod_name="$(basename "$mod")"
            link_file "$mod" "${TARGET_DIR}/.bash_aliases.d/${mod_name}"
        fi
    done
fi

# Link custom user binaries to ~/.local/bin
LOCAL_BIN="${TARGET_DIR}/.local/bin"
[ "$DRY_RUN" -eq 0 ] && mkdir -p "$LOCAL_BIN"

if [ -d "${DOTFILES_ROOT}/bin" ]; then
    for script in "${DOTFILES_ROOT}/bin"/*; do
        if [ -f "$script" ]; then
            [ "$DRY_RUN" -eq 0 ] && chmod +x "$script"
            script_name="$(basename "$script")"
            link_file "$script" "${LOCAL_BIN}/${script_name}"
        fi
    done
fi

if [ "$DRY_RUN" -eq 1 ]; then
    log_success "Dry-run preview completed. Zero changes were made to disk."
else
    log_success "Symlink process completed."
    if [ "$BACKUP_CREATED" -eq 1 ]; then
        log_info "Any overridden files are preserved in: $BACKUP_DIR"
    fi
fi
