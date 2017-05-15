# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDUtility.psd1
# // 
# // Purpose:   General utility routines useful for all PSD scripts.
# // 
# // ***************************************************************************

Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
$caller = Split-Path -Path $MyInvocation.PSCommandPath -Leaf
$verbosePreference = "Continue"
$global:psuDataPath = ""

function Get-PSDLocalDataPath
{
    param (
        [switch] $move
    )

    # Return the cached local data path if possible
    if ($global:psuDataPath -ne "" -and (-not $move))
    {
        if (Test-Path $global:psuDataPath)
        {
            return $global:psuDataPath
        }
    }

    # Always prefer the OS volume
    $localPath = ""
    if ($tsenv:OSVolumeGuid -ne "")
    {
        # If the OS volume GUID is set, we should use that volume
        Write-Verbose "Checking for OS volume using $($tsenv:OSVolumeGuid)."
        Get-Volume | ? { $_.UniqueID -like "*$($tsenv:OSVolumeGuid)*" } | % {
            $localPath = "$($_.DriveLetter):\MININT"
        }
    }
    
    if ($localPath -eq "")
    {
        # Look on all other volumes 
        Write-Verbose "Checking other volumes for a MININT folder."
        get-volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\MININT"} | Select-Object -First 1 | % {
            $localPath = "$($_.DriveLetter):\MININT"
        }
    }

    # Not found on any drive, create one on the current system drive
    if ($localPath -eq "")
    {
            $localPath = "$($env:SYSTEMDRIVE)\MININT"
    }

    # Create the MININT folder if it doesn't exist
    if ((Test-Path $localPath) -eq $false) {
        New-Item -ItemType Directory -Force -Path $localPath | Out-Null
    }

    $global:psuDataPath = $localPath
    return $localPath
}

function Initialize-PSDFolder
{
    Param( 
        $folderPath
    ) 

    if ((Test-Path $folderPath) -eq $false) {
        New-Item -ItemType Directory -Force -Path $folderPath | Out-Null
    }
}

function Start-PSDLogging
{
    $logPath = "$(Get-PSDLocalDataPath)\Logs"
    Initialize-PSDfolder $logPath
    Start-Transcript "$logPath\$caller.log" -Append
}

function Stop-PSDLogging
{
    Stop-Transcript
}

Start-PSDLogging

function Save-PSDVariables
{
    $v = [xml]"<?xml version=`"1.0`" ?><MediaVarList Version=`"4.00.5345.0000`"></MediaVarList>"
    Get-ChildItem TSEnv: | % {
        $element = $v.CreateElement("var")
        $element.SetAttribute("name", $_.Name) | Out-Null
        $element.AppendChild($v.createCDATASection($_.Value)) | Out-Null
        $v.DocumentElement.AppendChild($element) | Out-Null
    }
    $path = "$(Get-PSDLocaldataPath)\Variables.dat"
    $v.Save($path)
    return $path
}

function Restore-PSDVariables
{
    $path = "$(Get-PSDLocaldataPath)\Variables.dat"
    if (Test-Path $path) {
        [xml] $v = Get-Content $path
        $v | Select-Xml -Xpath "//var" | % { Set-Item tsenv:$($_.Node.name) -Value $_.Node.'#cdata-section' } 
    }
    return $path
}

function Clear-PSDInformation
{
    # TEMP:  Don't clean up
    return

    # Create a folder for the logs
    $logDest = "$($env:SystemRoot)\Temp\DeploymentLogs"
    Initialize-PSDFolder $logDest

    # Process each volume looking for MININT folders
    get-volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\MININT"} | % {

        $localPath = "$($_.DriveLetter):\MININT"

        # Copy any logs
        if (Test-Path "$localPath\Logs")
        {
            Copy-Item "$localPath\Logs\*" $logDest -Force
        }

        # Remove the MININT folder
        try
        {
            Remove-Item "$localPath" -Recurse -Force
        }
        catch
        {
            Write-Verbose "Unable to completely remove $localPath."
        }
    }

}

function Copy-PSDFolder
{
    param (
        [Parameter(Mandatory=$True,Position=1)]
        [string] $source,
        [Parameter(Mandatory=$True,Position=2)]
        [string] $destination
    )

    $s = $source.TrimEnd("\")
    $d = $destination.TrimEnd("\")
    Write-Verbose "Copying folder $source to $destination using XCopy"
    & xcopy $s $d /s /e /v /d /y /i | Out-Null
}
