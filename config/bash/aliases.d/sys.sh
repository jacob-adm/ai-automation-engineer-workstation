# ~/.bash_aliases.d/sys.sh: System inspection, GPU, Slurm, and safety confirmations

# Safety confirmations
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# System inspection
alias df='df -h'
alias du='du -h -c'
alias free='free -m'
alias top='htop 2>/dev/null || top'
alias path='echo -e ${PATH//:/\\n}'
alias reload='source ~/.bashrc && echo "Bash configuration reloaded."'
alias ports='ss -tulanp 2>/dev/null || netstat -tulanp 2>/dev/null'
alias update-dotfiles='dotfiles-update'

# Modern CLI fallbacks
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    alias bat='batcat'
fi

if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    alias fd='fdfind'
fi

# GPU & Slurm
alias gpu='watch -n 1 nvidia-smi 2>/dev/null || echo "nvidia-smi not available"'
alias gpu-mem='nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv 2>/dev/null || echo "nvidia-smi not available"'

if command -v squeue >/dev/null 2>&1; then
    alias q='squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %N %.10b"'
    alias qw='watch squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %N %.10b"'
    alias qq='squeue -u $(whoami)'
    alias qtest='sbatch --gres=gpu:1 --wrap="hostname; nvidia-smi"'
    alias qlogin='srun --gres=gpu:1 --pty $SHELL'
    alias qdel='scancel'
    alias qclear='scancel -u $(whoami)'
fi

myip() {
    echo -n "Local IP:  "
    hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A"
    echo -n "Public IP: "
    curl -s --max-time 3 https://ifconfig.me 2>/dev/null || echo "offline"
    echo ""
}

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
