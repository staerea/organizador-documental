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
# --- v1.11: configuracion de la plataforma (config_plataforma.csv junto a los scripts) ---
function Get-ConfigPlataforma([string]$dir) {
  $c = [ordered]@{ RaizDocumental = ''; CarpetaEntrada = 'INPUT'; CarpetaSolicitudes = '%DESCARGAS_NAVEGADOR%'; IntervaloVigilanteMin = '60'; CaducidadSolicitudHoras = '24'; ModoBorrados = 'INFORME' }
  $p = Join-Path $dir 'config_plataforma.csv'
  if (Test-Path -LiteralPath $p) {
    try { foreach ($f in @(Import-Csv -LiteralPath $p -Delimiter ';' -Encoding UTF8)) {
        $k = "$($f.Clave)".Trim(); if ($k -and $c.Contains($k)) { $c[$k] = "$($f.Valor)".Trim() } } } catch { } }
  if (-not $c.CarpetaEntrada -or $c.CarpetaEntrada -match '[\\/:*?"<>|]' -or $c.CarpetaEntrada -match '^(\.|_|\d\d_)') { $c.CarpetaEntrada = 'INPUT' }
  # v1.11.2: valores numericos y modo de borrado validados; ante cualquier duda, el modo seguro (INFORME)
  $n = 0; if (-not [int]::TryParse("$($c.IntervaloVigilanteMin)", [ref]$n) -or $n -lt 10 -or $n -gt 240) { $c.IntervaloVigilanteMin = '60' }
  $n = 0; if (-not [int]::TryParse("$($c.CaducidadSolicitudHoras)", [ref]$n) -or $n -lt 1 -or $n -gt 720) { $c.CaducidadSolicitudHoras = '24' }
  if ("$($c.ModoBorrados)" -ine 'ACTIVO') { $c.ModoBorrados = 'INFORME' } else { $c.ModoBorrados = 'ACTIVO' }
  return $c }
function Get-CarpetaDescargasNavegador {
  # Carpeta "Descargas" de Windows (la que usan por defecto Edge, Chrome y Firefox); admite redireccion a otro disco.
  $d = $null
  try { $v = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction Stop).'{374DE290-123F-4565-9164-39C4925E467B}'
        if ($v) { $d = [Environment]::ExpandEnvironmentVariables($v) } } catch { }
  if (-not $d -and $env:USERPROFILE) { $d = Join-Path $env:USERPROFILE 'Downloads' }
  if (-not $d -and $env:HOME) { $d = Join-Path $env:HOME 'Downloads' }
  return $d }
function Resolve-CarpetasSolicitudes([string]$valor) {
  $r = New-Object System.Collections.Generic.List[string]
  foreach ($x in ("$valor" -split '\|')) { $x = $x.Trim(); if (-not $x) { continue }
    if ($x -ieq '%DESCARGAS_NAVEGADOR%') { $x = Get-CarpetaDescargasNavegador } else { $x = [Environment]::ExpandEnvironmentVariables($x) }
    if ($x -and -not $r.Contains($x)) { $r.Add($x) } }
  return ,$r }
# --- v1.11.1: archivos nativos de Google (.gdoc, .gsheet...) son accesos a documentos en la nube: no se pueden leer ni hashear ---
function Test-GoogleNativo([string]$ruta) { return ([IO.Path]::GetExtension($ruta) -imatch '^\.(gdoc|gsheet|gslides|gdraw|gform|gmap|gsite|gjam|gtable|gscript|glink|gnote)$') }
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
