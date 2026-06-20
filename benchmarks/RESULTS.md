# Resultados de benchmark

> **⚠️ Importante:** Estos números se obtuvieron a ojo mirando el WebUI de llama.cpp. No son mediciones precisas. Sirven como referencia de órdenes de magnitud únicamente. Para datos fiables, medí vos mismo con tu hardware.

---

| Modelo | Quant | Contexto | t/s lectura | t/s escritura | VRAM aprox. | GPU |
|---|---|---|---|---|---|---|
| Qwythos 9B (Claude Mythos 5.1) | Q4_K_M | 300k–356k | ~1000–2000 | 13–20 | ~12 GB | RTX 4070 12GB |
| Gemma 4 26B (experimental) | Q4_K_XL | 256k | ~1000–2000 | ~5–10 | ~12 GB | RTX 4070 12GB |

---

## Cómo medir vos mismo

Cuando levantes el servidor con `--metrics`, el WebUI muestra en tiempo real:
- `ppl` — tokens por segundo de procesamiento (prompt ingest)
- `n_decode` / `t_decode` — tokens por segundo de generación
- `nvmem` — VRAM usada

Podés registrar esos valores manualmente o con el flag `--log-json` si tu fork lo soporta.
