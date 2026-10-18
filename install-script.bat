@echo off
rem Installs or upgrades a QBCore script, vehicle, EUP or map pack. Drag its zip or folder onto this file.
rem Your config and locale changes are kept.
if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\update.ps1" -Mode script
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\update.ps1" -Mode script -Source "%~1"
)
pause
