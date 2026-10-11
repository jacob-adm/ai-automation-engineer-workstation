# ==============================================================================
# File:        config/bash/aliases.d/sys.sh
# Component:   Modular Aliases: System Administration, GPU & HPC Operations
# Description: Provides safe filesystem defaults (interactive deletion/copying),
#              hardware telemetry (NVIDIA GPU utilization, Slurm workload queues),
#              network address resolution, and unified archive decompression.
# Invariants:  - cp, mv, and rm aliased with -i to prevent accidental data destruction.
#              - Debian binary name compatibility shims provided for bat and fd.
# Dependencies: bash, coreutils, ss/netstat, curl, tar (optional: nvidia-smi, squeue)
# Target OS:   POSIX Bash (Ubuntu 22.04+, Debian 12+, macOS)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Destructive Operation Safety Guards
# ------------------------------------------------------------------------------
# Require interactive confirmation before overwriting or deleting files
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# ------------------------------------------------------------------------------
# 2. System Resource & Network Diagnostics
# ------------------------------------------------------------------------------
alias df='df -h'
alias du='du -h -c'
alias free='free -m'
alias top='htop 2>/dev/null || top'
alias path='echo -e ${PATH//:/\\n}'
alias reload='source ~/.bashrc && echo "Bash configuration reloaded."'
alias ports='ss -tulanp 2>/dev/null || netstat -tulanp 2>/dev/null'
alias update-dotfiles='dotfiles-update'

# ------------------------------------------------------------------------------
# 3. Debian Binary Name Compatibility Shims
# ------------------------------------------------------------------------------
# Alias batcat -> bat if standard bat binary is unmapped
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    alias bat='batcat'
fi

# Alias fdfind -> fd if standard fd binary is unmapped
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    alias fd='fdfind'
fi

# ------------------------------------------------------------------------------
# 4. GPU & HPC Workload Telemetry (NVIDIA / Slurm)
# ------------------------------------------------------------------------------
alias gpu='watch -n 1 nvidia-smi 2>/dev/null || echo "nvidia-smi not available"'
alias gpu-mem='nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv 2>/dev/null || echo "nvidia-smi not available"'

# Slurm workload cluster helpers (enabled conditionally when squeue is present)
if command -v squeue >/dev/null 2>&1; then
    alias q='squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %N %.10b"'
    alias qw='watch squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %N %.10b"'
    alias qq='squeue -u $(whoami)'
    alias qtest='sbatch --gres=gpu:1 --wrap="hostname; nvidia-smi"'
    alias qlogin='srun --gres=gpu:1 --pty $SHELL'
    alias qdel='scancel'
    alias qclear='scancel -u $(whoami)'
fi

# ------------------------------------------------------------------------------
# 5. IP Address Resolution
# ------------------------------------------------------------------------------
# Displays local private interface IP and remote public WAN egress address
myip() {
    echo -n "Local IP:  "
    hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A"
    echo -n "Public IP: "
    curl -s --max-time 3 https://ifconfig.me 2>/dev/null || echo "offline"
    echo ""
}

# ------------------------------------------------------------------------------
# 6. Universal Archive Decompression Helper
# ------------------------------------------------------------------------------
# Dispatches archive extraction based on trailing file extension
extract() {
    if [ -z "$1" ]; then
        echo "Usage: extract <archive_file>"
        return 1
    fi
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.tar.xz)    tar xJf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
        return 1
    fi
}
