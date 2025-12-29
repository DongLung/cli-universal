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
node --version
npm --version

echo "- CLI utilities:"
rg --version
fzf --version
git --version

echo "All tooling detected successfully."
