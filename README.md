# qwen-coder-locally-on-32to64gb-macbook-silicon

A no-nonsense guide to running Qwen3-Coder-Next locally on Apple Silicon MacBooks with your choice of coding agent or CLI tool. Covers both **32GB** and **64GB** configurations.

> **What is this model?** An 80B parameter MoE model that only activates 3B params per inference. It scores near Claude Sonnet 4.5 on coding benchmarks while running on consumer hardware. Open weights, fully offline, your code never leaves your machine.

---

## 0. Check Your Mac

Not sure if your machine is compatible? Run the compatibility checker — it detects your chip, RAM, disk space, and installed tools, then tells you which configuration to use:

```bash
./check-compatibility.sh
```

---

## 1. Prerequisites

- macOS with Apple Silicon (M1/M2/M3/M4), 32GB or 64GB unified memory
- [Homebrew](https://brew.sh) installed
- ~30–50GB free disk space (depending on quantization choice)
- Node.js 18+ (for OpenCode / Pi) or Python 3.10+ (for Aider / LLM CLI)

---

## 2. Choose Your Backend

You have two main options for serving the model locally. If you already have Ollama installed, start there — it's the simplest path.

### Option 1: Ollama (simplest — recommended starting point)

Ollama handles downloading, quantization selection, and serving in one tool. If you already have it installed, you can skip straight to pulling a model.

```bash
# Install Ollama (skip if already installed)
brew install ollama

# Check if Ollama is already running
pgrep ollama && echo "Already running" || ollama serve &

# Pull the recommended model
ollama pull qwen2.5-coder:32b

# Verify it works
curl http://localhost:11434/v1/models
```

Ollama serves an OpenAI-compatible API on port 11434 automatically.

**Useful Ollama commands:**

```bash
ollama list              # See installed models and sizes
ollama rm <model-name>   # Remove a model to free disk space
ollama ps                # Show currently loaded models
```

### Option 2: llama-server (more control)

Use llama-server when you want to choose a specific quantization (Q4_K_M vs Q5_K_M vs Q6_K) or tune server parameters. Ollama picks a default quant — llama-server lets you control exactly which one.

```bash
brew install llama.cpp
```

That's it. Homebrew gives you Metal (GPU) acceleration out of the box.

---

## 3. Download the Model (llama-server path)

> **Skip this section if you're using Ollama** — `ollama pull` handles downloading automatically.

The right quantization depends on your RAM. All GGUF files are from [unsloth/Qwen3-Coder-Next-GGUF](https://huggingface.co/unsloth/Qwen3-Coder-Next-GGUF).

### 64GB Macs — use Q4_K_M or higher

With 64GB unified memory you have plenty of headroom. **Q4_K_M is the sweet spot** — dramatically better quality than Q2_K with room for large context windows.

| Quantization | Model size | RAM needed (with context) | Quality | Fits 64GB? |
|---|---|---|---|---|
| **Q4_K_M** | ~38GB | ~45GB with 64K ctx | Good — recommended | Yes, comfortably |
| **Q5_K_M** | ~45GB | ~52GB with 64K ctx | Very good | Yes |
| **Q6_K** | ~52GB | ~58GB with 32K ctx | Near-original | Tight — close browsers |
| Q2_K | ~26GB | ~32GB with 32K ctx | Fair | Yes, but unnecessarily low quality |

```bash
# Recommended for 64GB — Q4_K_M
llama-cli -hf unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M

# Higher quality option
llama-cli -hf unsloth/Qwen3-Coder-Next-GGUF:Q5_K_M
```

### 32GB Macs — use Q2_K

On 32GB you need the **Q2_K** quantization (~26GB). This is the only quant that fits comfortably and leaves room for context.

```bash
llama-cli -hf unsloth/Qwen3-Coder-Next-GGUF:Q2_K
```

> **Why Q2_K on 32GB?** Q4_K_M needs ~38GB just for the model weights — on a 32GB machine that means constant swapping and unusable speeds. Q2_K fits in ~26GB and leaves headroom for a usable context window. Quality is "fair" but genuinely usable for most coding tasks.

---

## 4. Start the Server (llama-server path)

> **Skip this section if you're using Ollama** — it serves automatically on port 11434.

### 64GB configuration (recommended)

```bash
llama-server \
  -hf unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M \
  --ctx-size 65536 \
  --n-gpu-layers 99 \
  --no-mmap \
  --flash-attn on \
  --temp 1.0 \
  --top-p 0.95 \
  --top-k 40 \
  --min-p 0.01 \
  --jinja \
  --port 8080
```

### 32GB configuration

```bash
llama-server \
  -hf unsloth/Qwen3-Coder-Next-GGUF:Q2_K \
  --ctx-size 32768 \
  --n-gpu-layers 99 \
  --no-mmap \
  --flash-attn on \
  --temp 1.0 \
  --top-p 0.95 \
  --top-k 40 \
  --min-p 0.01 \
  --jinja \
  --port 8080
```

### Key flags explained

See the [llama-server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) for the full list of flags.

| Flag | Why |
|---|---|
| `--ctx-size 65536` / `32768` | Caps context window. 64GB machines can use 64K tokens; 32GB machines should cap at 32K. **Critical** — the default 256K will OOM instantly. |
| `--n-gpu-layers 99` | Offloads as many layers as possible to Metal GPU. On 32GB, lower to `30-50` if you hit memory pressure. |
| `--no-mmap` | Loads model fully into RAM upfront — avoids page fault stuttering on macOS. Less critical on 64GB (more headroom) but still a reasonable default. |
| `--flash-attn on` | Enables Flash Attention for faster inference. Default is `auto` in newer versions. |

You now have an OpenAI-compatible API at `http://localhost:8080/v1`.

---

## 5. Choose Your Coding Tool

All of these talk to the same local endpoint. You can install several and switch freely.

> **Tip:** If you use pyenv or manage multiple Python versions, prefer `pipx install` over `pip install` to avoid polluting your Python environment.

### Option A — [Aider](https://aider.chat/) (git-native pair programmer)

Mature, battle-tested. Automatically detects your git repo, adds files to context, applies diffs directly, and auto-commits changes.

```bash
# Install (pipx recommended if available)
pipx install aider-chat
# OR: pip install aider-chat

# Run with llama-server
aider \
  --model openai/qwen3-coder-next \
  --openai-api-base http://localhost:8080/v1 \
  --openai-api-key not-needed

# Run with Ollama
aider --model ollama/qwen2.5-coder:32b
```

**Best for:** editing existing codebases, refactoring, fixing bugs across multiple files.

### Option B — [OpenCode](https://opencode.ai/) (interactive agent TUI)

Open-source coding agent with a polished terminal UI. More exploratory and agent-like than Aider.

```bash
# Install (Homebrew — recommended)
brew install anomalyco/tap/opencode

# Or via npm
npm install -g @opencode/cli

# Configure
opencode config set model http://localhost:8080/v1
opencode config set api-key "not-needed"

# Run
opencode
```

See the [install docs](https://opencode.ai/docs/#install) for more options.

**Best for:** scaffolding new projects, exploring solutions, greenfield development.

### Option C — [Pi](https://github.com/badlogic/pi-mono) (minimal, extensible coding harness)

Built by Mario Zechner as a reaction to Claude Code's growing complexity. Pi is intentionally minimal — it ships with solid defaults but skips sub-agents and plan mode. Instead, you extend it with TypeScript extensions, skills, and prompt templates that you can share as npm/git packages. Supports Ollama, OpenAI-compatible endpoints, Anthropic, Google, and many more providers natively.

```bash
# Install globally
npm install -g @mariozechner/pi-coding-agent

# Point at your local server
pi --model openai:qwen3-coder-next --api-base http://localhost:8080/v1

# Or if using Ollama instead of llama-server
pi --model ollama:qwen3-coder-next
```

Pi runs in four modes: interactive TUI, print/JSON for scripting, RPC for process integration, and SDK for embedding in your own apps. Install community packages with `pi install npm:@foo/pi-tools` or `pi install git:github.com/user/repo`. Configure with `pi config`.

**Best for:** developers who want Claude Code-style workflow without the bloat, and who value extensibility and control over their agent's behaviour.

### Option D — Simon Willison's [`llm`](https://llm.datasette.io/) (one-off tasks & Unix pipes)

Not an agent — this is a CLI tool for firing single prompts at any model and piping results through Unix workflows. Perfect for quick tasks where you don't need a full coding session.

```bash
# Install
brew install llm

# Install Ollama plugin (for local models)
llm install llm-ollama

# One-off prompts
llm -m qwen2.5-coder:32b "Write a Python function that reverses a linked list"

# Pipe code through it
cat myfile.py | llm -s "Explain this code"

# Generate commit messages from diffs
git diff HEAD | llm -s "write a conventional commit message"

# Generate docs from source
cat src/*.py | llm -s "generate a README.md in markdown" > README.md

# Explain errors
cat error.log | llm -s "explain this error and suggest fixes"

# Security review
cat app.js | llm -s "perform security analysis and list vulnerabilities"
```

The `llm` tool also supports tool use (since v0.26), logs all prompts/responses to SQLite for later review (`llm logs`), and has plugins for virtually every provider — OpenAI, Anthropic, Gemini, Ollama, llama-server, and more. It works with both cloud APIs and local models interchangeably.

**Best for:** quick questions, code review, commit messages, piping files through an LLM, scripting, batch processing. Not an agent — no file editing or autonomous action.

### Quick comparison

| | Aider | OpenCode | Pi | `llm` CLI |
|---|---|---|---|---|
| **Type** | Pair programmer | Agent TUI | Agent harness | One-shot CLI |
| **Autonomy** | Edits files, auto-commits | Explores & scaffolds | Extensible agent | Single prompt/response |
| **Git integration** | Built-in | Manual | Via skills | Via Unix pipes |
| **Learning curve** | Low | Low | Medium | Very low |
| **Best use** | Existing codebases | New projects | Custom workflows | Quick tasks & scripting |
| **Install** | `pip install` | `npm install` | `npm install` | `brew install` |

---

## 6. Memory Optimisation Tips

### 64GB Macs

You have plenty of headroom at Q4_K_M. Memory pressure is unlikely to be an issue unless you're running very large context windows at Q6_K.

- **Context scaling:** You can push `--ctx-size` to 65536 or even higher. More context = better multi-file work.
- **`--n-gpu-layers 99` is correct** — M1 Max / M2 Max / M3 Max have plenty of GPU memory bandwidth. Offload everything.
- **Q6_K at 64GB** is feasible but tight. Close browsers and heavy apps if you try it.

### 32GB Macs

Since you're running tight on 32GB, here are practical levers to pull:

**If you're hitting swap / slowdowns:**

1. **Reduce context further:** Change `--ctx-size 32768` to `16384`. You lose context window but gain stability.
2. **Reduce GPU layers:** Lower `--n-gpu-layers` from `99` to `30-50`. This splits work between GPU and CPU — slower but more stable.
3. **Close other apps.** Seriously. Browsers with many tabs are the enemy. Check Activity Monitor for memory pressure.
4. **Avoid conversation branching.** Don't regenerate responses — start fresh instead. llama.cpp handles linear conversations much better.

**Expected performance on 32GB with Q2_K:**

- ~15–25 tokens/sec generation speed
- 32K token context window (enough for most single-file tasks)
- Usable for day-to-day coding, refactoring, writing tests, explaining code
- May struggle with very complex multi-file architectural tasks

**Expected performance on 64GB with Q4_K_M:**

- ~15–25 tokens/sec generation speed (similar — bottleneck is compute, not memory)
- 64K token context window (handles multi-file tasks much better)
- Noticeably better output quality than Q2_K — fewer artifacts, better reasoning
- Comfortable headroom to run alongside browsers and other apps

---

## 7. Alternative Models

Depending on your RAM and use case, you might want a different model:

### Qwen2.5-Coder-32B — fast and proven

A 32B parameter model that runs well on both 32GB and 64GB Macs. The default Ollama quant is ~20GB, leaving plenty of room for context and other apps. Benchmarks put it between GPT-4o and Claude 3.5 Haiku on Aider's code editing tests.

**On 32GB Macs** this is arguably the best option — better quality than Qwen3-Coder-Next at Q2_K because you're running a smaller model at higher quantization.

**On 64GB Macs** it's a great **fast option** for quick tasks. Smaller model = faster inference. Use Qwen3-Coder-Next at Q4_K_M for complex work and Qwen2.5-Coder-32B for speed.

```bash
# Via Ollama (easiest path)
ollama pull qwen2.5-coder:32b

# Use with any agent — they all speak OpenAI-compatible API:
aider --model ollama/qwen2.5-coder:32b

# Or one-off with llm:
llm install llm-ollama
llm -m qwen2.5-coder:32b "your prompt here"

# Or with Pi:
pi --model ollama:qwen2.5-coder:32b
```

### Qwen3-Coder (the non-"Next" version)

Smaller and designed to run on a single RTX 4090 or 32GB Mac. Achieved 46.8% on SWE-Bench Verified — the best open-source result. If available via Ollama:

```bash
ollama pull qwen3-coder
```

### Smaller models for quick tasks

If you want a model that loads fast, answers quickly, and unloads without disrupting your workflow:

| Model | Size (Q4) | RAM needed | Quality | Good for |
|---|---|---|---|---|
| Qwen2.5-Coder-14B | ~9GB | ~12GB | Good | Single-file tasks, explanations |
| Qwen2.5-Coder-7B | ~5GB | ~8GB | Decent | Autocomplete-style use, quick questions |
| DeepSeek-Coder-V2-Lite | ~9GB | ~12GB | Good | Reasoning-heavy tasks |

All available via `ollama pull <model-name>`. These are great candidates for the `llm` CLI — small enough to load fast, answer a question, and unload without disrupting your workflow.

---

## 8. Quick Test

Once any server is running (llama-server or Ollama), verify it works:

```bash
# For llama-server (port 8080)
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-coder-next",
    "messages": [{"role": "user", "content": "Write a Python function that reverses a linked list"}],
    "max_tokens": 512
  }'

# For Ollama (port 11434)
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:32b",
    "messages": [{"role": "user", "content": "Write a Python function that reverses a linked list"}],
    "max_tokens": 512
  }'
```

If you get a JSON response with generated code, you're good to go.

---

## 9. Troubleshooting

**"Out of memory" or system becomes unresponsive**
→ Reduce `--ctx-size` and `--n-gpu-layers`. Restart the server. On 64GB, try a lower quantization before reducing context.

**Very slow (<5 tok/s)**
→ Check Activity Monitor → Memory tab. If memory pressure is red/yellow, close apps or reduce context size.

**Model outputs garbage or loops**
→ Add `--repeat-penalty 1.1` to the server command. Make sure you're using the recommended sampling params (temp 1.0, top-p 0.95).

**Agent can't connect**
→ Confirm the server is running: `curl http://localhost:8080/v1/models` (llama-server) or `curl http://localhost:11434/v1/models` (Ollama).

**Port conflict on 8080 or 11434**
→ Check what's using the port: `lsof -i :8080`. Either stop the other process or use a different `--port` flag.

**MLX is slow or buggy**
→ Known issue with KV cache during conversation branching. Use llama.cpp or Ollama instead for now.

**Ollama model management**
→ Use `ollama list` to see installed models, `ollama rm <name>` to free disk space, `ollama ps` to check what's loaded. See the [Ollama docs](https://github.com/ollama/ollama) for more.

---

## 10. Practical Strategy

### 64GB Macs

With 64GB you can run the full-size model at good quality. Recommended setup:

1. **Primary model:** Qwen3-Coder-Next at Q4_K_M via llama-server — best quality for complex work with 64K context
2. **Fast option:** Qwen2.5-Coder-32B via Ollama — quicker inference for simpler tasks
3. **Quick tasks:** `llm` CLI piped through your local model for commit messages, code review, error explanations, docs generation
4. **Agentic work:** Aider or Pi pointed at your local server for multi-file refactoring and longer coding sessions
5. **Complex architecture:** Fall back to Claude or GPT API when the local model isn't cutting it — no shame in that

### 32GB Macs

The most productive setup on 32GB is a **hybrid approach**:

1. **Daily driver:** Qwen2.5-Coder-32B via Ollama — better quality at this RAM level than Qwen3-Coder-Next at Q2
2. **Quick tasks:** `llm` CLI piped through your local model for commit messages, code review, error explanations, docs generation
3. **Agentic work:** Aider or Pi pointed at Ollama for multi-file refactoring and longer coding sessions
4. **Complex architecture:** Fall back to Claude or GPT API when the local model isn't cutting it — no shame in that

---

## Quick Reference

```bash
# === 64GB: Qwen3-Coder-Next via llama-server (best quality) ===

llama-server \
  -hf unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M \
  --ctx-size 65536 --n-gpu-layers 99 --no-mmap --flash-attn on \
  --temp 1.0 --top-p 0.95 --top-k 40 --min-p 0.01 \
  --jinja --port 8080

# === 32GB: Qwen3-Coder-Next via llama-server ===

llama-server \
  -hf unsloth/Qwen3-Coder-Next-GGUF:Q2_K \
  --ctx-size 32768 --n-gpu-layers 99 --no-mmap --flash-attn on \
  --temp 1.0 --top-p 0.95 --top-k 40 --min-p 0.01 \
  --jinja --port 8080

# === ANY RAM: Qwen2.5-Coder-32B via Ollama (fast, proven) ===

ollama pull qwen2.5-coder:32b && ollama serve

# === PICK YOUR TOOL ===

# Aider (pair programmer) — https://aider.chat/
aider --model openai/qwen3-coder-next \
      --openai-api-base http://localhost:8080/v1 \
      --openai-api-key not-needed

# Aider with Ollama
aider --model ollama/qwen2.5-coder:32b

# OpenCode (agent TUI) — https://opencode.ai/
opencode

# Pi (extensible harness) — https://github.com/badlogic/pi-mono
pi --model openai:qwen3-coder-next --api-base http://localhost:8080/v1

# llm (one-off tasks) — https://llm.datasette.io/
llm -m qwen2.5-coder:32b "your prompt"
cat file.py | llm -s "review this code"
git diff | llm -s "write commit message"
```
