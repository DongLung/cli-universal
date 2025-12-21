#!/bin/bash --login

set -euo pipefail

echo "Verifying language runtimes ..."

echo "- Python:"
python3 --version
for version in "3.12" "3.13" "3.14.0"; do
    uv run --python "${version}" -- python --version
done

echo "- uv:"
uv --version

echo "- Node.js:"
for version in "20" "22"; do
    nvm use --global "${version}"
    node --version
    npm --version
    pnpm --version
    yarn --version
done

echo "- CLI utilities:"
rg --version
fzf --version
git --version

echo "All tooling detected successfully."
