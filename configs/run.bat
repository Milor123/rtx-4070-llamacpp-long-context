@echo off
title llama.cpp Model Launcher

echo.
echo   ==============================
echo     llama.cpp Model Launcher
echo   ==============================
echo.
echo   1) Qwythos 9B  - 300k context (turbo2)
echo   2) Gemma 4 26B - 256k context (turbo3)
echo.
set /p "model=Select 1 or 2: "

if "%model%"=="1" goto qwythos
if "%model%"=="2" goto gemma

echo Invalid selection.
goto end

:qwythos
echo.
echo Launching Qwythos 9B...
pwsh.exe -ExecutionPolicy Bypass -File "%~dp0qwythos-9b-300k.ps1"
goto end

:gemma
echo.
echo Launching Gemma 4 26B...
pwsh.exe -ExecutionPolicy Bypass -File "%~dp0gemma-4-26b-256k.ps1"
goto end

:end
pause