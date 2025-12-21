#!/bin/bash --login

set -euo pipefail

CODEX_ENV_PYTHON_VERSION=${CODEX_ENV_PYTHON_VERSION:-}
CODEX_ENV_NODE_VERSION=${CODEX_ENV_NODE_VERSION:-}

echo "Configuring language runtimes..."

# For Python and Node, always run the install commands so we can install
# global libraries for linting and formatting. This just switches the version.

if [ -n "${CODEX_ENV_PYTHON_VERSION}" ]; then
    echo "# Python: ${CODEX_ENV_PYTHON_VERSION}"
    uv python install "${CODEX_ENV_PYTHON_VERSION}"
    PYTHON_DEFAULT_PATH="$(uv python find "${CODEX_ENV_PYTHON_VERSION}")"
    ln -sf "${PYTHON_DEFAULT_PATH}" /usr/local/bin/python3
fi

if [ -n "${CODEX_ENV_NODE_VERSION}" ]; then
    current=$(node -v | cut -d. -f1)   # ==> v20
    echo "# Node.js: v${CODEX_ENV_NODE_VERSION} (default: ${current})"
    if [ "${current}" != "v${CODEX_ENV_NODE_VERSION}" ]; then
        nvm alias default "${CODEX_ENV_NODE_VERSION}"
        nvm use "${CODEX_ENV_NODE_VERSION}"
        corepack enable
    fi
fi
