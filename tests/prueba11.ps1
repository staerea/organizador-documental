# Pruebas v1.11.4: al aplicar un plan, toda fila MOVER se compara por SHA-256 con el archivo vigente y con las filas
# anteriores del mismo plan; los identicos se apartan como copia verificada en lugar de entrar con sufijo _vN.
$ErrorActionPreference = 'Stop'
$S = if ($env:OD_DIST) { $env:OD_DIST } else { (Resolve-Path (Join-Path $PSScriptRoot '../dist')).Path }
$B = (Resolve-Path '.').Path; $R = "$B/raiz11"; $O = "$R/_ORGANIZACION"
$script:fallos = 0
function T($n,$c){ if (-not $c) { $script:fallos++ }; Write-Host ("{0,-66} {1}" -f $n, $(if($c){'OK'}else{'FALLO'})) }
function Hx($p) { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() }
if (Test-Path $R) { Remove-Item $R -Recurse -Force }
foreach ($d in '01_PROY/A','_ORGANIZACION','INPUT') { New-Item -ItemType Directory -Path "$R/$d" -Force | Out-Null }
Copy-Item "$S/Aplicar_Plan.ps1" $O
Set-Content "$R/01_PROY/A/Orig.pdf" 'contenido X' -NoNewline
Set-Content "$R/INPUT/copia (1).pdf" 'contenido X' -NoNewline
Set-Content "$R/INPUT/nuevo1.pdf" 'contenido Y' -NoNewline
Set-Content "$R/INPUT/nuevo2.pdf" 'contenido Y' -NoNewline
Set-Content "$R/INPUT/distinto.pdf" 'contenido Z' -NoNewline
Set-Content "$R/INPUT/fantasma.pdf" 'contenido W' -NoNewline
@([pscustomobject]@{RutaRelativa='01_PROY\A\Orig.pdf';SHA256=(Hx "$R/01_PROY/A/Orig.pdf");Tamano=11;FechaMod=0;Area='01_PROY';Estado='HEREDADO';NombreOriginal='';FechaClasificacion='2026-10-03';VersionSkill='1.0'},
  [pscustomobject]@{RutaRelativa='01_PROY\A\Ya_no_existe.pdf';SHA256=(Hx "$R/INPUT/fantasma.pdf");Tamano=11;FechaMod=0;Area='01_PROY';Estado='MOVIDO';NombreOriginal='x';FechaClasificacion='2026-10-03';VersionSkill='1.11'}) |
  Export-Csv "$O/manifiesto_documental.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8
$p = "$O/plan_t11.csv"
@(@('INPUT\copia (1).pdf','Orig_v2.pdf'),@('INPUT\nuevo1.pdf','Nuevo.pdf'),@('INPUT\nuevo2.pdf','Nuevo_v2.pdf'),@('INPUT\distinto.pdf','Distinto.pdf'),@('INPUT\fantasma.pdf','Fantasma.pdf')) | ForEach-Object {
  [pscustomobject]@{ Origen=$_[0]; Tipo='archivo'; Destino='01_PROY\A'; NuevoNombre=$_[1]; Accion='MOVER'; OriginalConservado=''; SHA256=''; Area='01_PROY' } } |
  Export-Csv $p -Delimiter ';' -NoTypeInformation -Encoding UTF8
& "$O/Aplicar_Plan.ps1" -Plan $p -Raiz $R | Out-Null
T 'T110 en simulacion no se mueve nada' ((Test-Path "$R/INPUT/nuevo2.pdf") -and -not (Test-Path "$R/01_PROY/A/Nuevo.pdf"))
Start-Sleep -Seconds 1.2; Get-ChildItem "$O/registro_*.csv" | Remove-Item
& "$O/Aplicar_Plan.ps1" -Plan $p -Raiz $R -Ejecutar | Out-Null
$reg = @(Get-ChildItem "$O/registro_*.csv" | Sort-Object LastWriteTime | Select-Object -Last 1 | ForEach-Object { Import-Csv $_.FullName -Delimiter ';' })
T 'T111 identico a un archivo vigente: apartado como __COPIA_1 verificada' ((Test-Path "$R/_DUPLICADOS_REVISAR/01_PROY/A/Orig__COPIA_1.pdf") -and -not (Test-Path "$R/01_PROY/A/Orig_v2.pdf"))
T 'T112 primer archivo nuevo entra con su nombre' (Test-Path "$R/01_PROY/A/Nuevo.pdf")
T 'T113 identico a otra fila del mismo plan: apartado, sin _v2' ((Test-Path "$R/_DUPLICADOS_REVISAR/01_PROY/A/Nuevo__COPIA_1.pdf") -and -not (Test-Path "$R/01_PROY/A/Nuevo_v2.pdf"))
T 'T114 contenido distinto: se mueve normalmente' (Test-Path "$R/01_PROY/A/Distinto.pdf")
T 'T115 hash de un archivo que ya no existe: no se trata como duplicado' (Test-Path "$R/01_PROY/A/Fantasma.pdf")
T 'T116 registro con DUPLICADO_DETECTADO_AL_APLICAR (2)' (@($reg | Where-Object Estado -eq 'DUPLICADO_DETECTADO_AL_APLICAR').Count -eq 2)
$man = @(Import-Csv "$O/manifiesto_documental.csv" -Delimiter ';')
T 'T117 manifiesto: copias DUPLICADO_VERIFICADO con su SHA' ((@($man | Where-Object { $_.Estado -eq 'DUPLICADO_VERIFICADO' -and $_.SHA256 }).Count -eq 2))
T 'T118 no se borra nada (6 archivos en total) y el original intacto' ((@(Get-ChildItem $R -Recurse -File -Filter *.pdf).Count -eq 6) -and ((Get-Content "$R/01_PROY/A/Orig.pdf" -Raw) -eq 'contenido X'))

# T119 (v1.11.5): un archivo ya clasificado que se mueve dentro del archivo no es duplicado de si mismo (incidencia 25-10)
Set-Content "$R/01_PROY/A/Propio_v2.pdf" 'contenido P' -NoNewline
[pscustomobject]@{RutaRelativa='01_PROY\A\Propio_v2.pdf';SHA256=(Hx "$R/01_PROY/A/Propio_v2.pdf");Tamano=11;FechaMod=0;Area='01_PROY';Estado='MOVIDO';NombreOriginal='p.pdf';FechaClasificacion='2026-10-11';VersionSkill='1.11'} | Export-Csv "$O/manifiesto_documental.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8 -Append
$p3 = "$O/plan_t119.csv"
[pscustomobject]@{ Origen='01_PROY\A\Propio_v2.pdf'; Tipo='archivo'; Destino='_DUPLICADOS_REVISAR\01_PROY\A'; NuevoNombre='Nuevo__COPIA_SIMILAR_1.pdf'; Accion='MOVER'; OriginalConservado='01_PROY\A\Nuevo.pdf'; SHA256=''; Area='_DUPLICADOS_REVISAR' } | Export-Csv $p3 -Delimiter ';' -NoTypeInformation -Encoding UTF8
Start-Sleep -Seconds 1.2; Get-ChildItem "$O/registro_*.csv" | Remove-Item
& "$O/Aplicar_Plan.ps1" -Plan $p3 -Raiz $R -Ejecutar | Out-Null
$reg3 = @(Get-ChildItem "$O/registro_*.csv" | ForEach-Object { Import-Csv $_.FullName -Delimiter ';' })
T 'T119 movimiento interno: sin autodeteccion, nombre del plan y estado MOVIDO' ((Test-Path "$R/_DUPLICADOS_REVISAR/01_PROY/A/Nuevo__COPIA_SIMILAR_1.pdf") -and (@($reg3 | Where-Object Estado -eq 'DUPLICADO_DETECTADO_AL_APLICAR').Count -eq 0) -and (@($reg3 | Where-Object Estado -eq 'MOVIDO').Count -eq 1))
Write-Host ("FALLOS: {0}" -f $script:fallos)
