# Pruebas v1.11: carpeta de entrada configurable (nuevos -> INPUT), rutas configurables, recogida de solicitudes
# desde la carpeta de descargas del navegador, solicitudes repetidas, raiz no disponible y M15 (copia verificada).
$ErrorActionPreference = 'Stop'
$S = if ($env:OD_DIST) { $env:OD_DIST } else { (Resolve-Path (Join-Path $PSScriptRoot '../dist')).Path }
$B = (Resolve-Path '.').Path; $R = "$B/raiz8"; $DL = "$B/descargas8"; $CP = "$B/copia8"; $O = "$R/_ORGANIZACION"
$script:fallos = 0
function T($n,$c){ if (-not $c) { $script:fallos++ }; Write-Host ("{0,-66} {1}" -f $n, $(if($c){'OK'}else{'FALLO'})) }
function Viejo($p) { Get-ChildItem -LiteralPath $p -Recurse -Force | ForEach-Object { $_.LastWriteTime = (Get-Date).AddMinutes(-10) }; (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddMinutes(-10) }
function Lat { $p = "$O/vigilante_latido_$(Get-Date -Format yyyyMM).csv"; if (Test-Path $p) { @(Import-Csv $p -Delimiter ';') } else { @() } }
function Cfg([hashtable]$v) { $c = [ordered]@{ RaizDocumental=''; CarpetaEntrada='INPUT'; CarpetaSolicitudes=$DL; ModoBorrados='ACTIVO' }; foreach ($k in $v.Keys) { $c[$k] = $v[$k] }
  ($c.Keys | ForEach-Object { [pscustomobject]@{ Clave=$_; Valor=$c[$_]; Descripcion='' } }) | Export-Csv "$O/config_plataforma.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8 }
function Reset {
  foreach ($d in $R, $DL, $CP) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
  foreach ($d in '01_PROY/A','_ORGANIZACION/planes_pendientes','nuevos') { New-Item -ItemType Directory -Path "$R/$d" -Force | Out-Null }
  New-Item -ItemType Directory -Path $DL, $CP -Force | Out-Null
  Copy-Item "$S/Vigilante_Raiz.ps1","$S/Aplicar_Plan.ps1","$S/Verificar_Integridad.ps1","$S/Generar_Panel_Duplicados.ps1","$S/Copia_Verificada.ps1","$S/Configurar_Plataforma.ps1" $O
  Cfg @{} }
function Vig { & "$O/Vigilante_Raiz.ps1" -EsperaSeg 0 | Out-Null }

# --- T60 migracion nuevos -> INPUT (solo existe nuevos) ---
Reset; Set-Content "$R/nuevos/a.pdf" '%PDF a'; New-Item -ItemType Directory "$R/nuevos/sub" | Out-Null; Set-Content "$R/nuevos/sub/b.txt" 'b'; Viejo $R
Vig
T 'T60 nuevos renombrada a INPUT con su contenido' ((Test-Path "$R/INPUT/a.pdf") -and (Test-Path "$R/INPUT/sub/b.txt") -and -not (Test-Path "$R/nuevos"))
T 'T60b latido ENTRADA_MIGRADA y historial con INPUT' ((@(Lat | Where-Object Evento -eq 'ENTRADA_MIGRADA').Count -eq 1) -and ((Get-Content "$O/entrada_historial.txt") -contains 'INPUT'))
Vig
T 'T60c segunda pasada: sin nueva migracion' (@(Lat | Where-Object Evento -eq 'ENTRADA_MIGRADA').Count -eq 1)

# --- T61 existen las dos: se traslada el contenido sin pisar nada ---
Reset; New-Item -ItemType Directory "$R/INPUT" | Out-Null; Set-Content "$R/INPUT/a.pdf" 'uno'; Set-Content "$R/nuevos/a.pdf" 'dos'; Viejo $R
Vig
T 'T61 ambas existen: nada se pisa y nuevos desaparece vacia' ((Get-Content "$R/INPUT/a.pdf") -eq 'uno' -and (Get-Content -LiteralPath "$R/INPUT/a [org2].pdf") -eq 'dos' -and -not (Test-Path "$R/nuevos"))

# --- T62 un plan antiguo que cita nuevos\ se aplica tras la migracion ---
Reset; Set-Content "$R/nuevos/Factura.pdf" '%PDF f'; Viejo $R
@([pscustomobject]@{ Origen='nuevos\Factura.pdf'; Tipo='archivo'; Destino='01_PROY\A'; NuevoNombre='Factura_2026.pdf'; Accion='MOVER'; OriginalConservado=''; SHA256=''; Area='01_PROY' }) |
  Export-Csv "$O/planes_pendientes/plan_20261007_1.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8
Viejo "$O/planes_pendientes"; Vig
T 'T62 plan con nuevos\ aplicado desde INPUT' ((Test-Path "$R/01_PROY/A/Factura_2026.pdf") -and -not (Test-Path "$R/INPUT/Factura.pdf"))

# --- T63 solicitud de borrado recogida de la carpeta de descargas configurada ---
Reset; New-Item -ItemType Directory "$R/_DUPLICADOS_REVISAR/01_PROY/A" -Force | Out-Null
Set-Content "$R/01_PROY/A/Doc.pdf" '%PDF igual'; Copy-Item "$R/01_PROY/A/Doc.pdf" "$R/_DUPLICADOS_REVISAR/01_PROY/A/Doc__COPIA_1.pdf"
$sol = 'SOLICITUD_BORRADO_DUPLICADOS_20261007_120000.csv'
@([pscustomobject]@{ RutaDuplicado='_DUPLICADOS_REVISAR\01_PROY\A\Doc__COPIA_1.pdf'; RutaOriginal='01_PROY\A\Doc.pdf'; Tipo='SHA'; Tamano='11'; SHA256=''; Solicitado=(Get-Date).ToUniversalTime().AddMinutes(-15).ToString('s') }) |
  Export-Csv "$DL/$sol" -Delimiter ';' -NoTypeInformation -Encoding UTF8
Copy-Item "$DL/$sol" "$B/sol_copia.csv" -Force; Viejo $R; Viejo $DL
Vig
T 'T63 copia borrada desde solicitud en Descargas' ((-not (Test-Path "$R/_DUPLICADOS_REVISAR/01_PROY/A/Doc__COPIA_1.pdf")) -and (Test-Path "$R/01_PROY/A/Doc.pdf"))
T 'T63b solicitud retirada de Descargas y archivada' ((-not (Test-Path "$DL/$sol")) -and (Test-Path "$O/borrados_solicitudes/procesadas/$sol"))
# --- T64 la misma solicitud reaparece en Descargas: se archiva sin repetir ---
Copy-Item "$B/sol_copia.csv" "$DL/$sol"; Viejo $DL
$nRes = @(Import-Csv "$O/borrados_solicitudes/procesadas/resultado_$sol" -Delimiter ';').Count
Vig
T 'T64 solicitud repetida archivada en procesadas\repetidas' ((Test-Path "$O/borrados_solicitudes/procesadas/repetidas/$sol") -and -not (Test-Path "$DL/$sol") -and -not (Test-Path "$O/borrados_solicitudes/$sol"))
T 'T64b no se vuelve a procesar' (@(Import-Csv "$O/borrados_solicitudes/procesadas/resultado_$sol" -Delimiter ';').Count -eq $nRes)
T 'T65 el panel indica las carpetas de recogida' ((Get-Content "$R/_DUPLICADOS_REVISAR/_panel/datos_1.js","$R/_DUPLICADOS_REVISAR/_panel/datos_2.js","$R/_DUPLICADOS_REVISAR/_panel/datos_3.js" -ErrorAction SilentlyContinue -Raw) -match [regex]::Escape(($DL -replace '\\','\\')))

# --- T66 raiz configurada no disponible ---
Reset; Cfg @{ RaizDocumental = "$B/no_existe" }
$err = $null; try { & "$O/Vigilante_Raiz.ps1" -EsperaSeg 0 | Out-Null } catch { $err = $_ }
T 'T66 raiz no disponible: registra y sale sin error' ((-not $err) -and (Test-Path "$O/vigilante_sin_raiz.txt") -and (Test-Path "$R/nuevos"))
Cfg @{ RaizDocumental = $R }; Vig
T 'T66b raiz configurada explicitamente: funciona' ((Test-Path "$R/INPUT") -and -not (Test-Path "$R/nuevos"))

# --- T67 Configurar_Plataforma: validacion y cambio de entrada ---
$e1 = $null; try { & "$O/Configurar_Plataforma.ps1" -Clave CarpetaEntrada -Valor '_MALA' *> $null } catch { $e1 = $_ }
T 'T67 nombre de entrada no valido rechazado' ([bool]$e1 -and ((Import-Csv "$O/config_plataforma.csv" -Delimiter ';' | Where-Object Clave -eq 'CarpetaEntrada').Valor -eq 'INPUT'))
& "$O/Configurar_Plataforma.ps1" -Clave CarpetaEntrada -Valor 'ENTRADA' *> $null
Set-Content "$R/INPUT/x.pdf" 'x'; Viejo $R; Vig
T 'T67b cambio a ENTRADA: INPUT se traslada sola' ((Test-Path "$R/ENTRADA/x.pdf") -and -not (Test-Path "$R/INPUT") -and -not (Test-Path "$R/nuevos"))
& "$O/Configurar_Plataforma.ps1" -Clave Restaurar *> $null
T 'T67c restaurar valores por defecto' ((Import-Csv "$O/config_plataforma.csv" -Delimiter ';' | Where-Object Clave -eq 'CarpetaEntrada').Valor -eq 'INPUT')

# --- T68 M16 no cuenta la entrada como cambio masivo ---
Reset; Cfg @{}; New-Item -ItemType Directory "$R/INPUT" -Force | Out-Null
1..230 | ForEach-Object { Set-Content "$R/INPUT/f$_.txt" "$_" }
$al = & "$O/Verificar_Integridad.ps1" -Raiz $R -Modo Alerta
T 'T68 230 archivos nuevos en INPUT no disparan alerta' ((-not $al) -and -not (Test-Path "$O/vigilante.pausa"))

# --- T69-T72 M15 copia verificada ---
Reset; Set-Content "$R/01_PROY/A/uno.pdf" 'version 1'; Set-Content "$R/01_PROY/A/dos.txt" 'dos'
@([pscustomobject]@{ Modulo='M15'; Nombre='Copia'; Activo='SI'; Modo='AUTOMATICO'; Parametros="Destino=$CP|Areas=01_PROY|MaxGBPorPasada=1" }) | Export-Csv "$O/config_modulos.csv" -Delimiter ';' -NoTypeInformation -Encoding UTF8
& "$O/Copia_Verificada.ps1" -Raiz $R
$res = @(Import-Csv "$O/copia_$(Get-Date -Format yyyyMMdd).csv" -Delimiter ';')
T 'T69 copia inicial verificada (2 archivos) e indice' ((@($res | Where-Object Estado -eq 'COPIADO_VERIFICADO').Count -eq 2) -and (Test-Path "$CP/raiz8/01_PROY/A/uno.pdf") -and (Test-Path "$CP/raiz8/_copia_indice.csv"))
& "$O/Copia_Verificada.ps1" -Raiz $R
$res2 = @(Import-Csv "$O/copia_$(Get-Date -Format yyyyMMdd).csv" -Delimiter ';')
T 'T69b sin cambios: no copia de nuevo' ($res2.Count -eq $res.Count)
Set-Content "$R/01_PROY/A/uno.pdf" 'CIFRADO!!'; (Get-Item "$R/01_PROY/A/uno.pdf").LastWriteTime = (Get-Date).AddMinutes(1)
& "$O/Copia_Verificada.ps1" -Raiz $R
$ver = @(Get-ChildItem "$CP/raiz8/01_PROY/A" -Filter 'uno__v*.pdf')
T 'T70 archivo cambiado: version nueva junto a la anterior, sin sobrescribir' ($ver.Count -eq 1 -and (Get-Content "$CP/raiz8/01_PROY/A/uno.pdf") -eq 'version 1' -and (Get-Content $ver[0].FullName) -eq 'CIFRADO!!')
& "$O/Copia_Verificada.ps1" -Raiz $R -Destino "$R/01_PROY"
T 'T71 destino dentro de la raiz sincronizada: rechazado' ((Get-Content "$O/copia_ultima.txt") -match 'DESTINO_RECHAZADO')
Remove-Item "$O/copia_ultima.txt"; & "$O/Copia_Verificada.ps1" -Raiz $R -Destino "$B/disco_desconectado"
T 'T71b destino no disponible: se registra y no se marca como hecha' ((-not (Test-Path "$O/copia_ultima.txt")) -and (@(Import-Csv "$O/copia_$(Get-Date -Format yyyyMMdd).csv" -Delimiter ';' | Where-Object Estado -eq 'DESTINO_NO_DISPONIBLE').Count -ge 1))
Set-Content "$O/vigilante.pausa" 'alerta'; Set-Content "$R/01_PROY/A/tres.txt" '3'
& "$O/Copia_Verificada.ps1" -Raiz $R
T 'T72 con alerta M16 activa no copia' (-not (Test-Path "$CP/raiz8/01_PROY/A/tres.txt"))
Remove-Item "$O/vigilante.pausa"
# T73 el vigilante lanza la copia una vez al dia (en segundo plano) si M15 esta activo
Remove-Item "$O/copia_ultima.txt" -ErrorAction SilentlyContinue; Vig; Start-Sleep -Seconds 4
T 'T73 vigilante lanza M15 (latido M15_COPIA_LANZADA y copia hecha)' ((@(Lat | Where-Object Evento -eq 'M15_COPIA_LANZADA').Count -ge 1) -and (Test-Path "$CP/raiz8/01_PROY/A/tres.txt"))
Write-Host ("FALLOS: {0}" -f $script:fallos)
