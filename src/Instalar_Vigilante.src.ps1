<#  Instala el vigilante como tarea del Programador de tareas de Windows (usuario actual).
    v1.9: permite arrancar y seguir con bateria y detiene una instancia colgada antes de volver a registrar la tarea.
    v1.11: la raiz, la entrada y las carpetas de recogida se leen de config_plataforma.csv (CONFIGURAR_PLATAFORMA.bat).
    v1.11.2: periodicidad configurable (IntervaloVigilanteMin, por defecto 60 min) y ejecucion SIN VENTANA: la tarea lanza
             wscript.exe con Vigilante_Oculto.vbs, que abre PowerShell oculto desde el inicio (powershell.exe -WindowStyle Hidden
             lanzado directamente por el Programador muestra un parpadeo de consola). Si wscript.exe o el .vbs no estan
             disponibles (VBScript es una caracteristica opcional de Windows en retirada progresiva), usa el metodo anterior.
             Limite por pasada: 55 min (los presupuestos internos del vigilante terminan antes).   #>
param([int]$IntervaloMin = 0)
$ErrorActionPreference = 'Stop'
#COMUN#
$nombre = 'Organizador_DESCARGAS_Vigilante'
$script = Join-Path $PSScriptRoot 'Vigilante_Raiz.ps1'; $vbs = Join-Path $PSScriptRoot 'Vigilante_Oculto.vbs'
if ($IntervaloMin -le 0) { $IntervaloMin = [int](Get-ConfigPlataforma $PSScriptRoot).IntervaloVigilanteMin }
try { Stop-ScheduledTask -TaskName $nombre -ErrorAction Stop } catch { }
$wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
if ((Test-Path -LiteralPath $wscript) -and (Test-Path -LiteralPath $vbs)) {
  $accion = New-ScheduledTaskAction -Execute $wscript -Argument ('//B //Nologo "{0}"' -f $vbs); $modo = 'sin ventana (wscript + PowerShell oculto)' }
else {
  $accion = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $script); $modo = 'PowerShell oculto (puede parpadear una ventana; VBScript no disponible)' }
$disparo = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervaloMin)
$ajustes = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 55) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $nombre -Action $accion -Trigger $disparo -Settings $ajustes -Description 'Organizador documental: detecta archivos nuevos en la raiz configurada, aparta duplicados, aplica planes de clasificacion y atiende las solicitudes del panel. Solo borra copias verificadas que el usuario solicita.' -Force | Out-Null
$t = Get-ScheduledTask -TaskName $nombre; $i = Get-ScheduledTaskInfo -TaskName $nombre
try { Set-Content -LiteralPath (Join-Path $PSScriptRoot 'tarea_vigilante.txt') -Value ("{0};intervalo={1};modo={2}" -f (Get-Date -Format s), $IntervaloMin, $modo) -Encoding UTF8 } catch { }
Write-Host ('Vigilante instalado (v1.11.2). Estado: {0}. Proxima ejecucion: {1}. Cada {2} minutos mientras su sesion de Windows este iniciada, tambien con bateria. Modo: {3}.' -f $t.State, $i.NextRunTime, $IntervaloMin, $modo) -ForegroundColor Green
