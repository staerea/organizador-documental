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
