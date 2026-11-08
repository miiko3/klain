@echo off
chcp 65001 >nul
title Klain Lab
cd /d "%~dp0"
if not exist "node_modules\electron\dist\electron.exe" (
  echo [Klain Lab] Electron не найден. Устанавливаю...
  call npm install --no-audit --no-fund
)
echo [Klain Lab] Запускаю окно...
start "" "node_modules\electron\dist\electron.exe" .
