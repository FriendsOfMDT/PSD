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

$verbosePreference = "Continue"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $($tsenv:DeployRoot)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TSEnv:VariableName is now $TSEnv:VariableName"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TSEnv:VariableValue is now $TSEnv:VariableValue"

$VariableName = $TSEnv:VariableName
$VariableValue = $TSEnv:VariableValue
New-Item -Path TSEnv: -Name "$VariableName" -Value "$VariableValue" -Force

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $VariableName is now $((Get-ChildItem -Path TSEnv: | Where-Object Name -Like $VariableName).value)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Save-PSDVariables

BREAK
<#
<variable name="VariableName" property="VariableName">DriverGroup001</variable>
<variable name="VariableValue" property="VariableValue">Client\Windows 10 1709\%model%</variable>
oEnvironment.Item(oEnvironment.Item("VariableName")) = oEnvironment.Item("VariableValue")
$tsenv:DeployRoot

powershell.exe -executionpolicy bypass -command "& {$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment; $tsenv.Value('ImageVersion') = get-date -uformat %m%d%Y}"

#>

