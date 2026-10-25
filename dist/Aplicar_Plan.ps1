<#  Aplica plan_<fecha>.csv: crea carpetas, mueve, renombra y aparta duplicados. NUNCA borra.
    Por defecto SIMULA; con -Ejecutar aplica. Actualiza el manifiesto (marcador de clasificados).
    Columnas del plan: Origen;Tipo;Destino;NuevoNombre;Accion;OriginalConservado;SHA256;Area
    v1.9.1: el registro y el manifiesto se escriben fila a fila (si la ejecucion se corta, lo hecho queda registrado y es reversible);
            en DUPLICADO con SHA256 vacio se comparan los hashes del duplicado y del original en el momento.
    v1.10.1: presupuesto de tiempo (-PresupuestoMin): si se agota, las filas que faltan se escriben en <plan>_resto_<hora>.csv
             junto al plan (planes_pendientes) y se aplican en la pasada siguiente, sin rozar el corte de 30 min de la tarea.
             Los archivos de mas de -MaxHashMB (1 GB) se mueven sin calcular su SHA-256 en ese momento (en Google Drive en
             streaming un hash de 4,5 GB tardo ~20 min); su fila del manifiesto queda con VersionSkill '1.10.1-sha-diferido'.
    v1.11: si un Origen cita una carpeta de entrada anterior (p. ej. nuevos\... tras renombrarla a INPUT) y ya no existe,
           se busca en la carpeta de entrada actual (config_plataforma.csv / entrada_historial.txt).   #>
param([Parameter(Mandatory=$true)][string]$Plan, [string]$Raiz = (Split-Path $PSScriptRoot -Parent), [switch]$Ejecutar, [int]$PresupuestoMin = 12, [int64]$MaxHashMB = 1024)
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
function Get-ZipHuella {
  # Huella de contenido de un ZIP: SHA-256 de la lista ordenada "ruta|tamano|CRC32" de sus archivos,
  # leida del directorio central (sin descomprimir). Ignora fechas internas, orden y nivel de compresion.
  param([string]$Path)
  $fs = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
  try {
    $len = $fs.Length; if ($len -lt 22) { return $null }
    $max = [int][Math]::Min($len, 65557); $buf = New-Object byte[] $max
    [void]$fs.Seek($len - $max, 'Begin'); $r = 0; while ($r -lt $max) { $r += $fs.Read($buf, $r, $max - $r) }
    $e = -1; for ($i = $max - 22; $i -ge 0; $i--) { if ([BitConverter]::ToUInt32($buf, $i) -eq 0x06054b50) { $e = $i; break } }
    if ($e -lt 0) { return $null }
    $n = [uint64][BitConverter]::ToUInt16($buf, $e + 10); $cdSize = [uint64][BitConverter]::ToUInt32($buf, $e + 12); $cdOff = [uint64][BitConverter]::ToUInt32($buf, $e + 16)
    if (($cdOff -eq 0xFFFFFFFF -or $n -eq 0xFFFF) -and $e -ge 20 -and [BitConverter]::ToUInt32($buf, $e - 20) -eq 0x07064b50) {
      $z64 = [BitConverter]::ToUInt64($buf, $e - 12); $b64 = New-Object byte[] 56; [void]$fs.Seek([int64]$z64, 'Begin'); [void]$fs.Read($b64, 0, 56)
      $n = [BitConverter]::ToUInt64($b64, 32); $cdSize = [BitConverter]::ToUInt64($b64, 40); $cdOff = [BitConverter]::ToUInt64($b64, 48) }
    $cd = New-Object byte[] ([int]$cdSize); [void]$fs.Seek([int64]$cdOff, 'Begin'); $r = 0; while ($r -lt $cd.Length) { $k = $fs.Read($cd, $r, $cd.Length - $r); if ($k -le 0) { break }; $r += $k }
    try { $cp437 = [Text.Encoding]::GetEncoding(437) } catch { $cp437 = [Text.Encoding]::GetEncoding(28591) }
    $lines = New-Object System.Collections.Generic.List[string]; $p = 0
    while ($p + 46 -le $cd.Length -and [BitConverter]::ToUInt32($cd, $p) -eq 0x02014b50) {
      $flag = [BitConverter]::ToUInt16($cd, $p + 8); $crc = [BitConverter]::ToUInt32($cd, $p + 16); $size = [uint64][BitConverter]::ToUInt32($cd, $p + 24)
      $nl = [BitConverter]::ToUInt16($cd, $p + 28); $xl = [BitConverter]::ToUInt16($cd, $p + 30); $cl = [BitConverter]::ToUInt16($cd, $p + 32)
      $enc = if ($flag -band 0x800) { [Text.Encoding]::UTF8 } else { $cp437 }
      $name = $enc.GetString($cd, $p + 46, $nl).Replace('\','/')
      if ($size -eq 0xFFFFFFFF) { $x = $p + 46 + $nl; $xe = $x + $xl
        while ($x + 4 -le $xe) { $id = [BitConverter]::ToUInt16($cd, $x); $sz = [BitConverter]::ToUInt16($cd, $x + 2)
          if ($id -eq 1) { $size = [BitConverter]::ToUInt64($cd, $x + 4); break }; $x += 4 + $sz } }
      if (-not $name.EndsWith('/') -and $name -notmatch '(^|/)__MACOSX/') { $lines.Add(('{0}|{1}|{2:x8}' -f $name, $size, $crc)) }
      $p += 46 + $nl + $xl + $cl }
    if ($lines.Count -eq 0) { return $null }
    $lines.Sort([StringComparer]::Ordinal)
    $sha = [Security.Cryptography.SHA256]::Create()
    $h = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))) | ForEach-Object { $_.ToString('x2') })
    return [pscustomobject]@{ Huella = $h; Entradas = $lines.Count }
  } catch { return $null } finally { $fs.Dispose() }
}
$org = Join-Path $Raiz '_ORGANIZACION'; $man = Join-Path $org 'manifiesto_documental.csv'
$entradaAct = (Get-ConfigPlataforma $org).CarpetaEntrada; $entradasAnt = @('nuevos')
$hp = Join-Path $org 'entrada_historial.txt'; if (Test-Path -LiteralPath $hp) { $entradasAnt += @(Get-Content -LiteralPath $hp -Encoding UTF8 | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) }
$entradasAnt = @($entradasAnt | Where-Object { $_ -ine $entradaAct } | Select-Object -Unique)
function Origen([string]$o) {   # v1.11
  $s = Join-Path $Raiz $o; if (Test-Path -LiteralPath $s) { return $s }
  foreach ($a in $entradasAnt) { if ($o.StartsWith($a + '\', [StringComparison]::OrdinalIgnoreCase)) {
      $alt = Join-Path $Raiz ($entradaAct + $o.Substring($a.Length)); if (Test-Path -LiteralPath $alt) { return $alt } } }
  return $s }
$filas = @(Import-Csv -LiteralPath $Plan -Delimiter ';' -Encoding UTF8 | Sort-Object @{Expression={$_.Accion -notlike 'DUPLICADO*'}})
$sello = Get-Date -Format 'yyyyMMdd_HHmmss'; $log = New-Object System.Collections.Generic.List[object]
New-Item -ItemType Directory -Path $org -Force | Out-Null
$logPath = Join-Path $org "registro_$sello.csv"
function Reg($o,$d,$e) { $r = [pscustomobject]@{Origen=$o;Destino=$d;Estado=$e}; $log.Add($r); $r | Export-Csv -LiteralPath $logPath -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append }
$nuevosMan = New-Object System.Collections.Generic.List[object]
function Sha([string]$p) { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() }
function ShaMan([string]$p) { if (Test-GoogleNativo $p) { return '' }; if ((Get-Item -LiteralPath $p).Length -gt $MaxHashMB * 1MB) { return '' }; Sha $p }   # v1.10.1
# v1.11.4: indice SHA-256 -> ruta de los archivos vigentes del manifiesto. Toda fila MOVER de un archivo se compara con el:
#          si su contenido ya existe en el archivo (o en una fila anterior del mismo plan), se aparta a _DUPLICADOS_REVISAR
#          como copia verificada en vez de entrar con un sufijo _vN. Evita que dos archivos identicos parezcan versiones.
$idxSha = @{}
if (Test-Path -LiteralPath $man) {
  $ultimo = @{}
  foreach ($m in @(Import-Csv -LiteralPath $man -Delimiter ';' -Encoding UTF8)) { if ($m.RutaRelativa) { $ultimo[$m.RutaRelativa.ToLower()] = $m } }
  foreach ($m in $ultimo.Values) {
    if ($m.SHA256 -and $m.Estado -in @('HEREDADO','MOVIDO','MOVIDO_HASH_NO_VERIFICADO','MOVIDO_HUELLA_NO_VERIFICADA') -and $m.RutaRelativa -notmatch '^_DUPLICADOS_REVISAR[\\/]') {
      $k = $m.SHA256.ToLower(); if (-not $idxSha.ContainsKey($k)) { $idxSha[$k] = $m.RutaRelativa } } } }
function CopiaLibre([string]$origRel) {
  $partes = @($origRel -split '[\\/]' | Where-Object { $_ }); $hoja = $partes[-1]; $d = ($partes[0..([Math]::Max(0,$partes.Count-2))] -join '\'); if ($partes.Count -lt 2) { $d = '' }
  $b = [IO.Path]::GetFileNameWithoutExtension($hoja); $e = [IO.Path]::GetExtension($hoja)
  $dir = Join-Path (Join-Path $Raiz '_DUPLICADOS_REVISAR') $d; $n = 1
  while (Test-Path -LiteralPath (Join-Path $dir ('{0}__COPIA_{1}{2}' -f $b,$n,$e))) { $n++ }
  return @{ Rel = (Join-Path '_DUPLICADOS_REVISAR' $d); Nombre = ('{0}__COPIA_{1}{2}' -f $b,$n,$e) } }
$reloj = [Diagnostics.Stopwatch]::StartNew(); $i = -1
function Libre([string]$dir,[string]$n,[bool]$carpeta) {
  $t = Join-Path $dir $n; if (-not (Test-Path -LiteralPath $t)) { return $t }
  if ($carpeta) { $b=$n; $e='' } else { $b=[IO.Path]::GetFileNameWithoutExtension($n); $e=[IO.Path]::GetExtension($n) }
  $k=2; do { $t = Join-Path $dir ("{0} [org{1}]{2}" -f $b,$k,$e); $k++ } while (Test-Path -LiteralPath $t); return $t }
foreach ($f in $filas) {
  $i++
  if ($Ejecutar -and $reloj.Elapsed.TotalMinutes -ge $PresupuestoMin) {   # v1.10.1: el resto, a un plan nuevo para la pasada siguiente
    $resto = Join-Path (Split-Path -Parent $Plan) ('{0}_resto_{1}.csv' -f [IO.Path]::GetFileNameWithoutExtension($Plan), (Get-Date -Format 'HHmmss'))
    $filas[$i..($filas.Count-1)] | Export-Csv -LiteralPath $resto -Delimiter ';' -NoTypeInformation -Encoding UTF8
    Reg $Plan $resto ('PLAN_APLAZADO: {0} filas pendientes' -f ($filas.Count - $i)); break }
  $src = Origen $f.Origen
  if (-not (Test-Path -LiteralPath $src)) { Reg $src '' 'NO_ENCONTRADO'; continue }
  $destRel = $f.Destino; $nuevo = $f.NuevoNombre; $estado = 'MOVIDO'; $carpeta = ($f.Tipo -eq 'carpeta')
  if ($f.Accion -eq 'DUPLICADO_ZIP') {   # mismo contenido interno, distinto archivo ZIP: se verifica recalculando la huella de ambos
    $orig = Join-Path $Raiz $f.OriginalConservado; $h1 = Get-ZipHuella $src; $h2 = if (Test-Path -LiteralPath $orig) { Get-ZipHuella $orig } else { $null }
    if ($h1 -and $h2 -and $h1.Huella -eq $h2.Huella) { $estado = 'DUPLICADO_ZIP_VERIFICADO' }
    else { $destRel = $destRel -replace '^_DUPLICADOS_REVISAR[\\/]',''; $nuevo = $nuevo -replace '__COPIA_','__DIFERENTE_'; $estado='MOVIDO_HUELLA_NO_VERIFICADA' }
  }
  elseif ($f.Accion -eq 'DUPLICADO') {
    $orig = Join-Path $Raiz $f.OriginalConservado
    if ($f.SHA256) { $ok = (Test-Path -LiteralPath $orig) -and ((Sha $src) -eq $f.SHA256.ToLower()) -and ((Sha $orig) -eq $f.SHA256.ToLower()) }
    else { $ok = (Test-Path -LiteralPath $orig) -and ((Get-Item -LiteralPath $src).Length -eq (Get-Item -LiteralPath $orig).Length) -and ((Sha $src) -eq (Sha $orig)) }
    if ($ok) { $estado = 'DUPLICADO_VERIFICADO' } else { $destRel = $destRel -replace '^_DUPLICADOS_REVISAR[\\/]',''; $nuevo = $nuevo -replace '__COPIA_','__DIFERENTE_'; $estado='MOVIDO_HASH_NO_VERIFICADO' }
  }
  $shaCalc = ''
  if ($f.Accion -notlike 'DUPLICADO*' -and -not $carpeta -and -not (Test-GoogleNativo $src)) {   # v1.11.4
    $shaCalc = ShaMan $src
    if ($shaCalc -and $idxSha.ContainsKey($shaCalc)) {
      $origRel = $idxSha[$shaCalc]; $origAbs = Join-Path $Raiz $origRel
      $mismo = ([IO.Path]::GetFullPath($origAbs)).TrimEnd('\','/') -ieq ([IO.Path]::GetFullPath($src)).TrimEnd('\','/')   # v1.11.5: nunca duplicado de si mismo
      if (-not $mismo -and (Test-Path -LiteralPath $origAbs) -and ((Sha $origAbs) -eq $shaCalc)) {
        $c = CopiaLibre $origRel; $destRel = $c.Rel; $nuevo = $c.Nombre; $estado = 'DUPLICADO_VERIFICADO'
        Reg $src $origAbs 'DUPLICADO_DETECTADO_AL_APLICAR' } } }
  $destDir = Join-Path $Raiz $destRel; $target = Libre $destDir $nuevo $carpeta
  if ($Ejecutar) {
    try { if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
          Move-Item -LiteralPath $src -Destination $target
          $items = if ($carpeta) { @(Get-ChildItem -LiteralPath $target -Recurse -File -Force) } else { @(Get-Item -LiteralPath $target) }
          foreach ($fi in $items) {
            $filaMan = ([pscustomobject]@{ RutaRelativa=$fi.FullName.Substring($Raiz.Length).TrimStart('\','/'); SHA256=$(if($f.SHA256 -and -not $carpeta){$f.SHA256.ToLower()}elseif($shaCalc -and -not $carpeta){$shaCalc}else{ShaMan $fi.FullName});
              Tamano=$fi.Length; FechaMod=[int64]($fi.LastWriteTimeUtc-[datetime]'1970-01-01').TotalMilliseconds; Area=$f.Area; Estado=$estado;
              NombreOriginal=$(if($carpeta){(Split-Path -Leaf $src)+'/'+$fi.Name}else{Split-Path -Leaf $src}); FechaClasificacion=(Get-Date -Format 'yyyy-MM-dd'); VersionSkill=$(if ($fi.Length -gt $MaxHashMB * 1MB -and -not $f.SHA256) { '1.11.4-sha-diferido' } else { '1.11.4' }) })
            $nuevosMan.Add($filaMan); if (Test-Path -LiteralPath $man) { $filaMan | Export-Csv -LiteralPath $man -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append } else { $filaMan | Export-Csv -LiteralPath $man -Delimiter ';' -NoTypeInformation -Encoding UTF8 } } }
    catch { $estado = 'ERROR: ' + $_.Exception.Message }
    if ($shaCalc -and $estado -eq 'MOVIDO' -and -not $idxSha.ContainsKey($shaCalc)) { $idxSha[$shaCalc] = $target.Substring($Raiz.Length).TrimStart('\','/') }   # v1.11.4
  } else { $estado = 'SIMULADO_' + $estado }
  Reg $src $target $estado
}
Write-Host ('Modo: ' + $(if ($Ejecutar) {'EJECUCION REAL'} else {'SIMULACION'}))
foreach ($g in ($log | Group-Object { ($_.Estado -split ':')[0] } | Sort-Object Name)) { Write-Host ('{0,6}  {1}' -f $g.Count, $g.Name) }
Write-Host "Registro: $logPath"
