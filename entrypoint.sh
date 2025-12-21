#!/bin/bash

echo "=================================="
echo "Welcome to openai/codex-universal!"
echo "=================================="

# Prefer the host timezone when provided (e.g., via -v /etc/timezone:/etc/timezone:ro)
if [ -z "${TZ:-}" ] && [ -f /etc/timezone ]; then
    export TZ="$(cat /etc/timezone)"
fi

/opt/codex/setup_universal.sh

echo "Environment ready. Dropping you into a bash shell."
exec bash --login "$@"
