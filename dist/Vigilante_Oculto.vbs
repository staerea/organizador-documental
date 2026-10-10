' Lanzador del vigilante SIN VENTANA (organizador-documental v1.11.2).
' El Programador de tareas ejecuta: wscript.exe //B //Nologo "<_ORGANIZACION>\Vigilante_Oculto.vbs"
' wscript.exe no tiene consola, y Run(..., 0, True) crea PowerShell con la ventana oculta desde el inicio,
' de modo que no aparece ni parpadea ninguna ventana de PowerShell o CMD. Espera a que termine la pasada.
Option Explicit
Dim sh, fso, dir, ps, cmd
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
ps = sh.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
cmd = """" & ps & """ -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\Vigilante_Raiz.ps1"""
WScript.Quit sh.Run(cmd, 0, True)
