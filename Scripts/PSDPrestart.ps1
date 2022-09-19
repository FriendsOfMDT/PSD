<#
.SYNOPSIS
    Runs a PowerShell script.
.DESCRIPTION
    Runs a PowerShell script.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDPrestart.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark
          Primary: @jarwidmark 
          Created: 
          Modified: 2019-05-17

          Version - 0.0.1 - () - Finalized functional version 1.

.Example
#>

if(Test-Path -Path X:\Deploy\Prestart\PSDPrestart.xml){
    [xml]$XML = Get-Content -Path X:\Deploy\Prestart\PSDPrestart.xml
    foreach($item in ($XML.Commands.Command)){
        Start-Process -FilePath $item.Executable -ArgumentList $item.Argument -Wait -PassThru
    }
}

