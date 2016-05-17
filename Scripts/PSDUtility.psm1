#
# PSDUtility.psm1
#

$deployRoot = Split-Path -Path $PSScriptRoot
Import-Module "$deployRoot\Tools\Modules\Microsoft.BDD.TaskSequenceModule" -Scope Global
$caller = Split-Path -Path $MyInvocation.PSCommandPath -Leaf
$verbosePreference = "Continue"
Write-Host "Caller $caller from $deployRoot"

function Get-PSDLocalDataPath
{
    # TODO: Cache the result if possible

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

function Get-PSDConnection
{
    param(
      [string] $uncPath,
      [string] $username,
      [string] $password
    )

    if (!$username -or !$password)
    {
        $cred = Get-Credential -Message "Specify credentials needed to connect to $uncPath"
    }
    else
    {
        $secure = ConvertTo-SecureString $password -AsPlainText -Force
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $secure
    }

    New-PSDrive -Name (Get-PSDAvailableDriveLetter) -PSProvider FileSystem -Root $uncPath -Credential $cred -Scope Global
}

function Get-PSDAvailableDriveLetter 
{
    $drives = (Get-PSDrive -PSProvider filesystem).Name
    foreach ($letter in "ZYXWVUTSRQPONMLKJIHGFED".ToCharArray()) {
        if ($drives -notcontains $letter) {
            return $letter
            break
        }
    }
} 

function Get-PSDContent
{
    param(
      [string] $id
    )

    if ($id -ieq "TaskSequencer")
    {
        if (Test-Path "X:\Deploy\Tools\$($tsenv:Architecture)\TSMBootstrap.exe") {
            $path = "X:\Deploy\Tools\$($tsenv:Architecture)"
            return $path
        }
        $path = "$($tsenv:DeployRoot)\Tools\$($tsenv:Architecture)"
        $destSuffix = "Tools\$($tsenv:Architecture)"
    }
    elseif ($id -ieq "Tools")
    {
        $path = "$($tsenv:DeployRoot)\Tools\$($tsenv:Architecture)"
        $destSuffix = "Tools\$($tsenv:Architecture)"
    }
    else
    {
        $path = "$($tsenv:DeployRoot)\$id"
        $destSuffix = $id
    }

    # If it's on a network drive, copy it locally

    $dest = "$(Get-PSDLocalDataPath)\$destSuffix"
    if ($path -like "\\*")
    {
        if (Test-Path $dest)
        {
            Write-Verbose "Already copied $id, not copying again."
        }
        else
        {
            Write-Verbose "Copying from $path to $dest"
            Copy-Item -Path $path -Destination $dest -Recurse
        }
        return $dest
    }
    else
    {
        Write-Verbose "Path for $id is already local, not copying"
        return $path
    }
}

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
    # Create a folder for the logs
    $logDest = "$($env:SystemRoot)\Temp\DeploymentLogs"
    Initialize-PSDFolder $logDest

    # Process each volume looking for MININT folders
    get-volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\MININT"} | % {

        $localPath = "$($_.DriveLetter):\MININT"

        # Copy any logs
        if (Test-Path "$localPath\Logs")
        {
            Copy-Item "$localPath\Logs\*.*" $logDest -Force
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