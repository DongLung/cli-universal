#!/bin/bash --login
#
# Verification Script
# Description: Verifies installed language runtimes and CLI utilities are functional
# Usage: ./verify.sh (run inside container to check environment setup)
# Exit Codes: 0=success, non-zero=verification failed
#

set -euo pipefail
export PATH="/opt/npm-global/bin:${PATH}"

echo "Verifying language runtimes ..."

echo "- Python:"
python3 --version
for version in "3.12" "3.13" "3.14.0"; do
    uv run --python "${version}" -- python --version || echo "  Python ${version}: not available"
done

echo "- uv:"
uv --version

echo "- Node.js:"
node --version
npm --version

echo "- AI CLI tools:"
codex --version
copilot --version
gemini --version

echo "- CLI utilities:"
rg --version
fzf --version
git --version

echo "All tooling detected successfully."
