@echo off
llama-server.exe -m "C:\Users\User\.vllm\gemma-4-26B-A4B-it-qat-UD\gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf" ^
  --host 127.0.0.1 --port 10000 -ngl 99 -c 256000 -b 8192 -ub 2048 ^
  --no-mmap --direct-io --temp 1.0 -np 1 -fa on ^
  --top-k 64 --top-p 0.95 --min-p 0 ^
  --cont-batching --metrics ^
  --chat-template-kwargs '{"preserve_thinking": true}' ^
  -ctv turbo3 -ctk turbo3 --jinja -tb 14 -t 14 --poll 100 ^
  --cpu-strict 1 --n-cpu-moe 14
