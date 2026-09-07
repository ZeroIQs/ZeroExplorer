Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
currentDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1Path = currentDir & "\ZeroExplore.ps1"

WshShell.CurrentDirectory = currentDir
WshShell.Run "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -STA -File """ & ps1Path & """", 0, False
