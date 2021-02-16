<#
.SYNOPSIS

.DESCRIPTION

.LINK

.NOTES
          FileName: PSDDrivers.ps1
          Solution: PowerShell Deployment for MDT
          Purpose: Download and install drivers
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2019-06-02

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.0.1 - () - Changed BaseDriverPath = "PSDResources\DriverPackages", to "fit" the new folder structure
          Version - 0.0.2 - () - Testing if there is a driver package to download.

          TODO:
          Verify that it works with new package format

          DriverGroup should be Array, solves fallback and more package, DriverGroup
            DriverGroup002=Windows 10 x64\Generic

          Add support for PNP

          Fallback Package as PNP (PSDDriverFallBackPNP=YES), default is NO

          Add support for nasty Universal Drivers  

.Example
#>

param (

)

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
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"

# Building source and destionation paths based on model DriverGroup001
$BaseDriverPath = "PSDResources\DriverPackages"
$SourceDriverPackagePath = ($BaseDriverPath + "\" + ($tsenv:DriverGroup001).Replace("\","-")).replace(" ","_")
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:DriverGroup001 is $($tsenv:DriverGroup001)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): SourceDriverPackagePath is now $SourceDriverPackagePath"

# Check of a driver package exists
$DriverPackageName = $($SourceDriverPackagePath | Split-Path -Leaf)
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Searching for package"
if((Test-PSDContent -content $BaseDriverPath | Where-Object Name -EQ $DriverPackageName) -NE $null){

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $DriverPackageName found"

    #Copy drivers to cache
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy $SourceDriverPackagePath to cache "
    Show-PSDActionProgress -Message "Trying to download driver package : $($SourceDriverPackagePath | Split-Path -Leaf)" -Step "1" -MaxStep "1"
    Get-PSDContent -content $SourceDriverPackagePath

    #Get all ZIP files from the cache
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Getting drivers..."
    $Zips = Get-ChildItem -Path "$($tsenv:OSVolume):\MININT\Cache\PSDResources\DriverPackages" -Filter *.zip -Recurse

    #Did we find any?
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Found $($Zips.count) packages"
    Show-PSDActionProgress -Message "Found $($Zips.count) packages" -Step "1" -MaxStep "1"
    Foreach($Zip in $Zips){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unpacking $($Zip.FullName)"
        #Need to use this method, since the assemblys can not be loaded due to a issue...
        if($PSDDebug -eq $true){
            Start PowerShell -ArgumentList "Expand-Archive -Path $($Zip.FullName) -DestinationPath $($tsenv:OSVolume):\Drivers -Force -Verbose" -Wait
        }
        else{
            Start PowerShell -ArgumentList "Expand-Archive -Path $($Zip.FullName) -DestinationPath $($tsenv:OSVolume):\Drivers -Force" -Wait
        }
    }

    Start-Sleep -Seconds 1

    #What do we have here
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get list of drivers from \Drivers"
    $Drivers = Get-ChildItem -Path "$($tsenv:OSVolume):\Drivers" -Filter *.inf -Recurse
    foreach($Driver in $Drivers){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $($Driver.Name) is now in the \Drivers folder"
        $TSxDriverInfo = Get-PSDDriverInfo -Path $Driver.FullName
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Driverinfo: Name:$($TSxDriverInfo.Name)  Vendor:$($TSxDriverInfo.Manufacturer)  Class:$($TSxDriverInfo.Class)  Date:$($TSxDriverInfo.Date)  Version:$($TSxDriverInfo.Version)"
    }
}
else{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No driver package found"
}


