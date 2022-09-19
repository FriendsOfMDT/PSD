<#
.SYNOPSIS
    Script that logs not yet supported features or scenarios
.DESCRIPTION
    Script that logs not yet supported features or scenarios
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDTBA.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark
          Primary: @Mikael_Nystrom 
          Created: 2022-01-21
          Modified: 
          Version:0.0.1 - () - Finalized functional version 1.
          TODO:

.Example
#>

param (

)

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility
Import-Module PSDDeploymentShare

$verbosePreference = "Continue"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $($tsenv:DeployRoot)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"

#Notify
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): The built in VB Script has been replaced by the script, however, the function the VB Script would have done is not yet implemented, sorry, working on this"
