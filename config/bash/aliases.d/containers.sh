# ~/.bash_aliases.d/containers.sh: Docker and container management shortcuts

alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dimg='docker images'
alias dstop='docker stop $(docker ps -q 2>/dev/null) 2>/dev/null || echo "No running containers"'
alias dprune='docker system prune -af --volumes'
alias dlogs='docker logs -f --tail 100'

# Ensure docker daemon is active before running commands
alias edocker='ensure-docker'
