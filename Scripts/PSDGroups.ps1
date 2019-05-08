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
Import-Module PSDUtility
Import-Module PSDDeploymentShare
$verbosePreference = "Continue"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $deployRoot"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"
