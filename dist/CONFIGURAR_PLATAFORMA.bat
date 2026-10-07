@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "_ORGANIZACION\Configurar_Plataforma.ps1"
pause
