rmdir c:\minint /s /q
powershell -noprofile -executionpolicy bypass -file ..\Installer\Install.ps1
powershell -noprofile -executionpolicy bypass -file \\%computername%\psdeploymentshare$\scripts\psdstart.ps1
