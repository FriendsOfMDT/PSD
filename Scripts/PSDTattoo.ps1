<#
.SYNOPSIS
    Script that writes deployment info on the registry
.DESCRIPTION
    Validate
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDTattoo.ps1
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

[CmdletBinding()]
param (

)

# Set scriptversion for logging
$ScriptVersion = "0.0.1"

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global -Verbose:$true
Import-Module PSDUtility -Verbose:$true
Import-Module PSDDeploymentShare -Verbose:$true

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

$TaskSequenceData = Get-ChildItem -Path "DeploymentShare:\Task Sequences" -Recurse | Where-Object ID -EQ $TSEnv:TaskSequenceID
$TSEnv:TaskSequenceName = $TaskSequenceData.Name
$TSEnv:TaskSequenceVersion = $TaskSequenceData.Version

# Create WMI Object
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating WMI Class PSDInfo"
$newClass = New-Object System.Management.ManagementClass("root\cimv2", [String]::Empty, $null); 
$newClass["__CLASS"] = "PSDInfo"; 
$newClass.Qualifiers.Add("Static", $true)
$newClass.Properties.Add("InstanceKey",[System.Management.CimType]::String, $false)
$newClass.Properties["InstanceKey"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("Computername",[System.Management.CimType]::String, $false)
$newClass.Properties.Add("InstallTime",[System.Management.CimType]::String, $false)
$newClass.Properties.Add("DeployRoot",[System.Management.CimType]::String, $false)
$newClass.Properties.Add("DeploymentToolkitVersion",[System.Management.CimType]::String, $false)
$newClass.Properties.Add("TaskSequenceID",[System.Management.CimType]::String, $false)
$newClass.Properties.Add("TaskSequenceName",[System.Management.CimType]::String, $false)
$newClass.Properties.Add("TaskSequenceVersion",[System.Management.CimType]::String, $false)
$newClass.Put()

# Get values
$InstallTime = Get-Date -Format G 
$Computername = $env:Computername

# Create array
$Argument = @{
InstanceKey="@"
Computername="$Computername"
InstallTime="$InstallTime"
DeployRoot="$tsenv:DeployRoot"
DeploymentToolkitVersion="$tsenv:DeploymentToolkitVersion"
TaskSequenceID="$tsenv:TaskSequenceID"
TaskSequenceName="$tsenv:TaskSequenceName"
TaskSequenceVersion="$tsenv:TaskSequenceVersion"
}

# Write WMI values
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Writing values to WMI"
$null = Set-WmiInstance -Class PSDInfo -Argument $Argument

# Set values
$FullRegKeyName = "HKLM:\SOFTWARE\PSDInfo"

# Create Registry key
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating HKLM:\SOFTWARE\PSDInfo"
$null = New-Item -Path $FullRegKeyName -type Directory -Force -ErrorAction SilentlyContinue

# Write Registry values
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Writing values to registry"
$null = New-ItemProperty $FullRegKeyName -Name "Computername" -Value $Computername -Type STRING -Force -ErrorAction SilentlyContinue
$null = New-ItemProperty $FullRegKeyName -Name "InstalledTime" -Value $InstallTime -Type STRING -Force -ErrorAction SilentlyContinue
$null = New-ItemProperty $FullRegKeyName -Name "DeployRoot" -Value $tsenv:DeployRoot -Type STRING -Force -ErrorAction SilentlyContinue
$null = New-ItemProperty $FullRegKeyName -Name "DeploymentToolkitVersion" -Value $tsenv:DeploymentToolkitVersion -Type STRING -Force -ErrorAction SilentlyContinue
$null = New-ItemProperty $FullRegKeyName -Name "TaskSequenceID" -Value $tsenv:TaskSequenceID -Type STRING -Force -ErrorAction SilentlyContinue
$null = New-ItemProperty $FullRegKeyName -Name "TaskSequenceName" -Value $tsenv:TaskSequenceName -Type STRING -Force -ErrorAction SilentlyContinue
$null = New-ItemProperty $FullRegKeyName -Name "TaskSequenceVersion" -Value $tsenv:TaskSequenceVersion -Type STRING -Force -ErrorAction SilentlyContinue
