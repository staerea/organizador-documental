@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo  REANUDAR VIGILANTE (organizador-documental, M16)
echo ============================================================
if not exist "_ORGANIZACION\vigilante.pausa" (
  echo El vigilante no esta en pausa. No hay nada que reanudar.
  pause
  exit /b
)
if exist "ALERTA_INTEGRIDAD.txt" type "ALERTA_INTEGRIDAD.txt"
echo.
echo Reanude solo si ha revisado la alerta y se trata de una falsa alarma.
choice /C SN /M "Reanudar el vigilante"
if errorlevel 2 exit /b
powershell -NoProfile -ExecutionPolicy Bypass -Command "$o='_ORGANIZACION'; $d=Join-Path $o 'alertas'; New-Item -ItemType Directory -Path $d -Force | Out-Null; $s=Get-Date -Format 'yyyyMMdd_HHmmss'; Move-Item -LiteralPath (Join-Path $o 'vigilante.pausa') -Destination (Join-Path $d ('vigilante.pausa_retirada_'+$s+'.txt')); if (Test-Path -LiteralPath 'ALERTA_INTEGRIDAD.txt') { Move-Item -LiteralPath 'ALERTA_INTEGRIDAD.txt' -Destination (Join-Path $d ('ALERTA_INTEGRIDAD_'+$s+'.txt')) }; Write-Host 'Vigilante reanudado. La alerta queda archivada en _ORGANIZACION\alertas.'"
pause
