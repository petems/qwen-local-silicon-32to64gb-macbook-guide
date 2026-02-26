#!/bin/bash
#
# check-compatibility.sh — Quick check if your Mac is ready for local Qwen models.
# Run: ./check-compatibility.sh

set -euo pipefail

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

pass()  { printf "  ${GREEN}✔${RESET} %s\n" "$1"; }
warn()  { printf "  ${YELLOW}⚠${RESET} %s\n" "$1"; }
fail()  { printf "  ${RED}✘${RESET} %s\n" "$1"; }
info()  { printf "  ${BLUE}ℹ${RESET} %s\n" "$1"; }
header(){ printf "\n${BOLD}%s${RESET}\n" "$1"; }

errors=0
warnings=0

# ── OS ──────────────────────────────────────────────────────────────
header "Operating System"

if [[ "$(uname)" == "Darwin" ]]; then
  macos_version=$(sw_vers -productVersion)
  pass "macOS $macos_version"
else
  fail "Not macOS ($(uname)). This guide is for Apple Silicon Macs."
  exit 1
fi

# ── Chip ────────────────────────────────────────────────────────────
header "Processor"

arch=$(uname -m)
if [[ "$arch" == "arm64" ]]; then
  chip=$(sysctl -n machdep.cpu.brand_string)
  pass "Apple Silicon — $chip"
else
  fail "Architecture is $arch, not arm64. This guide requires Apple Silicon."
  exit 1
fi

# ── RAM ─────────────────────────────────────────────────────────────
header "Unified Memory"

ram_bytes=$(sysctl -n hw.memsize)
ram_gb=$((ram_bytes / 1073741824))

if [[ $ram_gb -ge 64 ]]; then
  pass "${ram_gb}GB — 64GB configuration"
  info "Recommended: Qwen3-Coder-Next at Q4_K_M with 64K context"
  info "Also great:  Qwen2.5-Coder-32B via Ollama for quick tasks"
  ram_tier="64gb"
elif [[ $ram_gb -ge 32 ]]; then
  pass "${ram_gb}GB — 32GB configuration"
  info "Recommended: Qwen2.5-Coder-32B via Ollama (best quality at this RAM)"
  info "Alternative: Qwen3-Coder-Next at Q2_K (fits but lower quality)"
  ram_tier="32gb"
elif [[ $ram_gb -ge 16 ]]; then
  warn "${ram_gb}GB — below minimum for full models"
  info "Consider smaller models: Qwen2.5-Coder-14B (~12GB) or 7B (~8GB)"
  ram_tier="low"
  ((warnings++))
else
  fail "${ram_gb}GB — insufficient for the models in this guide"
  ram_tier="low"
  ((errors++))
fi

# ── Disk Space ──────────────────────────────────────────────────────
header "Disk Space"

free_gb=$(df -g / | awk 'NR==2 {print $4}')

if [[ $free_gb -ge 50 ]]; then
  pass "${free_gb}GB free — plenty of room"
elif [[ $free_gb -ge 30 ]]; then
  warn "${free_gb}GB free — enough for Q2_K/Q4_K_M, tight for larger quants"
  ((warnings++))
else
  fail "${free_gb}GB free — need at least 30GB for model downloads"
  ((errors++))
fi

# ── Tools ───────────────────────────────────────────────────────────
header "Tools"

# Homebrew
if command -v brew &>/dev/null; then
  pass "Homebrew installed ($(brew --version | head -1))"
else
  fail "Homebrew not found — install from https://brew.sh"
  ((errors++))
fi

# Ollama
if command -v ollama &>/dev/null; then
  pass "Ollama installed"
  if pgrep -x ollama &>/dev/null; then
    pass "Ollama is running"
    models=$(ollama list 2>/dev/null | tail -n +2)
    if [[ -n "$models" ]]; then
      info "Installed models:"
      while IFS= read -r line; do
        info "  $line"
      done <<< "$models"
    fi
  else
    warn "Ollama installed but not running (start with: ollama serve)"
    ((warnings++))
  fi
else
  info "Ollama not installed (install with: brew install ollama)"
fi

# llama-server
if command -v llama-server &>/dev/null; then
  pass "llama-server installed"
else
  info "llama-server not installed (install with: brew install llama.cpp)"
fi

# Node.js
if command -v node &>/dev/null; then
  node_version=$(node --version | sed 's/v//')
  node_major=$(echo "$node_version" | cut -d. -f1)
  if [[ $node_major -ge 18 ]]; then
    pass "Node.js $node_version"
  else
    warn "Node.js $node_version — need 18+ for OpenCode / Pi"
    ((warnings++))
  fi
else
  info "Node.js not installed (needed for OpenCode / Pi)"
fi

# Python
if command -v python3 &>/dev/null; then
  py_version=$(python3 --version | awk '{print $2}')
  py_minor=$(echo "$py_version" | cut -d. -f2)
  if [[ $py_minor -ge 10 ]]; then
    pass "Python $py_version"
  else
    warn "Python $py_version — need 3.10+ for Aider / llm CLI"
    ((warnings++))
  fi
else
  info "Python 3 not installed (needed for Aider / llm CLI)"
fi

# pipx
if command -v pipx &>/dev/null; then
  pass "pipx installed (recommended for Aider)"
else
  info "pipx not installed (recommended: brew install pipx)"
fi

# Coding agents
header "Coding Agents"

found_agent=false
if command -v aider &>/dev/null; then
  pass "Aider installed"; found_agent=true
fi
if command -v opencode &>/dev/null; then
  pass "OpenCode installed"; found_agent=true
fi
if command -v pi &>/dev/null; then
  pass "Pi installed"; found_agent=true
fi
if command -v llm &>/dev/null; then
  pass "llm CLI installed"; found_agent=true
fi
if [[ "$found_agent" == false ]]; then
  info "No coding agents installed yet — see Section 5 of README.md"
fi

# ── Summary ─────────────────────────────────────────────────────────
header "Summary"

if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
  printf "  ${GREEN}${BOLD}All clear!${RESET} "
  if [[ "$ram_tier" == "64gb" ]]; then
    echo "Your Mac is well-suited for the 64GB setup."
  else
    echo "Your Mac is ready for the 32GB setup."
  fi
elif [[ $errors -eq 0 ]]; then
  printf "  ${YELLOW}${BOLD}Mostly ready${RESET} — %d warning(s) above.\n" "$warnings"
else
  printf "  ${RED}${BOLD}Not ready${RESET} — %d error(s) and %d warning(s) above.\n" "$errors" "$warnings"
fi

echo ""
