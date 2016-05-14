$verbosePreference = "Continue"
$deployRoot = Split-Path -Path "$PSScriptRoot"
Import-Module "$deployRoot\Scripts\PSDUtility.psm1" -Force

dir tsenv: | Out-File "$($env:SystemDrive)\DumpVars.log"
