@echo off
rem ctp2-redux: HD-Einrichtung / HD setup (window with steps, see ctp2-redux-hd-setup.ps1)
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0ctp2-redux-hd-setup.ps1" %*
