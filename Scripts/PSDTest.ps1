<#
.SYNOPSIS

.DESCRIPTION
    Demo file to show the ability to use Run PowerShell Script in Task Sequence
.LINK

.NOTES
          FileName: PSDTest.ps1
          Solution: PowerShell Deployment for MDT
          Purpose: Download and install drivers
          Author: PSD Development Team
          Contact: @Mikael_Nystrom, @jarwidmark
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2020-11-29

          Version - 0.0.1 - () - Finalized functional version 1.

.Example
#>


param (
    $Param1,
    $Param2
)

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility
Import-Module PSDDeploymentShare

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true)
{
    $verbosePreference = "Continue"
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"
foreach($i in (Get-ChildItem -Path TSEnv:)){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property $($i.Name) is $($i.Value)"
}

Function Wait-PSDPrompt{
    Param(
        $prompt,
        $secondsToWait
    )
    Write-Host -NoNewline $prompt
    $secondsCounter = 0
    $subCounter = 0
    While ( (!$host.ui.rawui.KeyAvailable) -and ($count -lt $secondsToWait) ){
        start-sleep -m 10
        $subCounter = $subCounter + 10
        if($subCounter -eq 1000)
        {
            $secondsCounter++
            $subCounter = 0
            Write-Host -NoNewline "."
        }       
        If ($secondsCounter -eq $secondsToWait) { 
            Write-Host "`r`n"
            return $false;
        }
    }
    Write-Host "`r`n"
    return $true;
}

$Message = "$($MyInvocation.MyCommand.Name): Param1 is $Param1"
Write-PSDLog -Message $Message
Show-PSDActionProgress -Message $Message
Start-Sleep -Seconds 10

$Message = "$($MyInvocation.MyCommand.Name): Param2 is $Param2"
Write-PSDLog -Message $Message
Show-PSDActionProgress -Message $Message
Start-Sleep -Seconds 10

Wait-PSDPrompt -prompt "Press a key, or wait" -secondsToWait 5

Exit 0

