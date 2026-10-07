param([Parameter(Mandatory=$true)][string]$Registro)
$filas = @(Import-Csv -LiteralPath $Registro -Delimiter ';' -Encoding UTF8); [array]::Reverse($filas); $ok=0; $om=0
foreach ($f in $filas) { if ($f.Estado -notmatch '^(MOVIDO|DUPLICADO_VERIFICADO|DUPLICADO_ZIP_VERIFICADO)') { continue }
  if (-not (Test-Path -LiteralPath $f.Destino) -or (Test-Path -LiteralPath $f.Origen)) { $om++; continue }
  Move-Item -LiteralPath $f.Destino -Destination $f.Origen; $ok++ }
Write-Host "Restaurados: $ok | Omitidos: $om  (el manifiesto conserva las filas: revisalas si deshaces)"
