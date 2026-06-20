@echo off
llama-server.exe -m "C:\Users\User\.vllm\Qwythos-9B-Claude-Mythos-5-1M-GGUF\Qwythos-9B-Claude-Mythos-5-1M-Q4_K_M.gguf" ^
  --host 127.0.0.1 --port 10000 -ngl 99 -c 356000 -b 8192 -ub 2048 ^
  --no-mmap --direct-io --temp 0.6 -np 1 -fa on ^
  --top-k 20 --repeat-penalty 1.05 --top-p 0.95 --min-p 0 ^
  --cont-batching --metrics ^
  --chat-template-kwargs '{"preserve_thinking": true}' ^
  -ctv turbo2 -ctk turbo2 --jinja -tb 10 -t 10 --poll 100 ^
  --cpu-strict 1 --n-cpu-moe 5 ^
  --chat-template-file "%~dp0..\templates\3.6_chat_template-v10.jinja"
