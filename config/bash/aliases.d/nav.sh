# ~/.bash_aliases.d/nav.sh: Directory navigation and listings

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias -- -="cd -"

mkcd() {
    mkdir -p "$1" && cd "$1" || return
}

if [ -x /usr/bin/dircolors ]; then
    alias ls='ls --color=auto --group-directories-first'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias lt='ls -altr'
alias lsize='ls -alShr'
