$ErrorActionPreference='Stop'
$R = (Resolve-Path '.').Path + '/raiz'
$S = if ($env:OD_DIST) { $env:OD_DIST } else { (Resolve-Path (Join-Path $PSScriptRoot '../dist')).Path }
function Reset {
  if (Test-Path $R) { Remove-Item $R -Recurse -Force }
  foreach ($d in '01_PROY/A','01_PROY/B','02_ADMIN','06_DESARROLLO_SOFTWARE/app','_ORGANIZACION','INPUT') { New-Item -ItemType Directory -Path "$R/$d" -Force | Out-Null }
  Copy-Item "$S/Verificar_Integridad.ps1","$S/Vigilante_Raiz.ps1","$S/Aplicar_Plan.ps1" "$R/_ORGANIZACION/"
  Copy-Item '/mnt/user-data/outputs/org_v16/config_modulos_v16.csv' "$R/_ORGANIZACION/config_modulos.csv"
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
function Limpia { Remove-Item "$R/_ORGANIZACION/vigilante.pausa","$R/ALERTA_INTEGRIDAD.txt" -ErrorAction SilentlyContinue }
function T($n,$c){ Write-Host ("{0,-62} {1}" -f $n, $(if($c){"OK"}else{"FALLO"})) }
$O="$R/_ORGANIZACION"
function Lat { $p="$O/vigilante_latido_$(Get-Date -Format yyyyMM).csv"; if (Test-Path $p) { @(Import-Csv $p -Delimiter ';') } else { @() } }
function Man { @(Import-Csv "$O/manifiesto_documental.csv" -Delimiter ';') }
function Suelto($n,$c) { Set-Content "$R/$n" $c; (Get-Item "$R/$n").LastWriteTime=(Get-Date).AddMinutes(-5) }
# T30 presupuesto RAIZ agotado: no mueve, lo deja registrado y sigue con los planes
Reset; Suelto 'a30.pdf' 'contenido unico a30'; Suelto 'b30.pdf' 'contenido unico b30'
& "$O/Vigilante_Raiz.ps1" -Raiz $R -PresupuestoRaizMin 0
$l=Lat
T 'T30 presupuesto raiz 0: no mueve y registra RAIZ_APLAZADA' ((Test-Path "$R/a30.pdf") -and ($l.Evento -contains 'RAIZ_APLAZADA') -and (($l|?{$_.Evento -eq 'FIN_OK'}).Detalle -match 'raiz_pendientes=2'))
# T31 pasada normal: duplicado apartado con fila de manifiesto inmediata; resto a INPUT
$n0=(Man).Count
Copy-Item "$R/01_PROY/A/doc5.pdf" "$R/doc5 (1).pdf"; (Get-Item "$R/doc5 (1).pdf").LastWriteTime=(Get-Date).AddMinutes(-5)
& "$O/Vigilante_Raiz.ps1" -Raiz $R
$m=Man; $nueva=$m | ? { $_.VersionSkill -eq '1.9.2-vigilante' }
T 'T31 duplicado apartado y fila 1.9.2-vigilante en manifiesto' ((Test-Path "$R/_DUPLICADOS_REVISAR/01_PROY/A/doc5__COPIA_1.pdf") -and $nueva.Count -eq 1 -and $m.Count -eq $n0+1)
T 'T31b los no duplicados van a INPUT' ((Test-Path "$R/INPUT/a30.pdf") -and (Test-Path "$R/INPUT/b30.pdf"))
# T32 conciliacion: duplicado apartado por una pasada cortada (en el registro pero no en el manifiesto)
New-Item -ItemType Directory "$R/_DUPLICADOS_REVISAR/01_PROY/B" -Force | Out-Null
Copy-Item "$R/01_PROY/B/nota7.txt" "$R/_DUPLICADOS_REVISAR/01_PROY/B/nota7__COPIA_1.txt"
[pscustomobject]@{Fecha='2026-10-05T22:50:00';Origen="$R/nota7 (1).txt";Destino="$R/_DUPLICADOS_REVISAR/01_PROY/B/nota7__COPIA_1.txt";Estado='DUPLICADO_VERIFICADO'} |
  Export-Csv "$O/vigilante_$(Get-Date -Format yyyyMM).csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append
& "$O/Vigilante_Raiz.ps1" -Raiz $R
$c=@(Man | ? { $_.VersionSkill -eq '1.9.2-conciliacion' })
T 'T32 conciliacion repone la fila que faltaba' ($c.Count -eq 1 -and $c[0].RutaRelativa -like '*nota7__COPIA_1.txt' -and $c[0].SHA256 -eq (Get-FileHash "$R/01_PROY/B/nota7.txt").Hash.ToLower() -and $c[0].NombreOriginal -eq 'nota7 (1).txt')
& "$O/Vigilante_Raiz.ps1" -Raiz $R
T 'T32b la conciliacion no duplica filas en la siguiente pasada' (@(Man | ? { $_.VersionSkill -like '1.9.2*' }).Count -eq 2)
T 'T32c el duplicado de T31 tampoco se repone dos veces' (@(Man | ? { $_.RutaRelativa -like '*doc5__COPIA_1.pdf' }).Count -eq 1)
# T33 rotacion M16
Reset; New-Item -ItemType Directory "$R/10_B","$R/99_R" -Force | Out-Null; Set-Content "$R/10_B/x.txt" "x"; Set-Content "$R/99_R/y.txt" "y"
$null = & "$O/Verificar_Integridad.ps1" -Raiz $R -Modo Alerta -PresupuestoSeg 0
$mk = (Get-Content "$O/integridad_rotacion.txt" -Raw).Trim()
T 'T33 corte en la primera area: marca de rotacion' ($mk -eq '01_PROY')
Set-Content "$O/integridad_rotacion.txt" '99_R'
$null = & "$O/Verificar_Integridad.ps1" -Raiz $R -Modo Alerta -PresupuestoSeg 0
T 'T33b la siguiente pasada empieza por el area marcada (99_R)' ((Get-Content "$O/integridad_rotacion.txt" -Raw).Trim() -eq '99_R')
$null = & "$O/Verificar_Integridad.ps1" -Raiz $R -Modo Alerta -PresupuestoSeg 120
T 'T33c recorrido completo: la marca se vacia' (-not (Get-Content "$O/integridad_rotacion.txt" -Raw).Trim())
T 'T33d sin falsas alertas' (-not (Test-Path "$R/ALERTA_INTEGRIDAD.txt"))
