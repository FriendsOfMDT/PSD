# // ***************************************************************************
# // 
# // Copyright (c) Microsoft Corporation.  All rights reserved.
# // 
# // Microsoft Deployment Toolkit Solution Accelerator
# //
# // File:      ZTIUtility.psm1
# // 
# // Version:   6.3.8456.1000
# // 
# // Purpose:   Common PowerShell Library for Microsoft Deployment Toolkit
# // 
# // ***************************************************************************


# // ***************************************************************************
# // Initialization
# // ***************************************************************************

# Initialize constants

$mdtVersion = "6.3.8456.1000"
$scriptDir = split-path -parent $MyInvocation.MyCommand.Path
$scriptName = split-path -leaf $MyInvocation.MyCommand.Path
$moduleDir = split-path -parent $scriptDir


# Log the version

Write-Host "Microsoft Deployment Toolkit version: $mdtVersion"


# Add the MDT Module location to the Powershell Module search path.

if (($env:PSModulePath -split ";") -notcontains $ModuleDir)
{
	$env:PSModulePath += ";$moduleDir"
	Write-Host "PowerShell environment variable PSModulePath is now = $env:PSModulePath"
}


# Load the TS PowerShell provider if not already loaded

if ((Get-Module Microsoft.BDD.TaskSequenceModule) -eq $null)
{
	Write-Host "Import Microsoft.BDD.TaskSequenceModule"
	Import-Module Microsoft.BDD.TaskSequenceModule -Global

	if ((Get-Module Microsoft.BDD.TaskSequenceModule) -eq $null)
	{
		throw "Task Sequence Module did not load"
	}
}

