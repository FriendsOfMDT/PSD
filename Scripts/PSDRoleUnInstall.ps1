<#
.SYNOPSIS
    Uninstall Roles and Roleservices
.DESCRIPTION
    Uninstall Roles and Roleservices
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDRoleUnInstall.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @AndHammarskjold
          Primary: @jarwidmark 
          Created: 2019-05-17
          Modified: 2022-01-24

          Version - 0.0.1 - () - Finalized functional version 1.

          TODO:

.Example
#>

param (

)

# Set scriptversion for logging
$ScriptVersion = "0.0.1"

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility
Import-Module PSDDeploymentShare

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

# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"

# Check if we booted from WinPE
$Global:BootfromWinPE = $false
if ($env:SYSTEMDRIVE -eq "X:"){
    $Global:BootfromWinPE = $true
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): This script should only run in the full OS."
    Exit 0
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSRoleIndex is $($tsenv:OSRoleIndex)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property IsServerOS is $($TSEnv:IsServerOS)"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property UninstallOSRoles is $($tsenv:UninstallOSRoles)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property UninstallOSRoleServices is $($tsenv:UninstallOSRoleServices)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property UninstallOSFeatures is $($tsenv:UninstallOSFeatures)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property UninstallOptionalOSRoles is $($tsenv:UninstallOptionalOSRoles)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property UninstallOptionalOSRoleServices is $($tsenv:UninstallOptionalOSRoleServices)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property UninstallOptionalOSFeatures is $($tsenv:UninstallOptionalOSFeatures)"

switch ($TSEnv:IsServerOS)
{
    'True' {
        Import-Module ServerManager
        if($tsenv:UninstallOSRoles -ne $null -or $tsenv:UninstallOSRoles -ne ""){
            $OSRoles = $tsenv:UninstallOSRoles.Split(",")
            foreach($OSRole in $OSRoles){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Removing OSRole: $OSRole"
                Show-PSDActionProgress -Message "Removing OSRole: $OSRole"
                $OSRoleName = Get-WindowsFeature | Where-Object Name -EQ $OSRole
                if($OSRoleName.InstallState -eq "Installed"){
                    $Result = Remove-WindowsFeature -Name $OSRoleName.Name
                    if($Result.RestartNeeded -eq "YES"){
                        $RestartNeeded = $true
                    }
                }
            }
        }
        if($tsenv:UninstallOSRoleServices -ne $null -or $tsenv:UninstallOSRoleServices -ne ""){
            $OSRoleServices = $tsenv:UninstallOSRoleServices.Split(",")
            foreach($OSRoleService in $OSRoleServices){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Removing OSRoleService: $OSRoleService"
                Show-PSDActionProgress -Message "Removing OSRoleService $OSRoleService"
                $OSRoleServiceName = Get-WindowsFeature | Where-Object Name -EQ $OSRoleService
                if($OSRoleServiceName.InstallState -eq "Installed"){
                    $Result = Remove-WindowsFeature -Name $OSRoleServiceName.Name
                    if($Result.RestartNeeded -eq "YES"){
                        $RestartNeeded = $true
                    }
                }
            }
        }
        if($tsenv:UninstallOSFeatures -ne $null -or $tsenv:UninstallOSFeatures -ne ""){
            $OSFeatures = $tsenv:UninstallOSFeatures.Split(",")
            foreach($OSFeature in $OSFeatures){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Removing OSFeature: $OSFeature"
                Show-PSDActionProgress -Message "Removing OSFeature: $OSFeature"
                $OSFeatureName = Get-WindowsFeature | Where-Object Name -EQ $OSFeature
                if($OSFeatureName.InstallState -eq "Installed"){
                    $Result = Remove-WindowsFeature -Name $OSFeatureName.Name
                    if($Result.RestartNeeded -eq "YES"){
                        $RestartNeeded = $true
                    }
                }
            }
        }
    }
    Default {
        if($tsenv:OSRoles -ne $null -or $tsenv:OSRoles -ne ""){
            $OSRoles = $tsenv:OSRoles.Split(",")
            foreach($OSRole in $OSRoles){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Removing OSRole: $OSRole"
                Show-PSDActionProgress -Message "Removing OSRole: $OSRole"
                try{
                    $OSRoleName = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -EQ $OSRole
                    if($OSRoleName.State -eq "Enabled"){
                        $Result = Disable-WindowsOptionalFeature -Online -FeatureName $OSRoleName.FeatureName
                        if($Result.RestartNeeded -eq "True"){
                            $RestartNeeded = $true
                        }
                    }
                }
                catch{
                }
            }
        }
        if($tsenv:UninstallOSRoleServices -ne $null -or $tsenv:UninstallOSRoleServices -ne ""){
            $OSRoleServices = $tsenv:UninstallOSRoleServices.Split(",")
            foreach($OSRoleService in $OSRoleServices){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Removing OSRoleService: $OSRoleService"
                Show-PSDActionProgress -Message "Removing OSRoleService: $OSRoleService"
                try{
                    $OSRoleServiceName = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -EQ $OSRoleService
                    if($OSRoleServiceName.State -eq "Enabled"){
                        $Result = Disable-WindowsOptionalFeature -Online -FeatureName $OSRoleServiceName.FeatureName
                        if($Result.RestartNeeded -eq "True"){
                            $RestartNeeded = $true
                        }
                    }
                }
                catch{
                }
            }
        }
        if($tsenv:UninstallOSFeatures -ne $null -or $tsenv:UninstallOSFeatures -ne ""){
            $OSFeatures = $tsenv:UninstallOSFeatures.Split(",")
            foreach($OSFeature in $OSFeatures){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Removing OSFeature: $OSFeature"
                Show-PSDActionProgress -Message "Removing OSFeature: $OSFeature"
                Try{
                    $OSFeatureName = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -EQ $OSFeature
                    if($OSFeatureName.State -eq "Enabled"){
                        $Result = Disable-WindowsOptionalFeature -Online -FeatureName $OSFeatureName.FeatureName
                        if($Result.RestartNeeded -eq "True"){
                            $RestartNeeded = $true
                        }
                    }
                }
                Catch{
                }
            }
        }
    }
}

if($RestartNeeded -eq $true){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reboot needed"
    $tsenv:SMSTSRebootRequested = "true"
    Exit 3010
}
else{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reboot not needed"
    Exit 0
}