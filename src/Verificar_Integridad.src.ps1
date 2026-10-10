<#  M16 - INTEGRIDAD Y ALERTA TEMPRANA DE RANSOMWARE (organizador-documental v1.6).
    NUNCA borra, mueve ni modifica documentos. Solo lee, registra y, ante un patron anomalo,
    crea ALERTA_INTEGRIDAD.txt en la raiz y _ORGANIZACION\vigilante.pausa (el vigilante se detiene).
    Modos:
      -Modo Alerta   : comprobacion rapida (cada pasada del vigilante). Devuelve $true si hay alerta.
      -Modo Muestra  : recalculo diario del SHA-256 de una muestra rotatoria del manifiesto.
    Parametros por defecto: se leen de _ORGANIZACION\config_modulos.csv (fila M16).   #>
param([string]$Raiz = (Split-Path $PSScriptRoot -Parent), [ValidateSet('Alerta','Muestra')][string]$Modo = 'Alerta', [int]$PresupuestoSeg = 120, [int]$Intervalo06Min = 60)
# v1.9: en modo Alerta, 06_DESARROLLO_SOFTWARE (miles de archivos) solo se recorre una vez cada $Intervalo06Min minutos,
#       y el recorrido completo se corta si supera $PresupuestoSeg segundos (se registra, no se alerta).
$ErrorActionPreference = 'Stop'
#COMUN#
$org = Join-Path $Raiz '_ORGANIZACION'; $man = Join-Path $org 'manifiesto_documental.csv'
# v1.11: la carpeta de entrada (INPUT o la configurada) y sus nombres anteriores no cuentan como cambios masivos
$excluirTop = @('_ORGANIZACION', 'nuevos', (Get-ConfigPlataforma $org).CarpetaEntrada)
$hpI = Join-Path $org 'entrada_historial.txt'; if (Test-Path -LiteralPath $hpI) { $excluirTop += @(Get-Content -LiteralPath $hpI -Encoding UTF8 | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) }
$pausa = Join-Path $org 'vigilante.pausa'; $alertaTxt = Join-Path $Raiz 'ALERTA_INTEGRIDAD.txt'
$logPath = Join-Path $org ("integridad_{0}.csv" -f (Get-Date -Format 'yyyyMM'))

# ---------- configuracion ----------
$cfg = @{ Activo='SI'; MuestraDiaria='1/7'; UmbralCambios10min='200'; MaxMBDiaria='4096'; MinCorrupcionesAlerta='5' }
$cfgPath = Join-Path $org 'config_modulos.csv'
if (Test-Path -LiteralPath $cfgPath) {
  $fila = Import-Csv -LiteralPath $cfgPath -Delimiter ';' -Encoding UTF8 | Where-Object { $_.Modulo -eq 'M16' } | Select-Object -First 1
  if ($fila) { $cfg.Activo = $fila.Activo
    foreach ($kv in ("$($fila.Parametros)" -split '\|')) { if ($kv -match '^\s*([^=]+)=(.*)$') { $cfg[$matches[1].Trim()] = $matches[2].Trim() } } } }
if ($cfg.Activo -ne 'SI') { if ($Modo -eq 'Alerta') { return $false } else { return } }

function Log($ruta,$shaM,$shaA,$diag) {
  [pscustomobject]@{ Fecha=(Get-Date -Format s); RutaRelativa=$ruta; SHA256Manifiesto=$shaM; SHA256Actual=$shaA; Diagnostico=$diag } |
    Export-Csv -LiteralPath $logPath -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append }
function Rel([string]$p) { $p.Substring($Raiz.Length).TrimStart('\','/') }
function Alertar([string]$motivo, [string[]]$detalle) {
  $txt = @("ALERTA DE INTEGRIDAD - organizador-documental (M16)",
           ("Fecha: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
           ("Motivo: {0}" -f $motivo), "",
           "El vigilante ha quedado en PAUSA: no movera archivos ni aplicara planes.",
           "Que hacer:",
           "  1. No abra archivos desconocidos ni notas de rescate. Si sospecha ransomware, desconecte el equipo de la red.",
           "  2. Revise los ejemplos de abajo y el registro _ORGANIZACION\integridad_AAAAMM.csv.",
           "  3. Si es una falsa alarma (p. ej., una copia masiva legitima), ejecute REANUDAR_VIGILANTE.bat.",
           "", "Ejemplos (maximo 25):") + ($detalle | Select-Object -First 25 | ForEach-Object { "  - $_" })
  if (-not (Test-Path -LiteralPath $alertaTxt)) { Set-Content -LiteralPath $alertaTxt -Value $txt -Encoding UTF8 }
  else { Add-Content -LiteralPath $alertaTxt -Value (@("", "----") + $txt) -Encoding UTF8 }
  if (-not (Test-Path -LiteralPath $pausa)) { Set-Content -LiteralPath $pausa -Value ("{0} {1}" -f (Get-Date -Format s), $motivo) -Encoding UTF8 }
  Log '' '' '' ("ALERTA: " + $motivo)
}
# Firmas de cabecera (magic numbers) de formatos frecuentes
$firmas = @{ '.pdf'=@(0x25,0x50,0x44,0x46); '.zip'=@(0x50,0x4B); '.docx'=@(0x50,0x4B); '.xlsx'=@(0x50,0x4B); '.pptx'=@(0x50,0x4B);
             '.odt'=@(0x50,0x4B); '.ods'=@(0x50,0x4B); '.jpg'=@(0xFF,0xD8,0xFF); '.jpeg'=@(0xFF,0xD8,0xFF); '.png'=@(0x89,0x50,0x4E,0x47);
             '.gif'=@(0x47,0x49,0x46); '.doc'=@(0xD0,0xCF,0x11,0xE0); '.xls'=@(0xD0,0xCF,0x11,0xE0); '.ppt'=@(0xD0,0xCF,0x11,0xE0) }
function CabeceraOk([System.IO.FileInfo]$f) {
  $sig = $firmas[$f.Extension.ToLower()]; if (-not $sig -or $f.Length -lt $sig.Count) { return $true }
  try { $s = [IO.File]::Open($f.FullName,'Open','Read','ReadWrite'); $b = New-Object byte[] $sig.Count; [void]$s.Read($b,0,$sig.Count); $s.Dispose() } catch { return $true }
  for ($i=0; $i -lt $sig.Count; $i++) { if ($b[$i] -ne $sig[$i]) { return $false } }; return $true }

$extRansom  = '\.(locked|encrypted|enc[0-9]*|crypt|crypted|crypto|cry|locky|wncry|wcry|wnry|cerber|zepto|lockbit|ryk|crab|kraken|djvu|stop|phobos|makop)$'
$notaRansom = '^(!?_?readme|how_to_decrypt|how_to_recover|how_to_restore|decrypt|restore_files|recover_files|read_me_to_decrypt|_restore)[^\\]*\.(txt|html?|hta)$'

if ($Modo -eq 'Alerta') {
  if (Test-Path -LiteralPath $pausa) { return $true }
  # v1.11.2: la ventana de cambios masivos es el intervalo del vigilante (60 min por defecto); con 10 min, un cifrado
  #          ocurrido entre dos pasadas horarias quedaria fuera de la ventana. El umbral (UmbralCambios10min) se mantiene.
  $ventanaMin = [int](Get-ConfigPlataforma $org).IntervaloVigilanteMin; if ($ventanaMin -lt 10) { $ventanaMin = 10 }
  $lim = (Get-Date).AddMinutes(-$ventanaMin); $lim24 = (Get-Date).AddHours(-24)
  $umbral = [int]$cfg.UmbralCambios10min
  $cambiados = New-Object System.Collections.Generic.List[string]
  $sospechosos = New-Object System.Collections.Generic.List[string]; $carpetasExt = @{}
  $notas = New-Object System.Collections.Generic.List[string]; $carpetasNota = @{}
  $cabeceras = New-Object System.Collections.Generic.List[string]
  $reloj = [Diagnostics.Stopwatch]::StartNew(); $agotado = $false; $entro06 = $false; $corte = ''
  $marca06 = Join-Path $org 'integridad_ultimo_06.txt'; $toca06 = $true
  if (Test-Path -LiteralPath $marca06) { $toca06 = (((Get-Date) - (Get-Item -LiteralPath $marca06).LastWriteTime).TotalMinutes -ge $Intervalo06Min) }
  # v1.9.2: rotacion. Si una pasada se corta por presupuesto en un area, la siguiente empieza por esa area,
  #         para que ninguna carpeta (99, _DUPLICADOS_REVISAR, 11...) quede sistematicamente sin revisar. 06 va siempre al final.
  $marcaRot = Join-Path $org 'integridad_rotacion.txt'; $inicioRot = ''
  if (Test-Path -LiteralPath $marcaRot) { try { $inicioRot = (Get-Content -LiteralPath $marcaRot -Raw).Trim() } catch { } }
  $resto = @(Get-ChildItem -LiteralPath $Raiz -Directory -Force | Where-Object { $excluirTop -notcontains $_.Name -and $_.Name -ne '06_DESARROLLO_SOFTWARE' } |
             Sort-Object Name)
  $k = -1; for ($i = 0; $i -lt $resto.Count; $i++) { if ($resto[$i].Name -eq $inicioRot) { $k = $i; break } }
  if ($k -gt 0) { $resto = @($resto[$k..($resto.Count-1)]) + @($resto[0..($k-1)]) }
  $tops = @($resto) + @(Get-ChildItem -LiteralPath $Raiz -Directory -Force | Where-Object { $toca06 -and $_.Name -eq '06_DESARROLLO_SOFTWARE' })
  foreach ($t in $tops) {
    if ($agotado) { break }
    $esSoftware = ($t.Name -eq '06_DESARROLLO_SOFTWARE'); if ($esSoftware) { $entro06 = $true }
    # v1.9.1: enumeracion en streaming (.NET) para que el presupuesto de tiempo corte de verdad; Get-ChildItem -Recurse
    #         recogia todo el arbol antes de iterar y una pasada quedo colgada mas de 30 min el 04-10-2026.
    try { $enum = [IO.Directory]::EnumerateFiles($t.FullName, '*', [IO.SearchOption]::AllDirectories) } catch { Log '' '' '' ('M16_ENUM_ERROR: ' + $t.Name); continue }
    try { foreach ($ruta in $enum) {
      if ($reloj.Elapsed.TotalSeconds -gt $PresupuestoSeg) { $agotado = $true; $corte = $t.Name; break }
      $f = New-Object IO.FileInfo $ruta
      if ($f.Name -match $extRansom) { $sospechosos.Add((Rel $f.FullName)); $carpetasExt[$f.DirectoryName] = 1 }
      if (-not $esSoftware -and $f.Name -match $notaRansom -and $f.CreationTime -gt $lim24) { $notas.Add((Rel $f.FullName)); $carpetasNota[$f.DirectoryName] = 1 }
      if ($f.LastWriteTime -gt $lim) {
        if (-not $esSoftware) { $cambiados.Add((Rel $f.FullName)) }
        if (-not (CabeceraOk $f)) { $cabeceras.Add((Rel $f.FullName)) } } } } catch { Log '' '' '' ('M16_ENUM_ERROR: ' + $t.Name + ' ' + $_.Exception.Message) } }
  if ($agotado) { Log '' '' '' ("M16_ALERTA_PRESUPUESTO_AGOTADO: recorrido cortado a los {0} s (carpeta {1})" -f $PresupuestoSeg, $corte) }   # v1.9.2: antes se anotaba la carpeta SIGUIENTE a la del corte
  try { if ($agotado -and $corte -ne '06_DESARROLLO_SOFTWARE') { Set-Content -LiteralPath $marcaRot -Value $corte }
        elseif (Test-Path -LiteralPath $marcaRot) { Set-Content -LiteralPath $marcaRot -Value '' } } catch { }
  # la marca se pone si se llego a recorrer 06 (aunque se cortara): asi un 06 muy lento no se reintenta en cada pasada
  if ($entro06) { try { Set-Content -LiteralPath $marca06 -Value (Get-Date -Format s) } catch { } }
  $motivos = @(); $det = @()
  if ($cambiados.Count -gt $umbral) { $motivos += ("{0} archivos modificados en los ultimos 10 minutos (umbral {1})" -f $cambiados.Count, $umbral); $det += $cambiados }
  if ($sospechosos.Count -ge 5 -and $carpetasExt.Count -ge 2) { $motivos += ("{0} archivos con extensiones tipicas de cifrado en {1} carpetas" -f $sospechosos.Count, $carpetasExt.Count); $det += $sospechosos }
  if ($notas.Count -ge 2 -and $carpetasNota.Count -ge 2) { $motivos += ("{0} posibles notas de rescate creadas en 24 h en {1} carpetas" -f $notas.Count, $carpetasNota.Count); $det += $notas }
  if ($cabeceras.Count -ge 3) { $motivos += ("{0} archivos recientes cuya cabecera no coincide con su extension" -f $cabeceras.Count); $det += $cabeceras }
  if ($motivos.Count) { Alertar ($motivos -join ' | ') $det; return $true }
  return $false
}

# ---------- Modo Muestra (diario) ----------
$lockM = Join-Path $org 'integridad.lock'
if (Test-Path -LiteralPath $lockM) { if (((Get-Date) - (Get-Item -LiteralPath $lockM).LastWriteTime).TotalHours -lt 6) { return } }
Set-Content -LiteralPath $lockM -Value (Get-Date -Format s)
try {
  $estadoPath = Join-Path $org 'integridad_estado.csv'; $puntero = 0; $ultimo = ''
  if (Test-Path -LiteralPath $estadoPath) { $e = Import-Csv -LiteralPath $estadoPath -Delimiter ';' -Encoding UTF8 | Select-Object -First 1; $puntero = [int]$e.Puntero; $ultimo = $e.UltimaMuestra }
  $hoy = Get-Date -Format 'yyyy-MM-dd'; if ($ultimo -eq $hoy) { return }
  # ultima fila por ruta (el manifiesto es de solo anexado)
  $filas = [ordered]@{}; foreach ($m in (Import-Csv -LiteralPath $man -Delimiter ';' -Encoding UTF8)) {
    if ($m.Estado -like 'BORRADO*') { $filas.Remove($m.RutaRelativa) } elseif ($m.SHA256) { $filas[$m.RutaRelativa] = $m } }   # v1.10: las copias borradas por el usuario no cuentan
  $lista = @($filas.Values); $n = $lista.Count; if ($n -eq 0) { return }
  $den = 7; if ($cfg.MuestraDiaria -match '^1/(\d+)$') { $den = [int]$matches[1] }
  $objetivo = [math]::Ceiling($n / $den); $maxBytes = [int64]$cfg.MaxMBDiaria * 1MB
  if ($puntero -ge $n) { $puntero = 0 }
  $hechos = 0; $bytes = [int64]0; $corruptos = New-Object System.Collections.Generic.List[string]; $nuevasFilas = New-Object System.Collections.Generic.List[object]
  $cont = @{ OK=0; MODIFICADO=0; NO_ENCONTRADO=0; CORRUPCION_SILENCIOSA=0; ERROR=0 }
  while ($hechos -lt $objetivo -and $bytes -lt $maxBytes) {
    $m = $lista[$puntero]; $puntero = ($puntero + 1) % $n; $hechos++
    $p = Join-Path $Raiz $m.RutaRelativa
    if (-not (Test-Path -LiteralPath $p)) { $cont.NO_ENCONTRADO++; continue }   # movido o renombrado por el usuario: no es una alarma
    try {
      $fi = Get-Item -LiteralPath $p; $bytes += $fi.Length
      $sha = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()
      $mt = [int64]($fi.LastWriteTimeUtc - [datetime]'1970-01-01').TotalMilliseconds
      if ($sha -eq $m.SHA256.ToLower()) { $cont.OK++ }
      elseif ([string]$fi.Length -eq $m.Tamano -and [string]$mt -eq $m.FechaMod) {
        $cont.CORRUPCION_SILENCIOSA++; $corruptos.Add($m.RutaRelativa); Log $m.RutaRelativa $m.SHA256 $sha 'CORRUPCION_SILENCIOSA' }
      else {
        $cont.MODIFICADO++; Log $m.RutaRelativa $m.SHA256 $sha 'MODIFICADO_LEGITIMO'
        $nuevasFilas.Add([pscustomobject]@{ RutaRelativa=$m.RutaRelativa; SHA256=$sha; Tamano=$fi.Length; FechaMod=$mt; Area=$m.Area; Estado='ACTUALIZADO_INTEGRIDAD';
          NombreOriginal=$m.NombreOriginal; FechaClasificacion=$hoy; VersionSkill='1.6-M16' }) }
    } catch { $cont.ERROR++; Log $m.RutaRelativa $m.SHA256 '' ('ERROR: ' + $_.Exception.Message) }
  }
  if ($nuevasFilas.Count) { $nuevasFilas | Export-Csv -LiteralPath $man -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append }
  if ($corruptos.Count -ge [int]$cfg.MinCorrupcionesAlerta) {
    Alertar ("{0} archivos con contenido alterado sin cambio de fecha ni tamano (posible corrupcion o cifrado)" -f $corruptos.Count) $corruptos }
  [pscustomobject]@{ Puntero=$puntero; UltimaMuestra=$hoy } | Export-Csv -LiteralPath $estadoPath -Delimiter ';' -NoTypeInformation -Encoding UTF8
  Log '' '' '' ("MUESTRA {0}: revisados={1} MB={2:N0} OK={3} MODIFICADO={4} NO_ENCONTRADO={5} CORRUPCION={6} ERROR={7}" -f $hoy,$hechos,($bytes/1MB),$cont.OK,$cont.MODIFICADO,$cont.NO_ENCONTRADO,$cont.CORRUPCION_SILENCIOSA,$cont.ERROR)
} finally { Remove-Item -LiteralPath $lockM -ErrorAction SilentlyContinue }
