# ==============================================================================
# File:        config/bash/aliases.d/git.sh
# Component:   Modular Aliases: Version Control & Git Operations
# Description: Streamlines Git workflows with concise aliases for repository
#              status, topological commit graphs, stage management, and branch switching.
# Invariants:  - Commit graph aliases include colorized hashes, relative timestamps, and authors.
#              - Default status alias uses short-format branch tracking (-sb).
# Dependencies: git
# Target OS:   POSIX Bash (Ubuntu 22.04+, Debian 12+, macOS)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Status & Diff Inspection
# ------------------------------------------------------------------------------
alias gs='git status -sb'
alias gst='git status'
alias gd='git diff'
alias gds='git diff --staged'

# ------------------------------------------------------------------------------
# 2. History & Commit Graphs
# ------------------------------------------------------------------------------
alias gl='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'

# ------------------------------------------------------------------------------
# 3. Branching & Switching
# ------------------------------------------------------------------------------
alias gco='git checkout'
alias gb='git branch -v'

# ------------------------------------------------------------------------------
# 4. Synchronization (Pull / Push)
# ------------------------------------------------------------------------------
alias gp='git pull'
alias gP='git push'

# ------------------------------------------------------------------------------
# 5. Staging & Commits
# ------------------------------------------------------------------------------
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gunstage='git reset HEAD --'
