#!/bin/bash --login

set -euo pipefail

CODEX_ENV_PYTHON_VERSION=${CODEX_ENV_PYTHON_VERSION:-}
CODEX_ENV_NODE_VERSION=${CODEX_ENV_NODE_VERSION:-}

echo "Configuring language runtimes..."

# For Python and Node, always run the install commands so we can install
# global libraries for linting and formatting. This just switches the version.

if [ -n "${CODEX_ENV_PYTHON_VERSION}" ]; then
    echo "# Python: ${CODEX_ENV_PYTHON_VERSION}"
    # Use the same HOME as build time to avoid re-downloading
    export UV_HOME=/opt/uv
    export PATH=$UV_HOME/.local/bin:$PATH
    HOME=/opt/uv uv python install "${CODEX_ENV_PYTHON_VERSION}" >/dev/null 2>&1 || true
    PYTHON_DEFAULT_PATH="$(HOME=/opt/uv uv python find "${CODEX_ENV_PYTHON_VERSION}")"
    ln -sf "${PYTHON_DEFAULT_PATH}" /usr/local/bin/python3
fi

if [ -n "${CODEX_ENV_NODE_VERSION}" ]; then
    current=$(node -v | cut -d. -f1)   # ==> v20
    echo "# Node.js: v${CODEX_ENV_NODE_VERSION} (default: ${current})"
    if [ "${current}" != "v${CODEX_ENV_NODE_VERSION}" ]; then
        #nvm alias default "${CODEX_ENV_NODE_VERSION}"
        #nvm use "${CODEX_ENV_NODE_VERSION}"
        corepack enable
    fi
fi
