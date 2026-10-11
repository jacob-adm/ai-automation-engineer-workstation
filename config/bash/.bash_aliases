# ==============================================================================
# File:        config/bash/.bash_aliases
# Component:   Master Alias Dispatcher
# Description: Dynamically discovers and evaluates modular alias definitions
#              from ~/.bash_aliases.d/ alongside host-specific local overrides.
# Invariants:  - Modules ingested alphabetically based on standard glob sorting.
#              - Local overrides (~/.bash_aliases.local) evaluated last to permit overrides.
# Dependencies: bash 4+
# Target OS:   POSIX Bash (Ubuntu 22.04+, Debian 12+, macOS)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Modular Alias Ingestion
# ------------------------------------------------------------------------------
# Iterate through all shell scripts in the modular aliases directory
if [ -d "$HOME/.bash_aliases.d" ]; then
    for module in "$HOME/.bash_aliases.d"/*.sh; do
        if [ -f "$module" ]; then
            # shellcheck disable=SC1090
            . "$module"
        fi
    done
fi

# ------------------------------------------------------------------------------
# 2. Local Machine Overrides
# ------------------------------------------------------------------------------
# Load developer-specific uncommitted alias overrides if present
if [ -f "$HOME/.bash_aliases.local" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.bash_aliases.local"
fi
