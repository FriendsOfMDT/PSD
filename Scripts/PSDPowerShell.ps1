<#
.SYNOPSIS
    Runs a PowerShell script.
.DESCRIPTION
    Runs a PowerShell script.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDPowerShell.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @AndHammarskjold
          Primary: @jarwidmark 
          Created: 
          Modified: 2019-05-17

          Version - 0.0.1 - () - Finalized functional version 1.

          TODO:

.Example
#>

[CmdletBinding()]
param (

)

# Set scriptversion for logging
$ScriptVersion = "0.0.1"

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

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Starting: $($MyInvocation.MyCommand.Name) - Version $ScriptVersion"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): The task sequencer log is located at $("$tsenv:_SMSTSLogPath\SMSTS.LOG"). For task sequence failures, please consult this log."
Write-PSDEvent -MessageID 41000 -severity 1 -Message "Starting: $($MyInvocation.MyCommand.Name)"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:ScriptName $($tsenv:ScriptName)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:Parameters $($tsenv:Parameters)"

$ScriptToRun = Find-PSDFile -FileName $($tsenv:ScriptName)

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run: $ScriptToRun"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): ArgumentList: $ScriptToRun $tsenv:Parameters"

Start PowerShell -ArgumentList "$ScriptToRun $tsenv:Parameters" -Wait -PassThru