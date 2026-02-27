#!/bin/bash
#
# setup-llm-local.sh — Configure Simon Willison's `llm` CLI to use your local llama-server.
# Run: ./setup-llm-local.sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { printf "  ${GREEN}✔${RESET} %s\n" "$1"; }
warn() { printf "  ${YELLOW}⚠${RESET} %s\n" "$1"; }
fail() { printf "  ${RED}✘${RESET} %s\n" "$1"; }
info() { printf "  ${BLUE}ℹ${RESET} %s\n" "$1"; }

PORT="${1:-8080}"
MODEL_ID="${2:-qwen-local}"
MODEL_NAME="${3:-qwen3-coder-next}"
LLM_DIR="$HOME/Library/Application Support/io.datasette.llm"
YAML_FILE="$LLM_DIR/extra-openai-models.yaml"

printf "\n${BOLD}Setting up llm CLI for local llama-server${RESET}\n\n"

# Check llm is installed
if ! command -v llm &>/dev/null; then
  fail "llm CLI not found. Install with: brew install llm"
  exit 1
fi
pass "llm CLI found"

# Check if llama-server is reachable
if curl -s "http://localhost:$PORT/v1/models" &>/dev/null; then
  pass "llama-server responding on port $PORT"
  # Try to detect the model name from the running server
  detected=$(curl -s "http://localhost:$PORT/v1/models" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [[ -n "$detected" ]]; then
    MODEL_NAME="$detected"
    info "Detected model: $MODEL_NAME"
  fi
else
  warn "llama-server not responding on port $PORT (config will still be written)"
fi

# Create directory if needed
mkdir -p "$LLM_DIR"

# Check for existing config
ENTRY="- model_id: $MODEL_ID
  model_name: $MODEL_NAME
  api_base: \"http://localhost:$PORT/v1\""

if [[ -f "$YAML_FILE" ]]; then
  if grep -q "model_id: $MODEL_ID" "$YAML_FILE"; then
    warn "Model '$MODEL_ID' already exists in $YAML_FILE"
    info "Current contents:"
    sed 's/^/    /' "$YAML_FILE"
    printf "\n"
    read -rp "  Overwrite the '$MODEL_ID' entry? [y/N] " answer
    if [[ "${answer,,}" != "y" ]]; then
      info "No changes made."
      exit 0
    fi
    # Remove existing entry (from model_id line to next entry or EOF)
    tmp=$(mktemp)
    awk -v id="$MODEL_ID" '
      /^- model_id:/ { if (index($0, id)) { skip=1; next } else { skip=0 } }
      skip && /^- / { skip=0 }
      !skip { print }
    ' "$YAML_FILE" > "$tmp"
    mv "$tmp" "$YAML_FILE"
  fi
  # Append entry
  printf "%s\n" "$ENTRY" >> "$YAML_FILE"
  pass "Updated $YAML_FILE"
else
  printf "%s\n" "$ENTRY" > "$YAML_FILE"
  pass "Created $YAML_FILE"
fi

printf "\n${BOLD}Config written:${RESET}\n"
sed 's/^/    /' "$YAML_FILE"

printf "\n${BOLD}Usage:${RESET}\n"
info "llm -m $MODEL_ID \"your prompt here\""
info "cat file.py | llm -m $MODEL_ID -s \"review this code\""
info "git diff | llm -m $MODEL_ID -s \"write commit message\""
printf "\n"
