@echo off
rem Updates Fusion Menu without losing your settings, pictures or edits.
rem Put the zip from your Cfx.re keymaster in the "updates" folder and double-click this file,
rem or drag the zip onto this file. Stop the server first.
if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\update.ps1" -Mode fusion
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\update.ps1" -Mode fusion -Source "%~1"
)
pause
