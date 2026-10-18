@echo off
title Fusion Menu installer
rem The installer sets up a database service, firewall and shortcuts, so it asks Windows for admin rights.
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Asking Windows for permission to install... click Yes.
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    if errorlevel 1 (
        echo.
        echo Permission was not given. Running without admin rights instead.
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\install.ps1"
        pause
    )
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\install.ps1"
echo.
pause
