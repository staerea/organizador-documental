$ErrorActionPreference='Stop'
$R = (Resolve-Path '.').Path + '/raiz'
$S = if ($env:OD_DIST) { $env:OD_DIST } else { (Resolve-Path (Join-Path $PSScriptRoot '../dist')).Path }
function Reset {
  if (Test-Path $R) { Remove-Item $R -Recurse -Force }
  foreach ($d in '01_PROY/A','01_PROY/B','02_ADMIN','06_DESARROLLO_SOFTWARE/app','_ORGANIZACION','INPUT') { New-Item -ItemType Directory -Path "$R/$d" -Force | Out-Null }
  Copy-Item "$S/Verificar_Integridad.ps1","$S/Vigilante_Raiz.ps1","$S/Aplicar_Plan.ps1","$S/Generar_Panel_Duplicados.ps1" "$R/_ORGANIZACION/"
  Copy-Item '/mnt/user-data/outputs/org_v16/config_modulos_v16.csv' "$R/_ORGANIZACION/config_modulos.csv"
  @([pscustomobject]@{ Clave='ModoBorrados'; Valor='ACTIVO'; Descripcion='' }) | Export-Csv "$R/_ORGANIZACION/config_plataforma.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8   # v1.11.2: por defecto INFORME
  $pdf = [Text.Encoding]::ASCII.GetBytes("%PDF-1.4 contenido ")
  for ($i=0;$i -lt 150;$i++){ [IO.File]::WriteAllBytes("$R/01_PROY/A/doc$i.pdf", $pdf + [byte[]](1..($i+1))) }
  for ($i=0;$i -lt 150;$i++){ Set-Content "$R/01_PROY/B/nota$i.txt" "nota $i" }
  for ($i=0;$i -lt 20;$i++){ Set-Content "$R/02_ADMIN/f$i.txt" "admin $i" }
  for ($i=0;$i -lt 300;$i++){ Set-Content "$R/06_DESARROLLO_SOFTWARE/app/m$i.js" "x$i" }
  Set-Content "$R/06_DESARROLLO_SOFTWARE/app/README.txt" "readme"
  $old=(Get-Date).AddDays(-3); Get-ChildItem $R -Recurse -File | ? { $_.FullName -notlike '*_ORGANIZACION*' } | % { $_.LastWriteTime=$old; $_.CreationTime=$old }
  $rows = Get-ChildItem $R -Recurse -File | ? { $_.FullName -notlike '*_ORGANIZACION*' } | % {
    [pscustomobject]@{RutaRelativa=$_.FullName.Substring($R.Length).TrimStart('/');SHA256=(Get-FileHash $_.FullName).Hash.ToLower();Tamano=$_.Length;
      FechaMod=[int64]($_.LastWriteTimeUtc-[datetime]'1970-01-01').TotalMilliseconds;Area='x';Estado='HEREDADO';NombreOriginal='';FechaClasificacion='2026-10-03';VersionSkill='1.0'} }
  $rows | Export-Csv "$R/_ORGANIZACION/manifiesto_documental.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8
}
function T($n,$c){ Write-Host ("{0,-66} {1}" -f $n, $(if($c){"OK"}else{"FALLO"})) }
$O="$R/_ORGANIZACION"; $DR="$R/_DUPLICADOS_REVISAR"
function Lat { $p="$O/vigilante_latido_$(Get-Date -Format yyyyMM).csv"; if (Test-Path $p) { @(Import-Csv $p -Delimiter ';') } else { @() } }
function Man { @(Import-Csv "$O/manifiesto_documental.csv" -Delimiter ';') }
function Panel { $best=$null; foreach ($f in Get-ChildItem "$DR/_panel" -Filter 'datos_*.js' -File -ErrorAction SilentlyContinue) { $c = Get-Content $f.FullName -Raw; $j = $c.Substring($c.IndexOf('push(')+5); $j = $j.Substring(0, $j.LastIndexOf(');')); $o = $j | ConvertFrom-Json; if (-not $best -or $o.iso -gt $best.iso) { $best = $o } }; $best }
function Viejo($p) { (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddMinutes(-5) }
Reset
1..3 | % { Copy-Item "$R/01_PROY/A/doc5.pdf" "$R/doc5 ($_).pdf"; Viejo "$R/doc5 ($_).pdf" }
New-Item -ItemType Directory "$DR/01_PROY/B" -Force | Out-Null
Set-Content "$DR/01_PROY/B/huerfano__COPIA_1.txt" "sin original"
Set-Content "$DR/01_PROY/B/nota3__COPIA_1.txt" "nota X"     # mismo tamano que "nota 3", distinto contenido
& "$O/Vigilante_Raiz.ps1" -Raiz $R
$P = Panel; $g5 = $P.grupos | ? { $_.o -like '*doc5.pdf' }
T 'T40 tres copias iguales -> un grupo con 3 copias verificadas (SHA)' ($g5 -and @($g5.c).Count -eq 3 -and -not (@($g5.c) | ? { $_.v -ne 'SHA' }))
T 'T40b el original del grupo existe y es el clasificado' ($g5.oe -and $g5.o -eq '01_PROY\A\doc5.pdf')
$gh = $P.grupos | ? { $_.c[0].r -like '*huerfano__COPIA_1.txt' }
T 'T41 copia sin original -> no se puede borrar' ($gh -and -not $gh.oe -and $gh.c[0].v -eq 'NO')
$gn = $P.grupos | ? { $_.o -like '*nota3.txt' }
T 'T42 mismo tamano y contenido distinto -> TAM (se verificara al borrar)' ($gn -and $gn.c[0].v -eq 'TAM')
T 'T42b latido PANEL_ACTUALIZADO' ((Lat).Evento -contains 'PANEL_ACTUALIZADO')
# solicitud: las 3 copias + casos que NO deben borrarse
$filas = @(
 @('_DUPLICADOS_REVISAR\01_PROY\A\doc5__COPIA_1.pdf','01_PROY\A\doc5.pdf','SHA'),
 @('_DUPLICADOS_REVISAR\01_PROY\A\doc5__COPIA_2.pdf','01_PROY\A\doc5.pdf','SHA'),
 @('_DUPLICADOS_REVISAR\01_PROY\A\doc5__COPIA_3.pdf','01_PROY\A\doc5.pdf','SHA'),
 @('_DUPLICADOS_REVISAR\01_PROY\B\nota3__COPIA_1.txt','01_PROY\B\nota3.txt','SHA'),
 @('_DUPLICADOS_REVISAR\01_PROY\B\huerfano__COPIA_1.txt','01_PROY\B\huerfano.txt','SHA'),
 @('01_PROY\A\doc7.pdf','01_PROY\A\doc5.pdf','SHA'),
 @('_DUPLICADOS_REVISAR\..\01_PROY\A\doc8.pdf','01_PROY\A\doc5.pdf','SHA'),
 @('_DUPLICADOS_REVISAR\01_PROY\A\doc5__COPIA_1.pdf','_DUPLICADOS_REVISAR\01_PROY\A\doc5__COPIA_2.pdf','SHA'))
$csv = "$R/SOLICITUD_BORRADO_DUPLICADOS_20261005_233000.csv"
$filas | % { [pscustomobject]@{ RutaDuplicado=$_[0]; RutaOriginal=$_[1]; Tipo=$_[2]; Tamano=''; SHA256=''; Solicitado=(Get-Date).ToUniversalTime().AddMinutes(-15).ToString('s') } } | Export-Csv $csv -Delimiter ';' -NoTypeInformation -Encoding UTF8
Viejo $csv
& "$O/Vigilante_Raiz.ps1" -Raiz $R -PresupuestoBorradoMin 0
T 'T43 presupuesto 0: la solicitud se recoge pero no se borra nada' ((Test-Path "$O/borrados_solicitudes/SOLICITUD_BORRADO_DUPLICADOS_20261005_233000.csv") -and (Test-Path "$DR/01_PROY/A/doc5__COPIA_1.pdf") -and ((Lat).Evento -contains 'BORRADOS_APLAZADOS'))
T 'T43b la solicitud no acaba en INPUT' (-not (Test-Path "$R/INPUT/SOLICITUD_BORRADO_DUPLICADOS_20261005_233000.csv"))
& "$O/Vigilante_Raiz.ps1" -Raiz $R
T 'T44 las tres copias se borran' (-not (Test-Path "$DR/01_PROY/A/doc5__COPIA_1.pdf") -and -not (Test-Path "$DR/01_PROY/A/doc5__COPIA_2.pdf") -and -not (Test-Path "$DR/01_PROY/A/doc5__COPIA_3.pdf"))
T 'T44b el original se conserva en su carpeta' (Test-Path "$R/01_PROY/A/doc5.pdf")
T 'T44c contenido distinto: no se borra' (Test-Path "$DR/01_PROY/B/nota3__COPIA_1.txt")
T 'T44d sin original: no se borra' (Test-Path "$DR/01_PROY/B/huerfano__COPIA_1.txt")
T 'T44e fuera de _DUPLICADOS_REVISAR o con ..: no se borra' ((Test-Path "$R/01_PROY/A/doc7.pdf") -and (Test-Path "$R/01_PROY/A/doc8.pdf"))
$res = Import-Csv (Get-ChildItem "$O/borrados_solicitudes/procesadas/resultado_*.csv").FullName -Delimiter ';'
T 'T45 resultado: 3 borrados y 5 rechazos con motivo' (@($res | ? Estado -eq 'BORRADO_VERIFICADO').Count -eq 3 -and @($res | ? { $_.Estado -like 'NO_BORRADO*' -and $_.Motivo }).Count -eq 5)
T 'T45b solicitud movida a procesadas' (Test-Path "$O/borrados_solicitudes/procesadas/SOLICITUD_BORRADO_DUPLICADOS_20261005_233000.csv")
T 'T45c manifiesto: 3 filas BORRADO_POR_USUARIO con hash' (@(Man | ? { $_.Estado -eq 'BORRADO_POR_USUARIO' -and $_.SHA256 }).Count -eq 3)
$P2 = Panel
T 'T46 el panel se regenera sin el grupo borrado y con historial' (-not ($P2.grupos | ? { $_.o -like '*doc5.pdf' }) -and @($P2.borrados | ? e -eq 'BORRADO_VERIFICADO').Count -eq 3)
T 'T46b sin falsas alertas M16' (-not (Test-Path "$R/ALERTA_INTEGRIDAD.txt"))
# T47 la muestra de integridad no cuenta las copias borradas
Remove-Item "$O/integridad_estado.csv","$O/integridad.lock" -ErrorAction SilentlyContinue
(Import-Csv "$O/config_modulos.csv" -Delimiter ';') | % { if ($_.Modulo -eq 'M16') { $_.Parametros = ($_.Parametros -replace 'MuestraDiaria=1/\d+','MuestraDiaria=1/1') }; $_ } | Export-Csv "$O/config_modulos.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8
& "$O/Verificar_Integridad.ps1" -Raiz $R -Modo Muestra
$il = (Import-Csv (Get-ChildItem "$O/integridad_*.csv" | ? Name -match '\d{6}').FullName -Delimiter ';' | ? { $_.Diagnostico -like 'MUESTRA*' } | Select -Last 1).Diagnostico
T 'T47 muestra: NO_ENCONTRADO=0 tras borrar copias' ($il -match 'NO_ENCONTRADO=0')
# T53 ranura bloqueada y HTML bloqueado (simulados con carpetas del mismo nombre)
Reset; New-Item -ItemType Directory "$DR/_panel/datos_1.js","$DR/PANEL_DUPLICADOS.html" -Force | Out-Null
Copy-Item "$R/01_PROY/A/doc3.pdf" "$R/doc3 (1).pdf"; (Get-Item "$R/doc3 (1).pdf").LastWriteTime=(Get-Date).AddMinutes(-5)
& "$O/Vigilante_Raiz.ps1" -Raiz $R
$l = Lat | ? Evento -eq 'PANEL_ACTUALIZADO' | Select-Object -Last 1
T 'T53 ranura 1 bloqueada: escribe otra ranura y el panel se actualiza' ($l -and $l.Detalle -notmatch 'ranura=datos_1' -and (Panel).grupos.Count -ge 1)
T 'T53b HTML bloqueado: se escribe PANEL_DUPLICADOS_2.html' ((Test-Path "$DR/PANEL_DUPLICADOS_2.html" -PathType Leaf) -and $l.Detalle -match 'bloqueado')
T 'T53c la pasada termina bien' ((Lat | Select-Object -Last 1).Evento -eq 'FIN_OK')
# T54 generador que excede el tiempo: se detiene y la pasada sigue
Reset; Copy-Item "$R/01_PROY/A/doc4.pdf" "$R/doc4 (1).pdf"; (Get-Item "$R/doc4 (1).pdf").LastWriteTime=(Get-Date).AddMinutes(-5)
& "$O/Vigilante_Raiz.ps1" -Raiz $R -PanelMaxSeg 0
T 'T54 tiempo agotado: PANEL_TIEMPO_AGOTADO y FIN_OK' (((Lat).Evento -contains 'PANEL_TIEMPO_AGOTADO') -and (Lat | Select-Object -Last 1).Evento -eq 'FIN_OK')
# T55 temporales antiguos del panel se limpian; el HTML no se reescribe si no cambia
Reset; Set-Content "$DR/PANEL_DUPLICADOS.tmp123" "viejo" -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory $DR -Force | Out-Null; Set-Content "$DR/PANEL_DUPLICADOS.tmp123" "viejo"
& "$O/Generar_Panel_Duplicados.ps1" -Raiz $R | Out-Null; $t1 = (Get-Item "$DR/PANEL_DUPLICADOS.html").LastWriteTime
Start-Sleep -Milliseconds 1200; $r2 = & "$O/Generar_Panel_Duplicados.ps1" -Raiz $R
T 'T55 temporal antiguo eliminado y HTML sin cambios en la 2a generacion' (-not (Test-Path "$DR/PANEL_DUPLICADOS.tmp123") -and $r2.Html -eq 'sin_cambios' -and (Get-Item "$DR/PANEL_DUPLICADOS.html").LastWriteTime -eq $t1)
T 'T55b la 2a generacion usa otra ranura' ($r2.Ranura -ne $null -and @(Get-ChildItem "$DR/_panel" -Filter 'datos_*.js' -File).Count -eq 2)
