#!/bin/bash
#
# start-llama-server.sh — Start llama-server with the right config for your Mac's RAM.
# Run: ./start-llama-server.sh
#
# Override defaults with environment variables:
#   PORT=9090 ./start-llama-server.sh
#   GPU_LAYERS=50 ./start-llama-server.sh
#   CTX_SIZE=16384 ./start-llama-server.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { printf "  ${GREEN}✔${RESET} %s\n" "$1"; }
warn() { printf "  ${YELLOW}⚠${RESET} %s\n" "$1"; }
fail() { printf "  ${RED}✘${RESET} %s\n" "$1"; }
info() { printf "  ${BLUE}ℹ${RESET} %s\n" "$1"; }

PORT="${PORT:-8080}"

printf "\n${BOLD}Detecting system configuration...${RESET}\n\n"

# Check we're on macOS Apple Silicon
if [[ "$(uname)" != "Darwin" ]]; then
  fail "Not macOS. This script is for Apple Silicon Macs."
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  fail "Not Apple Silicon ($(uname -m)). This script requires arm64."
  exit 1
fi

chip=$(sysctl -n machdep.cpu.brand_string)
pass "Apple Silicon — $chip"

# Check llama-server is installed
if ! command -v llama-server &>/dev/null; then
  fail "llama-server not found. Install with: brew install llama.cpp"
  exit 1
fi
pass "llama-server installed"

# Check port is free
if lsof -i ":$PORT" &>/dev/null; then
  fail "Port $PORT is already in use"
  info "Check what's using it: lsof -i :$PORT"
  info "Override with: PORT=9090 ./start-llama-server.sh"
  exit 1
fi
pass "Port $PORT is free"

# Detect RAM and pick configuration
ram_bytes=$(sysctl -n hw.memsize)
ram_gb=$((ram_bytes / 1073741824))

if [[ $ram_gb -ge 64 ]]; then
  pass "${ram_gb}GB RAM — using 64GB configuration"
  MODEL="unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M"
  QUANT="Q4_K_M"
  MODEL_SIZE="~38GB"
  CTX_SIZE="${CTX_SIZE:-65536}"
  GPU_LAYERS="${GPU_LAYERS:-99}"
elif [[ $ram_gb -ge 32 ]]; then
  pass "${ram_gb}GB RAM — using 32GB configuration"
  MODEL="unsloth/Qwen3-Coder-Next-GGUF:Q2_K"
  QUANT="Q2_K"
  MODEL_SIZE="~26GB"
  CTX_SIZE="${CTX_SIZE:-32768}"
  GPU_LAYERS="${GPU_LAYERS:-40}"
else
  fail "${ram_gb}GB RAM — not enough for Qwen3-Coder-Next"
  info "Minimum 32GB unified memory required."
  info "Consider smaller models via Ollama instead (see README.md Section 7)."
  exit 1
fi

printf "\n${BOLD}Configuration:${RESET}\n"
info "Model:      $MODEL"
info "Quant:      $QUANT ($MODEL_SIZE)"
info "Context:    $CTX_SIZE tokens"
info "GPU layers: $GPU_LAYERS"
info "Port:       $PORT"

# Check disk space for model download
free_gb=$(df -g / | awk 'NR==2 {print $4}')
if [[ $free_gb -lt 30 ]]; then
  warn "Only ${free_gb}GB free disk space — model download may fail"
fi

printf "\n${BOLD}Starting llama-server...${RESET}\n"
info "API will be available at http://localhost:$PORT/v1"
info "Press Ctrl+C to stop\n"

exec llama-server \
  -hf "$MODEL" \
  --ctx-size "$CTX_SIZE" \
  --n-gpu-layers "$GPU_LAYERS" \
  --no-mmap \
  --flash-attn on \
  --temp 1.0 \
  --top-p 0.95 \
  --top-k 40 \
  --min-p 0.01 \
  --jinja \
  --port "$PORT"
