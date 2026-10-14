@echo off
chcp 65001 >nul
title Crimson Night - Vampire Game Server
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
if errorlevel 1 (
  echo.
  echo Server failed to start. Opening the game file directly instead...
  start "" "%~dp0index.html"
  pause
)
