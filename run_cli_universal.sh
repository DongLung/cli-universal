#!/usr/bin/env bash
set -euo pipefail

########################################
# Image
########################################
IMAGE_BASE="${IMAGE_BASE:-cli-universal:python}"
CODEX_ENV_PYTHON_VERSION="${CODEX_ENV_PYTHON_VERSION:-3.12}"
IMAGE="${IMAGE:-${IMAGE_BASE}${CODEX_ENV_PYTHON_VERSION}}"

########################################
# Workspace
########################################
HOST_DIR="${HOST_DIR:-$(pwd)}"
WORK_NAME="$(basename "$HOST_DIR")"
WORKDIR="/workspace/${WORK_NAME}"

########################################
# Language versions (override via env)
########################################
BACKUP_TAG=""

########################################
# Update behavior
########################################
UPDATE_ON_START="${UPDATE_ON_START:-1}"

########################################
# CLI Tool Selection
########################################
CLI_TOOL="${CLI_TOOL:-}"  # Options: codex, copilot, gemini, bash, or empty for menu

########################################
# API Keys (export on host)
########################################
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"

########################################
# Host directories (mounted into container)
########################################
VOL_NPM_GLOBAL="${VOL_NPM_GLOBAL:-$HOME/.npm-global}"
VOL_NPM_CACHE="${VOL_NPM_CACHE:-$HOME/.npm-cache}"
VOL_CODEX_HOME="${VOL_CODEX_HOME:-$HOME/.codex}"
VOL_COPILOT_HOME="${VOL_COPILOT_HOME:-$HOME/.copilot}"
VOL_GEMINI_HOME="${VOL_GEMINI_HOME:-$HOME/.gemini}"

########################################
# Preflight
########################################
command -v podman >/dev/null 2>&1 || { echo "ERROR: podman 不存在"; exit 1; }
[ -d "$HOST_DIR" ] || { echo "ERROR: HOST_DIR 不存在：$HOST_DIR"; exit 1; }

# Ensure host directories exist
mkdir -p "$VOL_NPM_GLOBAL" "$VOL_NPM_CACHE" "$VOL_CODEX_HOME" "$VOL_COPILOT_HOME" "$VOL_GEMINI_HOME"

########################################
# Image tag rotation (optional backup)
########################################
if podman image exists "$IMAGE" >/dev/null 2>&1; then
  created="$(podman image inspect --format '{{.Created}}' "$IMAGE" 2>/dev/null | head -n1 || true)"
  created_date="$(date -d "${created:-now}" +%Y%m%d 2>/dev/null || date +%Y%m%d)"
  BACKUP_TAG="${IMAGE}-${created_date}"
  if ! podman image exists "$BACKUP_TAG" >/dev/null 2>&1; then
    podman tag "$IMAGE" "$BACKUP_TAG"
    echo "[image] existing image tagged as backup: $BACKUP_TAG"
  else
    echo "[image] backup tag already present: $BACKUP_TAG"
  fi
fi

########################################
# Post-setup hook (runs after entrypoint)
########################################
POST_SETUP_CMD='exec /opt/menu.sh'

########################################
# Run
########################################
echo "[run] IMAGE=$IMAGE"
echo "[run] Workspace=$WORKDIR"
echo "[run] Language versions:"
echo "  Python=$CODEX_ENV_PYTHON_VERSION"
if [ -n "$BACKUP_TAG" ]; then
  echo "[run] Existing image preserved as: $BACKUP_TAG"
fi
echo ""
echo "[cli] Available CLI tools:"
echo "  - Codex   : CLI_TOOL=codex ./run_cli_universal.sh"
echo "  - Copilot : CLI_TOOL=copilot ./run_cli_universal.sh"
echo "  - Gemini  : CLI_TOOL=gemini ./run_cli_universal.sh"
echo "  - Bash    : CLI_TOOL=bash ./run_cli_universal.sh"
echo "  - Menu    : ./run_cli_universal.sh (default)"
echo ""
if [ -n "$CLI_TOOL" ]; then
  echo "[cli] Starting with: $CLI_TOOL"
else
  echo "[cli] Starting with: interactive menu"
fi
echo ""

podman run --rm -it \
  -e CODEX_ENV_PYTHON_VERSION="$CODEX_ENV_PYTHON_VERSION" \
  -e CLI_TOOL="$CLI_TOOL" \
  ${OPENAI_API_KEY:+-e "OPENAI_API_KEY=$OPENAI_API_KEY"} \
  ${GITHUB_TOKEN:+-e "GITHUB_TOKEN=$GITHUB_TOKEN"} \
  ${GEMINI_API_KEY:+-e "GEMINI_API_KEY=$GEMINI_API_KEY"} \
  -p 1455:1455 \
  -v /etc/localtime:/etc/localtime:ro \
  -v "${VOL_NPM_GLOBAL}:/opt/npm-global" \
  -v "${VOL_NPM_CACHE}:/opt/npm-cache" \
  -v "${VOL_CODEX_HOME}:/home/cliuser/.codex" \
  -v "${VOL_COPILOT_HOME}:/home/cliuser/.copilot" \
  -v "${VOL_GEMINI_HOME}:/home/cliuser/.gemini" \
  -v "${HOST_DIR}:${WORKDIR}" \
  -w "${WORKDIR}" \
  "$IMAGE" \
  -c "$POST_SETUP_CMD"
