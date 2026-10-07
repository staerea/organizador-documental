'@
$utf8 = New-Object Text.UTF8Encoding $true
# --- datos: ranura rotatoria (la mas antigua primero; si esta bloqueada, la siguiente) ---
if (-not (Test-Path -LiteralPath $pdir)) { New-Item -ItemType Directory -Path $pdir | Out-Null }
$js = '(window.PANEL_SLOTS = window.PANEL_SLOTS || []).push(' + $json + ');'
$ranuras = @(1..3 | ForEach-Object { $p = Join-Path $pdir ("datos_{0}.js" -f $_); [pscustomobject]@{ Ruta = $p; Fecha = $(if (Test-Path -LiteralPath $p) { (Get-Item -LiteralPath $p).LastWriteTime } else { [datetime]::MinValue }) } } | Sort-Object Fecha)
$escrita = $null; $fallos = @()
foreach ($r in $ranuras) { try { [IO.File]::WriteAllText($r.Ruta, $js, $utf8); $escrita = Split-Path -Leaf $r.Ruta; break } catch { $fallos += ((Split-Path -Leaf $r.Ruta) + ': ' + $_.Exception.Message) } }
# --- HTML fijo: solo se reescribe si falta o si cambia la plantilla ---
$estadoHtml = 'sin_cambios'
$actual = $null; try { if (Test-Path -LiteralPath $salida) { $actual = [IO.File]::ReadAllText($salida) } } catch { }
if ($actual -ne $plantilla) {
  try { [IO.File]::WriteAllText($salida, $plantilla, $utf8); $estadoHtml = 'actualizado' }
  catch { $alt = Join-Path $dupDir 'PANEL_DUPLICADOS_2.html'
          try { [IO.File]::WriteAllText($alt, $plantilla, $utf8); $estadoHtml = 'bloqueado; escrito PANEL_DUPLICADOS_2.html' } catch { $estadoHtml = 'bloqueado' } } }
# temporales de versiones anteriores del propio panel (no son documentos)
Get-ChildItem -LiteralPath $dupDir -Filter 'PANEL_DUPLICADOS.tmp*' -File -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-Item -LiteralPath $_.FullName -ErrorAction Stop } catch { } }
$res = [pscustomobject]@{ Grupos = $grupos.Count; Copias = ($grupos.Values | ForEach-Object { $_.c.Count } | Measure-Object -Sum).Sum; Incompleto = $cortado; Ranura = $escrita; Html = $estadoHtml; Fallos = ($fallos -join ' | '); Segundos = [int]$reloj.Elapsed.TotalSeconds }
try { $res | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $org 'panel_ultimo.json') -Encoding UTF8 } catch { }
if (-not $escrita) { throw ('ninguna ranura de datos escribible: ' + ($fallos -join ' | ')) }
$res
