#!/bin/bash
#
# setup-pi-local.sh — Configure Pi coding agent for local models.
# Detects your RAM and sets up ~/.pi/agent/models.json with the right models.
# Run: ./setup-pi-local.sh
#
# Override defaults with environment variables:
#   LLAMA_PORT=9090 ./setup-pi-local.sh
#   OLLAMA_PORT=11434 ./setup-pi-local.sh

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

LLAMA_PORT="${LLAMA_PORT:-8080}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
PI_DIR="$HOME/.pi/agent"
MODELS_FILE="$PI_DIR/models.json"

printf "\n${BOLD}Setting up Pi for local models${RESET}\n\n"

# Check Pi is installed
if ! command -v pi &>/dev/null; then
  fail "Pi not found. Install with: brew install pi-coding-agent"
  exit 1
fi
pass "Pi $(pi --version 2>/dev/null) found"

# Detect RAM
ram_bytes=$(sysctl -n hw.memsize)
ram_gb=$((ram_bytes / 1073741824))
pass "${ram_gb}GB unified memory detected"

# Build providers based on what's available
providers=""
usage_lines=""

# Check llama-server
if curl -s "http://localhost:$LLAMA_PORT/v1/models" &>/dev/null; then
  detected=$(curl -s "http://localhost:$LLAMA_PORT/v1/models" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  detected="${detected:-}"
  pass "llama-server responding on port $LLAMA_PORT${detected:+ — model: $detected}"
  # Use a clean model ID for Pi (no slashes/colons) and set the display name to the full ID
  llama_model="qwen3-coder-next"
  llama_display="${detected:-$llama_model}"

  if [[ $ram_gb -ge 64 ]]; then
    ctx=65536
  else
    ctx=32768
  fi

  providers="${providers:+$providers,
    }\"llama-server\": {
      \"baseUrl\": \"http://localhost:$LLAMA_PORT/v1\",
      \"api\": \"openai-completions\",
      \"apiKey\": \"local\",
      \"models\": [
        {
          \"id\": \"$llama_model\",
          \"contextWindow\": $ctx,
          \"maxTokens\": 32000
        }
      ]
    }"
  usage_lines="${usage_lines}pi --model llama-server/$llama_model\n"
else
  info "llama-server not responding on port $LLAMA_PORT (skipping)"
fi

# Check Ollama
if curl -s "http://localhost:$OLLAMA_PORT/v1/models" &>/dev/null; then
  pass "Ollama responding on port $OLLAMA_PORT"

  # Discover installed Ollama models
  ollama_models=""
  if command -v ollama &>/dev/null; then
    while IFS= read -r model_name; do
      [[ -z "$model_name" ]] && continue
      ollama_models="${ollama_models:+$ollama_models,
        }{ \"id\": \"$model_name\" }"
      usage_lines="${usage_lines}pi --model ollama/$model_name\n"
    done < <(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
  fi

  if [[ -z "$ollama_models" ]]; then
    # Fallback if ollama CLI not available
    ollama_models="{ \"id\": \"qwen3:latest\" }"
    usage_lines="${usage_lines}pi --model ollama/qwen3:latest\n"
  fi

  info "Found Ollama models: $(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ' ')"

  providers="${providers:+$providers,
    }\"ollama\": {
      \"baseUrl\": \"http://localhost:$OLLAMA_PORT/v1\",
      \"api\": \"openai-completions\",
      \"apiKey\": \"ollama\",
      \"models\": [
        $ollama_models
      ]
    }"
else
  info "Ollama not responding on port $OLLAMA_PORT (skipping)"
fi

# Bail if nothing found
if [[ -z "$providers" ]]; then
  fail "No local model servers found. Start llama-server or Ollama first."
  info "llama-server: ./start-llama-server.sh"
  info "Ollama: ollama serve"
  exit 1
fi

# Create directory
mkdir -p "$PI_DIR"

# Check for existing config
if [[ -f "$MODELS_FILE" ]]; then
  warn "Existing $MODELS_FILE found:"
  sed 's/^/    /' "$MODELS_FILE"
  printf "\n"
  read -rp "  Overwrite? [y/N] " answer
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    info "No changes made."
    exit 0
  fi
fi

# Write config
cat > "$MODELS_FILE" << EOF
{
  "providers": {
    $providers
  }
}
EOF

pass "Written $MODELS_FILE"

printf "\n${BOLD}Config written:${RESET}\n"
sed 's/^/    /' "$MODELS_FILE"

printf "\n${BOLD}Verify:${RESET}\n"
info "pi --list-models"

printf "\n${BOLD}Usage:${RESET}\n"
printf "$usage_lines" | while IFS= read -r line; do
  info "$line"
done
printf "\n"
