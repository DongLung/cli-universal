#!/usr/bin/env bash
set -euo pipefail

########################################
# Image
########################################
IMAGE_BASE="${IMAGE_BASE:-cli-universal:python}"
CODEX_ENV_PYTHON_VERSION="${CODEX_ENV_PYTHON_VERSION:-3.12}"
CODEX_ENV_NODE_VERSION="${CODEX_ENV_NODE_VERSION:-22}"
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
# API Keys (export on host)
########################################
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"

########################################
# Volumes
########################################
VOL_NPM_GLOBAL="${VOL_NPM_GLOBAL:-npm-global}"
VOL_NPM_CACHE="${VOL_NPM_CACHE:-npm-cache}"
VOL_CODEX_HOME="${VOL_CODEX_HOME:-ai-codex-home}"
VOL_COPILOT_HOME="${VOL_COPILOT_HOME:-ai-copilot-home}"
VOL_GEMINI_HOME="${VOL_GEMINI_HOME:-ai-gemini-home}"

########################################
# Preflight
########################################
command -v podman >/dev/null 2>&1 || { echo "ERROR: podman 不存在"; exit 1; }
[ -d "$HOST_DIR" ] || { echo "ERROR: HOST_DIR 不存在：$HOST_DIR"; exit 1; }

ensure_volume() {
  podman volume exists "$1" >/dev/null 2>&1 || podman volume create "$1" >/dev/null
}

ensure_volume "$VOL_NPM_GLOBAL"
ensure_volume "$VOL_NPM_CACHE"
ensure_volume "$VOL_CODEX_HOME"
ensure_volume "$VOL_COPILOT_HOME"
ensure_volume "$VOL_GEMINI_HOME"

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
POST_SETUP_CMD='
  set -e

  # npm global 設定（避免 NPM_CONFIG_PREFIX 與 nvm 衝突）
  npm config --global set prefix /opt/npm-global
  npm config --global set cache  /opt/npm-cache
  export PATH="/opt/npm-global/bin:$PATH"

  if [ "'"$UPDATE_ON_START"'" = "1" ]; then
    echo "[update] updating codex / copilot / gemini ..."
    npm i -g \
      @openai/codex@latest \
      @github/copilot@latest \
      @google/gemini-cli@latest
  fi

  echo "[versions]"
  python --version 2>/dev/null || true
  node --version   2>/dev/null || true

  codex --version   || true
  copilot --version || true
  gemini --version  || true

  exec /usr/bin/bash
'

########################################
# Run
########################################
echo "[run] IMAGE=$IMAGE"
echo "[run] Workspace=$WORKDIR"
echo "[run] Language versions:"
echo "  Python=$CODEX_ENV_PYTHON_VERSION"
echo "  Node=$CODEX_ENV_NODE_VERSION"
if [ -n "$BACKUP_TAG" ]; then
  echo "[run] Existing image preserved as: $BACKUP_TAG"
fi

podman run --rm -it \
  -e CODEX_ENV_PYTHON_VERSION="$CODEX_ENV_PYTHON_VERSION" \
  -e CODEX_ENV_NODE_VERSION="$CODEX_ENV_NODE_VERSION" \
  ${OPENAI_API_KEY:+-e "OPENAI_API_KEY=$OPENAI_API_KEY"} \
  ${GITHUB_TOKEN:+-e "GITHUB_TOKEN=$GITHUB_TOKEN"} \
  ${GEMINI_API_KEY:+-e "GEMINI_API_KEY=$GEMINI_API_KEY"} \
  -v /etc/localtime:/etc/localtime:ro \
  -v /etc/timezone:/etc/timezone:ro \
  -v "${VOL_NPM_GLOBAL}:/opt/npm-global" \
  -v "${VOL_NPM_CACHE}:/opt/npm-cache" \
  -v "${VOL_CODEX_HOME}:/root/.codex" \
  -v "${VOL_COPILOT_HOME}:/root/.copilot" \
  -v "${VOL_GEMINI_HOME}:/root/.gemini" \
  -v "${HOST_DIR}:${WORKDIR}" \
  -w "${WORKDIR}" \
  "$IMAGE" \
  bash -lc "$POST_SETUP_CMD"
