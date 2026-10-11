# ==============================================================================
# File:        config/bash/aliases.d/containers.sh
# Component:   Modular Aliases: Container Lifecycle & Engine Management
# Description: Provides streamlined operational aliases for Docker process inspection,
#              mass container termination, aggressive volume pruning, and daemon recovery.
# Invariants:  - Mass container stop fails gracefully if zero containers are active.
#              - Process listing formats output into compact tabular columns.
# Dependencies: docker, ensure-docker
# Target OS:   POSIX Bash (Ubuntu 22.04+, Debian 12+, macOS)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Container Inspection & Process Listing
# ------------------------------------------------------------------------------
# Tabular process list showing container ID, name, status, and port bindings
alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dimg='docker images'

# ------------------------------------------------------------------------------
# 2. Lifecycle & Cleanup
# ------------------------------------------------------------------------------
# Gracefully halt all running containers across the local Docker daemon
alias dstop='docker stop $(docker ps -q 2>/dev/null) 2>/dev/null || echo "No running containers"'

# Aggressively prune unused containers, networks, dangling images, and build volumes
alias dprune='docker system prune -af --volumes'

# Tail recent container output logs
alias dlogs='docker logs -f --tail 100'

# ------------------------------------------------------------------------------
# 3. Daemon Health & Socket Recovery
# ------------------------------------------------------------------------------
# Launch or verify Docker socket readiness via workstation utility
alias edocker='ensure-docker'
