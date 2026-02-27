# qwen-coder-locally-on-32to64gb-macbook-silicon

A no-nonsense guide to running Qwen coding models locally on Apple Silicon MacBooks with your choice of coding agent or CLI tool. Covers both **32GB** and **64GB** configurations.

> **About the models:** This guide covers three main local models — **Qwen3-Coder-Next** (80B MoE, 3B active, coding-specialized), **Qwen3.5-35B-A3B** (35B MoE, 3B active, general-purpose), and **Qwen2.5-Coder-32B** (32B dense, coding-focused). All run fully offline — your code never leaves your machine.

## Start Here — Pick Your Path

**64GB Macs:**
- **Recommended:** Qwen3-Coder-Next at Q4_K_M via llama-server — best quality for complex coding work
- **Alternative:** Qwen3.5-35B-A3B via Ollama — strong general-purpose + coding, lighter on RAM
- **Fast option:** Qwen2.5-Coder-32B via Ollama for quicker tasks

**32GB Macs:**
- **Recommended:** Qwen3.5-35B-A3B via Ollama — best balance of quality and RAM usage (~22GB at Q4_K_M)
- **Alternative:** Qwen2.5-Coder-32B via Ollama — proven and fast
- **Alternative:** Qwen3-Coder-Next at Q2_K (fits but lower quality due to aggressive quantization)

### Which model should I pick?

| | Qwen3-Coder-Next | Qwen3.5-35B-A3B | Qwen2.5-Coder-32B |
|---|---|---|---|
| **Total / active params** | 80B / 3B | 35B / 3B | 32B / 32B (dense) |
| **Architecture** | MoE (coding-specialized) | MoE (general-purpose) | Dense (coding-focused) |
| **Context** | 256K | 256K | 32K |
| **RAM @ Q4_K_M** | ~38GB (64GB Mac) | ~22GB (32GB Mac) | ~20GB (32GB Mac) |
| **Best for** | Complex agentic coding on 64GB | All-rounder on 32GB or 64GB | Quick tasks, proven reliability |
| **License** | Open weights | Apache 2.0 | Apache 2.0 |

**TL;DR:** On 64GB, use Qwen3-Coder-Next for serious coding. On 32GB, use Qwen3.5-35B-A3B — it has the same 3B active params as Coder-Next but fits comfortably without aggressive quantization.

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

# Check if Ollama is already running (safe pattern)
if ! pgrep ollama >/dev/null 2>&1; then
  ollama serve &
  sleep 2  # Give it a moment to start
fi

# Pull the recommended model for your RAM tier
# For 32GB: qwen3.5:35b-a3b (recommended — ~22GB, fits comfortably)
#        or qwen2.5-coder:32b (proven alternative)
# For 64GB: qwen3.5:35b-a3b (light option) or qwen2.5-coder:32b (fast option)
ollama pull qwen3.5:35b-a3b
# ollama pull qwen2.5-coder:32b  # alternative

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

### 32GB Macs — Qwen3.5-35B-A3B at Q4_K_M (recommended) or Qwen3-Coder-Next at Q2_K

**Option A (recommended): Qwen3.5-35B-A3B at Q4_K_M** — fits comfortably in ~22GB, leaving plenty of room for context. Good quality quantization (not aggressive like Q2_K).

```bash
llama-cli -hf unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M
```

**Option B: Qwen3-Coder-Next at Q2_K** — the coding-specialized model, but needs aggressive quantization to fit in 32GB (~26GB).

```bash
llama-cli -hf unsloth/Qwen3-Coder-Next-GGUF:Q2_K
```

> **Which to pick on 32GB?** Qwen3.5-35B-A3B at Q4_K_M gives better overall quality because the quantization is much less aggressive. Qwen3-Coder-Next has coding-specific training, but Q2_K quantization loses a lot of that advantage. For most users, Qwen3.5-35B-A3B is the better 32GB choice.

---

## 4. Start the Server (llama-server path)

> **Skip this section if you're using Ollama** — it serves automatically on port 11434.

**Quick start:** The included script auto-detects your RAM and picks the right model/context size:

```bash
./start-llama-server.sh

# Override defaults with environment variables:
PORT=9090 ./start-llama-server.sh
GPU_LAYERS=50 ./start-llama-server.sh
CTX_SIZE=16384 ./start-llama-server.sh
MODEL_VARIANT=coder-next ./start-llama-server.sh  # Use Qwen3-Coder-Next instead of Qwen3.5 on 32GB
```

Or run manually with the commands below.

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

### 32GB configuration — Qwen3.5-35B-A3B (recommended)

```bash
llama-server \
  -hf unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M \
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

> **Why 99 GPU layers with Qwen3.5?** At ~22GB the model fits comfortably in 32GB unified memory, so you can offload all layers to GPU. This is a major advantage over Qwen3-Coder-Next Q2_K which needs conservative GPU layer settings.

### 32GB configuration — Qwen3-Coder-Next Q2_K (alternative)

```bash
llama-server \
  -hf unsloth/Qwen3-Coder-Next-GGUF:Q2_K \
  --ctx-size 32768 \
  --n-gpu-layers 40 \
  --no-mmap \
  --flash-attn on \
  --temp 1.0 \
  --top-p 0.95 \
  --top-k 40 \
  --min-p 0.01 \
  --jinja \
  --port 8080
```

> **Why 40 GPU layers on 32GB?** This conservative default prevents swap storms on first run. You can increase to 60-80 if your system handles it well, but start conservative to ensure stability.

### Key flags explained

See the [llama-server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) for the full list of flags.

| Flag | Why |
|---|---|
| `--ctx-size 65536` / `32768` | Caps context window. 64GB machines can use 64K tokens; 32GB machines should cap at 32K. **Critical** — the default 256K will OOM instantly. |
| `--n-gpu-layers 99` / `40` | Offloads layers to Metal GPU. 64GB can use 99 (all layers). 32GB uses conservative 40 to prevent memory pressure — tune upward if stable. |
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
aider --model ollama/qwen3.5:35b-a3b
# Or the older but proven:
# aider --model ollama/qwen2.5-coder:32b
```

**Best for:** editing existing codebases, refactoring, fixing bugs across multiple files.

### Option B — [OpenCode](https://opencode.ai/) (interactive agent TUI)

Open-source coding agent with a polished terminal UI. More exploratory and agent-like than Aider.

```bash
# Install (Homebrew — recommended)
brew install anomalyco/tap/opencode

# Or via npm
npm install -g @opencode/cli
```

OpenCode uses a JSON config file (`opencode.jsonc`) in your project root. This repo includes one pre-configured for both llama-server and Ollama. To use it, just run:

```bash
# Run from this repo's directory — it picks up opencode.jsonc automatically
opencode
```

The included `opencode.jsonc` defines both providers so you can switch between them. To change the default model, edit the `"model"` field:

```jsonc
// Use llama-server (default)
"model": "llama.cpp/qwen3-coder-next"

// Or switch to Ollama
"model": "ollama/qwen3.5:35b-a3b"
// Or the older Qwen2.5:
// "model": "ollama/qwen2.5-coder:32b"
```

See the [install docs](https://opencode.ai/docs/#install) for more options.

**Best for:** scaffolding new projects, exploring solutions, greenfield development.

### Option C — [Pi](https://github.com/badlogic/pi-mono) (minimal, extensible coding harness)

Built by Mario Zechner as a reaction to Claude Code's growing complexity. Pi is intentionally minimal — it ships with solid defaults but skips sub-agents and plan mode. Instead, you extend it with TypeScript extensions, skills, and prompt templates that you can share as npm/git packages. Supports Ollama, OpenAI-compatible endpoints, Anthropic, Google, and many more providers natively.

```bash
# Install (Homebrew — recommended)
brew install pi-coding-agent

# Or via npm
npm install -g @mariozechner/pi-coding-agent
```

Pi discovers models via `~/.pi/agent/models.json`. Run the setup script to configure it automatically:

```bash
./setup-pi-local.sh
```

Or manually create `~/.pi/agent/models.json`:

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://localhost:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "models": [
        { "id": "qwen3:latest" }
      ]
    },
    "llama-server": {
      "baseUrl": "http://localhost:8080/v1",
      "api": "openai-completions",
      "apiKey": "local",
      "models": [
        { "id": "qwen3-coder-next", "contextWindow": 65536, "maxTokens": 32000 }
      ]
    }
  }
}
```

Then run with whichever provider you have running:

```bash
# Verify your models are visible
pi --list-models

# Use llama-server
pi --model llama-server/qwen3-coder-next

# Use Ollama
pi --model ollama/qwen3:latest
```

Pi runs in four modes: interactive TUI, print/JSON for scripting, RPC for process integration, and SDK for embedding in your own apps. Install community packages with `pi install npm:@foo/pi-tools` or `pi install git:github.com/user/repo`. Configure with `pi config`. See [pi.dev](https://pi.dev/) and the [custom models docs](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/models.md) for more.

**Best for:** developers who want Claude Code-style workflow without the bloat, and who value extensibility and control over their agent's behaviour.

### Option D — Simon Willison's [`llm`](https://llm.datasette.io/) (one-off tasks & Unix pipes)

Not an agent — this is a CLI tool for firing single prompts at any model and piping results through Unix workflows. Perfect for quick tasks where you don't need a full coding session.

```bash
# Install
brew install llm

# Install Ollama plugin (for local models via Ollama)
llm install llm-ollama
```

**Two ways to use it with local models:**

**Via Ollama** — simplest if you already use Ollama. Note: `llm -m qwen3` tells Ollama to load the model, which **spins up a separate model instance**. If you already have a large model loaded in llama-server, this will compete for memory and may cause swapping/freezing.

```bash
# These use Ollama (will load the model into Ollama's memory)
llm -m qwen2.5-coder:32b "Write a Python function that reverses a linked list"
llm -m qwen3 "Write a Python function that reverses a linked list"
```

**Via llama-server** — if you already have llama-server running on port 8080, point `llm` at it directly. No extra memory needed. Run the setup script to configure it automatically:

```bash
./setup-llm-local.sh
```

Or manually add this to `~/Library/Application Support/io.datasette.llm/extra-openai-models.yaml`:

```yaml
- model_id: qwen-local
  model_name: qwen3-coder-next
  api_base: "http://localhost:8080/v1"
```

Then use it like any other model:

```bash
llm -m qwen-local "Write a Python function that reverses a linked list"
```

**Pipe-friendly examples (work with either setup):**

```bash
# Pipe code through it
cat myfile.py | llm -m qwen-local -s "Explain this code"

# Generate commit messages from diffs
git diff HEAD | llm -m qwen-local -s "write a conventional commit message"

# Generate docs from source
cat src/*.py | llm -m qwen-local -s "generate a README.md in markdown" > README.md

# Explain errors
cat error.log | llm -m qwen-local -s "explain this error and suggest fixes"

# Security review
cat app.js | llm -m qwen-local -s "perform security analysis and list vulnerabilities"
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

### Model naming across tools

Each tool has its own model naming convention. Here's how to reference your local models:

| Scenario | Aider | OpenCode | Pi | `llm` CLI |
|---|---|---|---|---|
| **llama-server on 8080** | `openai/qwen3-coder-next` | `llama.cpp/qwen3-coder-next` (via `opencode.jsonc`) | `llama-server/qwen3-coder-next` | Custom alias: `qwen-local` |
| **Ollama (qwen3.5)** | `ollama/qwen3.5:35b-a3b` | `ollama/qwen3.5:35b-a3b` | `ollama/qwen3.5:35b-a3b` | `qwen3.5:35b-a3b` (with llm-ollama) |
| **Ollama (qwen2.5)** | `ollama/qwen2.5-coder:32b` | `ollama/qwen2.5-coder:32b` | `ollama/qwen2.5-coder:32b` | `qwen2.5-coder:32b` |
| **Ollama (qwen3)** | `ollama/qwen3-coder-next` | `ollama/qwen3-coder-next` | `ollama/qwen3:latest` | `qwen3` (with llm-ollama) |

**OpenCode configuration note:** OpenCode uses a project-level `opencode.jsonc` config file (included in this repo). It defines custom providers with the `@ai-sdk/openai-compatible` npm package, so you can name models explicitly and set context/output limits. No API key is needed for local providers — just omit it. Edit `opencode.jsonc` to change the default model or add new providers.

---

## 6. Memory Optimisation Tips

### 64GB Macs

You have plenty of headroom at Q4_K_M. Memory pressure is unlikely to be an issue unless you're running very large context windows at Q6_K.

- **Context scaling:** You can push `--ctx-size` to 65536 or even higher. More context = better multi-file work.
- **`--n-gpu-layers 99` is correct** — M1 Max / M2 Max / M3 Max have plenty of GPU memory bandwidth. Offload everything.
- **Q6_K at 64GB** is feasible but tight. Close browsers and heavy apps if you try it.

### 32GB Macs

The default configuration above uses conservative settings (--ctx-size 32768, --n-gpu-layers 40) to ensure stable first runs.

**If you're hitting swap / slowdowns:**

1. **Reduce context further:** Change `--ctx-size 32768` to `16384`. You lose context window but gain stability.
2. **Reduce GPU layers:** Lower `--n-gpu-layers` from `40` to `30`. This splits more work between GPU and CPU — slower but more stable.
3. **Close other apps.** Seriously. Browsers with many tabs are the enemy. Check Activity Monitor for memory pressure.
4. **Avoid conversation branching.** Don't regenerate responses — start fresh instead. llama.cpp handles linear conversations much better.

**Advanced tuning — if system is stable:**

If your 32GB Mac handles the conservative defaults well, you can tune upward:
- Increase `--n-gpu-layers` to `60-80` for faster inference
- Try `--ctx-size 49152` if you need more context and have headroom

Monitor Activity Monitor → Memory tab. If you see yellow/red memory pressure, back off.

**Expected performance on 32GB with Q2_K:**

- Generation speed typically in the 15–25 tokens/sec range (varies by task complexity)
- 32K token context window (enough for most single-file tasks)
- Usable for day-to-day coding, refactoring, writing tests, explaining code
- May struggle with very complex multi-file architectural tasks

**Expected performance on 64GB with Q4_K_M:**

- Generation speed typically in the 15–25 tokens/sec range (bottleneck is compute, not memory)
- 64K token context window (handles multi-file tasks much better)
- Noticeably better output quality than Q2_K — fewer artifacts, better reasoning
- Comfortable headroom to run alongside browsers and other apps

---

## 7. Alternative Models

Depending on your RAM and use case, you might want a different model:

### Qwen3.5-35B-A3B — best all-rounder for 32GB

Released 2026-02-24. A 35B MoE model with only 3B active parameters — same active params as Qwen3-Coder-Next but in a much smaller package. General-purpose (coding, reasoning, vision, multilingual) rather than coding-specialized, but benchmarks show competitive coding performance (~72% on SWE-Bench Verified for the 27B variant).

**On 32GB Macs** this is the new top recommendation — at Q4_K_M (~22GB) it fits comfortably with room for context and other apps. Much better quantization quality than Qwen3-Coder-Next at Q2_K.

**On 64GB Macs** it's a lighter alternative to Qwen3-Coder-Next. Use Coder-Next for maximum coding quality and Qwen3.5 when you want a capable model that leaves more RAM headroom.

```bash
# Via Ollama (easiest)
ollama pull qwen3.5:35b-a3b

# Use with any agent:
aider --model ollama/qwen3.5:35b-a3b

# Via llama-server (more control)
llama-server -hf unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M \
  --ctx-size 32768 --n-gpu-layers 99 --no-mmap --flash-attn on \
  --temp 1.0 --top-p 0.95 --top-k 40 --min-p 0.01 \
  --jinja --port 8080

# Or one-off with llm:
llm -m qwen3.5:35b-a3b "your prompt here"
```

### Qwen2.5-Coder-32B — fast and proven

A 32B parameter model that runs well on both 32GB and 64GB Macs. The default Ollama quant is ~20GB, leaving plenty of room for context and other apps. Performs well on code editing and generation tasks.

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

# Or with Pi (add to ~/.pi/agent/models.json first):
pi --model ollama/qwen2.5-coder:32b
```

### Qwen3-Coder (the non-"Next" version)

Smaller and designed to run on a single RTX 4090 or 32GB Mac. Performs well on software engineering benchmarks. If available via Ollama:

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

**Ollama model management**
→ Use `ollama list` to see installed models, `ollama rm <name>` to free disk space, `ollama ps` to check what's loaded. See the [Ollama docs](https://github.com/ollama/ollama) for more.

---

## 10. Practical Strategy

### 64GB Macs

With 64GB you can run the full-size model at good quality. Recommended setup:

1. **Primary model:** Qwen3-Coder-Next at Q4_K_M via llama-server — best quality for complex work with 64K context
2. **Lighter alternative:** Qwen3.5-35B-A3B via Ollama — strong all-rounder that leaves more RAM headroom
3. **Fast option:** Qwen2.5-Coder-32B via Ollama — quicker inference for simpler tasks
4. **Quick tasks:** `llm` CLI piped through your local model for commit messages, code review, error explanations, docs generation
5. **Agentic work:** Aider or Pi pointed at your local server for multi-file refactoring and longer coding sessions
6. **Complex architecture:** Fall back to Claude or GPT API when the local model isn't cutting it — no shame in that

### 32GB Macs

The most productive setup on 32GB is a **hybrid approach**:

1. **Daily driver:** Qwen3.5-35B-A3B via Ollama — best quality at this RAM level, fits comfortably at Q4_K_M
2. **Fast alternative:** Qwen2.5-Coder-32B via Ollama — proven and reliable for quick coding tasks
3. **Quick tasks:** `llm` CLI piped through your local model for commit messages, code review, error explanations, docs generation
4. **Agentic work:** Aider or Pi pointed at Ollama for multi-file refactoring and longer coding sessions
5. **Complex architecture:** Fall back to Claude or GPT API when the local model isn't cutting it — no shame in that

---

## Quick Reference

```bash
# === 64GB: Qwen3-Coder-Next via llama-server (best quality) ===

llama-server \
  -hf unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M \
  --ctx-size 65536 --n-gpu-layers 99 --no-mmap --flash-attn on \
  --temp 1.0 --top-p 0.95 --top-k 40 --min-p 0.01 \
  --jinja --port 8080

# === 32GB: Qwen3.5-35B-A3B via llama-server (recommended for 32GB) ===

llama-server \
  -hf unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M \
  --ctx-size 32768 --n-gpu-layers 99 --no-mmap --flash-attn on \
  --temp 1.0 --top-p 0.95 --top-k 40 --min-p 0.01 \
  --jinja --port 8080

# === 32GB: Qwen3-Coder-Next via llama-server (alternative) ===

llama-server \
  -hf unsloth/Qwen3-Coder-Next-GGUF:Q2_K \
  --ctx-size 32768 --n-gpu-layers 40 --no-mmap --flash-attn on \
  --temp 1.0 --top-p 0.95 --top-k 40 --min-p 0.01 \
  --jinja --port 8080

# === ANY RAM: Ollama models ===

# Safe start pattern - checks if already running
if ! pgrep ollama >/dev/null 2>&1; then
  ollama serve &
  sleep 2
fi
ollama pull qwen3.5:35b-a3b       # recommended for 32GB
ollama pull qwen2.5-coder:32b     # proven alternative

# === PICK YOUR TOOL ===

# Aider (pair programmer) — https://aider.chat/
aider --model openai/qwen3-coder-next \
      --openai-api-base http://localhost:8080/v1 \
      --openai-api-key not-needed

# Aider with Ollama
aider --model ollama/qwen3.5:35b-a3b
# aider --model ollama/qwen2.5-coder:32b   # alternative

# OpenCode (agent TUI) — https://opencode.ai/
# Uses opencode.jsonc in project root for provider config
opencode                                    # uses default model from config
# Edit opencode.jsonc "model" field to switch between:
#   "llama.cpp/qwen3-coder-next"            # llama-server on :8080
#   "ollama/qwen3.5:35b-a3b"               # Ollama on :11434
#   "ollama/qwen2.5-coder:32b"              # Ollama on :11434

# Pi (extensible harness) — https://pi.dev/
# Requires ~/.pi/agent/models.json config (see Section 5, Option C)
pi --model llama-server/qwen3-coder-next
pi --model ollama/qwen3:latest

# llm (one-off tasks) — https://llm.datasette.io/
# Via Ollama (loads model in Ollama — don't mix with running llama-server)
llm -m qwen3.5:35b-a3b "your prompt"
llm -m qwen2.5-coder:32b "your prompt"
# Via llama-server (uses already-running server — no extra memory)
llm -m qwen-local "your prompt"
cat file.py | llm -m qwen-local -s "review this code"
git diff | llm -m qwen-local -s "write commit message"
```
