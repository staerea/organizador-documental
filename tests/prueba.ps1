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
function Alerta { [bool](& "$R/_ORGANIZACION/Verificar_Integridad.ps1" -Raiz $R -Modo Alerta) }
function Limpia { Remove-Item "$R/_ORGANIZACION/vigilante.pausa","$R/ALERTA_INTEGRIDAD.txt" -ErrorAction SilentlyContinue }
function T($n,$c){ Write-Host ("{0,-55} {1}" -f $n, $(if($c){'OK'}else{'FALLO'})) }

Reset
T 'T1 base sin cambios -> sin alerta' (-not (Alerta))
Get-ChildItem "$R/01_PROY" -Recurse -File | Select -First 250 | % { $_.LastWriteTime = Get-Date }
T 'T2 250 cambios en 10 min -> alerta' (Alerta)
T 'T2b crea pausa y ALERTA_INTEGRIDAD.txt' ((Test-Path "$R/_ORGANIZACION/vigilante.pausa") -and (Test-Path "$R/ALERTA_INTEGRIDAD.txt"))
Set-Content "$R/suelto.pdf" "%PDF x"; (Get-Item "$R/suelto.pdf").LastWriteTime=(Get-Date).AddMinutes(-5)
& "$R/_ORGANIZACION/Vigilante_Raiz.ps1" -Raiz $R
T 'T2c vigilante en pausa no mueve nada' ((Test-Path "$R/suelto.pdf") -and (Test-Path "$R/ALERTA_INTEGRIDAD.txt"))
Reset
Get-ChildItem "$R/06_DESARROLLO_SOFTWARE" -Recurse -File | % { $_.LastWriteTime = Get-Date }
T 'T3 300 cambios solo en 06 (compilacion) -> sin alerta' (-not (Alerta))
Reset
1..3 | % { Set-Content "$R/01_PROY/A/x$_.pdf.locked" "zz" }; 1..3 | % { Set-Content "$R/02_ADMIN/y$_.docx.encrypted" "zz" }
T 'T4 6 extensiones de cifrado en 2 carpetas -> alerta' (Alerta); Limpia
Reset
Set-Content "$R/01_PROY/A/HOW_TO_DECRYPT.txt" "pay"; Set-Content "$R/02_ADMIN/HOW_TO_DECRYPT.txt" "pay"
T 'T5 notas de rescate en 2 carpetas -> alerta' (Alerta); Limpia
Reset
T 'T5b README.txt de software no alerta' (-not (Alerta))
1..3 | % { [IO.File]::WriteAllBytes("$R/02_ADMIN/cifrado$_.pdf", [byte[]](200..230)) }
T 'T6 3 PDF recientes con cabecera falsa -> alerta' (Alerta); Limpia
Reset
$c=Import-Csv "$R/_ORGANIZACION/config_modulos.csv" -Delimiter ';'; ($c|?{$_.Modulo -eq 'M16'}).Activo='NO'; $c|Export-Csv "$R/_ORGANIZACION/config_modulos.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8
Get-ChildItem "$R/01_PROY" -Recurse -File | Select -First 250 | % { $_.LastWriteTime = Get-Date }
T 'T7 M16 desactivado -> sin alerta' (-not (Alerta))
Reset
# Muestra: corrupcion silenciosa (2), modificacion legitima (1), archivo movido (1)
$man = Import-Csv "$R/_ORGANIZACION/manifiesto_documental.csv" -Delimiter ';'
$n0 = $man.Count
foreach ($i in 0,1) { $f=Get-Item "$R/01_PROY/A/doc$i.pdf"; $t=$f.LastWriteTime; $b=[IO.File]::ReadAllBytes($f.FullName); $b[-1]=($b[-1]+1)%256; [IO.File]::WriteAllBytes($f.FullName,$b); (Get-Item $f.FullName).LastWriteTime=$t }
Add-Content "$R/01_PROY/A/doc2.pdf" "mas"
Move-Item "$R/01_PROY/A/doc3.pdf" "$R/01_PROY/B/doc3_movido.pdf"
$cfgf="$R/_ORGANIZACION/config_modulos.csv"; (Get-Content $cfgf) -replace 'MuestraDiaria=1/7','MuestraDiaria=1/1' | Set-Content $cfgf -Encoding UTF8
& "$R/_ORGANIZACION/Verificar_Integridad.ps1" -Raiz $R -Modo Muestra
$log = Import-Csv (Get-ChildItem "$R/_ORGANIZACION/integridad_*.csv").FullName -Delimiter ';'
T 'T8 detecta 2 corrupciones silenciosas' ((@($log|?{$_.Diagnostico -eq 'CORRUPCION_SILENCIOSA'})).Count -eq 2)
T 'T8b detecta 1 modificacion legitima' ((@($log|?{$_.Diagnostico -eq 'MODIFICADO_LEGITIMO'})).Count -eq 1)
T 'T8c no alerta con 2 corrupciones (<5)' (-not (Test-Path "$R/_ORGANIZACION/vigilante.pausa"))
T 'T8d manifiesto ampliado con la fila actualizada' ((Import-Csv "$R/_ORGANIZACION/manifiesto_documental.csv" -Delimiter ';').Count -eq $n0+1)
Write-Host ($log | ? { $_.Diagnostico -like 'MUESTRA*' } | Select -Expand Diagnostico)
& "$R/_ORGANIZACION/Verificar_Integridad.ps1" -Raiz $R -Modo Muestra
T 'T8e segunda ejecucion el mismo dia no repite' ((@(Import-Csv (Get-ChildItem "$R/_ORGANIZACION/integridad_*.csv").FullName -Delimiter ';' | ?{$_.Diagnostico -like 'MUESTRA*'})).Count -eq 1)
foreach ($i in 10..15) { $f=Get-Item "$R/01_PROY/A/doc$i.pdf"; $t=$f.LastWriteTime; $b=[IO.File]::ReadAllBytes($f.FullName); $b[-1]=($b[-1]+7)%256; [IO.File]::WriteAllBytes($f.FullName,$b); (Get-Item $f.FullName).LastWriteTime=$t }
Set-Content "$R/_ORGANIZACION/integridad_estado.csv" "`"Puntero`";`"UltimaMuestra`"`r`n`"0`";`"2000-01-01`"" -Encoding UTF8
& "$R/_ORGANIZACION/Verificar_Integridad.ps1" -Raiz $R -Modo Muestra
T 'T9 6 corrupciones silenciosas -> alerta y pausa' ((Test-Path "$R/_ORGANIZACION/vigilante.pausa") -and (Test-Path "$R/ALERTA_INTEGRIDAD.txt"))
Reset
Set-Content "$R/nuevo_doc.pdf" "%PDF-1.4 nuevo"; (Get-Item "$R/nuevo_doc.pdf").LastWriteTime=(Get-Date).AddMinutes(-5)
& "$R/_ORGANIZACION/Vigilante_Raiz.ps1" -Raiz $R
T 'T10 vigilante normal con M16 activo mueve a INPUT' ((Test-Path "$R/INPUT/nuevo_doc.pdf") -and -not (Test-Path "$R/nuevo_doc.pdf"))
$vl = Import-Csv (Get-ChildItem "$R/_ORGANIZACION/vigilante_*.csv").FullName -Delimiter ';'
Write-Host ($vl | % { "$($_.Estado)" }) 
Set-Content "$R/ALERTA_INTEGRIDAD.txt" "x"; (Get-Item "$R/ALERTA_INTEGRIDAD.txt").LastWriteTime=(Get-Date).AddMinutes(-5)
& "$R/_ORGANIZACION/Vigilante_Raiz.ps1" -Raiz $R
T 'T11 ALERTA_INTEGRDAD.txt no se mueve a INPUT' (Test-Path "$R/ALERTA_INTEGRIDAD.txt")
$archivosAntes = 0
