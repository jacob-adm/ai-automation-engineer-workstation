# ~/.bash_aliases: Master aliases entry point
# Loads modular alias collections from ~/.bash_aliases.d/

if [ -d "$HOME/.bash_aliases.d" ]; then
    for module in "$HOME/.bash_aliases.d"/*.sh; do
        if [ -f "$module" ]; then
            # shellcheck disable=SC1090
            . "$module"
        fi
    done
fi

# Local alias overrides if present
if [ -f "$HOME/.bash_aliases.local" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.bash_aliases.local"
fi
