# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDNextPhase.ps1
# // 
# // Purpose:   Next PHASE
# // 
# // 
# // ***************************************************************************

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

#Next Phase
$PHASE = $tsenv:PHASE
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Current Phase is $PHASE"

switch ($PHASE)
{
    INITIALIZATION {$PHASE = "VALIDATION"}
    VALIDATION {$PHASE = "STATECAPTURE"}
    STATECAPTURE {$PHASE = "PREINSTALL"}
    PREINSTALL {$PHASE = "INSTALL"}
    INSTALL {$PHASE = "POSTINSTALL"}
    POSTINSTALL {$PHASE = "STATERESTORE"}
    STATERESTORE {$PHASE = ""}
}

$tsenv:PHASE = $Phase

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Next Phase is $PHASE"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Save-PSDVariables
