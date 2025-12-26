#!/usr/bin/env bash
# Extract CLI tool versions from built image

set -euo pipefail

IMAGE="${1:-cli-universal:python3.12}"

echo "Extracting versions from image: ${IMAGE}"
echo ""

if ! podman image exists "${IMAGE}" 2>/dev/null && ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "Error: Image ${IMAGE} not found"
    exit 1
fi

RUNTIME="podman"
if ! command -v podman >/dev/null 2>&1; then
    RUNTIME="docker"
fi

echo "Using runtime: ${RUNTIME}"
echo ""

CODEX_VERSION=$(${RUNTIME} run --rm "${IMAGE}" cat /opt/versions/codex.txt 2>/dev/null | head -n1 || echo "unknown")
COPILOT_VERSION=$(${RUNTIME} run --rm "${IMAGE}" cat /opt/versions/copilot.txt 2>/dev/null | head -n1 || echo "unknown")
GEMINI_VERSION=$(${RUNTIME} run --rm "${IMAGE}" cat /opt/versions/gemini.txt 2>/dev/null | head -n1 || echo "unknown")

echo "Detected CLI versions:"
echo "  Codex CLI:          ${CODEX_VERSION}"
echo "  GitHub Copilot CLI: ${COPILOT_VERSION}"
echo "  Gemini CLI:         ${GEMINI_VERSION}"
echo ""

# Also show from image labels
echo "Image labels:"
${RUNTIME} image inspect "${IMAGE}" --format '{{range $k, $v := .Config.Labels}}{{if or (eq $k "io.github.cli.codex.version") (eq $k "io.github.cli.copilot.version") (eq $k "io.github.cli.gemini.version")}}  {{$k}}: {{$v}}{{println}}{{end}}{{end}}' 2>/dev/null || echo "  (labels not available)"
