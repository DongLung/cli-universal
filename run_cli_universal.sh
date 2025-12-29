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
POST_SETUP_CMD='
  set -e

  # npm global settings (to avoid NPM_CONFIG_PREFIX conflicts)
  npm config --global set prefix /opt/npm-global
  npm config --global set cache  /opt/npm-cache
  export PATH="/opt/npm-global/bin:$PATH"

  # Function to show menu and handle selection
  show_menu() {
    while true; do
      echo ""
      echo "========================================"
      echo "CLI Universal - Tool Selection"
      echo "========================================"
      echo "1. Update codex, copilot, gemini CLI"
      echo "2. Use Codex"
      echo "3. Use Copilot CLI"
      echo "4. Use Gemini CLI"
      echo "5. Container Bash"
      echo "========================================"
      echo ""
      
      # Read with timeout (10 seconds)
      echo -n "Select option (default: 3 in 10s): "
      if read -t 10 choice; then
        echo ""
      else
        echo ""
        echo "[timeout] No selection made, starting Copilot CLI..."
        choice=3
      fi
      
      case "$choice" in
        1)
          echo "[update] Updating codex / copilot / gemini ..."
          npm i -g --no-fund --loglevel=error \
            @openai/codex@latest \
            @github/copilot@latest \
            @google/gemini-cli@latest 2>&1 | grep -v "warn deprecated" || echo "[update] Update completed"
          echo "[update] Update finished!"
          # Return to menu
          continue
          ;;
        2)
          echo "[cli] Launching Codex..."
          if command -v codex >/dev/null 2>&1; then
            exec codex
          else
            echo "Error: codex not installed. Select option 1 to install."
            sleep 3
            continue
          fi
          ;;
        3)
          echo "[cli] Launching Copilot CLI..."
          if command -v copilot >/dev/null 2>&1; then
            exec copilot
          else
            echo "Error: copilot not installed. Select option 1 to install."
            sleep 3
            continue
          fi
          ;;
        4)
          echo "[cli] Launching Gemini CLI..."
          if command -v gemini >/dev/null 2>&1; then
            exec gemini
          else
            echo "Error: gemini not installed. Select option 1 to install."
            sleep 3
            continue
          fi
          ;;
        5)
          echo "[cli] Entering Bash shell..."
          exec bash
          ;;
        *)
          echo "Invalid option. Please select 1-5."
          sleep 2
          continue
          ;;
      esac
    done
  }

  # Check if CLI_TOOL is specified
  CLI_TOOL="'"$CLI_TOOL"'"
  
  if [ -z "$CLI_TOOL" ]; then
    # No CLI_TOOL specified, show menu
    show_menu
  else
    # CLI_TOOL specified, launch directly
    echo ""
    echo "[versions]"
    python --version 2>/dev/null || echo "Python: not configured"
    node --version   2>/dev/null || echo "Node.js: not configured"
    echo ""

    codex --version 2>/dev/null   || echo "codex: installed"
    copilot --version 2>/dev/null || echo "copilot: installed"
    gemini --version 2>/dev/null  || echo "gemini: installed"
    echo ""
    
    echo "========================================"
    echo "Launching $CLI_TOOL CLI..."
    echo "========================================"
    case "$CLI_TOOL" in
      codex)
        if command -v codex >/dev/null 2>&1; then
          exec codex
        else
          echo "Error: codex not installed."
          exit 1
        fi
        ;;
      copilot)
        if command -v copilot >/dev/null 2>&1; then
          exec copilot
        else
          echo "Error: copilot not installed."
          exit 1
        fi
        ;;
      gemini)
        if command -v gemini >/dev/null 2>&1; then
          exec gemini
        else
          echo "Error: gemini not installed."
          exit 1
        fi
        ;;
      bash)
        echo "Entering Bash shell..."
        exec bash
        ;;
      *)
        echo "Unknown CLI_TOOL: $CLI_TOOL"
        echo "Valid options: codex, copilot, gemini, bash"
        exit 1
        ;;
    esac
  fi
'

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
  ${OPENAI_API_KEY:+-e "OPENAI_API_KEY=$OPENAI_API_KEY"} \
  ${GITHUB_TOKEN:+-e "GITHUB_TOKEN=$GITHUB_TOKEN"} \
  ${GEMINI_API_KEY:+-e "GEMINI_API_KEY=$GEMINI_API_KEY"} \
  -p 1455:1455 \
  -v /etc/localtime:/etc/localtime:ro \
  -v "${VOL_NPM_GLOBAL}:/opt/npm-global" \
  -v "${VOL_NPM_CACHE}:/opt/npm-cache" \
  -v "${VOL_CODEX_HOME}:/root/.codex" \
  -v "${VOL_COPILOT_HOME}:/root/.copilot" \
  -v "${VOL_GEMINI_HOME}:/root/.gemini" \
  -v "${HOST_DIR}:${WORKDIR}" \
  -w "${WORKDIR}" \
  "$IMAGE" \
  -c "$POST_SETUP_CMD"
