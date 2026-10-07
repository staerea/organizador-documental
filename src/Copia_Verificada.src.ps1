<#  M15 - COPIA DE SEGURIDAD VERIFICABLE (organizador-documental v1.11).
    Copia incremental SIN ESPEJO de las areas configuradas a un destino NO sincronizado (disco externo u otra unidad).
    - Nunca borra ni sobrescribe nada en el destino: si un archivo cambia, la version nueva se guarda junto a la anterior
      como <nombre>__v<AAAAMMDD_HHmmss>.<ext>; asi un cifrado en origen no destruye la copia buena.
    - Verifica cada copia recalculando el SHA-256 en destino. Resultado: _ORGANIZACION\copia_<AAAAMMDD>.csv
      (Fecha;Archivo;SHA256Origen;SHA256Destino;Estado). Indice de lo copiado: <Destino>\<raiz>\_copia_indice.csv.
    - No actua si el vigilante esta en pausa por alerta M16 (no se copian archivos posiblemente cifrados).
    - Parametros en config_modulos.csv (fila M15): Destino=, Areas=, MaxGBPorPasada= (por defecto 50).
    - La lanza el vigilante una vez al dia en segundo plano; se puede ejecutar a mano. Si se agota el presupuesto,
      la pasada siguiente continua donde quedo.   #>
param([string]$Raiz = (Split-Path $PSScriptRoot -Parent), [string]$Destino = '', [string]$Areas = '', [double]$MaxGBPorPasada = 0, [int]$PresupuestoMin = 120)
$ErrorActionPreference = 'Stop'
$Raiz = $Raiz.TrimEnd('\','/')
$org = Join-Path $Raiz '_ORGANIZACION'; $hoy = Get-Date -Format 'yyyyMMdd'
$resPath = Join-Path $org ("copia_{0}.csv" -f $hoy); $marca = Join-Path $org 'copia_ultima.txt'; $lock = Join-Path $org 'copia.lock'
$cfg = @{ Destino = ''; Areas = '01_STAEREA_PROYECTOS,02_STAEREA_ADMIN,08_ASESORIA_LABORAL_FISCAL,09_PERSONAL_SENSIBLE'; MaxGBPorPasada = '50' }
$cfgPath = Join-Path $org 'config_modulos.csv'
if (Test-Path -LiteralPath $cfgPath) {
  $fila = Import-Csv -LiteralPath $cfgPath -Delimiter ';' -Encoding UTF8 | Where-Object { $_.Modulo -eq 'M15' } | Select-Object -First 1
  if ($fila) { foreach ($kv in ("$($fila.Parametros)" -split '\|')) { if ($kv -match '^\s*([^=]+)=(.*)$' -and $matches[2].Trim()) { $cfg[$matches[1].Trim()] = $matches[2].Trim() } } } }
if (-not $Destino) { $Destino = [Environment]::ExpandEnvironmentVariables($cfg.Destino) }
if (-not $Areas) { $Areas = $cfg.Areas }
if ($MaxGBPorPasada -le 0) { $MaxGBPorPasada = [double]$cfg.MaxGBPorPasada }
function Res($a,$so,$sd,$e) { [pscustomobject]@{ Fecha=(Get-Date -Format s); Archivo=$a; SHA256Origen=$so; SHA256Destino=$sd; Estado=$e } |
  Export-Csv -LiteralPath $resPath -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append }
function Marca($estado) { Set-Content -LiteralPath $marca -Value ("{0};{1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $estado) -Encoding UTF8 }
if (Test-Path -LiteralPath (Join-Path $org 'vigilante.pausa')) { Res '' '' '' 'NO_EJECUTADA_PAUSA_M16'; return }
if (-not $Destino) { Res '' '' '' 'SIN_DESTINO_CONFIGURADO'; Marca 'SIN_DESTINO'; return }
if (-not (Test-Path -LiteralPath $Destino -PathType Container)) { Res $Destino '' '' 'DESTINO_NO_DISPONIBLE'; return }   # disco desconectado: se reintenta
$rD = (Resolve-Path -LiteralPath $Destino).Path.TrimEnd('\','/'); $rR = (Resolve-Path -LiteralPath $Raiz).Path.TrimEnd('\','/')
if ($rD.StartsWith($rR, [StringComparison]::OrdinalIgnoreCase) -or $rD -match '\\Mi unidad(\\|$)|\\My Drive(\\|$)|Google Drive|OneDrive|Dropbox') {
  Res $Destino '' '' 'DESTINO_RECHAZADO_SINCRONIZADO'; Marca 'DESTINO_RECHAZADO'; return }   # una copia dentro de la nube sincronizada no protege
if (Test-Path -LiteralPath $lock) { $ed = ((Get-Date) - (Get-Item -LiteralPath $lock).LastWriteTime).TotalMinutes; if ($ed -lt ($PresupuestoMin + 30)) { return } }
Set-Content -LiteralPath $lock -Value ("{0}|{1}" -f (Get-Date -Format s), $PID)
try {
  $base = Join-Path $Destino (Split-Path -Leaf $Raiz); if (-not (Test-Path -LiteralPath $base)) { New-Item -ItemType Directory -Path $base | Out-Null }
  $idxPath = Join-Path $base '_copia_indice.csv'; $idx = @{}
  if (Test-Path -LiteralPath $idxPath) { foreach ($x in (Import-Csv -LiteralPath $idxPath -Delimiter ';' -Encoding UTF8)) { $idx[$x.RutaRelativa] = $x } }
  function IdxAdd($o) { $o | Export-Csv -LiteralPath $idxPath -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append; $idx[$o.RutaRelativa] = $o }
  function ShaDe([string]$p) { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() }
  $reloj = [Diagnostics.Stopwatch]::StartNew(); $bytes = [int64]0; $lim = [int64]($MaxGBPorPasada * 1GB)
  $nOk = 0; $nVer = 0; $nErr = 0; $agotado = $false
  foreach ($a in ($Areas -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $ad = Join-Path $Raiz $a; if (-not (Test-Path -LiteralPath $ad -PathType Container)) { Res $a '' '' 'AREA_NO_ENCONTRADA'; continue }
    foreach ($fp in [IO.Directory]::EnumerateFiles($ad, '*', [IO.SearchOption]::AllDirectories)) {
      if ($reloj.Elapsed.TotalMinutes -ge $PresupuestoMin -or $bytes -ge $lim) { $agotado = $true; break }
      $rel = $fp.Substring($Raiz.Length).TrimStart('\','/') -replace '/', '\'
      if ($rel -match '(^|\\)(desktop\.ini|thumbs\.db|~\$[^\\]*)$') { continue }
      try {
        $fi = Get-Item -LiteralPath $fp; $fm = [int64]($fi.LastWriteTimeUtc - [datetime]'1970-01-01').TotalMilliseconds
        $prev = $idx[$rel]
        if ($prev -and [int64]$prev.Tamano -eq $fi.Length -and [int64]$prev.FechaMod -eq $fm) { continue }   # sin cambios
        $so = ShaDe $fp
        if ($prev -and $prev.SHA256 -eq $so) { IdxAdd ([pscustomobject]@{ RutaRelativa=$rel; SHA256=$so; Tamano=$fi.Length; FechaMod=$fm; Copia=$prev.Copia; FechaCopia=$prev.FechaCopia }); continue }
        $relDst = $rel; $estado = 'COPIADO_VERIFICADO'
        if ($prev) { $e = [IO.Path]::GetExtension($rel); $relDst = $rel.Substring(0, $rel.Length - $e.Length) + ('__v{0}' -f (Get-Date -Format 'yyyyMMdd_HHmmss')) + $e; $estado = 'VERSION_NUEVA_VERIFICADA' }
        $dst = Join-Path $base ($relDst -replace '\\', [IO.Path]::DirectorySeparatorChar); $k = 2
        while (Test-Path -LiteralPath $dst) { $e = [IO.Path]::GetExtension($relDst); $dst = Join-Path $base ((($relDst.Substring(0, $relDst.Length - $e.Length)) + "__c$k" + $e) -replace '\\', [IO.Path]::DirectorySeparatorChar); $k++ }   # nunca sobrescribe
        $dd = Split-Path -Parent $dst; if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory -Path $dd -Force | Out-Null }
        Copy-Item -LiteralPath $fp -Destination $dst; $bytes += $fi.Length
        $sd = ShaDe $dst
        if ($sd -ne $so) { Res $rel $so $sd 'ERROR_VERIFICACION'; $nErr++; continue }   # la copia defectuosa se conserva para analisis; no se indexa
        IdxAdd ([pscustomobject]@{ RutaRelativa=$rel; SHA256=$so; Tamano=$fi.Length; FechaMod=$fm; Copia=$dst.Substring($base.Length).TrimStart('\','/'); FechaCopia=(Get-Date -Format s) })
        Res $rel $so $sd $estado; if ($prev) { $nVer++ } else { $nOk++ }
      } catch { Res $rel '' '' ('ERROR: ' + $_.Exception.Message); $nErr++ } }
    if ($agotado) { break } }
  $res = "copiados={0} versiones={1} errores={2} MB={3:N0}" -f $nOk, $nVer, $nErr, ($bytes / 1MB)
  if ($agotado) { Res '' '' '' ('PRESUPUESTO_AGOTADO; continua en la proxima pasada; ' + $res) }
  elseif ($nErr) { Res '' '' '' ('CON_ERRORES; se reintenta en la proxima pasada; ' + $res) }
  else { Marca ('COMPLETA; ' + $res) }
} finally { Remove-Item -LiteralPath $lock -ErrorAction SilentlyContinue }
