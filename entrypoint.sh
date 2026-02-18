#!/bin/bash
set -euo pipefail
#
# Entrypoint Script
# Description: Container entrypoint that configures environment and launches CLI tools or commands
# Usage: Automatically invoked by Docker/Podman; supports direct commands or -c flag for bash execution
# Environment: TZ (optional, auto-detected from /etc/timezone if not set)
#

echo "=================================="
echo "Welcome to openai/codex-universal!"
echo "=================================="

# Prefer the host timezone when provided (e.g., via -v /etc/timezone:/etc/timezone:ro)
if [ -z "${TZ:-}" ] && [ -f /etc/timezone ]; then
    export TZ="$(cat /etc/timezone)"
fi

/opt/codex/setup_universal.sh

# If no arguments provided, show menu
if [ ${#} -eq 0 ]; then
    echo "Environment ready."
    exec /opt/menu.sh
# If first argument is -c, execute with bash -c
elif [ "${1}" = "-c" ]; then
    echo "Environment ready."
    shift
    exec bash --login -c "$@"
else
    # If arguments provided, execute the command
    echo "Environment ready."
    exec "$@"
fi
