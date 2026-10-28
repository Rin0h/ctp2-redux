@echo off
rem ctp2-redux: HD-Grafiken aus der eigenen Installation erzeugen (siehe .ps1)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ctp2-redux-hochskalieren.ps1" %*
echo.
pause
