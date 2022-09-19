<#
.SYNOPSIS
    Set variable
.DESCRIPTION
    Set variable
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDSetVariable.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2022-01-12
          Version:0.0.2 - () - Finalized functional version 1.
          TODO:

.Example
#>

[CmdletBinding()]
param (

)

# Set scriptversion for logging
$ScriptVersion = "0.0.2"

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global -Verbose:$true
Import-Module PSDUtility -Verbose:$true

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

New-Item -Path TSEnv: -Name "$TSEnv:VariableName" -Value "$TSEnv:VariableValue" -Force
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property $TSEnv:VariableName is $((Get-ChildItem -Path TSEnv: | Where-Object Name -Like $TSEnv:VariableName).value)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Save-PSDVariables | Out-Null
