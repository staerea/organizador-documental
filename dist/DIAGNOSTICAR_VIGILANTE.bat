@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo  DIAGNOSTICO DEL VIGILANTE (solo lectura, no cambia nada)
echo ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "_ORGANIZACION\Diagnosticar_Vigilante.ps1"
pause
