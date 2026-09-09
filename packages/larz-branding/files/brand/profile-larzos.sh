# LarzOS shell environment - /etc/profile.d/larzos.sh
LARZOS=1
export LARZOS

# One-time hint for a fresh interactive login shell.
if [ -n "$PS1" ] && [ -z "$LARZOS_HINT_SHOWN" ] && [ ! -f "$HOME/.larzos-hinted" ]; then
    LARZOS_HINT_SHOWN=1
    printf '\033[0;90mLarzOS - try:\033[0m larz help  \033[0;90m|\033[0m  larz plan  \033[0;90m|\033[0m  larz ai "..."\n'
    : > "$HOME/.larzos-hinted" 2>/dev/null || true
fi
