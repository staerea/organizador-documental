<#  PANEL DE DUPLICADOS (organizador-documental v1.11.2).
    Genera _DUPLICADOS_REVISAR\PANEL_DUPLICADOS.html: un registro por grupo (documento clasificado que se conserva + todas sus
    copias en _DUPLICADOS_REVISAR), con miniaturas, ubicacion, estado de verificacion y marcado para borrar.
    El panel NO borra: crea SOLICITUD_BORRADO_DUPLICADOS_<fecha>.csv, que el vigilante verifica (SHA-256 o huella ZIP,
    original presente fuera de _DUPLICADOS_REVISAR) y ejecuta. Este script solo lee y escribe el propio panel.
    v1.11.2: copias de solicitudes caducadas (se pueden volver a marcar) y aviso del modo de borrado (INFORME/ACTIVO).
    v1.11: el panel indica en que carpetas recoge el vigilante las solicitudes (config_plataforma.csv; por defecto la
           carpeta Descargas del navegador, la raiz documental y la carpeta de entrada).
    v1.10.3: textos del original contenidos en su columna (sin solaparse con las copias) y huella SHA-256
             abreviada como 12 primeras + 12 ultimas cifras en el original y en cada copia (a 1 cm del estado).
    v1.10.2: PANEL_DUPLICADOS.html es fijo (solo se reescribe si cambia la plantilla) y los datos van en
    _DUPLICADOS_REVISAR\_panel\datos_1..3.js, rotatorios: se escribe el mas antiguo y, si esta bloqueado, el siguiente.
    Motivo: el 06-10-2026 el HTML quedo bloqueado (no se podia sobrescribir) y la pasada se colgo en la fase PANEL.   #>
param([string]$Raiz = (Split-Path $PSScriptRoot -Parent), [int]$PresupuestoSeg = 240)
$ErrorActionPreference = 'Stop'
#COMUN#
$org = Join-Path $Raiz '_ORGANIZACION'; $man = Join-Path $org 'manifiesto_documental.csv'
$dupDir = Join-Path $Raiz '_DUPLICADOS_REVISAR'; $salida = Join-Path $dupDir 'PANEL_DUPLICADOS.html'; $pdir = Join-Path $dupDir '_panel'
if (-not (Test-Path -LiteralPath $dupDir)) { New-Item -ItemType Directory -Path $dupDir | Out-Null }
$reloj = [Diagnostics.Stopwatch]::StartNew()
function Rel([string]$p) { $p.Substring($Raiz.Length).TrimStart('\','/') -replace '/', '\' }
function Abs([string]$r) { Join-Path $Raiz ($r -replace '\\', [IO.Path]::DirectorySeparatorChar) }
# --- manifiesto: ultima fila por ruta; rutas clasificadas por SHA ---
$porRel = @{}; $porSha = @{}
if (Test-Path -LiteralPath $man) {
  foreach ($m in (Import-Csv -LiteralPath $man -Delimiter ';' -Encoding UTF8)) {
    if (-not $m.RutaRelativa) { continue }
    $m.RutaRelativa = $m.RutaRelativa.Replace('/', '\')
    $k = $m.RutaRelativa.ToLowerInvariant(); $porRel[$k] = $m
    if ($m.SHA256 -and $m.Estado -notlike 'BORRADO*' -and $m.RutaRelativa -notlike '_DUPLICADOS_REVISAR*') {
      $s = $m.SHA256.ToLowerInvariant(); if (-not $porSha.ContainsKey($s)) { $porSha[$s] = New-Object System.Collections.Generic.List[string] }
      if (-not $porSha[$s].Contains($m.RutaRelativa)) { $porSha[$s].Add($m.RutaRelativa) } } } }
function ShaMan([string]$r) { $m = $porRel[$r.ToLowerInvariant()]; if ($m -and $m.SHA256 -and $m.Estado -notlike 'BORRADO*') { return $m.SHA256.ToLowerInvariant() }; return '' }
$rx = '^(?<b>.*)__COPIA(?<z>_CONTENIDO)?_\d+(?<e>\.[^.\\]*)?$'
$grupos = [ordered]@{}; $cortado = $false
foreach ($ruta in [IO.Directory]::EnumerateFiles($dupDir, '*', [IO.SearchOption]::AllDirectories)) {
  if ($reloj.Elapsed.TotalSeconds -gt $PresupuestoSeg) { $cortado = $true; break }
  $fi = New-Object IO.FileInfo $ruta
  if ($fi.Name -like 'PANEL_DUPLICADOS*' -or $fi.Name -ieq 'desktop.ini' -or $fi.FullName.StartsWith($pdir, [StringComparison]::OrdinalIgnoreCase)) { continue }
  $rel = Rel $fi.FullName; $sinPref = $rel.Substring('_DUPLICADOS_REVISAR\'.Length)
  $mDup = $porRel[$rel.ToLowerInvariant()]; $shaDup = ShaMan $rel
  $esZip = $false; $orig = $null
  $mm = [regex]::Match($sinPref, $rx)
  if ($mm.Success) { $orig = $mm.Groups['b'].Value + $mm.Groups['e'].Value; $esZip = $mm.Groups['z'].Success }
  if ($mDup -and $mDup.Estado -like '*ZIP*') { $esZip = $true }
  $origOk = $orig -and (Test-Path -LiteralPath (Abs $orig) -PathType Leaf)
  if (-not $origOk -and $shaDup -and $porSha.ContainsKey($shaDup)) {
    foreach ($c in $porSha[$shaDup]) { if (Test-Path -LiteralPath (Abs $c) -PathType Leaf) { $orig = $c; $origOk = $true; break } } }
  if (-not $orig) { $orig = $sinPref }
  $v = 'NO'; $motivo = ''; $oTam = $null; $shaOrig = ''
  if ($origOk) {
    $oTam = (Get-Item -LiteralPath (Abs $orig)).Length; $shaOrig = ShaMan $orig
    if ($esZip) { $v = 'ZIP' }
    elseif ($shaDup -and $shaOrig -and $shaDup -eq $shaOrig -and $oTam -eq $fi.Length) { $v = 'SHA' }
    elseif ($oTam -eq $fi.Length) { $v = 'TAM' }
    else { $motivo = 'El tamaño no coincide con el original' } }
  else { $motivo = 'Original no localizado: conserve esta copia' }
  $k = $orig.ToLowerInvariant()
  if (-not $grupos.Contains($k)) {
    $otros = @(); if ($shaOrig -and $porSha.ContainsKey($shaOrig)) { $otros = @($porSha[$shaOrig] | Where-Object { $_ -ne $orig } | Select-Object -First 5) }
    $grupos[$k] = [ordered]@{ o = $orig; os = $oTam; oe = [bool]$origOk; sha = $shaOrig; otros = @($otros); c = New-Object System.Collections.Generic.List[object] } }
  $grupos[$k].c.Add([ordered]@{ r = $rel; s = $fi.Length; f = $(if ($mDup -and $mDup.FechaClasificacion) { $mDup.FechaClasificacion } else { $fi.CreationTime.ToString('yyyy-MM-dd') }); v = $v; m = $motivo; h = $shaDup })
}
# --- historial de borrados (registro del vigilante, mes actual y anterior) ---
$borr = New-Object System.Collections.Generic.List[object]
foreach ($mes in @((Get-Date).AddMonths(-1), (Get-Date))) {
  $lp = Join-Path $org ("vigilante_{0}.csv" -f $mes.ToString('yyyyMM'))
  if (Test-Path -LiteralPath $lp) { foreach ($l in (Import-Csv -LiteralPath $lp -Delimiter ';' -Encoding UTF8)) {
    if ($l.Estado -like 'BORRADO*' -or $l.Estado -like 'NO_BORRADO*') {
      $r = $l.Origen; if ($r.StartsWith($Raiz, [StringComparison]::OrdinalIgnoreCase)) { $r = Rel $r }
      $borr.Add([ordered]@{ f = $l.Fecha.Replace('T', ' '); r = $r; e = $l.Estado }) } } } }
$borrados = @($borr | Select-Object -Last 300); [array]::Reverse($borrados)
# v1.11.2: copias de solicitudes caducadas (pendientes_confirmacion) que no figuran en ninguna solicitud vigente ni ejecutada
$cfgPl = Get-ConfigPlataforma $org; $solD = Join-Path $org 'borrados_solicitudes'; $caduc = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$pcDir = Join-Path $solD 'pendientes_confirmacion'
if (Test-Path -LiteralPath $pcDir) {
  foreach ($fc in @(Get-ChildItem -LiteralPath $pcDir -File -Filter 'SOLICITUD_BORRADO_DUPLICADOS_*.csv')) { try { foreach ($x in (Import-Csv -LiteralPath $fc.FullName -Delimiter ';' -Encoding UTF8)) { if ($x.RutaDuplicado) { [void]$caduc.Add($x.RutaDuplicado.TrimStart('\')) } } } catch { } }
  foreach ($fv in @(Get-ChildItem -LiteralPath $solD -File -Filter '*.csv' -ErrorAction SilentlyContinue) + @(Get-ChildItem -LiteralPath (Join-Path $solD 'procesadas') -File -Filter 'resultado_*.csv' -ErrorAction SilentlyContinue)) {
    try { foreach ($x in (Import-Csv -LiteralPath $fv.FullName -Delimiter ';' -Encoding UTF8)) { if ($x.RutaDuplicado) { [void]$caduc.Remove($x.RutaDuplicado.TrimStart('\')) } } } catch { } } }
$datos = [ordered]@{ iso = (Get-Date -Format 's'); generado = (Get-Date -Format 'dd/MM/yyyy HH:mm'); incompleto = $cortado; recogida = @(@(Resolve-CarpetasSolicitudes $cfgPl.CarpetaSolicitudes) + @($Raiz)); modoBorrados = $cfgPl.ModoBorrados; caducidadHoras = [int]$cfgPl.CaducidadSolicitudHoras; caducadas = @($caduc); grupos = @($grupos.Values); borrados = $borrados }
$json = ($datos | ConvertTo-Json -Depth 6 -Compress) -replace '</', '<\/'
$plantilla = @'
