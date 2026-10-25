$ErrorActionPreference='Stop'
$R = (Resolve-Path '.').Path + '/raiz'
$S = if ($env:OD_DIST) { $env:OD_DIST } else { (Resolve-Path (Join-Path $PSScriptRoot '../dist')).Path }
function Reset {
  if (Test-Path $R) { Remove-Item $R -Recurse -Force }
  foreach ($d in '01_PROY/A','01_PROY/B','02_ADMIN','06_DESARROLLO_SOFTWARE/app','_ORGANIZACION','INPUT') { New-Item -ItemType Directory -Path "$R/$d" -Force | Out-Null }
  Copy-Item "$S/Verificar_Integridad.ps1","$S/Vigilante_Raiz.ps1","$S/Aplicar_Plan.ps1","$S/Generar_Panel_Duplicados.ps1" "$R/_ORGANIZACION/"
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
function T($n,$c){ Write-Host ("{0,-66} {1}" -f $n, $(if($c){"OK"}else{"FALLO"})) }
$O="$R/_ORGANIZACION"
Reset; New-Item -ItemType Directory "$O/planes_pendientes" -Force | Out-Null
1..4 | % { Set-Content "$R/INPUT/n$_.txt" "contenido nuevo $_"; (Get-Item "$R/INPUT/n$_.txt").LastWriteTime=(Get-Date).AddMinutes(-5) }
$plan = "$O/planes_pendientes/plan_20261006_1200_bloque.csv"
1..4 | % { [pscustomobject]@{Origen="INPUT\n$_.txt";Tipo='archivo';Destino='01_PROY\A';NuevoNombre="N_$_.txt";Accion='MOVER';OriginalConservado='';SHA256='';Area='01_PROY'} } | Export-Csv $plan -Delimiter ';' -NoTypeInformation -Encoding UTF8
(Get-Item $plan).LastWriteTime=(Get-Date).AddMinutes(-5)
& "$O/Aplicar_Plan.ps1" -Plan $plan -Raiz $R -Ejecutar -PresupuestoMin 0 | Out-Null
$resto = @(Get-ChildItem "$O/planes_pendientes" -Filter '*_resto_*.csv')
T 'T50 presupuesto 0: no mueve nada y deja el resto como plan nuevo' ($resto.Count -eq 1 -and @(Import-Csv $resto[0].FullName -Delimiter ';').Count -eq 4 -and (Test-Path "$R/INPUT/n1.txt"))
$reg = Import-Csv (Get-ChildItem "$O/registro_*.csv" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName -Delimiter ';'
T 'T50b registro PLAN_APLAZADO' (($reg.Estado -join ' ') -match 'PLAN_APLAZADO: 4')
Remove-Item $plan; (Get-Item $resto[0].FullName).LastWriteTime=(Get-Date).AddMinutes(-5)
& "$O/Vigilante_Raiz.ps1" -Raiz $R
T 'T51 el vigilante aplica el plan resto en la pasada siguiente' ((Test-Path "$R/01_PROY/A/N_4.txt") -and -not (Test-Path "$R/INPUT/n4.txt") -and (Test-Path "$O/planes_aplicados/$($resto[0].Name)"))
# T52 hash diferido para archivos grandes
Set-Content "$R/INPUT/grande.bin" ("x" * 5000); (Get-Item "$R/INPUT/grande.bin").LastWriteTime=(Get-Date).AddMinutes(-5)
$p2="$O/plan_t52.csv"; [pscustomobject]@{Origen='INPUT\grande.bin';Tipo='archivo';Destino='01_PROY\A';NuevoNombre='Grande.bin';Accion='MOVER';OriginalConservado='';SHA256='';Area='01_PROY'} | Export-Csv $p2 -Delimiter ';' -NoTypeInformation -Encoding UTF8
& "$O/Aplicar_Plan.ps1" -Plan $p2 -Raiz $R -Ejecutar -MaxHashMB 0 | Out-Null
$m = Import-Csv "$O/manifiesto_documental.csv" -Delimiter ';' | ? { $_.RutaRelativa -like '*Grande.bin' }
T 'T52 archivo grande: se mueve y el SHA queda diferido' ((Test-Path "$R/01_PROY/A/Grande.bin") -and -not $m.SHA256 -and $m.VersionSkill -eq '1.11.4-sha-diferido')
$m4 = Import-Csv "$O/manifiesto_documental.csv" -Delimiter ';' | ? { $_.RutaRelativa -like '*N_4.txt' }
T 'T52b archivo normal: SHA calculado (1.10.1)' ($m4.SHA256 -and $m4.VersionSkill -eq '1.11.4')
