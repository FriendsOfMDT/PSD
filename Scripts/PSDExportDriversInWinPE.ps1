<#
.SYNOPSIS
    Update gathered information in the task sequence environment.
.DESCRIPTION
    Update gathered information in the task sequence environment.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDGather.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2020-06-16

          Version - 0.0.1 - () - Finalized functional version 1.
          TODO:

.Example
#>

[CmdletBinding()]
param (

)

# Set scriptversion for logging
$ScriptVersion = "0.0.1"

# Load core module
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility
Import-Module PSDGather

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true)
{
    $verbosePreference = "Continue"
}

Write-PSDEvent -MessageID 41000 -severity 1 -Message "Starting: $($MyInvocation.MyCommand.Name)"
