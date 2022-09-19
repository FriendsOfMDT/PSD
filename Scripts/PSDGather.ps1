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
          Version - 0.0.2 - Fixed Variable LogPath
          Version - 0.0.3 - Minor change
          TODO:

.Example
#>

[CmdletBinding()]
param (

)

# Set scriptversion for logging
$ScriptVersion = "0.0.3"

# Load core module
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global -Verbose:$true
Import-Module PSDUtility -Verbose:$true
Import-Module PSDGather -Verbose:$true

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

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property GatherLocalOnly is $($tsenv:GatherLocalOnly)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property RulesFile is $($tsenv:RulesFile)"

switch ($tsenv:GatherLocalOnly)
{
    'true' {
        # Gather local info to make sure key variables are set (e.g. Architecture)
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Gather local info to make sure key variables are set (e.g. Architecture)"
        Get-PSDLocalInfo
    }
    Default {
        # Gather local info to make sure key variables are set (e.g. Architecture)
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Gather local info to make sure key variables are set (e.g. Architecture)"
        Get-PSDLocalInfo
        
        $mappingFile = Find-PSDFile -FileName ZTIGather.xml
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing CustomSettings.ini"
        Invoke-PSDRules -FilePath "$control\CustomSettings.ini" -MappingFile $mappingFile
    }
}

# Set LogPath
$TSenv:LogPath = "$(Get-PSDLocalDataPath)\SMSOSD\OSDLOGS"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TSenv:LogPath is now = $TSenv:LogPath"

# Save all the current variables for later use
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Save-PSDVariables
