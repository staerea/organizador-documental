<#  Instala el vigilante como tarea del Programador de tareas de Windows (usuario actual, cada 10 min).
    v1.9: permite arrancar y seguir con bateria (antes la tarea no arrancaba, o se cortaba, al desenchufar un portatil)
          y detiene una instancia colgada antes de volver a registrar la tarea.
    v1.11: la raiz, la entrada y las carpetas de recogida se leen de config_plataforma.csv (CONFIGURAR_PLATAFORMA.bat). #>
$nombre = 'Organizador_DESCARGAS_Vigilante'
$script = Join-Path $PSScriptRoot 'Vigilante_Raiz.ps1'
try { Stop-ScheduledTask -TaskName $nombre -ErrorAction Stop } catch { }
$accion = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $script)
$disparo = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 10)
$ajustes = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $nombre -Action $accion -Trigger $disparo -Settings $ajustes -Description 'Organizador documental: detecta archivos nuevos en la raiz configurada, aparta duplicados, aplica planes de clasificacion y atiende las solicitudes del panel. Solo borra copias verificadas que el usuario solicita.' -Force | Out-Null
$t = Get-ScheduledTask -TaskName $nombre; $i = Get-ScheduledTaskInfo -TaskName $nombre
Write-Host ('Vigilante instalado (v1.11). Estado: {0}. Proxima ejecucion: {1}. Cada 10 minutos mientras tu sesion de Windows este iniciada, tambien con bateria.' -f $t.State, $i.NextRunTime) -ForegroundColor Green
