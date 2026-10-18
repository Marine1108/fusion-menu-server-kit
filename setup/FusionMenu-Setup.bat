@echo off
title Fusion Menu setup
rem One-click setup: downloads the Fusion Menu server kit and sets up the whole server on this PC.
rem Windows asks for permission because a database service, firewall rule and shortcuts are set up.
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Asking Windows for permission to install... click Yes.
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/Marine1108/fusion-menu-server-kit/main/setup/get-fusion.ps1'))"
echo.
pause
