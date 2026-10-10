# Pruebas v1.11.2: caducidad de solicitudes de borrado, modo INFORME (por defecto), panel con solicitudes caducadas,
# ventana del M16 igual al intervalo del vigilante y lanzador sin ventana (VBScript).
$ErrorActionPreference = 'Stop'
$S = if ($env:OD_DIST) { $env:OD_DIST } else { (Resolve-Path (Join-Path $PSScriptRoot '../dist')).Path }
$B = (Resolve-Path '.').Path; $R = "$B/raiz10"; $DL = "$B/descargas10"; $O = "$R/_ORGANIZACION"
$script:fallos = 0
function T($n,$c){ if (-not $c) { $script:fallos++ }; Write-Host ("{0,-70} {1}" -f $n, $(if($c){'OK'}else{'FALLO'})) }
function Viejo($p) { Get-ChildItem -LiteralPath $p -Recurse -Force | ForEach-Object { $_.LastWriteTime = (Get-Date).AddMinutes(-10) }; (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddMinutes(-10) }
function Lat { $p = "$O/vigilante_latido_$(Get-Date -Format yyyyMM).csv"; if (Test-Path $p) { @(Import-Csv $p -Delimiter ';') } else { @() } }
function Cfg([hashtable]$v) { $c = [ordered]@{ CarpetaEntrada='INPUT'; CarpetaSolicitudes=$DL }; foreach ($k in $v.Keys) { $c[$k] = $v[$k] }
  ($c.Keys | ForEach-Object { [pscustomobject]@{ Clave=$_; Valor=$c[$_]; Descripcion='' } }) | Export-Csv "$O/config_plataforma.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8 }
function Reset([switch]$SinCfg) {
  foreach ($d in $R, $DL) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
  foreach ($d in '01_PROY/A','_DUPLICADOS_REVISAR/01_PROY/A','_ORGANIZACION','INPUT') { New-Item -ItemType Directory -Path "$R/$d" -Force | Out-Null }
  New-Item -ItemType Directory -Path $DL -Force | Out-Null
  Copy-Item "$S/Vigilante_Raiz.ps1","$S/Aplicar_Plan.ps1","$S/Generar_Panel_Duplicados.ps1","$S/Verificar_Integridad.ps1" $O
  Set-Content "$R/01_PROY/A/Doc.pdf" '%PDF original'; Set-Content "$R/_DUPLICADOS_REVISAR/01_PROY/A/Doc__COPIA_1.pdf" '%PDF original'
  Set-Content "$O/config_modulos.csv" "Modulo;Nombre;Activo;Modo;Parametros`r`nM16;Integridad;NO;AUTOMATICO;" -Encoding UTF8
  if (-not $SinCfg) { Cfg @{ ModoBorrados='ACTIVO' } } }
function Sol([string]$nombre, [string]$solicitado) {
  $row = [pscustomobject]@{ RutaDuplicado='_DUPLICADOS_REVISAR\01_PROY\A\Doc__COPIA_1.pdf'; RutaOriginal='01_PROY\A\Doc.pdf'; Tipo='SHA'; Tamano='14'; SHA256=''; Solicitado=$solicitado }
  $row | Export-Csv "$DL/$nombre" -Delimiter ';' -NoTypeInformation -Encoding UTF8; (Get-Item "$DL/$nombre").LastWriteTime = (Get-Date).AddMinutes(-10) }
function Vig { & "$O/Vigilante_Raiz.ps1" -EsperaSeg 0 | Out-Null }
$copia = "$R/_DUPLICADOS_REVISAR/01_PROY/A/Doc__COPIA_1.pdf"
$utc = { param($h) (Get-Date).ToUniversalTime().AddHours(-$h).ToString('yyyy-MM-ddTHH:mm:ss') }

# T90 solicitud de hace 30 h en modo ACTIVO -> caduca, no se borra
Reset; Sol 'SOLICITUD_BORRADO_DUPLICADOS_20261006_160512.csv' (& $utc 30); Viejo $R; Vig
T 'T90 solicitud de 30 h: no se borra la copia' (Test-Path $copia)
T 'T90b pasa a pendientes_confirmacion y latido SOLICITUDES_CADUCADAS' ((Test-Path "$O/borrados_solicitudes/pendientes_confirmacion/SOLICITUD_BORRADO_DUPLICADOS_20261006_160512.csv") -and (@(Lat | Where-Object Evento -eq 'SOLICITUDES_CADUCADAS').Count -eq 1))
T 'T90c el panel ofrece volver a marcar la copia (caducadas)' ((Get-Content "$R/_DUPLICADOS_REVISAR/_panel/datos_*.js" -Raw) -match 'Doc__COPIA_1')
$js = (Get-ChildItem "$R/_DUPLICADOS_REVISAR/_panel/datos_*.js" | Sort-Object LastWriteTime | Select-Object -Last 1 | Get-Content -Raw)
T 'T90d datos del panel: caducadas contiene la copia' ($js -match '"caducadas":\s*\[\s*"_DUPLICADOS_REVISAR')
# T91 nueva solicitud reciente (reconfirmada) en modo ACTIVO -> se borra
Sol 'SOLICITUD_BORRADO_DUPLICADOS_20261010_120000.csv' (& $utc 0.2); Vig
T 'T91 solicitud reconfirmada (12 min): copia borrada y original intacto' ((-not (Test-Path $copia)) -and (Test-Path "$R/01_PROY/A/Doc.pdf"))
$js = (Get-ChildItem "$R/_DUPLICADOS_REVISAR/_panel/datos_*.js" | Sort-Object LastWriteTime | Select-Object -Last 1 | Get-Content -Raw)
T 'T91b la copia ya no figura como caducada' ($js -notmatch '"caducadas":\s*\[\s*"_DUPLICADOS_REVISAR')
# T92 solicitud sin fecha -> caduca
Reset; Sol 'SOLICITUD_BORRADO_DUPLICADOS_20261010_120100.csv' ''; Viejo $R; Vig
T 'T92 solicitud sin fecha valida: no se ejecuta' ((Test-Path $copia) -and (Test-Path "$O/borrados_solicitudes/pendientes_confirmacion/SOLICITUD_BORRADO_DUPLICADOS_20261010_120100.csv"))
# T93 modo INFORME (por defecto sin clave): verifica, informa, no borra, la solicitud espera
Reset -SinCfg; Cfg @{}; Sol 'SOLICITUD_BORRADO_DUPLICADOS_20261010_120200.csv' (& $utc 0.2); Viejo $R; Vig
T 'T93 INFORME: la copia no se borra' (Test-Path $copia)
T 'T93b informe con SE_BORRARIA y solicitud a la espera' (((Import-Csv "$O/borrados_solicitudes/informe_SOLICITUD_BORRADO_DUPLICADOS_20261010_120200.csv" -Delimiter ';').Estado -eq 'SE_BORRARIA') -and (Test-Path "$O/borrados_solicitudes/SOLICITUD_BORRADO_DUPLICADOS_20261010_120200.csv"))
T 'T93c latido BORRADOS_SOLO_INFORME' (@(Lat | Where-Object Evento -eq 'BORRADOS_SOLO_INFORME').Count -eq 1)
Vig
T 'T93d segunda pasada INFORME: sin filas repetidas en el informe' (@(Import-Csv "$O/borrados_solicitudes/informe_SOLICITUD_BORRADO_DUPLICADOS_20261010_120200.csv" -Delimiter ';').Count -eq 1)
T 'T93e el panel avisa del modo INFORME' ((Get-ChildItem "$R/_DUPLICADOS_REVISAR/_panel/datos_*.js" | Get-Content -Raw) -match '"modoBorrados":\s*"INFORME"')
# T94 se autoriza (ACTIVO) dentro del plazo -> se ejecuta
Cfg @{ ModoBorrados='ACTIVO' }; Vig
T 'T94 ACTIVO autorizado dentro del plazo: copia borrada y solicitud archivada' ((-not (Test-Path $copia)) -and (Test-Path "$O/borrados_solicitudes/procesadas/SOLICITUD_BORRADO_DUPLICADOS_20261010_120200.csv"))
# T95 configuracion con valores no validos -> modo seguro e intervalo por defecto
Reset -SinCfg; Cfg @{ ModoBorrados='activo-ya'; IntervaloVigilanteMin='5' }; Sol 'SOLICITUD_BORRADO_DUPLICADOS_20261010_120300.csv' (& $utc 0.2); Viejo $R; Vig
T 'T95 ModoBorrados no valido se trata como INFORME (no borra)' (Test-Path $copia)
T 'T95b estado_plataforma: intervalo 60 y modo INFORME' ((Get-Content "$O/estado_plataforma.json" -Raw | ConvertFrom-Json | ForEach-Object { $_.intervaloMin -eq 60 -and $_.modoBorrados -eq 'INFORME' }))
# T96 M16: la ventana de cambios masivos es el intervalo (60 min por defecto)
Reset; Set-Content "$O/config_modulos.csv" "Modulo;Nombre;Activo;Modo;Parametros`r`nM16;Integridad;SI;AUTOMATICO;UmbralCambios10min=200" -Encoding UTF8
New-Item -ItemType Directory "$R/02_ADMIN" | Out-Null; 1..250 | ForEach-Object { $p = "$R/02_ADMIN/f$_.txt"; Set-Content $p 'x'; (Get-Item $p).LastWriteTime = (Get-Date).AddMinutes(-40) }
$al = [bool](& "$O/Verificar_Integridad.ps1" -Raiz $R -Modo Alerta)
T 'T96 250 cambios hace 40 min con intervalo 60: alerta' $al
Remove-Item "$O/vigilante.pausa","$R/ALERTA_INTEGRIDAD.txt" -ErrorAction SilentlyContinue; Cfg @{ ModoBorrados='ACTIVO'; IntervaloVigilanteMin='10' }
$al = [bool](& "$O/Verificar_Integridad.ps1" -Raiz $R -Modo Alerta)
T 'T96b los mismos cambios con intervalo 10: sin alerta' (-not $al)
# T97 lanzador sin ventana
$vb = [IO.File]::ReadAllBytes("$S/Vigilante_Oculto.vbs"); $vt = [Text.Encoding]::ASCII.GetString($vb)
T 'T97 VBS en ASCII sin BOM, con CRLF, oculto (0) y esperando (True)' (($vb[0] -ne 0xEF) -and ($vt -match "`r`n") -and ($vt -match 'sh\.Run\(cmd, 0, True\)') -and ($vt -match 'Vigilante_Raiz\.ps1') -and (-not ($vb | Where-Object { $_ -gt 127 })))
$ins = Get-Content "$S/Instalar_Vigilante.ps1" -Raw
T 'T97b instalador: wscript con el VBS, intervalo configurable y limite 55 min' (($ins -match 'wscript\.exe') -and ($ins -match 'Vigilante_Oculto\.vbs') -and ($ins -match 'IntervaloVigilanteMin') -and ($ins -match 'Minutes 55'))
Write-Host ("FALLOS: {0}" -f $script:fallos)
