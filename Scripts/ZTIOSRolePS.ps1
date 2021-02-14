
# // ***************************************************************************
# // 
# // Copyright (c) Microsoft Corporation.  All rights reserved.
# // 
# // Microsoft Deployment Toolkit Solution Accelerator
# //
# // File:      ZTIOSRolePS.ps1
# // 
# // Version:   6.3.8456.1000
# // 
# // Purpose:   Install or remove roles and features using PowerShell
# // 
# // ***************************************************************************

[CmdletBinding()]
Param(
	$FeatureName,
	$Source = "",
	[switch] $Uninstall,
	[switch] $CompletelyRemove
)

# Load the ZTIUtility if we are outside of the MDT Powershell Host Task Sequence (For testing).

Import-Module ZTIUtility.psm1


# Load the ServerManager module

Import-Module ServerManager


# Process the specified feature

if ($Uninstall)
{
	if ($CompletelyRemove)
	{
		Write-Host "Completely removing Windows feature $featureName"
		$result = Remove-WindowsFeature -Name $featureName -Remove -WarningAction SilentlyContinue
	}
	else
	{
		Write-Host "Uninstalling Windows feature $featureName"
		$result = Remove-WindowsFeature -Name $featureName -WarningAction SilentlyContinue
	}
}
else
{
	Write-Host "Installing Windows feature $featureName"
	if ($source -eq "")
	{
		$result = Add-WindowsFeature -Name $featureName -WarningAction SilentlyContinue
	}
	else
	{
		$result = Add-WindowsFeature -Name $featureName -Source $source -WarningAction SilentlyContinue
	}
}

# Report the result

if ($result.Success -eq $false)
{
	# Report a failure
	if ($result.RestartNeeded -eq "Yes")
	{
		Write-Host "Failed to process Windows feature, reboot required."
		exit 1001
	}
	else
	{
		Write-Host "Failed to process Windows feature."
		exit 1000
	}
}
if ($result.RestartNeeded -eq "Yes")
{
	# Report a reboot
	Write-Host "Windows feature processed, reboot required."
	exit 3010
}
Write-Host "Windows feature processed"
exit 0
