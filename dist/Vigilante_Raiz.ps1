<#  VIGILANTE de la RAIZ (se ejecuta cada 10 min desde el Programador de tareas).
    1) Lo que aparece suelto en la raiz (archivos o carpetas), una vez estable:
       - duplicado exacto (SHA-256) o ZIP con mismo contenido -> _DUPLICADOS_REVISAR\<carpeta del original>\<original>__COPIA[_CONTENIDO]_n
       - resto -> carpeta de entrada (INPUT por defecto; cola para la clasificacion de Claude)
    2) Aplica automaticamente los planes que Claude deja en _ORGANIZACION\planes_pendientes\ (Aplicar_Plan.ps1 -Ejecutar).
    3) (v1.6, M16) Antes de actuar comprueba la integridad (Verificar_Integridad.ps1 -Modo Alerta); si hay alerta
       o existe _ORGANIZACION\vigilante.pausa, no hace nada. Una vez al dia lanza la muestra de integridad en segundo plano.
    4) (v1.9) Bloqueo con PID y fase; se considera huerfano si el proceso ya no existe o a los 35 min (la tarea se corta a los 30).
       Cada pasada deja una fila en _ORGANIZACION\vigilante_latido_<AAAAMM>.csv (inicio/fin, duracion, fase, saltos).
    5) (v1.9.2) La fase RAIZ tiene presupuesto ($PresupuestoRaizMin min): ante una llegada masiva sigue en la proxima pasada
       y no deja sin aplicar los planes ni roza el corte de 30 min. Cada duplicado apartado se escribe al momento en el
       manifiesto, y una fase CONCILIAR repone las filas que falten de pasadas cortadas (segun el registro del mes).
    6) (v1.10) Panel de duplicados: atiende las solicitudes SOLICITUD_BORRADO_DUPLICADOS_*.csv que crea
       _DUPLICADOS_REVISAR\PANEL_DUPLICADOS.html y regenera ese panel cuando hay cambios (o cada hora).
    7) (v1.11) Rutas configurables en _ORGANIZACION\config_plataforma.csv (CONFIGURAR_PLATAFORMA.bat): raiz documental
       (por defecto G:\Mi unidad\DESCARGAS), carpeta de entrada (por defecto INPUT; antes "nuevos") y carpetas donde se
       recogen las solicitudes de la interfaz (por defecto la carpeta Descargas del navegador, ademas de la raiz y la entrada).
       Si cambia el nombre de la entrada, la carpeta anterior se traslada sola (registro ENTRADA_MIGRADA) y los planes que aun
       citen el nombre antiguo se siguen aplicando. Una solicitud ya procesada que reaparece se archiva sin repetirla.
       Una vez al dia lanza la copia verificada (M15) si esta activa y su destino esta disponible.
    UNICA excepcion a "nunca borra": a peticion expresa del usuario (solicitud del panel) borra copias que esten DENTRO de
    _DUPLICADOS_REVISAR, solo si su original sigue fuera de esa carpeta y el contenido es identico (SHA-256, o huella ZIP);
    en Google Drive el borrado va a la papelera (30 dias). Cada decision queda en el registro, el resultado y el manifiesto.
    Fuera de ese caso, NUNCA borra nada. Todo queda en _ORGANIZACION\vigilante_<AAAAMM>.csv y en el manifiesto.   #>
param([string]$Raiz = '', [string]$Entrada = '', [int]$EsperaSeg = 120, [int]$HuerfanoMin = 35, [int]$PresupuestoM16Seg = 120, [int]$PresupuestoRaizMin = 15, [int]$PresupuestoConciliarSeg = 180, [int]$PresupuestoBorradoMin = 6, [int]$PanelMaxSeg = 300)
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
$cfgP = Get-ConfigPlataforma $PSScriptRoot
if (-not $Raiz) { $Raiz = if ($cfgP.RaizDocumental) { $cfgP.RaizDocumental } else { Split-Path $PSScriptRoot -Parent } }
$Raiz = $Raiz.TrimEnd('\','/'); if (-not $Entrada) { $Entrada = $cfgP.CarpetaEntrada }
if (-not (Test-Path -LiteralPath (Join-Path $Raiz '_ORGANIZACION') -PathType Container)) {   # v1.11: raiz no disponible (Drive sin montar, ruta mal configurada)
  try { Add-Content -LiteralPath (Join-Path $PSScriptRoot 'vigilante_sin_raiz.txt') -Value ("{0};raiz no disponible;{1}" -f (Get-Date -Format s), $Raiz) -Encoding UTF8 } catch { }
  return }
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
$lock = Join-Path $org 'vigilante.lock'
$latPath = Join-Path $org ("vigilante_latido_{0}.csv" -f (Get-Date -Format 'yyyyMM'))
$t0 = Get-Date; $script:fase = 'INICIO'
function Latido($evento,$detalle) {
  try { [pscustomobject]@{ Fecha=(Get-Date -Format s); Evento=$evento; Fase=$script:fase; DuracionSeg=[int]((Get-Date)-$t0).TotalSeconds; PID=$PID; Detalle=$detalle } |
    Export-Csv -LiteralPath $latPath -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append } catch { } }
function Fase($f) { $script:fase = $f; try { Set-Content -LiteralPath $lock -Value ("{0}|{1}|{2}" -f (Get-Date -Format s), $PID, $f) } catch { } }
if (Test-Path -LiteralPath $lock) {
  # Bloqueo v1.9: "fecha|pid|fase". Huerfano si el proceso que lo creo ya no existe o si supera $HuerfanoMin minutos.
  $txt = (Get-Content -LiteralPath $lock -Raw -ErrorAction SilentlyContinue); if (-not $txt) { $txt = '' }
  $partes = $txt.Trim() -split '\|'; $edad = ((Get-Date) - (Get-Item -LiteralPath $lock).LastWriteTime).TotalMinutes
  $vivo = $false; $cl = $null
  if ($partes.Count -ge 2 -and $partes[1] -match '^\d+$') {
    $pr = Get-Process -Id ([int]$partes[1]) -ErrorAction SilentlyContinue
    $vivo = [bool]($pr -and $pr.ProcessName -match '^(powershell|pwsh)$')
    if ($vivo) {   # el PID puede haberse reutilizado: solo cuenta si su linea de ordenes es la del vigilante
      $cl = $null; try { $cl = (Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f [int]$partes[1]) -ErrorAction Stop).CommandLine } catch { }
      if ($cl -and $cl -notmatch 'Vigilante_Raiz') { $vivo = $false } } }
  elseif ($edad -lt $HuerfanoMin) { $vivo = $true }   # bloqueo antiguo sin PID: se respeta solo hasta $HuerfanoMin
  if ($vivo -and $edad -lt $HuerfanoMin) { Latido 'SALTO_EN_CURSO' ("bloqueo de {0:N0} min, fase {1}" -f $edad, $(if($partes.Count -ge 3){$partes[2]}else{'?'})); return }
  Latido 'BLOQUEO_HUERFANO_RECUPERADO' ("edad {0:N0} min; contenido: {1}" -f $edad, $txt.Trim())
  if ($vivo -and $cl -match 'Vigilante_Raiz') { try { Stop-Process -Id ([int]$partes[1]) -Force -ErrorAction Stop; Latido 'PROCESO_COLGADO_DETENIDO' $partes[1] } catch { } }
}
$pausa = Join-Path $org 'vigilante.pausa'
if (Test-Path -LiteralPath $pausa) { Latido 'SALTO_PAUSA_M16' ''; return }   # pausado por el M16 hasta que el usuario lo reanude
Fase 'INICIO'
$logPath = Join-Path $org ("vigilante_{0}.csv" -f (Get-Date -Format 'yyyyMM'))
function Log($o,$d,$e) { [pscustomobject]@{Fecha=(Get-Date -Format s);Origen=$o;Destino=$d;Estado=$e} | Export-Csv -LiteralPath $logPath -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append }
function Rel([string]$p) { $p.Substring($Raiz.Length).TrimStart('\','/') -replace '/', '\' }   # v1.10: siempre con \ (como en Windows)
function Abs([string]$r) { Join-Path $Raiz ($r -replace '\\', [IO.Path]::DirectorySeparatorChar) }
function ManAdd($fila) {   # v1.9.2: fila a fila, para que una pasada cortada no deje duplicados apartados sin registrar
  if (Test-Path -LiteralPath $man) { $fila | Export-Csv -LiteralPath $man -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append }
  else { $fila | Export-Csv -LiteralPath $man -Delimiter ';' -NoTypeInformation -Encoding UTF8 } }
function Libre([string]$dir,[string]$n,[bool]$carpeta) {
  $t = Join-Path $dir $n; if (-not (Test-Path -LiteralPath $t)) { return $t }
  if ($carpeta) { $b=$n; $e='' } else { $b=[IO.Path]::GetFileNameWithoutExtension($n); $e=[IO.Path]::GetExtension($n) }
  $k=2; do { $t = Join-Path $dir ("{0} [org{1}]{2}" -f $b,$k,$e); $k++ } while (Test-Path -LiteralPath $t); return $t }
function Estable($item) {
  $lim = (Get-Date).AddSeconds(-$EsperaSeg)
  if ($item.PSIsContainer) { $fs = @(Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
    if ($fs.Count -eq 0) { return $item.LastWriteTime -lt $lim }
    return (($fs | Measure-Object LastWriteTime -Maximum).Maximum -lt $lim) }
  if ($item.LastWriteTime -gt $lim) { return $false }
  try { $s = [IO.File]::Open($item.FullName,'Open','Read','None'); $s.Dispose(); return $true } catch { return $false } }
try {
  # --- v1.11: migracion de la carpeta de entrada (nuevos -> INPUT, o cualquier cambio posterior de nombre) ---
  Fase 'ENTRADA'
  $entradaDir = Join-Path $Raiz $Entrada; $histP = Join-Path $org 'entrada_historial.txt'
  $hist = @('nuevos'); if (Test-Path -LiteralPath $histP) { $hist += @(Get-Content -LiteralPath $histP -Encoding UTF8 | ForEach-Object { "$_".Trim() } | Where-Object { $_ -and $_ -notmatch '^#' }) }
  $anteriores = @($hist | Where-Object { $_ -ine $Entrada } | Select-Object -Unique)
  foreach ($a in $anteriores) {
    $ad = Join-Path $Raiz $a; if (-not (Test-Path -LiteralPath $ad -PathType Container)) { continue }
    if (-not (Test-Path -LiteralPath $entradaDir)) { Move-Item -LiteralPath $ad -Destination $entradaDir; Log $ad $entradaDir 'ENTRADA_RENOMBRADA'; Latido 'ENTRADA_MIGRADA' ("{0} -> {1} (renombrada)" -f $a, $Entrada) }
    else { $nTr = 0
      foreach ($c in @(Get-ChildItem -LiteralPath $ad -Force)) { $dst = Libre $entradaDir $c.Name $c.PSIsContainer; Move-Item -LiteralPath $c.FullName -Destination $dst; Log $c.FullName $dst 'ENTRADA_TRASLADADA'; $nTr++ }
      if (@(Get-ChildItem -LiteralPath $ad -Force).Count -eq 0) { Remove-Item -LiteralPath $ad }   # carpeta ya vacia: no es un documento
      Latido 'ENTRADA_MIGRADA' ("{0} -> {1} ({2} elementos trasladados)" -f $a, $Entrada, $nTr) } }
  if (-not (@($hist) -icontains $Entrada)) { Add-Content -LiteralPath $histP -Value $Entrada -Encoding UTF8 }
  if (-not (Test-Path -LiteralPath $entradaDir)) { New-Item -ItemType Directory -Path $entradaDir | Out-Null }
  # --- M16: integridad y alerta temprana (si esta activo en config_modulos.csv) ---
  $integ = Join-Path $org 'Verificar_Integridad.ps1'
  if (Test-Path -LiteralPath $integ) {
    $alerta = $false
    Fase 'M16_ALERTA'
    try { $alerta = [bool](& $integ -Raiz $Raiz -Modo Alerta -PresupuestoSeg $PresupuestoM16Seg) } catch { Log '' '' ('M16_ERROR: ' + $_.Exception.Message) }
    if ($alerta) { Log '' '' 'PAUSADO_POR_ALERTA_M16'; Latido 'FIN_ALERTA_M16' ''; return }
    $est = Join-Path $org 'integridad_estado.csv'; $hoy = Get-Date -Format 'yyyy-MM-dd'
    $hecha = (Test-Path -LiteralPath $est) -and ((Get-Content -LiteralPath $est -Raw) -match [regex]::Escape($hoy))
    if (-not $hecha -and -not (Test-Path -LiteralPath (Join-Path $org 'integridad.lock'))) {
      try { Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $integ),'-Raiz',('"{0}"' -f $Raiz),'-Modo','Muestra') | Out-Null }
      catch { Log '' '' ('M16_MUESTRA_NO_LANZADA: ' + $_.Exception.Message) } }
  }
  # --- v1.11, M15: copia verificada (una vez al dia, en segundo plano, si esta activa) ---
  $copiaPs = Join-Path $org 'Copia_Verificada.ps1'; $cfgM = Join-Path $org 'config_modulos.csv'
  if ((Test-Path -LiteralPath $copiaPs) -and (Test-Path -LiteralPath $cfgM)) {
    $m15 = @(Import-Csv -LiteralPath $cfgM -Delimiter ';' -Encoding UTF8 | Where-Object { $_.Modulo -eq 'M15' -and $_.Activo -eq 'SI' }).Count -gt 0
    $marcaCopia = Join-Path $org 'copia_ultima.txt'; $hoyC = Get-Date -Format 'yyyy-MM-dd'
    $hechaC = (Test-Path -LiteralPath $marcaCopia) -and ((Get-Content -LiteralPath $marcaCopia -Raw) -match [regex]::Escape($hoyC))
    if ($m15 -and -not $hechaC -and -not (Test-Path -LiteralPath (Join-Path $org 'copia.lock'))) {
      try { $exeC = (Get-Process -Id $PID).Path; $spc = @{ FilePath = $exeC; ArgumentList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $copiaPs),'-Raiz',('"{0}"' -f $Raiz)) }
            if ($env:OS -eq 'Windows_NT') { $spc.WindowStyle = 'Hidden' }; Start-Process @spc | Out-Null; Latido 'M15_COPIA_LANZADA' '' }
      catch { Log '' '' ('M15_NO_LANZADA: ' + $_.Exception.Message) } } }
  # --- indices del manifiesto ---
  Fase 'MANIFIESTO'
  $porSha = @{}; $enMan = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  if (Test-Path -LiteralPath $man) { foreach ($m in (Import-Csv -LiteralPath $man -Delimiter ';' -Encoding UTF8)) {
      if ($m.RutaRelativa) { [void]$enMan.Add($m.RutaRelativa) }
      if ($m.SHA256 -and $m.RutaRelativa -notlike '_DUPLICADOS_REVISAR*' -and -not $porSha.ContainsKey($m.SHA256)) { $porSha[$m.SHA256] = $m.RutaRelativa } } }
  $porHuella = @{}; $hzPath = Join-Path $org 'huellas_zip.csv'; $hzSha = @{}
  if (Test-Path -LiteralPath $hzPath) { foreach ($z in (Import-Csv -LiteralPath $hzPath -Delimiter ';' -Encoding UTF8)) { $hzSha[$z.SHA256] = $z.HuellaZip
      if ($porSha.ContainsKey($z.SHA256) -and -not $porHuella.ContainsKey($z.HuellaZip)) { $porHuella[$z.HuellaZip] = $porSha[$z.SHA256] } } }
  $exclDirRx = '^(\d\d_.*|_.*|99_.*)$'   # carpetas de area y de control (solo carpetas: un ARCHIVO que empiece por _ o NN_ si se procesa)
  $exclRx = '^(desktop\.ini|thumbs\.db|~\$.*|.*\.(crdownload|part|partial|download|tmp|opdownload)|(INVENTARIAR|SEMBRAR_MANIFIESTO|INSTALAR_VIGILANTE|DESINSTALAR_VIGILANTE|REANUDAR_VIGILANTE|APLICAR.*)\.bat|ALERTA_INTEGRIDAD\.txt|SOLICITUD_BORRADO_DUPLICADOS_.*\.csv)$'
  $exclTxt = Join-Path $org 'excluir_raiz.txt'; $exclExtra = @(); if (Test-Path -LiteralPath $exclTxt) { $exclExtra = @(Get-Content -LiteralPath $exclTxt | Where-Object { $_ -and $_ -notmatch '^#' }) }
  # --- v1.9.2: conciliacion del manifiesto con el registro del mes (duplicados apartados por pasadas cortadas) ---
  Fase 'CONCILIAR'; $nConc = 0
  if (Test-Path -LiteralPath $logPath) {
    $rc = [Diagnostics.Stopwatch]::StartNew()
    foreach ($l in @(Import-Csv -LiteralPath $logPath -Delimiter ';' -Encoding UTF8 | Where-Object { $_.Estado -like 'DUPLICADO*' -and $_.Destino })) {
      if ($rc.Elapsed.TotalSeconds -gt $PresupuestoConciliarSeg) { Latido 'CONCILIAR_APLAZADA' 'presupuesto agotado; sigue en la proxima pasada'; break }
      if (-not $l.Destino.StartsWith($Raiz, [StringComparison]::OrdinalIgnoreCase)) { continue }
      $rd = Rel $l.Destino; if ($enMan.Contains($rd) -or -not (Test-Path -LiteralPath $l.Destino)) { continue }
      try { $fi = Get-Item -LiteralPath $l.Destino
        ManAdd ([pscustomobject]@{ RutaRelativa=$rd; SHA256=(Get-FileHash -LiteralPath $l.Destino -Algorithm SHA256).Hash.ToLower(); Tamano=$fi.Length;
          FechaMod=[int64]($fi.LastWriteTimeUtc-[datetime]'1970-01-01').TotalMilliseconds; Area='_DUPLICADOS_REVISAR'; Estado=$l.Estado;
          NombreOriginal=(Split-Path -Leaf $l.Origen); FechaClasificacion=($l.Fecha.Substring(0,10)); VersionSkill='1.9.2-conciliacion' })
        [void]$enMan.Add($rd); $nConc++ } catch { Log $l.Destino '' ('CONCILIAR_ERROR: ' + $_.Exception.Message) } }
    if ($nConc) { Latido 'CONCILIADO' ("filas repuestas en el manifiesto: {0}" -f $nConc) }
  }
  # --- v1.10: solicitudes de borrado del panel de duplicados ---
  Fase 'BORRADOS'; $nBorr = 0; $nRech = 0
  $solDir = Join-Path $org 'borrados_solicitudes'; $solHechas = Join-Path $solDir 'procesadas'; $rxSol = '^SOLICITUD_BORRADO_DUPLICADOS_.*\.csv$'
  $carpetasSol = @(@($Raiz, $entradaDir) + @(Resolve-CarpetasSolicitudes $cfgP.CarpetaSolicitudes) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique)
  foreach ($s in @($carpetasSol | ForEach-Object { Get-ChildItem -LiteralPath $_ -File -Force -ErrorAction SilentlyContinue } | Where-Object { $_.Name -match $rxSol })) {
    if (-not (Estable $s)) { continue }
    foreach ($d in $solDir, $solHechas) { if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d | Out-Null } }
    $previa = @((Join-Path $solHechas $s.Name), (Join-Path $solDir $s.Name) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1)
    if ($previa.Count -and (Get-Item -LiteralPath $previa[0]).Length -eq $s.Length) {   # v1.11: ya recibida antes (p. ej. copia que sigue en Descargas)
      $rep = Join-Path $solHechas 'repetidas'; if (-not (Test-Path -LiteralPath $rep)) { New-Item -ItemType Directory -Path $rep | Out-Null }
      $dst = Libre $rep $s.Name $false; Move-Item -LiteralPath $s.FullName -Destination $dst; Log $s.FullName $dst 'SOLICITUD_REPETIDA_ARCHIVADA'; continue }
    $dst = Libre $solDir $s.Name $false; Move-Item -LiteralPath $s.FullName -Destination $dst; Log $s.FullName $dst 'SOLICITUD_BORRADO_RECIBIDA' }
  if (Test-Path -LiteralPath $solDir) {
    $rb = [Diagnostics.Stopwatch]::StartNew(); $sha256 = [Security.Cryptography.SHA256]::Create()
    foreach ($s in @(Get-ChildItem -LiteralPath $solDir -File | Where-Object { $_.Name -match $rxSol } | Sort-Object Name)) {
      $resPath = Join-Path $solDir ('resultado_' + $s.Name); $hechas = @{}
      if (Test-Path -LiteralPath $resPath) { foreach ($x in (Import-Csv -LiteralPath $resPath -Delimiter ';' -Encoding UTF8)) { $hechas[$x.RutaDuplicado] = 1 } }
      $filas = @(); try { $filas = @(Import-Csv -LiteralPath $s.FullName -Delimiter ';' -Encoding UTF8) } catch { Log $s.FullName '' ('SOLICITUD_ILEGIBLE: ' + $_.Exception.Message) }
      $completa = $true
      foreach ($f in $filas) {
        $d = "$($f.RutaDuplicado)".Trim().TrimStart('\'); $o = "$($f.RutaOriginal)".Trim().TrimStart('\')
        if ($hechas.ContainsKey($d)) { continue }
        if ($rb.Elapsed.TotalMinutes -ge $PresupuestoBorradoMin) { $completa = $false; break }
        $est = ''; $mot = ''; $shaD = ''
        $malo = '(^|\\)\.\.(\\|$)|:|[*?]'
        if (-not $d -or -not $o) { $est = 'NO_BORRADO'; $mot = 'fila incompleta' }
        elseif ($d -notlike '_DUPLICADOS_REVISAR\*' -or $d -match $malo -or $d -like '*\PANEL_DUPLICADOS*' -or $d -like '_DUPLICADOS_REVISAR\_panel\*') { $est = 'NO_BORRADO'; $mot = 'la copia no esta dentro de _DUPLICADOS_REVISAR' }
        elseif ($o -like '_DUPLICADOS_REVISAR*' -or $o -like '_ORGANIZACION*' -or $o -match $malo) { $est = 'NO_BORRADO'; $mot = 'el original indicado no es valido' }
        elseif (-not (Test-Path -LiteralPath (Abs $d) -PathType Leaf)) { $est = 'NO_BORRADO_YA_NO_EXISTE'; $mot = 'la copia ya no esta' }
        elseif (-not (Test-Path -LiteralPath (Abs $o) -PathType Leaf)) { $est = 'NO_BORRADO_ORIGINAL_AUSENTE'; $mot = 'el original no esta en su carpeta: se conserva la copia' }
        else {
          try {
            $pd = Abs $d; $po = Abs $o; $fd = Get-Item -LiteralPath $pd; $fo = Get-Item -LiteralPath $po; $igual = $false
            if ("$($f.Tipo)" -eq 'ZIP') { $h1 = Get-ZipHuella $pd; $h2 = Get-ZipHuella $po; $igual = [bool]($h1 -and $h2 -and $h1.Huella -eq $h2.Huella) }
            else { $igual = ($fd.Length -eq $fo.Length) -and ((Get-FileHash -LiteralPath $pd -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $po -Algorithm SHA256).Hash) }
            if (-not $igual) { $est = 'NO_BORRADO_CONTENIDO_DISTINTO'; $mot = 'el contenido no coincide con el original: se conserva la copia' }
            else {
              $shaD = (Get-FileHash -LiteralPath $pd -Algorithm SHA256).Hash.ToLower(); $tamD = $fd.Length; $fmD = [int64]($fd.LastWriteTimeUtc-[datetime]'1970-01-01').TotalMilliseconds
              Remove-Item -LiteralPath $pd   # en Google Drive para escritorio va a la papelera de Drive (30 dias)
              ManAdd ([pscustomobject]@{ RutaRelativa=$d; SHA256=$shaD; Tamano=$tamD; FechaMod=$fmD; Area='_DUPLICADOS_REVISAR'; Estado='BORRADO_POR_USUARIO';
                NombreOriginal=$o; FechaClasificacion=(Get-Date -Format 'yyyy-MM-dd'); VersionSkill='1.11' })
              $est = 'BORRADO_VERIFICADO'; $mot = 'identico a ' + $o }
          } catch { $est = 'NO_BORRADO_ERROR'; $mot = $_.Exception.Message } }
        if ($est -eq 'BORRADO_VERIFICADO') { $nBorr++ } else { $nRech++ }
        [pscustomobject]@{ Fecha=(Get-Date -Format s); RutaDuplicado=$d; RutaOriginal=$o; Estado=$est; Motivo=$mot; SHA256=$shaD } |
          Export-Csv -LiteralPath $resPath -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append
        Log $(if ($d) { Abs $d } else { '' }) $(if ($o) { Abs $o } else { '' }) $est
      }
      if ($completa) { if (-not (Test-Path -LiteralPath $solHechas)) { New-Item -ItemType Directory -Path $solHechas | Out-Null }
        Move-Item -LiteralPath $s.FullName -Destination (Libre $solHechas $s.Name $false)
        if (Test-Path -LiteralPath $resPath) { Move-Item -LiteralPath $resPath -Destination (Libre $solHechas ('resultado_' + $s.Name) $false) } }
      else { Latido 'BORRADOS_APLAZADOS' ("limite de {0} min; la solicitud {1} sigue en la proxima pasada" -f $PresupuestoBorradoMin, $s.Name); break }
    }
    if ($nBorr -or $nRech) { Latido 'BORRADOS' ("borrados={0} no_borrados={1}" -f $nBorr, $nRech) }
  }
  Fase 'RAIZ'
  $nMov = 0; $nPend = 0; $nDupRaiz = 0
  foreach ($it in @(Get-ChildItem -LiteralPath $Raiz -Force)) {
    if ($it.Name -eq $Entrada -or ($it.PSIsContainer -and @($anteriores) -icontains $it.Name) -or ($it.PSIsContainer -and $it.Name -imatch $exclDirRx) -or (-not $it.PSIsContainer -and $it.Name -imatch $exclRx) -or $exclExtra -contains $it.Name) { continue }
    if (((Get-Date) - $t0).TotalMinutes -ge $PresupuestoRaizMin) { $nPend++; continue }   # v1.9.2: se cuentan y quedan para la proxima pasada
    if (-not (Estable $it)) { continue }
    $src = $it.FullName; $destino = $null; $estado = 'EN_COLA'
    if (-not $it.PSIsContainer) {
      $sha = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash.ToLower(); $orig = $null; $suf = '__COPIA_'
      if ($porSha.ContainsKey($sha) -and (Test-Path -LiteralPath (Join-Path $Raiz $porSha[$sha]))) { $orig = $porSha[$sha]; $estado = 'DUPLICADO_VERIFICADO' }
      elseif ($it.Extension -ieq '.zip') { $zh = Get-ZipHuella $src
        if ($zh -and $porHuella.ContainsKey($zh.Huella) -and (Test-Path -LiteralPath (Join-Path $Raiz $porHuella[$zh.Huella]))) {
          $orig = $porHuella[$zh.Huella]; $estado = 'DUPLICADO_ZIP_VERIFICADO'; $suf = '__COPIA_CONTENIDO_' } }
      if ($orig) {
        $od = Split-Path -Parent $orig; $ob = [IO.Path]::GetFileNameWithoutExtension($orig); $oe = [IO.Path]::GetExtension($orig)
        $dd = Join-Path (Join-Path $Raiz '_DUPLICADOS_REVISAR') $od; if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory -Path $dd -Force | Out-Null }
        $k = 1; do { $destino = Join-Path $dd ("{0}{1}{2}{3}" -f $ob,$suf,$k,$oe); $k++ } while (Test-Path -LiteralPath $destino)
        Move-Item -LiteralPath $src -Destination $destino
        $fi = Get-Item -LiteralPath $destino
        ManAdd ([pscustomobject]@{ RutaRelativa=(Rel $destino); SHA256=$sha; Tamano=$fi.Length; FechaMod=[int64]($fi.LastWriteTimeUtc-[datetime]'1970-01-01').TotalMilliseconds;
          Area='_DUPLICADOS_REVISAR'; Estado=$estado; NombreOriginal=$it.Name; FechaClasificacion=(Get-Date -Format 'yyyy-MM-dd'); VersionSkill='1.9.2-vigilante' })
        [void]$enMan.Add((Rel $destino)); $nDupRaiz++; Log $src $destino $estado; $nMov++; continue }
    }
    $destino = Libre $entradaDir $it.Name $it.PSIsContainer
    Move-Item -LiteralPath $src -Destination $destino; Log $src $destino $estado; $nMov++
  }
  if ($nPend) { Latido 'RAIZ_APLAZADA' ("limite de {0} min; quedan {1} elementos en la raiz para la proxima pasada" -f $PresupuestoRaizMin, $nPend) }
  # --- planes que deja la clasificacion diaria de Claude ---
  Fase 'PLANES'; $nPlan = 0
  $pend = Join-Path $org 'planes_pendientes'; $apl = Join-Path $org 'planes_aplicados'
  if (Test-Path -LiteralPath $pend) {
    foreach ($p in @(Get-ChildItem -LiteralPath $pend -Filter 'plan_*.csv' -File | Sort-Object Name)) {
      if (-not (Estable $p)) { continue }
      if ($nPlan -ge 1 -and ((Get-Date) - $t0).TotalMinutes -ge 12) { Latido 'PLANES_APLAZADOS' 'limite de 12 min por pasada; siguen en la proxima'; break }   # v1.9.1: por bloques, sin rozar el corte de 30 min
      if (-not (Test-Path -LiteralPath $apl)) { New-Item -ItemType Directory -Path $apl | Out-Null }
      try { & (Join-Path $org 'Aplicar_Plan.ps1') -Plan $p.FullName -Raiz $Raiz -Ejecutar | Out-Null; $st = 'PLAN_APLICADO' } catch { $st = 'PLAN_ERROR: ' + $_.Exception.Message }
      Move-Item -LiteralPath $p.FullName -Destination (Libre $apl $p.Name $false); Log $p.FullName '' $st; $nPlan++ }
  }
  # --- v1.10: panel de duplicados (si hubo cambios, si no existe o cada hora) ---
  Fase 'PANEL'
  $genP = Join-Path $org 'Generar_Panel_Duplicados.ps1'; $panel = Join-Path (Join-Path $Raiz '_DUPLICADOS_REVISAR') 'PANEL_DUPLICADOS.html'
  if (Test-Path -LiteralPath $genP) {
    $toca = ($nDupRaiz + $nBorr + $nRech + $nConc + $nPlan) -gt 0 -or -not (Test-Path -LiteralPath $panel)
    if (-not $toca) { $toca = ((Get-Date) - (Get-Item -LiteralPath $panel).LastWriteTime).TotalMinutes -ge 60 }
    if ($toca -and ((Get-Date) - $t0).TotalMinutes -lt 24) {
      # v1.10.2: en un proceso aparte con tiempo maximo, para que un panel bloqueado no cuelgue la pasada (06-10-2026 11:12)
      try {
        $exe = (Get-Process -Id $PID).Path; $estP = Join-Path $org 'panel_ultimo.json'
        $sp = @{ FilePath = $exe; PassThru = $true; ArgumentList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $genP),'-Raiz',('"{0}"' -f $Raiz)) }
        if ($env:OS -eq 'Windows_NT') { $sp.WindowStyle = 'Hidden' }
        $tp = Get-Date; $pp = Start-Process @sp
        if (-not $pp.WaitForExit($PanelMaxSeg * 1000)) { try { $pp.Kill() } catch { }; Latido 'PANEL_TIEMPO_AGOTADO' ("el generador supero {0} s y se detuvo; se reintenta en la proxima pasada" -f $PanelMaxSeg) }
        else { $rp = $null; try { if ((Get-Item -LiteralPath $estP).LastWriteTime -ge $tp.AddSeconds(-2)) { $rp = Get-Content -LiteralPath $estP -Raw | ConvertFrom-Json } } catch { }
          if ($rp -and $rp.Ranura) { Latido 'PANEL_ACTUALIZADO' ("grupos={0} copias={1} incompleto={2} ranura={3} html={4}" -f $rp.Grupos, $rp.Copias, $rp.Incompleto, $rp.Ranura, $rp.Html) }
          else { Log '' '' ('PANEL_ERROR: el generador termino sin escribir datos' + $(if ($rp) { ' (' + $rp.Fallos + ')' } else { '' })) } } }
      catch { Log '' '' ('PANEL_ERROR: ' + $_.Exception.Message) } } }
  try { [ordered]@{ version = '1.11'; ultimaPasada = (Get-Date -Format s); raiz = $Raiz; entrada = $Entrada; carpetasSolicitudes = @($carpetasSol); movidos = $nMov; planes = $nPlan; borrados = $nBorr } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $org 'estado_plataforma.json') -Encoding UTF8 } catch { }
  Fase 'FIN'; Latido 'FIN_OK' ("movidos={0} planes={1} raiz_pendientes={2} conciliados={3} borrados={4}" -f $nMov, $nPlan, $nPend, $nConc, $nBorr)
} catch { Log '' '' ('ERROR: ' + $_.Exception.Message); Latido 'FIN_ERROR' $_.Exception.Message }
finally { Remove-Item -LiteralPath $lock -ErrorAction SilentlyContinue }
