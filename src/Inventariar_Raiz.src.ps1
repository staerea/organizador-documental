<#  Inventario local de la RAIZ ordenada (solo lectura). Calcula SHA-256 de cada archivo,
    reutilizando el hash del manifiesto si tamano y fecha no han cambiado.
    Uso: powershell -ExecutionPolicy Bypass -File .\_ORGANIZACION\Inventariar_Raiz.ps1   #>
param([string]$Raiz = (Split-Path $PSScriptRoot -Parent), [string]$Entrada = '',
      [string[]]$NoHashear = @('06_DESARROLLO_SOFTWARE'), [switch]$Sembrar)
$ErrorActionPreference = 'Stop'
#COMUN#
if (-not $Entrada) { $Entrada = (Get-ConfigPlataforma (Join-Path $Raiz '_ORGANIZACION')).CarpetaEntrada }   # v1.11
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
$cache = @{}
$hzPath = Join-Path $org 'huellas_zip.csv'; $hz = @{}
if (Test-Path -LiteralPath $hzPath) { foreach ($z in (Import-Csv -LiteralPath $hzPath -Delimiter ';' -Encoding UTF8)) { $hz[$z.SHA256] = $z } }
$hzNuevas = New-Object System.Collections.Generic.List[object]
if (Test-Path -LiteralPath $man) { foreach ($m in (Import-Csv -LiteralPath $man -Delimiter ';' -Encoding UTF8)) { $cache[$m.RutaRelativa] = $m } }
$out = New-Object System.Collections.Generic.List[object]
$files = Get-ChildItem -LiteralPath $Raiz -Recurse -File -Force | Where-Object { $_.FullName -notlike "$org*" }
$i = 0
foreach ($f in $files) {
  $i++; Write-Progress -Activity 'Inventariando' -Status $f.Name -PercentComplete ([int](100*$i/[math]::Max(1,$files.Count)))
  $rel = $f.FullName.Substring($Raiz.Length).TrimStart('\','/')
  $top = ($rel -split '[\\/]')[0]
  $mt = [int64]($f.LastWriteTimeUtc - [datetime]'1970-01-01').TotalMilliseconds
  $c = $cache[$rel]; $hash = ''
  if ($c -and $c.Tamano -eq [string]$f.Length -and $c.FechaMod -eq [string]$mt) { $hash = $c.SHA256 }
  elseif ($NoHashear -notcontains $top) { try { $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower() } catch { $hash = 'ERROR' } }
  $huella = ''; $nEnt = ''
  if ($f.Extension -ieq '.zip' -and $hash -and $hash -ne 'ERROR') {
    if ($hz.ContainsKey($hash)) { $huella = $hz[$hash].HuellaZip; $nEnt = $hz[$hash].Entradas }
    else { $zh = Get-ZipHuella $f.FullName; if ($zh) { $huella = $zh.Huella; $nEnt = $zh.Entradas
             $row = [pscustomobject]@{ SHA256=$hash; HuellaZip=$huella; Entradas=$nEnt }; $hz[$hash] = $row; $hzNuevas.Add($row) } } }
  $out.Add([pscustomobject]@{ RutaRelativa=$rel; Carpeta=$top; Tamano=$f.Length; FechaMod=$mt; SHA256=$hash;
    EnManifiesto=[bool]$c; EsEntrada=($top -eq $Entrada); HuellaZip=$huella; EntradasZip=$nEnt })
}
New-Item -ItemType Directory -Path $org -Force | Out-Null
if ($Sembrar) {  # Primera vez: marca como YA CLASIFICADO todo lo que esta fuera de la carpeta de entrada
  $seed = $out | Where-Object { -not $_.EnManifiesto -and -not $_.EsEntrada -and $_.Carpeta -ne $_.RutaRelativa } | ForEach-Object {
    [pscustomobject]@{ RutaRelativa=$_.RutaRelativa; SHA256=$_.SHA256; Tamano=$_.Tamano; FechaMod=$_.FechaMod; Area=$_.Carpeta; Estado='HEREDADO';
      NombreOriginal=''; FechaClasificacion=(Get-Date -Format 'yyyy-MM-dd'); VersionSkill='1.0' } }
  if (Test-Path -LiteralPath $man) { $seed | Export-Csv -LiteralPath $man -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append }
  else { $seed | Export-Csv -LiteralPath $man -Delimiter ';' -NoTypeInformation -Encoding UTF8 }
  foreach ($o in $out) { if (-not $o.EsEntrada -and $o.Carpeta -ne $o.RutaRelativa) { $o.EnManifiesto = $true } }
  Write-Host ("Manifiesto sembrado con {0} archivos ya clasificados." -f @($seed).Count) }
if ($hzNuevas.Count) { if (Test-Path -LiteralPath $hzPath) { $hzNuevas | Export-Csv -LiteralPath $hzPath -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append }
  else { $hzNuevas | Export-Csv -LiteralPath $hzPath -Delimiter ';' -NoTypeInformation -Encoding UTF8 } }
# ZIP con el mismo contenido pero distinto archivo (cambian fechas internas, orden o compresion)
$gz = @($out | Where-Object { $_.HuellaZip } | Group-Object HuellaZip | Where-Object { @($_.Group.SHA256 | Select-Object -Unique).Count -gt 1 })
if ($gz.Count) { $rep = foreach ($g in $gz) { foreach ($x in $g.Group) { [pscustomobject]@{ HuellaZip=$g.Name; RutaRelativa=$x.RutaRelativa; SHA256=$x.SHA256; Tamano=$x.Tamano; Entradas=$x.EntradasZip } } }
  $rep | Export-Csv -LiteralPath (Join-Path $org ("zip_mismo_contenido_{0}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))) -Delimiter ';' -NoTypeInformation -Encoding UTF8 }
Write-Host ("ZIP con el mismo contenido y distinto archivo (solo cambia fecha/compresion): {0} grupos" -f $gz.Count)
$dest = Join-Path $org ("inventario_{0}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$out | Export-Csv -LiteralPath $dest -Delimiter ';' -NoTypeInformation -Encoding UTF8
Write-Host ("Archivos: {0} | En entrada '{1}': {2} | Sin clasificar fuera de entrada: {3}" -f $out.Count, $Entrada, ($out | ? EsEntrada).Count, ($out | ? { -not $_.EnManifiesto -and -not $_.EsEntrada }).Count)
Write-Host "Inventario: $dest"
