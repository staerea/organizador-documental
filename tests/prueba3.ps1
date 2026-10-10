. ./prueba.ps1 *> $null
$O="$R/_ORGANIZACION"
function Lat { if (Test-Path "$O/vigilante_latido_$(Get-Date -Format yyyyMM).csv") { @(Import-Csv "$O/vigilante_latido_$(Get-Date -Format yyyyMM).csv" -Delimiter ';') } else { @() } }
function Vig { & "$O/Vigilante_Raiz.ps1" -Raiz $R }
function Viejo($min) { (Get-Item "$O/vigilante.lock").LastWriteTime = (Get-Date).AddMinutes(-$min) }
function Suelto($n) { Set-Content "$R/$n" "%PDF $n"; (Get-Item "$R/$n").LastWriteTime=(Get-Date).AddMinutes(-5) }
# T13 bloqueo antiguo sin PID (formato v1.7) de 70 min -> se recupera y la pasada trabaja
Reset; Set-Content "$O/vigilante.lock" "2026-10-04T18:48:30"; Viejo 70; Suelto 'a13.pdf'; Vig
$l=Lat; T 'T13 bloqueo v1.7 de 70 min se recupera y mueve' ((Test-Path "$R/INPUT/a13.pdf") -and ($l.Evento -contains 'BLOQUEO_HUERFANO_RECUPERADO') -and ($l.Evento -contains 'FIN_OK'))
T 'T13b el bloqueo se libera al terminar' (-not (Test-Path "$O/vigilante.lock"))
# T14 bloqueo sin PID de 10 min -> se respeta
Reset; Set-Content "$O/vigilante.lock" "2026-10-04T20:00:00"; Viejo 10; Suelto 'a14.pdf'; Vig
T 'T14 bloqueo v1.7 reciente se respeta (no mueve)' ((Test-Path "$R/a14.pdf") -and ((Lat).Evento -contains 'SALTO_EN_CURSO'))
# T15 bloqueo con PID vivo (este proceso pwsh) de 5 min -> se respeta
Reset; Set-Content "$O/vigilante.lock" ("{0}|{1}|RAIZ" -f (Get-Date -Format s), $PID); Viejo 5; Suelto 'a15.pdf'; Vig
T 'T15 bloqueo con proceso vivo se respeta' ((Test-Path "$R/a15.pdf") -and ((Lat | ? Evento -eq 'SALTO_EN_CURSO').Detalle -match 'RAIZ'))
# T16 bloqueo con PID muerto de 5 min -> se recupera de inmediato
Reset; Set-Content "$O/vigilante.lock" ("{0}|999999|M16_ALERTA" -f (Get-Date -Format s)); Viejo 5; Suelto 'a16.pdf'; Vig
T 'T16 bloqueo con proceso muerto se recupera al momento' ((Test-Path "$R/INPUT/a16.pdf") -and ((Lat).Evento -contains 'BLOQUEO_HUERFANO_RECUPERADO'))
# T17 bloqueo con PID vivo pero 40 min -> se recupera; no se mata un proceso no verificado
Reset; Set-Content "$O/vigilante.lock" ("{0}|{1}|PLANES" -f (Get-Date -Format s), $PID); Viejo 70; Suelto 'a17.pdf'; Vig
T 'T17 bloqueo de 70 min (v1.11.2: limite 65) se recupera sin matar procesos ajenos' ((Test-Path "$R/INPUT/a17.pdf") -and -not ((Lat).Evento -contains 'PROCESO_COLGADO_DETENIDO'))
# T18 presupuesto agotado -> sin alerta y registrado
Reset; 1..3 | % { Set-Content "$R/01_PROY/A/x$_.pdf.locked" "zz" }; 1..3 | % { Set-Content "$R/02_ADMIN/y$_.docx.encrypted" "zz" }
$a = [bool](& "$O/Verificar_Integridad.ps1" -Raiz $R -Modo Alerta -PresupuestoSeg 0)
$il = Import-Csv (Get-ChildItem "$O/integridad_*.csv").FullName -Delimiter ';'
T 'T18 presupuesto agotado: no alerta y lo registra' ((-not $a) -and (($il.Diagnostico -join ' ') -match 'PRESUPUESTO_AGOTADO'))
# T19 06 se recorre la primera vez y luego se omite durante el intervalo
Reset; New-Item -ItemType Directory "$R/06_DESARROLLO_SOFTWARE/lib" | Out-Null
1..3 | % { Set-Content "$R/06_DESARROLLO_SOFTWARE/app/z$_.js.locked" "zz"; Set-Content "$R/06_DESARROLLO_SOFTWARE/lib/w$_.js.locked" "zz" }
T 'T19 cifrado en 06: la primera pasada lo detecta' (Alerta); Limpia
T 'T19b la marca de 06 no se crea si hubo alerta... o si; segunda pasada omite 06' (-not (Alerta)); Limpia
(Get-Item "$O/integridad_ultimo_06.txt").LastWriteTime=(Get-Date).AddMinutes(-61)
T 'T19c pasado el intervalo vuelve a recorrer 06 y detecta' (Alerta); Limpia
# T20 latido FIN_OK con recuento
Reset; Suelto 'a20.pdf'; Vig
T 'T20 latido FIN_OK con movidos=1' (((Lat | ? Evento -eq 'FIN_OK').Detalle) -match 'movidos=1')
# T21 06 lento: si el presupuesto se agota dentro de 06 se pone la marca y no se reintenta en la siguiente pasada
Reset; $null = & "$O/Verificar_Integridad.ps1" -Raiz $R -Modo Alerta -PresupuestoSeg 0
T 'T21 presupuesto agotado antes de 06: sin marca de 06' (-not (Test-Path "$O/integridad_ultimo_06.txt"))
