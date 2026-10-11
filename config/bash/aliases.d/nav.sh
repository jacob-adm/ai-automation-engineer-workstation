# ==============================================================================
# File:        config/bash/aliases.d/nav.sh
# Component:   Modular Aliases: Directory Navigation & File Listings
# Description: Accelerates filesystem navigation with multi-level parent cd aliases,
#              atomic mkdir-and-enter helper (mkcd), and colorized listing views.
# Invariants:  - mkcd returns immediately without changing cwd if directory creation fails.
#              - GNU ls uses --group-directories-first when dircolors is present.
# Dependencies: bash, ls, mkdir
# Target OS:   POSIX Bash (Ubuntu 22.04+, Debian 12+, macOS)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Hierarchical Directory Navigation
# ------------------------------------------------------------------------------
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias -- -="cd -"

# ------------------------------------------------------------------------------
# 2. Atomic Directory Creation & Entry
# ------------------------------------------------------------------------------
# Creates parent paths recursively and enters the target directory upon success
mkcd() {
    mkdir -p "$1" && cd "$1" || return
}

# ------------------------------------------------------------------------------
# 3. File Listing Views
# ------------------------------------------------------------------------------
if [ -x /usr/bin/dircolors ]; then
    alias ls='ls --color=auto --group-directories-first'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias lt='ls -altr'
alias lsize='ls -alShr'
