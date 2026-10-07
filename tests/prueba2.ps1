. ./prueba.ps1 *> $null
Reset
Copy-Item "$S/Vigilante_Raiz.ps1" "$R/_ORGANIZACION/" -Force
Set-Content "$R/_Estado_NDMI.pdf" "%PDF a"; Set-Content "$R/0_2020_res.pdf" "%PDF b"; Set-Content "$R/01_suelto.pdf" "%PDF c"
New-Item -ItemType Directory "$R/_OTRA_CONTROL" | Out-Null; Set-Content "$R/REANUDAR_VIGILANTE.bat" "x"
Get-ChildItem $R -File | % { $_.LastWriteTime=(Get-Date).AddMinutes(-5) }
& "$R/_ORGANIZACION/Vigilante_Raiz.ps1" -Raiz $R
T 'T12 archivos que empiezan por _ / NN_ van a INPUT' ((Test-Path "$R/INPUT/_Estado_NDMI.pdf") -and (Test-Path "$R/INPUT/0_2020_res.pdf") -and (Test-Path "$R/INPUT/01_suelto.pdf"))
T 'T12b carpetas de area/control y .bat propios intactos' ((Test-Path "$R/_OTRA_CONTROL") -and (Test-Path "$R/01_PROY") -and (Test-Path "$R/REANUDAR_VIGILANTE.bat"))
