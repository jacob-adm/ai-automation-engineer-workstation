# ~/.bash_profile: executed by bash(1) for login shells.

# Source ~/.profile if it exists
if [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi

# Source ~/.bashrc if it exists and hasn't been sourced yet
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
