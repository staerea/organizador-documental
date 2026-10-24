<#  Diagnostico del vigilante (organizador-documental, v1.11.4). SOLO LECTURA: no cambia la tarea ni ningun archivo
    salvo el informe _ORGANIZACION\diagnostico_vigilante_<fecha>.txt. Lo ejecuta el usuario con DIAGNOSTICAR_VIGILANTE.bat.   #>
$ErrorActionPreference = 'Continue'
$nombre = 'Organizador_DESCARGAS_Vigilante'
$sello = Get-Date -Format 'yyyyMMdd_HHmmss'
$out = Join-Path $PSScriptRoot ('diagnostico_vigilante_{0}.txt' -f $sello)
$l = New-Object System.Collections.Generic.List[string]
function A([string]$t) { $l.Add($t); Write-Host $t }
A ('DIAGNOSTICO DEL VIGILANTE - {0}' -f (Get-Date -Format 's'))
A ('Equipo: {0} | Usuario: {1}' -f $env:COMPUTERNAME, $env:USERNAME)
try { $os = Get-CimInstance Win32_OperatingSystem; A ('Windows: {0} compilacion {1} | ultimo arranque: {2:s}' -f $os.Caption, $os.BuildNumber, $os.LastBootUpTime) } catch { A ('Windows: no disponible ({0})' -f $_.Exception.Message) }
A ''
A '--- Tarea programada ---'
try {
  $t = Get-ScheduledTask -TaskName $nombre -ErrorAction Stop; $i = Get-ScheduledTaskInfo -TaskName $nombre
  A ('Estado: {0}' -f $t.State)
  A ('Ultima ejecucion: {0:s} | Resultado: 0x{1:X8} | Proxima: {2:s} | Ejecuciones perdidas: {3}' -f $i.LastRunTime, $i.LastTaskResult, $i.NextRunTime, $i.NumberOfMissedRuns)
  foreach ($a in $t.Actions) { A ('Accion: {0} {1}' -f $a.Execute, $a.Arguments) }
  foreach ($d in $t.Triggers) { A ('Disparador: {0} | inicio {1} | habilitado {2} | repeticion {3} durante {4}' -f $d.CimClass.CimClassName, $d.StartBoundary, $d.Enabled, $d.Repetition.Interval, $d.Repetition.Duration) }
  A ('Principal: {0} | LogonType {1} | RunLevel {2}' -f $t.Principal.UserId, $t.Principal.LogonType, $t.Principal.RunLevel)
  A ('Ajustes: StartWhenAvailable={0} | Limite={1} | MultipleInstances={2} | DisallowStartIfOnBatteries={3}' -f $t.Settings.StartWhenAvailable, $t.Settings.ExecutionTimeLimit, $t.Settings.MultipleInstances, $t.Settings.DisallowStartIfOnBatteries)
} catch { A ('TAREA NO ENCONTRADA o no legible: {0}' -f $_.Exception.Message) }
A ''
A '--- Lanzador sin ventana (VBScript) ---'
$ws = Join-Path $env:SystemRoot 'System32\wscript.exe'; $dll = Join-Path $env:SystemRoot 'System32\vbscript.dll'
A ('wscript.exe: {0} | vbscript.dll: {1} | Vigilante_Oculto.vbs: {2}' -f (Test-Path -LiteralPath $ws), (Test-Path -LiteralPath $dll), (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Vigilante_Oculto.vbs')))
try { $cap = Get-WindowsCapability -Online -Name 'VBSCRIPT*' -ErrorAction Stop; foreach ($c in $cap) { A ('Caracteristica {0}: {1}' -f $c.Name, $c.State) } } catch { A 'Caracteristica VBSCRIPT: no consultable sin permisos de administrador (no es un error)' }
try {
  $tmp = Join-Path $env:TEMP ('prueba_vbs_{0}.vbs' -f $sello); Set-Content -LiteralPath $tmp -Value 'WScript.Echo "VBS_OK"' -Encoding ASCII
  $r = & (Join-Path $env:SystemRoot 'System32\cscript.exe') //Nologo $tmp 2>&1; A ('Prueba de VBScript: {0}' -f (($r | Out-String).Trim()))
  Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
} catch { A ('Prueba de VBScript: FALLO {0}' -f $_.Exception.Message) }
A ''
A '--- Unidad y archivos ---'
$cfg = Join-Path $PSScriptRoot 'config_plataforma.csv'
if (Test-Path -LiteralPath $cfg) { foreach ($f in @(Import-Csv -LiteralPath $cfg -Delimiter ';' -Encoding UTF8)) { A ('Config {0} = {1}' -f $f.Clave, $f.Valor) } } else { A 'config_plataforma.csv: NO EXISTE' }
foreach ($n in 'vigilante.lock','vigilante.pausa','vigilante_sin_raiz.txt') { $p = Join-Path $PSScriptRoot $n; if (Test-Path -LiteralPath $p) { A ('{0}: EXISTE, contenido: {1}' -f $n, ((Get-Content -LiteralPath $p -TotalCount 3) -join ' | ')) } else { A ('{0}: no existe' -f $n) } }
$lat = Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'vigilante_latido_*.csv' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
if ($lat) { A ('Ultimas lineas de {0}:' -f $lat.Name); foreach ($x in (Get-Content -LiteralPath $lat.FullName -Tail 3)) { A ('  ' + $x) } }
A ''
A '--- Historial del Programador de tareas (ultimos 15 eventos de esta tarea, si el historial esta activado) ---'
try {
  $ev = Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 3000 -ErrorAction Stop | Where-Object { $_.Message -like ('*' + $nombre + '*') } | Select-Object -First 15
  if (-not $ev) { A 'Sin eventos de esta tarea (historial desactivado o sin ejecuciones recientes).' }
  foreach ($e in $ev) { A ('{0:s} | Id {1} | {2}' -f $e.TimeCreated, $e.Id, (($e.Message -split "`r?`n")[0])) }
} catch { A ('Historial no disponible: {0}' -f $_.Exception.Message) }
A ''
A '--- Prueba manual sin cambios (Test-Path de la raiz) ---'
try { $raiz = (Import-Csv -LiteralPath $cfg -Delimiter ';' -Encoding UTF8 | Where-Object Clave -eq 'RaizDocumental').Valor; A ('Raiz {0}: {1}' -f $raiz, (Test-Path -LiteralPath $raiz)) } catch { }
Set-Content -LiteralPath $out -Value $l -Encoding UTF8
A ''; A ('Informe guardado en: {0}' -f $out)
