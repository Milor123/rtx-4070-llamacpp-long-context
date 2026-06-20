🇪🇸 **Español** · 🇬🇧 [English](README.md) · 🇨🇳 [中文](readme_zh.md)

---

# RTX 4070 + llama.cpp: Contexto Largo con Baja VRAM

Mi experiencia utilizando una **RTX 4070 (12 GB VRAM)** para correr modelos de lenguaje grande con contextos extendidos (hasta 300k–500k tokens) usando [llama.cpp](https://github.com/ggerganov/llama.cpp) y herramientas como [OpenCode](https://github.com/sgth/opencode) que dependen de MCPs y tool-calling interno.

---

## Hardware

| Componente | Detalle |
|---|---|
| GPU | NVIDIA RTX 4070 — **12 GB VRAM** |
| RAM | 48 GB DDR5 |
| CPU | Intel Core i5 14ª gen |

---

## Por qué compartir esto

Con 12 GB de VRAM no alcanza para correr modelos grandes con contextos largos "de fábrica". Después de probar varias configuraciones, forks y parámetros, llegué a un setup que me permite usar modelos como:

- **Qwythos 9B** con contexto de **300k tokens**
- **Gemma 4 26B** con contexto de **256k tokens**

Ambos con velocidades decentes y MCPs funcionando correctamente.

---

## Fork utilizado

Uso el fork mantenido por **AtomicBot-ai** que incluye mejoras de aceleración por GPU:

> [https://github.com/AtomicBot-ai/atomic-llama-cpp-turboquant](https://github.com/AtomicBot-ai/atomic-llama-cpp-turboquant)

### TurboQuant — el secreto detrás del contexto grande

Todo esto funciona gracias a **TurboQuant**, la tecnología de compresión de KV cache que viene en el fork de AtomicBot. Los flags `-ctv turbo2` y `-ctk turbo2` (o `turbo3` para Gemma 4) activan la compresión de la cache de keys/values, reduciendo drásticamente el consumo de VRAM por token de contexto.

¿Qué significa esto en la práctica?

- **Sin TurboQuant**: con 12 GB de VRAM apenas llegás a ~32k tokens
- **Con TurboQuant (turbo2)**: llegás a 300k+ tokens con el mismo modelo, misma GPU
- **Con TurboQuant (turbo3, Gemma 4)**: llegás a 256k tokens en un modelo de 26B parámetros

El costo es velocidad: la compresión/descompresión lleva tiempo, así que la generación es más lenta de lo que sería sin TurboQuant. Pero es un tradeoff totalmente aceptable cuando podés multiplicar por 10x tu contexto usable.

---

## El problema: MCPs no funcionaban

El modelo Qwythos no rendía bien con las herramientas internas de OpenCode (MCPs). El problema era el chat template: el que venía por defecto con el modelo no soportaba correctamente el formato de tool-calling. Lo solucioné adjuntando el template Jinja que está en `templates/3.6_chat_template-v10.jinja` (tomado de [este gist](https://gist.github.com/Milor123/ecb30311450c6b5fe581dab4df7515b7)).

Con ese template activado (`--chat-template-file ... --jinja`) los MCPs y las llamadas internas del modelo funcionan sin problemas.

---

## Configuraciones

### Qwythos 9B — 300k tokens de contexto

```powershell
.\llama-server.exe -m "Qwythos-9B-Claude-Mythos-5-1M-Q4_K_M.gguf" --host 127.0.0.1 --port 10000 -ngl 99 -c 356000 -b 8192 -ub 2048 --no-mmap --direct-io --temp 0.6 -np 1 -fa on --top-k 20 --repeat-penalty 1.05 --top-p 0.95 --min-p 0 --cont-batching --metrics --chat-template-kwargs '{"preserve_thinking": true}' -ctv turbo2 -ctk turbo2 --jinja -tb 10 -t 10 --poll 100 --cpu-strict 1 --n-cpu-moe 5 --chat-template-file "templates/3.6_chat_template-v10.jinja"
```

**Rendimiento observado:** 13–20 t/s en generación con ese contexto.

### Gemma 4 26B — 256k tokens de contexto

```powershell
.\llama-server.exe -m "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf" --host 127.0.0.1 --port 10000 -ngl 99 -c 256000 -b 8192 -ub 2048 --no-mmap --direct-io --temp 1.0 -np 1 -fa on --top-k 64 --top-p 0.95 --min-p 0 --cont-batching --metrics --chat-template-kwargs '{"preserve_thinking": true}' -ctv turbo3 -ctk turbo3 --jinja -tb 14 -t 14 --poll 100 --cpu-strict 1 --n-cpu-moe 14
```

**Nota:** MTP (Multi-Token Prediction) no logré que me funcionara con este fork. Quizás lxs desarrolladores aún están trabajando en eso.

---

## Parámetros clave explicados

| Parámetro | Valor recomendado | Nota |
|---|---|---|
| `-ngl` | 99 | Capa máxima en GPU |
| `-c` | 256000–356000 | Tamaño del contexto en tokens |
| `-b` | 8192 | Batch size para lectura de prompt |
| `-ub` | 2048 | Micro-batching |
| `-tb` | 10–14 | Threads para batch (↑ = más VRAM, procesamiento más lento) |
| `-t` | 10–14 | Threads de generación |
| `--n-cpu-moe` | 5–17 | MoE offloading a CPU |
| `--jinja` | sí | Necesario para usar `--chat-template-file` |
| `-ctv/-ctk` | turbo2 o turbo3 | Activación de **TurboQuant** — comprime la KV cache. turbo2 para la mayoría de modelos, turbo3 para Gemma 4 |
| `--no-mmap --direct-io` | sí | Evita pagefile, mejora rendimiento en Windows |
| `--cont-batching` | sí | Batching continuo |
| `--cpu-strict` | 1 | Fuerza CPU estricto para capas offloaded |

### `-b` y `-ub` — el punto dulce de la lectura

Estos dos parámetros son **determinantes para la velocidad de lectura (prompt ingestion)**. Si los seteas mal, el modelo se vuelve completamente inútil porque leer el contexto es tan lento que no vale la pena usarlo.

En mi caso encontré un punto dulce en `-b 8192` y `-ub 2048`. Con esos valores la lectura anda entre ~1000–2000 t/s sin saturar la VRAM. Seguro existen combinaciones mejores, yo probé pocos valores y no soy muy técnico en esto. Si encontrás un punto más dulce, abrí un issue o PR y lo compartimos.

### `--n-cpu-moe` — el parámetro que define todo

Este es **el parámetro más importante** para GPUs con poca VRAM:

- **Valor bajo** (5): más VRAM libre, menos carga en CPU, velocidades más altas. Útil para contextos cortos o GPUs con 16+ GB VRAM.
- **Valor alto** (14–17): más capas MoE van a CPU, más lenta la generación, pero se puede estirar el contexto significativamente. Necesario para modelos muy pesados como Gemma 4 26B.

Si aumentás `--n-cpu-moe`, podés incrementar el contexto, pero la velocidad de escritura cae. Bajarlo mejora la velocidad pero reduce el contexto máximo usable.

---

## Rendimiento observado (visual, no medido)

Los números que anoté son **visuales del WebUI**, no tomados de herramientas de medición precisas. Son referencias muy groseras:

- **Qwythos 9B**: velocidad de escritura entre ~13–20 t/s con contexto de ~300k tokens
- **Gemma 4 26B**: la generación es más lenta con el `--n-cpu-moe` alto, pero compensa porque necesitás buena velocidad de lectura (~1000–2000 t/s) para procesar contextos largos como los que usa OpenCode

No tomes estos valores como exactos. Varían mucho según carga del sistema, temperatura, VRAM compartida, etc.

---

## Para quién es esto

- Usuarios de **RTX 4060 / 4070 / 5060 / 5070** con 8–12 GB VRAM
- Quienes quieren correr contextos largos (128k–500k) sin morir en el intento
- Cualquiera que use **OpenCode** o similar y necesite MCPs funcionando con modelos quantizados

---

## Estructura de este repo

```
├── README.md                  # English guide
├── readme_es.md               # Esta guía (español)
├── readme_zh.md               # 中文版本
├── configs/
│   ├── qwythos-9b-300k.ps1    # Comando para Qwythos
│   ├── gemma-4-26b-256k.ps1   # Comando para Gemma 4
│   └── run.bat                # Lanzador
├── templates/
│   └── 3.6_chat_template-v10.jinja  # Template para MCPs
└── benchmarks/
    └── RESULTS.md             # Notas sobre rendimiento
```

---

## Si tenés otra GPU

Probá los parámetros y registralos. Los archivos `configs/` se pueden adaptar a cualquier GPU de la línea RTX. Cambiá sobre todo `--n-cpu-moe`, `-tb`, `-t`, `-b`, `-ub` y `-c` según tu VRAM disponible.

## Licencia

MIT — usá y compartí lo que quieras.

---

🇪🇸 **Español** · 🇬🇧 [English](README.md) · 🇨🇳 [中文](readme_zh.md)
