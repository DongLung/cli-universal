#!/bin/bash

echo "=================================="
echo "Welcome to openai/codex-universal!"
echo "=================================="

# Prefer the host timezone when provided (e.g., via -v /etc/timezone:/etc/timezone:ro)
if [ -z "${TZ:-}" ] && [ -f /etc/timezone ]; then
    export TZ="$(cat /etc/timezone)"
fi

/opt/codex/setup_universal.sh

# If no arguments provided, show menu
if [ $# -eq 0 ]; then
    echo "Environment ready."
    exec /opt/menu.sh
# If first argument is -c, execute with bash -c
elif [ "$1" = "-c" ]; then
    echo "Environment ready."
    shift
    exec bash --login -c "$@"
else
    # If arguments provided, execute the command
    echo "Environment ready."
    exec "$@"
fi
