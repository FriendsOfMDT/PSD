# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDSetVariables.ps1
# // 
# // Purpose:   Set variable
# // 
# // 
# // ***************************************************************************

param (

)

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true)
{
    $verbosePreference = "Continue"
}

Write-PSDEvent -MessageID 41000 -severity 1 -Message "Starting: $($MyInvocation.MyCommand.Name)"

$VariableName = $TSEnv:VariableName
$VariableValue = $TSEnv:VariableValue
New-Item -Path TSEnv: -Name "$VariableName" -Value "$VariableValue" -Force

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $VariableName is now $((Get-ChildItem -Path TSEnv: | Where-Object Name -Like $VariableName).value)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Save-PSDVariables | Out-Null
