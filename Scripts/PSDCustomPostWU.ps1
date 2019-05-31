# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDTemplate.ps1
# // 
# // Purpose:   Apply the specified operating system.
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
