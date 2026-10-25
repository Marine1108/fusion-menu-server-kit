@echo off
rem Updates the FiveM server program (FXServer), and txAdmin with it. Stop the server first.
rem   update-fxserver.bat            the recommended build (the safe choice)
rem   update-fxserver.bat latest     the newest build (the newest txAdmin patch)
rem   update-fxserver.bat rollback   back to the build you had before
if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\update-fxserver.ps1"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\update-fxserver.ps1" -Choice %1
)
pause
