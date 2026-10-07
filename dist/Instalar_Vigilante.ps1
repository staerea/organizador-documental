<#  Instala el vigilante como tarea del Programador de tareas de Windows (usuario actual, cada 10 min).
    v1.9: permite arrancar y seguir con bateria (antes la tarea no arrancaba, o se cortaba, al desenchufar un portatil)
          y detiene una instancia colgada antes de volver a registrar la tarea. #>
$nombre = 'Organizador_DESCARGAS_Vigilante'
$script = Join-Path $PSScriptRoot 'Vigilante_Raiz.ps1'
try { Stop-ScheduledTask -TaskName $nombre -ErrorAction Stop } catch { }
$accion = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $script)
$disparo = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 10)
$ajustes = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $nombre -Action $accion -Trigger $disparo -Settings $ajustes -Description 'Detecta archivos nuevos en la raiz de DESCARGAS, aparta duplicados y aplica planes de clasificacion. Nunca borra.' -Force | Out-Null
$t = Get-ScheduledTask -TaskName $nombre; $i = Get-ScheduledTaskInfo -TaskName $nombre
Write-Host ('Vigilante instalado (v1.9). Estado: {0}. Proxima ejecucion: {1}. Cada 10 minutos mientras tu sesion de Windows este iniciada, tambien con bateria.' -f $t.State, $i.NextRunTime) -ForegroundColor Green
