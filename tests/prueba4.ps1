$ErrorActionPreference='Stop'
$R=(Resolve-Path '.').Path+'/raiz4'; $S = if ($env:OD_DIST) { $env:OD_DIST } else { (Resolve-Path (Join-Path $PSScriptRoot "../dist")).Path }
function T($n,$c){ Write-Host ("{0,-60} {1}" -f $n, $(if($c){'OK'}else{'FALLO'})) }
if (Test-Path $R) { Remove-Item $R -Recurse -Force }
New-Item -ItemType Directory "$R/_ORGANIZACION","$R/INPUT","$R/01_A" -Force | Out-Null
Copy-Item "$S/Aplicar_Plan.ps1","$S/Deshacer.ps1" "$R/_ORGANIZACION/"
Set-Content -LiteralPath "$R/INPUT/a.pdf" "AAA"; Set-Content -LiteralPath "$R/INPUT/a (1).pdf" "AAA"; Set-Content -LiteralPath "$R/INPUT/b.pdf" "BBB"; Set-Content -LiteralPath "$R/INPUT/b [org2].pdf" "BBX"; Set-Content -LiteralPath "$R/INPUT/c.txt" "C"
$plan=@(
 [pscustomobject]@{Origen='INPUT\a.pdf';Tipo='archivo';Destino='01_A';NuevoNombre='Doc_A.pdf';Accion='MOVER';OriginalConservado='';SHA256='';Area='01_A'},
 [pscustomobject]@{Origen='INPUT\a (1).pdf';Tipo='archivo';Destino='_DUPLICADOS_REVISAR\01_A';NuevoNombre='Doc_A__COPIA_1.pdf';Accion='DUPLICADO';OriginalConservado='INPUT\a.pdf';SHA256='';Area='_DUPLICADOS_REVISAR'},
 [pscustomobject]@{Origen='INPUT\b.pdf';Tipo='archivo';Destino='01_A';NuevoNombre='Doc_B.pdf';Accion='MOVER';OriginalConservado='';SHA256='';Area='01_A'},
 [pscustomobject]@{Origen='INPUT\b [org2].pdf';Tipo='archivo';Destino='_DUPLICADOS_REVISAR\01_A';NuevoNombre='Doc_B__COPIA_1.pdf';Accion='DUPLICADO';OriginalConservado='INPUT\b.pdf';SHA256='';Area='_DUPLICADOS_REVISAR'},
 [pscustomobject]@{Origen='INPUT\no_existe.pdf';Tipo='archivo';Destino='01_A';NuevoNombre='x.pdf';Accion='MOVER';OriginalConservado='';SHA256='';Area='01_A'})
$plan | Export-Csv "$R/_ORGANIZACION/plan_t.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8
& "$R/_ORGANIZACION/Aplicar_Plan.ps1" -Plan "$R/_ORGANIZACION/plan_t.csv" -Raiz $R -Ejecutar | Out-Null
$reg=Import-Csv (Get-ChildItem "$R/_ORGANIZACION/registro_*.csv").FullName -Delimiter ';'
T 'A1 duplicado identico sin SHA en el plan -> DUPLICADO_VERIFICADO' (($reg|?{$_.Origen -like '*a (1).pdf'}).Estado -eq 'DUPLICADO_VERIFICADO' -and (Test-Path "$R/_DUPLICADOS_REVISAR/01_A/Doc_A__COPIA_1.pdf"))
T 'A2 contenido distinto -> se mueve como __DIFERENTE_ al area' (($reg|?{$_.Origen -like '*b `[org2`].pdf'}).Estado -eq 'MOVIDO_HASH_NO_VERIFICADO' -and (Test-Path "$R/01_A/Doc_B__DIFERENTE_1.pdf"))
T 'A3 originales movidos y renombrados' ((Test-Path "$R/01_A/Doc_A.pdf") -and (Test-Path "$R/01_A/Doc_B.pdf"))
T 'A4 NO_ENCONTRADO registrado' (($reg|?{$_.Estado -eq 'NO_ENCONTRADO'}).Count -eq 1)
$man=Import-Csv "$R/_ORGANIZACION/manifiesto_documental.csv" -Delimiter ';'
T 'A5 manifiesto con 4 filas y hash calculado' ($man.Count -eq 4 -and -not ($man | ? { -not $_.SHA256 }))
& "$R/_ORGANIZACION/Deshacer.ps1" -Registro (Get-ChildItem "$R/_ORGANIZACION/registro_*.csv").FullName | Out-Null
T 'A6 deshacer restaura los 4 en INPUT' ((Get-ChildItem "$R/INPUT").Count -eq 5)
