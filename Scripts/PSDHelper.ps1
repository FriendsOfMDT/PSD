<#
.SYNOPSIS
    Helper script for troubleshooting.
.DESCRIPTION
    Helper script for troubleshooting.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDHelper.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2020-06-16

          Version - 0.0.1 - () - Finalized functional version 1.

.Example
#>

Param(
    $MDTDeploySharePath,
    $UserName,
    $Password
)

#Connect
& net use $MDTDeploySharePath $Password /USER:$UserName

# Set the module path based on the current script path
$deployRoot = Split-Path -Path "$PSScriptRoot"
$env:PSModulePath = $env:PSModulePath + ";$deployRoot\Tools\Modules"


#Import Env
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global -Force -Verbose
Import-Module PSDUtility -Force -Verbose -Scope Global
Import-Module PSDDeploymentShare -Force -Verbose -Scope Global
Import-Module PSDGather -Force -Verbose -Scope Global

dir tsenv: | Out-File "$($env:SystemDrive)\PSDDumpVars.log"
Get-Content -Path "$($env:SystemDrive)\PSDDumpVars.log"

