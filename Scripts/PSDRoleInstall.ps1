<#
.SYNOPSIS
    Installs Roles and Roleservices
.DESCRIPTION
    Installs Roles and Roleservices
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDRoleInstall.ps1
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


# Check if we booted from WinPE
$Global:BootfromWinPE = $false
if ($env:SYSTEMDRIVE -eq "X:"){
    $Global:BootfromWinPE = $true
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): This script should only run in the full OS."
    Exit 0
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSRoleIndex is $($tsenv:OSRoleIndex)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property IsServerOS is $($TSEnv:IsServerOS)"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSRoles is $($tsenv:OSRoles)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSRoleServices is $($tsenv:OSRoleServices)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSFeatures is $($tsenv:OSFeatures)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OptionalOSRoles is $($tsenv:OptionalOSRoles)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OptionalOSRoleServices is $($tsenv:OptionalOSRoleServices)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OptionalOSFeatures is $($tsenv:OptionalOSFeatures)"

switch ($TSEnv:IsServerOS)
{
    'True' {
        Import-Module ServerManager
        if($tsenv:OSRoles -ne "" -or $tsenv:OSRoles -ne $null){
            $OSRoles = $tsenv:OSRoles.Split(",")
            foreach($OSRole in $OSRoles){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Adding OSRole: $OSRole"
                Show-PSDActionProgress -Message "Adding OSRole: $OSRole"
                try{
                    $OSRoleName = Get-WindowsFeature | Where-Object Name -EQ $OSRole
                    if($OSRoleName.InstallState -ne "Installed"){
                        $Result = Add-WindowsFeature -Name $OSRoleName.Name
                        if($Result.RestartNeeded -eq "YES"){
                            $RestartNeeded = $true
                        }
                    }
                }
                catch{
                }
            }
        }
        if($tsenv:OSRoleServices -ne "" -or $tsenv:OSRoleServices -ne $null){
            $OSRoleServices = $tsenv:OSRoleServices.Split(",")
            foreach($OSRoleService in $OSRoleServices){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Adding OSRoleService: $OSRoleService"
                Show-PSDActionProgress -Message "Adding OSRoleService: $OSRoleService"
                try{
                    $OSRoleServiceName = Get-WindowsFeature | Where-Object Name -EQ $OSRoleService
                    if($OSRoleServiceName.InstallState -ne "Installed"){
                        $Result = Add-WindowsFeature -Name $OSRoleServiceName.Name
                        if($Result.RestartNeeded -eq "YES"){
                            $RestartNeeded = $true
                        }
                    }
                }
                catch{
                }
            }
        }
        if($tsenv:OSFeatures -ne "" -or $tsenv:OSFeatures -ne $null){
            $OSFeatures = $tsenv:OSFeatures.Split(",")
            foreach($OSFeature in $OSFeatures){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Adding OSFeature: $OSFeature"
                Show-PSDActionProgress -Message "Adding OSFeature: $OSFeature"
                Try{
                    $OSFeatureName = Get-WindowsFeature | Where-Object Name -EQ $OSFeature
                    if($OSFeatureName.InstallState -ne "Installed"){
                        $Result = Add-WindowsFeature -Name $OSFeatureName.Name
                        if($Result.RestartNeeded -eq "YES"){
                            $RestartNeeded = $true
                        }
                    }
                }
                Catch{
                }
            }
        }
    }
    Default {
        if($tsenv:OSRoles -ne "" -or $tsenv:OSRoles -ne $null){
            $OSRoles = $tsenv:OSRoles.Split(",")
            foreach($OSRole in $OSRoles){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Adding OSRole: $OSRole"
                Show-PSDActionProgress -Message "Adding OSRole: $OSRole"
                try{
                    $OSRoleName = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -EQ $OSRole
                    if($OSRoleName.State -ne "Enabled"){
                        $Result = Enable-WindowsOptionalFeature -Online -FeatureName $OSRoleName.FeatureName -All -NoRestart
                        if($Result.RestartNeeded -eq "True"){
                            $RestartNeeded = $true
                        }
                    }
                }
                catch{
                }
            }
        }
        if($tsenv:OSRoleServices -ne "" -or $tsenv:OSRoleServices -ne $null){
            $OSRoleServices = $tsenv:OSRoleServices.Split(",")
            foreach($OSRoleService in $OSRoleServices){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Adding OSRoleService: $OSRoleService"
                Show-PSDActionProgress -Message "Adding OSRoleService: $OSRoleService"
                try{
                    $OSRoleServiceName = Get-WindowsOptionalFeature -Online| Where-Object FeatureName -EQ $OSRoleService
                    if($OSRoleServiceName.State -ne "Enabled"){
                        $Result = Enable-WindowsOptionalFeature -Online -FeatureName $OSRoleServiceName.FeatureName -All -NoRestart
                        if($Result.RestartNeeded -eq "True"){
                            $RestartNeeded = $true
                        }
                    }
                }
                catch{
                }
            }
        }
        if($tsenv:OSFeatures -ne "" -or $tsenv:OSFeatures -ne $null){
        $OSFeatures = $tsenv:OSFeatures.Split(",")
            foreach($OSFeature in $OSFeatures){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Adding OSFeature: $OSFeature"
                Show-PSDActionProgress -Message "Adding OSFeature: $OSFeature"
                Try{
                    $OSFeatureName = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -EQ $OSFeature
                    if($OSFeatureName.State -ne "Enabled"){
                        $Result = Enable-WindowsOptionalFeature -Online -FeatureName $OSFeatureName.FeatureName -All -NoRestart
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
