# Gemma 4 26B — 256k context (turbo3)
# Cambiá estas rutas si clonaste en otro lado:
$buildDir = "C:\Users\User\Documents\TEO\atomic-llama-cpp-turboquant\build\bin\Release"
$model    = "C:\Users\User\.vllm\gemma-4-26B-A4B-it-qat-UD\gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf"
$template = Join-Path $PSScriptRoot "..\templates\3.6_chat_template-v10.jinja"

$env:LLAMA_CHAT_TEMPLATE_KWARGS = '{"preserve_thinking": true}'
Set-Location $buildDir

cmd /c ".\llama-server.exe -m `"$model`" --host 127.0.0.1 --port 10000 -ngl 99 -c 256000 -b 8192 -ub 2048 --no-mmap --direct-io --temp 1.0 -np 1 -fa on --top-k 64 --top-p 0.95 --min-p 0 --cont-batching --metrics -ctv turbo3 -ctk turbo3 --jinja -tb 14 -t 14 --poll 100 --cpu-strict 1 --n-cpu-moe 14 --chat-template-file `"$template`""

pause
