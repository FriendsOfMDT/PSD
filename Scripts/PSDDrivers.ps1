<#
.SYNOPSIS
    Downloads drivers during the WinPE phase

.DESCRIPTION
    Downloads drivers during the WinPE phase

.LINK

.NOTES
          FileName: PSDDrivers.ps1
          Solution: PowerShell Deployment for MDT
          Purpose: Download and install drivers
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2019-06-02

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.0.1 - () - Changed BaseDriverPath = "PSDResources\DriverPackages", to "fit" the new folder structure
          Version - 0.0.2 - () - Testing if there is a driver package to download.
          Version - 0.0.3 - () - Added support for DriverPath, GenericDriverPath, FallBackDriverPath
          Version - 0.0.4 - () - Added support for importing VMware drivers that contains "," in the folder name

          TODO:
          - Verify that it works with new package format
          - Add support for PNP, Fallback Package as PNP (PSDDriverFallBackPNP=YES), default is NO

.Example
#>

[CmdletBinding()]
param (

)

# Set scriptversion for logging
$ScriptVersion = "0.0.3"

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module DISM
Import-Module PSDUtility
Import-Module PSDDeploymentShare

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true){
    $verbosePreference = "Continue"
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Starting: $($MyInvocation.MyCommand.Name) - Version $ScriptVersion"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): The task sequencer log is located at $("$tsenv:_SMSTSLogPath\SMSTS.LOG"). For task sequence failures, please consult this log."
Write-PSDEvent -MessageID 41000 -severity 1 -Message "Starting: $($MyInvocation.MyCommand.Name)"

# Values from TaskSequence Step
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DriverSelectionProfile is $($tsenv:DriverSelectionProfile)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DriverInjectionMode is $($tsenv:DriverInjectionMode)"

# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"

if($tsenv:drivergroup001 -ne ""){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property Drivergroup001 is $tsenv:drivergroup001"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Drivergroups are currently not supported, please use DriverPath, FallbackDriverPath and GenericDriverPath" -Loglevel 2
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Setting Driverpath to Drivergroup001 for convenience"
    
    $tsenv:DriverPath = $tsenv:drivergroup001
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DriverPath is $tsenv:DriverPath"
}

# Building source and destination paths based on model DriverPath
$BaseDriverPath = "PSDResources\DriverPackages"
#$SourceDriverPackagePath = ($BaseDriverPath + "\" + ($tsenv:DriverPath).Replace("\","-")).Replace(" ","_")
$SourceDriverPackagePath = ($BaseDriverPath + "\" + ($tsenv:DriverPath).Replace("\","-").Replace(" ","_").Replace(",","_"))
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DriverPath is $($tsenv:DriverPath)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property GenericDriverPath is $($tsenv:GenericDriverPath)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property FallbackDriverPath is $($tsenv:FallbackDriverPath)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable SourceDriverPackagePath is $SourceDriverPackagePath"

# Check of a driver package exists, else try to get the fallback package if FallbackDriverPath=YES
# DriverPackageName is the base name of the folder containing the driver package, since we dont know (or care) about the actual filename.
$DriverPackageName = $($SourceDriverPackagePath | Split-Path -Leaf)
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Searching for package(s)"
if((Test-PSDContent -content $BaseDriverPath | Where-Object Name -EQ $DriverPackageName) -NE $null){

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): DriverPackageName $DriverPackageName found"

    #Copy drivers to cache
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy $SourceDriverPackagePath to cache "
    Show-PSDActionProgress -Message "Trying to download driver package(s) : $($SourceDriverPackagePath | Split-Path -Leaf)" -Step "1" -MaxStep "1"
    Get-PSDContent -content $SourceDriverPackagePath
}
else{
    if($tsenv:FallbackDriverPath -ne ""){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Entering FallbackDriver section"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property FallbackDriverPath is $tsenv:FallbackDriverPath"

        $BaseDriverPath = "PSDResources\DriverPackages"
        $SourceDriverPackagePath = ($BaseDriverPath + "\" + ($tsenv:FallbackDriverPath).Replace("\","-")).replace(" ","_")
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DriverPath is $($tsenv:DriverPath)"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable SourceDriverPackagePath is $SourceDriverPackagePath"

        $DriverPackageName = $($SourceDriverPackagePath | Split-Path -Leaf)
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Searching for package(s)"
        if((Test-PSDContent -content $BaseDriverPath | Where-Object Name -EQ $DriverPackageName) -NE $null){
            Show-PSDActionProgress -Message "Trying to download driver package(s) : $($SourceDriverPackagePath | Split-Path -Leaf)" -Step "1" -MaxStep "1"
            Get-PSDContent -content $SourceDriverPackagePath
        }
        else{
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No driver package(s) found, could be a bad thing..."
        }
    }
}


if($tsenv:GenericDriverPath -ne ""){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Entering GenericDriver section"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property GenericDriverPath is $tsenv:GenericDriverPath"

    $BaseDriverPath = "PSDResources\DriverPackages"
    $SourceDriverPackagePath = ($BaseDriverPath + "\" + ($tsenv:GenericDriverPath).Replace("\","-")).replace(" ","_")
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DriverPath is $($tsenv:DriverPath)"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable SourceDriverPackagePath is $SourceDriverPackagePath"

    $DriverPackageName = $($SourceDriverPackagePath | Split-Path -Leaf)
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Searching for package(s)"
    if((Test-PSDContent -content $BaseDriverPath | Where-Object Name -EQ $DriverPackageName) -NE $null){
        Show-PSDActionProgress -Message "Trying to download driver package(s) : $($SourceDriverPackagePath | Split-Path -Leaf)" -Step "1" -MaxStep "1"
        Get-PSDContent -content $SourceDriverPackagePath
    }
    else{
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No driver package(s) found, could be a bad thing..."
    }
}

# Create Drivers folder
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating $($tsenv:OSVolume):\Drivers folder"
$Result = New-Item -Path "$($tsenv:OSVolume):\Drivers" -ItemType Directory -Force

# Get all archived files from the cache
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Getting driver(s)..."
$Zips = Get-ChildItem -Path "$($tsenv:OSVolume):\MININT\Cache\PSDResources\DriverPackages" -Filter *.zip -Recurse
$WIMs = Get-ChildItem -Path "$($tsenv:OSVolume):\MININT\Cache\PSDResources\DriverPackages" -Filter *.wim -Recurse

# Did we find any ZIP Files?
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Found $($Zips.count) ZIP package(s)"
Show-PSDActionProgress -Message "Found $($Zips.count) package(s)" -Step "1" -MaxStep "1"
Foreach($Zip in $Zips){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unpacking $($Zip.FullName)"
    #Need to use this method, since the assemblys can not be loaded due to an issue...
    if($PSDDebug -eq $true){
        $ArgumentList = "Expand-Archive -Path $($Zip.FullName) -DestinationPath $($tsenv:OSVolume):\Drivers -Force -Verbose"
    }
    else{
        $ArgumentList = "Expand-Archive -Path $($Zip.FullName) -DestinationPath $($tsenv:OSVolume):\Drivers -Force"
    }

    $Process = "PowerShell"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Entering ZIP file section"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run: $Process $ArgumentList"
    Start-Process $Process -ArgumentList $ArgumentList -NoNewWindow -PassThru -Wait
}

# Did we find any WIM Files?
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Found $($WIMs.count) WIM package(s)"
Show-PSDActionProgress -Message "Found $($WIMs.count) package(s)" -Step "1" -MaxStep "1"
Foreach($WIM in $WIMs){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unpacking $($WIM.FullName)"
    # Expanding WIM files for now, since we may have multiple WIM files
    if($PSDDebug -eq $true){
        $ArgumentList = "Expand-WindowsImage -ImagePath $($WIM.FullName) -ApplyPath $($tsenv:OSVolume):\Drivers -Index 1 -Verbose"
    }
    else{
        $ArgumentList = "Expand-WindowsImage -ImagePath $($WIM.FullName) -ApplyPath $($tsenv:OSVolume):\Drivers -Index 1"
    }

    $Process = "PowerShell"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Entering WIM file section"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run: $Process $ArgumentList"
    Start-Process $Process -ArgumentList $ArgumentList -NoNewWindow -PassThru -Wait
}

Start-Sleep -Seconds 1

# What do we have here
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get list of drivers from \Drivers"
$Drivers = Get-ChildItem -Path "$($tsenv:OSVolume):\Drivers" -Filter *.inf -Recurse
foreach($Driver in $Drivers){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $($Driver.Name) is now in the \Drivers folder"
    $PSDDriverInfo = Get-PSDDriverInfo -Path $Driver.FullName
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Driverinfo: Name:$($PSDDriverInfo.Name)  Vendor:$($PSDDriverInfo.Manufacturer)  Class:$($PSDDriverInfo.Class)  Date:$($PSDDriverInfo.Date)  Version:$($PSDDriverInfo.Version)"
}
