🇪🇸 [Español](readme_es.md) · 🇬🇧 [English](README.md) · 🇨🇳 **中文**

---

# RTX 4070 + llama.cpp：低显存下的长上下文推理

我使用 **RTX 4070（12 GB 显存）** 运行大语言模型并扩展上下文（最高 300k–500k tokens）的经验，基于 [llama.cpp](https://github.com/ggerganov/llama.cpp) 和依赖 MCP 及内部工具调用的 [OpenCode](https://github.com/sgth/opencode) 等工具。

---

## 硬件配置

| 组件 | 详情 |
|---|---|
| GPU | NVIDIA RTX 4070 — **12 GB 显存** |
| RAM | 48 GB DDR5 |
| CPU | Intel Core i5 第14代 |

---

## 为什么分享这个

用 12 GB 显存根本无法"开箱即用"地运行长上下文的大模型。经过多次尝试不同的配置、分支和参数，我终于找到了一套方案，可以运行以下模型：

- **Qwythos 9B**：**300k tokens** 上下文
- **Gemma 4 26B**：**256k tokens** 上下文

两者速度尚可，且 MCP 工作正常。

---

## 使用的分支

我使用的是 **AtomicBot-ai** 维护的分支，包含 GPU 加速优化：

> [https://github.com/AtomicBot-ai/atomic-llama-cpp-turboquant](https://github.com/AtomicBot-ai/atomic-llama-cpp-turboquant)

### TurboQuant — 长上下文的秘密

这一切都归功于 **TurboQuant**，这是 AtomicBot 分支自带的 KV 缓存压缩技术。`-ctv turbo2` 和 `-ctk turbo2`（Gemma 4 使用 `turbo3`）参数激活了键值缓存压缩，大幅降低了每个上下文 token 的显存消耗。

实际效果：

- **无 TurboQuant**：12 GB 显存只能达到约 ~32k tokens
- **TurboQuant (turbo2)**：相同模型、相同 GPU 可达到 300k+ tokens
- **TurboQuant (turbo3, Gemma 4)**：26B 参数模型可达到 256k tokens

代价是速度：压缩/解压缩需要时间，因此生成速度比不使用 TurboQuant 时要慢。但当你可以将可用上下文扩展 10 倍时，这是一个完全可以接受的权衡。

---

## 问题：MCP 无法工作

Qwythos 模型无法正常使用 OpenCode 的内部工具（MCP）。问题出在聊天模板上：模型自带的模板不支持正确的工具调用格式。我通过附加 `templates/3.6_chat_template-v10.jinja`（来自[这个 gist](https://gist.github.com/Milor123/ecb30311450c6b5fe581dab4df7515b7)）中的 Jinja 模板解决了这个问题。

启用该模板后（`--chat-template-file ... --jinja`），MCP 和模型的内部调用都能正常工作。

---

## 配置

### Qwythos 9B — 300k 上下文

```powershell
.\llama-server.exe -m "Qwythos-9B-Claude-Mythos-5-1M-Q4_K_M.gguf" --host 127.0.0.1 --port 10000 -ngl 99 -c 356000 -b 8192 -ub 2048 --no-mmap --direct-io --temp 0.6 -np 1 -fa on --top-k 20 --repeat-penalty 1.05 --top-p 0.95 --min-p 0 --cont-batching --metrics --chat-template-kwargs '{"preserve_thinking": true}' -ctv turbo2 -ctk turbo2 --jinja -tb 10 -t 10 --poll 100 --cpu-strict 1 --n-cpu-moe 5 --chat-template-file "templates/3.6_chat_template-v10.jinja"
```

**观察性能：** 上下文约 300k 时生成速度 13–20 t/s。

### Gemma 4 26B — 256k 上下文

```powershell
.\llama-server.exe -m "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf" --host 127.0.0.1 --port 10000 -ngl 99 -c 256000 -b 8192 -ub 2048 --no-mmap --direct-io --temp 1.0 -np 1 -fa on --top-k 64 --top-p 0.95 --min-p 0 --cont-batching --metrics --chat-template-kwargs '{"preserve_thinking": true}' -ctv turbo3 -ctk turbo3 --jinja -tb 14 -t 14 --poll 100 --cpu-strict 1 --n-cpu-moe 14
```

**注意：** 我未能在此分支上启用多 token 预测 (MTP)。开发者可能还在完善中。

---

## 关键参数说明

| 参数 | 推荐值 | 说明 |
|---|---|---|
| `-ngl` | 99 | GPU 最大层数 |
| `-c` | 256000–356000 | 上下文大小（tokens） |
| `-b` | 8192 | 提示词读取的批大小 |
| `-ub` | 2048 | 微批处理 |
| `-tb` | 10–14 | 批处理线程数（↑ = 显存更多，处理更慢） |
| `-t` | 10–14 | 生成线程数 |
| `--n-cpu-moe` | 5–17 | MoE CPU 卸载 |
| `--jinja` | 是 | `--chat-template-file` 必需 |
| `-ctv/-ctk` | turbo2 或 turbo3 | 激活 **TurboQuant** — 压缩 KV 缓存。大多数模型用 turbo2，Gemma 4 用 turbo3 |
| `--no-mmap --direct-io` | 是 | 避免 pagefile，提高 Windows 性能 |
| `--cont-batching` | 是 | 连续批处理 |
| `--cpu-strict` | 1 | 对卸载层强制严格 CPU 模式 |

### `-b` 和 `-ub` — 提示词读取的最佳点

这两个参数**对提示词读取速度至关重要**。设置不当会导致模型完全无法使用，因为读取上下文太慢，根本不值得使用。

我找到的最佳点是 `-b 8192` 和 `-ub 2048`。使用这些值，读取速度可达约 1000–2000 t/s，同时不会占满显存。肯定还有更好的组合——我只测试了少数几个值，在这方面我不是很专业。如果你找到更好的点，请提交 issue 或 PR，我们共同分享。

### `--n-cpu-moe` — 决定一切的参数

这是**低显存 GPU 最重要的参数**：

- **低值（5）**：更多空闲显存，CPU 负载更小，速度更高。适用于短上下文或 16+ GB 显存的 GPU。
- **高值（14–17）**：更多 MoE 层交由 CPU 处理，生成速度较慢，但可以显著扩展上下文。Gemma 4 26B 等重型模型必需。

增加 `--n-cpu-moe` 可以增加上下文，但生成速度会下降。降低该值可以提高速度，但会减少最大可用上下文。

---

## 观察性能（目测，非精确测量）

我记录的数值是**从 WebUI 目测估算**的，并非来自精确测量工具。是非常粗略的参考：

- **Qwythos 9B**：~300k 上下文时生成速度约 13–20 t/s
- **Gemma 4 26B**：`--n-cpu-moe` 较高时生成速度较慢，但值得，因为你需要良好的读取速度（~1000–2000 t/s）来处理 OpenCode 等使用的长上下文

请勿将这些值视为精确值。它们会因系统负载、温度、共享显存等因素而有很大差异。

---

## 适用人群

- **RTX 4060 / 4070 / 5060 / 5070** 用户，8–12 GB 显存
- 希望运行长上下文（128k–500k）而不想做无用功的人
- 使用 **OpenCode** 或类似工具、需要 MCP 与量化模型配合工作的人

---

## 仓库结构

```
├── README.md                  # English guide
├── readme_es.md               # Spanish guide
├── readme_zh.md               # 中文指南（本文件）
├── run.bat                    # 启动器
├── configs/
│   ├── qwythos-9b-300k.ps1    # Qwythos 命令
│   └── gemma-4-26b-256k.ps1   # Gemma 4 命令
├── templates/
│   └── 3.6_chat_template-v10.jinja  # MCP 模板
└── benchmarks/
    └── RESULTS.md             # 性能说明
```

---

## 如果你有不同型号的 GPU

尝试这些参数并记录下来。`configs/` 中的文件可以适配任何 RTX 系列 GPU。根据你的可用显存调整 `--n-cpu-moe`、`-tb`、`-t`、`-b`、`-ub` 和 `-c`。

## 许可证

MIT — 自由使用和分享。

---

🇪🇸 [Español](readme_es.md) · 🇬🇧 [English](README.md) · 🇨🇳 **中文**
