<#  CONFIGURAR PLATAFORMA (organizador-documental v1.11).
    Edita _ORGANIZACION\config_plataforma.csv:
      RaizDocumental     carpeta raiz que se organiza (por defecto G:\Mi unidad\DESCARGAS)
      CarpetaEntrada     bandeja de entrada dentro de la raiz (por defecto INPUT)
      CarpetaSolicitudes carpetas donde se recogen los CSV que crea la interfaz (panel); varias separadas por |.
                         %DESCARGAS_NAVEGADOR% = carpeta Descargas de Windows (la que usan por defecto los navegadores).
                         Ademas, siempre se recogen de la raiz y de la carpeta de entrada.
    Sin parametros abre un menu. Con -Clave y -Valor cambia un valor sin preguntar (-Clave Restaurar vuelve a los valores
    por defecto). Nunca borra nada: al cambiar de raiz COPIA _ORGANIZACION a la nueva raiz (si no existe alli) y vuelve a
    registrar el vigilante apuntando a ella; la raiz anterior queda intacta.   #>
param([string]$Clave = '', [string]$Valor = '', [switch]$SinRegistrarTarea)
$ErrorActionPreference = 'Stop'
# --- v1.11: configuracion de la plataforma (config_plataforma.csv junto a los scripts) ---
function Get-ConfigPlataforma([string]$dir) {
  $c = [ordered]@{ RaizDocumental = ''; CarpetaEntrada = 'INPUT'; CarpetaSolicitudes = '%DESCARGAS_NAVEGADOR%' }
  $p = Join-Path $dir 'config_plataforma.csv'
  if (Test-Path -LiteralPath $p) {
    try { foreach ($f in @(Import-Csv -LiteralPath $p -Delimiter ';' -Encoding UTF8)) {
        $k = "$($f.Clave)".Trim(); if ($k -and $c.Contains($k)) { $c[$k] = "$($f.Valor)".Trim() } } } catch { } }
  if (-not $c.CarpetaEntrada -or $c.CarpetaEntrada -match '[\\/:*?"<>|]' -or $c.CarpetaEntrada -match '^(\.|_|\d\d_)') { $c.CarpetaEntrada = 'INPUT' }
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
$org = $PSScriptRoot; $cfgPath = Join-Path $org 'config_plataforma.csv'
$desc = [ordered]@{ RaizDocumental = 'Carpeta raiz que organiza el vigilante'; CarpetaEntrada = 'Bandeja de entrada dentro de la raiz';
                    CarpetaSolicitudes = 'Carpetas donde se recogen los CSV del panel (separadas por | - %DESCARGAS_NAVEGADOR% = Descargas de Windows)' }
$porDefecto = [ordered]@{ RaizDocumental = 'G:\Mi unidad\DESCARGAS'; CarpetaEntrada = 'INPUT'; CarpetaSolicitudes = '%DESCARGAS_NAVEGADOR%' }
function Guardar($c, [string]$ruta) {
  $filas = foreach ($k in $desc.Keys) { [pscustomobject]@{ Clave = $k; Valor = $c[$k]; Descripcion = $desc[$k] } }
  $tmp = $ruta + '.tmp'; $filas | Export-Csv -LiteralPath $tmp -Delimiter ';' -NoTypeInformation -Encoding UTF8
  Move-Item -LiteralPath $tmp -Destination $ruta -Force }
function Validar([string]$k, [string]$v, $c) {
  switch ($k) {
    'CarpetaEntrada' { if (-not $v -or $v -match '[\\/:*?"<>|]' -or $v -match '^(\.|_|\d\d_)') { throw "Nombre de entrada no valido: '$v' (sin barras ni signos, y sin empezar por _ , . ni NN_)." } }
    'RaizDocumental' { if (-not $v) { throw 'La raiz no puede quedar vacia.' }
                       if (-not (Test-Path -LiteralPath $v -PathType Container)) { throw "La carpeta '$v' no existe." } }
    'CarpetaSolicitudes' { foreach ($x in @(Resolve-CarpetasSolicitudes $v)) { if (-not (Test-Path -LiteralPath $x -PathType Container)) { Write-Warning "La carpeta '$x' no existe ahora; se usara cuando exista." } } }
    default { throw "Clave desconocida: $k" } } }
function Cambiar([string]$k, [string]$v) {
  $c = Get-ConfigPlataforma $org; if (-not $c.RaizDocumental) { $c.RaizDocumental = Split-Path $org -Parent }
  if ($k -eq 'Restaurar') { $c = [ordered]@{}; foreach ($x in $porDefecto.Keys) { $c[$x] = $porDefecto[$x] }; Guardar $c $cfgPath; Write-Host 'Valores por defecto restaurados.'; return }
  $v = $v.Trim().TrimEnd('\'); Validar $k $v $c; $antes = $c[$k]; $c[$k] = $v
  if ($k -eq 'RaizDocumental' -and $v -ine $antes) {
    $nuevaOrg = Join-Path $v '_ORGANIZACION'
    if (-not (Test-Path -LiteralPath $nuevaOrg)) { Copy-Item -LiteralPath $org -Destination $nuevaOrg -Recurse; Write-Host "Copiada _ORGANIZACION a $nuevaOrg (la original no se toca)." }
    foreach ($b in @(Get-ChildItem -LiteralPath (Split-Path $org -Parent) -Filter '*.bat' -File)) { $d = Join-Path $v $b.Name; if (-not (Test-Path -LiteralPath $d)) { Copy-Item -LiteralPath $b.FullName -Destination $d } }
    Guardar $c (Join-Path $nuevaOrg 'config_plataforma.csv'); Guardar $c $cfgPath
    if (-not $SinRegistrarTarea -and $env:OS -eq 'Windows_NT') { & (Join-Path $nuevaOrg 'Instalar_Vigilante.ps1') }
    Write-Host "Raiz cambiada a $v. El vigilante trabaja ahora con la copia de _ORGANIZACION de la nueva raiz."; return }
  Guardar $c $cfgPath; Write-Host ("{0}: '{1}' -> '{2}'" -f $k, $antes, $v)
  if ($k -eq 'CarpetaEntrada') { Write-Host 'En la proxima pasada el vigilante trasladara el contenido de la entrada anterior a la nueva (no borra nada).' } }
if ($Clave) { Cambiar $Clave $Valor; return }
while ($true) {
  $c = Get-ConfigPlataforma $org; if (-not $c.RaizDocumental) { $c.RaizDocumental = Split-Path $org -Parent }
  Write-Host ''; Write-Host '=== CONFIGURACION DE LA PLATAFORMA (organizador-documental v1.11) ===' -ForegroundColor Cyan
  Write-Host ("1) Raiz documental      : {0}" -f $c.RaizDocumental)
  Write-Host ("2) Carpeta de entrada   : {0}" -f $c.CarpetaEntrada)
  Write-Host ("3) Recogida de los CSV  : {0}" -f $c.CarpetaSolicitudes)
  Write-Host ("     (ahora mismo: {0}; y siempre la raiz y la entrada)" -f ((@(Resolve-CarpetasSolicitudes $c.CarpetaSolicitudes)) -join ' | '))
  Write-Host '4) Restaurar valores por defecto'; Write-Host '0) Salir'
  $o = Read-Host 'Opcion'
  try {
    switch ($o) {
      '1' { $v = Read-Host 'Nueva raiz (ruta completa de una carpeta existente)'; if ($v) { Cambiar 'RaizDocumental' $v } }
      '2' { $v = Read-Host 'Nuevo nombre de la carpeta de entrada'; if ($v) { Cambiar 'CarpetaEntrada' $v } }
      '3' { $v = Read-Host 'Carpetas de recogida (separadas por | - %DESCARGAS_NAVEGADOR% = Descargas de Windows)'; if ($v) { Cambiar 'CarpetaSolicitudes' $v } }
      '4' { Cambiar 'Restaurar' '' }
      '0' { return }
      default { Write-Host 'Opcion no valida.' } }
  } catch { Write-Host ('No se ha cambiado: ' + $_.Exception.Message) -ForegroundColor Yellow } }
