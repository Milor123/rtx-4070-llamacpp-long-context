🇪🇸 [Español](readme_es.md) · 🇬🇧 **English** · 🇨🇳 [中文](readme_zh.md)

---

# RTX 4070 + llama.cpp: Large Context on Low VRAM

My experience using an **RTX 4070 (12 GB VRAM)** to run large language models with extended contexts (up to 300k–500k tokens) using [llama.cpp](https://github.com/ggerganov/llama.cpp) and tools like [OpenCode](https://github.com/sgth/opencode) that rely on MCPs and internal tool-calling.

---

## Hardware

| Component | Detail |
|---|---|
| GPU | NVIDIA RTX 4070 — **12 GB VRAM** |
| RAM | 48 GB DDR5 |
| CPU | Intel Core i5 14th gen |

---

## Why share this

With 12 GB of VRAM you can't run large models with long contexts "out of the box." After trying various configurations, forks, and parameters, I found a setup that lets me run models like:

- **Qwythos 9B** with **300k token context**
- **Gemma 4 26B** with **256k token context**

Both at decent speeds with MCPs working correctly.

---

## The fork I use

I use the fork maintained by **AtomicBot-ai** which includes GPU acceleration improvements:

> [https://github.com/AtomicBot-ai/atomic-llama-cpp-turboquant](https://github.com/AtomicBot-ai/atomic-llama-cpp-turboquant)

### TurboQuant — the secret behind large context

All of this works thanks to **TurboQuant**, the KV cache compression technology that comes with the AtomicBot fork. The flags `-ctv turbo2` and `-ctk turbo2` (or `turbo3` for Gemma 4) activate keys/values cache compression, drastically reducing VRAM consumption per context token.

What does this mean in practice?

- **Without TurboQuant**: with 12 GB VRAM you barely get ~32k tokens
- **With TurboQuant (turbo2)**: you reach 300k+ tokens with the same model, same GPU
- **With TurboQuant (turbo3, Gemma 4)**: you reach 256k tokens on a 26B parameter model

The cost is speed: compression/decompression takes time, so generation is slower than it would be without TurboQuant. But it's a totally acceptable tradeoff when you can multiply your usable context by 10x.

---

## The problem: MCPs weren't working

The Qwythos model didn't perform well with OpenCode's internal tools (MCPs). The issue was the chat template: the one that came with the model didn't properly support the tool-calling format. I fixed it by attaching the Jinja template in `templates/3.6_chat_template-v10.jinja` (taken from [this gist](https://gist.github.com/Milor123/ecb30311450c6b5fe581dab4df7515b7)).

With that template activated (`--chat-template-file ... --jinja`) the MCPs and internal model calls work without issues.

---

## Configurations

### Qwythos 9B — 300k context

```powershell
.\llama-server.exe -m "Qwythos-9B-Claude-Mythos-5-1M-Q4_K_M.gguf" --host 127.0.0.1 --port 10000 -ngl 99 -c 356000 -b 8192 -ub 2048 --no-mmap --direct-io --temp 0.6 -np 1 -fa on --top-k 20 --repeat-penalty 1.05 --top-p 0.95 --min-p 0 --cont-batching --metrics --chat-template-kwargs '{"preserve_thinking": true}' -ctv turbo2 -ctk turbo2 --jinja -tb 10 -t 10 --poll 100 --cpu-strict 1 --n-cpu-moe 5 --chat-template-file "templates/3.6_chat_template-v10.jinja"
```

**Observed performance:** 13–20 t/s generation at that context size.

### Gemma 4 26B — 256k context

For Gemma 4 I used a **different fork**: [https://github.com/cortexist/llama.cpp](https://github.com/cortexist/llama.cpp) (it supports turbo3 for Gemma 4).

```powershell
.\llama-server.exe -m "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf" --host 127.0.0.1 --port 10000 -ngl 99 -c 256000 -b 8192 -ub 2048 --no-mmap --direct-io --temp 1.0 -np 1 -fa on --top-k 64 --top-p 0.95 --min-p 0 --cont-batching --metrics --chat-template-kwargs '{"preserve_thinking": true}' -ctv turbo3 -ctk turbo3 --jinja -tb 14 -t 14 --poll 100 --cpu-strict 1 --n-cpu-moe 14
```

**Note:** I couldn't get MTP (Multi-Token Prediction) to work with this fork. The developers might still be working on it.

---

## Key parameters explained

| Parameter | Recommended value | Note |
|---|---|---|
| `-ngl` | 99 | Max layers on GPU |
| `-c` | 256000–356000 | Context size in tokens |
| `-b` | 8192 | Batch size for prompt ingestion |
| `-ub` | 2048 | Micro-batching |
| `-tb` | 10–14 | Batch threads (↑ = more VRAM, slower processing) |
| `-t` | 10–14 | Generation threads |
| `--n-cpu-moe` | 5–17 | MoE CPU offloading |
| `--jinja` | yes | Required for `--chat-template-file` |
| `-ctv/-ctk` | turbo2 or turbo3 | Activates **TurboQuant** — compresses KV cache. turbo2 for most models, turbo3 for Gemma 4 |
| `--no-mmap --direct-io` | yes | Avoids pagefile, improves performance on Windows |
| `--cont-batching` | yes | Continuous batching |
| `--cpu-strict` | 1 | Forces strict CPU mode for offloaded layers |

### `-b` and `-ub` — the prompt ingestion sweet spot

These two parameters are **critical for prompt ingestion speed**. If you set them wrong, the model becomes completely unusable because reading the context is so slow it's not worth using.

I found a sweet spot at `-b 8192` and `-ub 2048`. With these values, ingestion runs at ~1000–2000 t/s without saturating VRAM. There are probably better combinations — I only tested a few values and I'm not very technical about this. If you find a sweeter spot, open an issue or PR and we'll share it.

### `--n-cpu-moe` — the parameter that defines everything

This is **the most important parameter** for low-VRAM GPUs:

- **Low value** (5): more free VRAM, less CPU load, higher speeds. Useful for short contexts or GPUs with 16+ GB VRAM.
- **High value** (14–17): more MoE layers go to CPU, slower generation, but you can stretch the context significantly. Necessary for very heavy models like Gemma 4 26B.

If you increase `--n-cpu-moe`, you can increase context, but generation speed drops. Lowering it improves speed but reduces the maximum usable context.

---

## Observed performance (visual, not measured)

The numbers I wrote down are **visual estimates from the WebUI**, not from precise measurement tools. They're very rough references:

- **Qwythos 9B**: generation speed between ~13–20 t/s with ~300k context
- **Gemma 4 26B**: generation is slower with high `--n-cpu-moe`, but it's worth it because you need good ingestion speed (~1000–2000 t/s) to process long contexts like those used by OpenCode

Don't take these values as exact. They vary a lot depending on system load, temperature, shared VRAM, etc.

---

## Who this is for

- **RTX 4060 / 4070 / 5060 / 5070** users with 8–12 GB VRAM
- Anyone wanting to run long contexts (128k–500k) without dying trying
- Anyone using **OpenCode** or similar and needing MCPs working with quantized models

---

## Repo structure

```
├── README.md                  # Landing page with languages
├── readme_es.md               # Spanish guide
├── readme_en.md               # English guide (this file)
├── readme_zh.md               # Chinese guide
├── configs/
│   ├── qwythos-9b-300k.bat    # Qwythos command
│   └── gemma-4-26b-256k.bat   # Gemma 4 command
├── templates/
│   └── 3.6_chat_template-v10.jinja  # MCP template
└── benchmarks/
    └── RESULTS.md             # Performance notes
```

---

## If you have a different GPU

Try the parameters and log them. The `configs/` files can be adapted to any RTX-series GPU. Change `--n-cpu-moe`, `-tb`, `-t`, `-b`, `-ub` and `-c` according to your available VRAM.

## License

MIT — use and share freely.

---

🇪🇸 [Español](readme_es.md) · 🇬🇧 **English** · 🇨🇳 [中文](readme_zh.md)
