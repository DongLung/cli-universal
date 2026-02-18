#!/usr/bin/env bash
#
# Interactive Menu
# Description: Presents interactive menu for selecting and launching CLI tools (codex, copilot, gemini, bash)
# Usage: Called by entrypoint.sh or run directly; use CLI_TOOL env var to skip menu
# Environment: CLI_TOOL, DEFAULT_SELECTION (default: 3), MENU_TIMEOUT (default: 10)
#

set -euo pipefail

# Default CLI tool when none is selected via menu timeout
DEFAULT_SELECTION="${DEFAULT_SELECTION:-3}"
MENU_TIMEOUT="${MENU_TIMEOUT:-10}"
CLI_TOOL="${CLI_TOOL:-}"  # Options: codex, copilot, gemini, bash; empty shows menu

configure_npm() {
  npm config --global set prefix /opt/npm-global
  npm config --global set cache  /opt/npm-cache
  export PATH="/opt/npm-global/bin:$PATH"
}

launch_cli() {
  local tool="${1:-}"
  if [ -z "${tool}" ]; then
    echo "Error: No CLI tool specified"; exit 1
  fi
  
  case "${tool}" in
    codex)
      if command -v codex >/dev/null 2>&1; then
        exec codex
      else
        echo "Error: codex not installed. Run option 1 to install."; exit 1
      fi
      ;;
    copilot)
      if command -v copilot >/dev/null 2>&1; then
        exec copilot
      else
        echo "Error: copilot not installed. Run option 1 to install."; exit 1
      fi
      ;;
    gemini)
      if command -v gemini >/dev/null 2>&1; then
        exec gemini
      else
        echo "Error: gemini not installed. Run option 1 to install."; exit 1
      fi
      ;;
    bash)
      echo "Entering Bash shell..."; exec bash
      ;;
    *)
      echo "Unknown CLI_TOOL: ${tool}"; echo "Valid options: codex, copilot, gemini, bash"; exit 1
      ;;
  esac
}

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

    echo -n "Select option (default: ${DEFAULT_SELECTION} in ${MENU_TIMEOUT}s): "
    if read -t "${MENU_TIMEOUT}" -r choice && [ -n "${choice:-}" ]; then
      echo ""
    else
      echo ""
      echo "[timeout] No selection made, starting Copilot CLI..."
      choice="${DEFAULT_SELECTION}"
    fi

    case "${choice}" in
      1)
        echo "[update] Updating codex / copilot / gemini ..."
        npm i -g --no-fund --loglevel=error \
          @openai/codex@latest \
          @github/copilot@latest \
          @google/gemini-cli@latest 2>&1 | grep -v "warn deprecated" || echo "[update] Update completed"
        echo "[update] Update finished!"
        continue
        ;;
      2)
        echo "[cli] Launching Codex..."; launch_cli codex
        ;;
      3)
        echo "[cli] Launching Copilot CLI..."; launch_cli copilot
        ;;
      4)
        echo "[cli] Launching Gemini CLI..."; launch_cli gemini
        ;;
      5)
        echo "[cli] Entering Bash shell..."; launch_cli bash
        ;;
      *)
        echo "Invalid option. Please select 1-5."; sleep 2; continue
        ;;
    esac
    break
  done
}

main() {
  configure_npm

  echo ""
  echo "[cli] Available CLI tools: codex, copilot, gemini, bash"
  if [ -n "${CLI_TOOL}" ]; then
    echo "[cli] Starting with: ${CLI_TOOL}"
    echo ""
    echo "[versions]"
    python --version 2>/dev/null || echo "Python: not configured"
    node --version   2>/dev/null || echo "Node.js: not configured"
    echo ""
    codex --version 2>/dev/null   || echo "codex: not installed"
    copilot --version 2>/dev/null || echo "copilot: not installed"
    gemini --version 2>/dev/null  || echo "gemini: not installed"
    echo ""
    launch_cli "${CLI_TOOL}"
  else
    echo "[cli] No CLI_TOOL specified; showing menu"
    show_menu
  fi
}

main "$@"
