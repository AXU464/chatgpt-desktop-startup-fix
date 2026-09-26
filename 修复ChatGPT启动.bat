@echo off
title ChatGPT Runtime Fix
if not exist "%~dp0Fix-ChatGPTRuntime.ps1" (
    echo [ERROR] Fix-ChatGPTRuntime.ps1 not found next to this .bat
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-ChatGPTRuntime.ps1"
echo.
pause
