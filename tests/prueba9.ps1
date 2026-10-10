# Pruebas v1.11.1: un elemento de la raiz que falla no detiene la pasada (incidencia 07-10-2026, .gdoc ilegible)
# y los archivos nativos de Google (.gdoc, .gsheet...) se encolan sin hash y se clasifican sin hash.
$ErrorActionPreference = 'Stop'
$S = if ($env:OD_DIST) { $env:OD_DIST } else { (Resolve-Path (Join-Path $PSScriptRoot '../dist')).Path }
$B = (Resolve-Path '.').Path; $R = "$B/raiz9"; $O = "$R/_ORGANIZACION"
$script:fallos = 0
function T($n,$c){ if (-not $c) { $script:fallos++ }; Write-Host ("{0,-66} {1}" -f $n, $(if($c){'OK'}else{'FALLO'})) }
function Viejo($p) { Get-ChildItem -LiteralPath $p -Recurse -Force | ForEach-Object { $_.LastWriteTime = (Get-Date).AddMinutes(-10) }; (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddMinutes(-10) }
function Lat { $p = "$O/vigilante_latido_$(Get-Date -Format yyyyMM).csv"; if (Test-Path $p) { @(Import-Csv $p -Delimiter ';') } else { @() } }
function Reg { $p = "$O/vigilante_$(Get-Date -Format yyyyMM).csv"; if (Test-Path $p) { @(Import-Csv $p -Delimiter ';') } else { @() } }
if (Test-Path $R) { & chattr -R -i $R 2>$null; Remove-Item $R -Recurse -Force }
foreach ($d in '01_PROY/A','_ORGANIZACION/planes_pendientes','INPUT') { New-Item -ItemType Directory -Path "$R/$d" -Force | Out-Null }
Copy-Item "$S/Vigilante_Raiz.ps1","$S/Aplicar_Plan.ps1" $O
Set-Content "$R/bloqueado.pdf" '%PDF b'; Set-Content "$R/normal.pdf" '%PDF n'; Set-Content "$R/Pasos para Investigar un Tema.gdoc" '{"doc_id":"x"}'
Set-Content "$R/Tabla.gsheet" '{"doc_id":"y"}'
@([pscustomobject]@{ Origen='INPUT\Tabla.gsheet'; Tipo='archivo'; Destino='01_PROY\A'; NuevoNombre='Tabla_Proyecto.gsheet'; Accion='MOVER'; OriginalConservado=''; SHA256=''; Area='01_PROY' }) |
  Export-Csv "$O/planes_pendientes/plan_20261010_1.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8
Viejo $R; & chattr +i "$R/bloqueado.pdf"
& "$O/Vigilante_Raiz.ps1" -EsperaSeg 0 | Out-Null
$l = Lat
T 'T80 la pasada termina bien aunque un elemento falle (FIN_OK, no FIN_ERROR)' ((@($l | Where-Object Evento -eq 'FIN_OK').Count -eq 1) -and (@($l | Where-Object Evento -eq 'FIN_ERROR').Count -eq 0))
T 'T80b el elemento que falla se registra y sigue en la raiz' ((Test-Path "$R/bloqueado.pdf") -and (@(Reg | Where-Object { $_.Estado -like 'ERROR_ELEMENTO*' }).Count -eq 1) -and (@($l | Where-Object Evento -eq 'RAIZ_ELEMENTOS_CON_ERROR').Count -eq 1))
T 'T80c los demas elementos se mueven a INPUT' ((Test-Path "$R/INPUT/normal.pdf") -and -not (Test-Path "$R/normal.pdf"))
T 'T81 .gdoc encolado sin hash (EN_COLA_GOOGLE_NATIVO)' ((Test-Path -LiteralPath "$R/INPUT/Pasos para Investigar un Tema.gdoc") -and (@(Reg | Where-Object Estado -eq 'EN_COLA_GOOGLE_NATIVO').Count -ge 1))
T 'T82 plan con .gsheet aplicado; manifiesto sin SHA' ((Test-Path "$R/01_PROY/A/Tabla_Proyecto.gsheet") -and ((@(Import-Csv "$O/manifiesto_documental.csv" -Delimiter ';' | Where-Object RutaRelativa -like '*Tabla_Proyecto.gsheet')[0].SHA256) -eq ''))
& chattr -i "$R/bloqueado.pdf"
Write-Host ("FALLOS: {0}" -f $script:fallos)
