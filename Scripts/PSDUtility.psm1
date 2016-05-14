$deployRoot = Split-Path -Path $PSScriptRoot
Import-Module "$deployRoot\Tools\Modules\Microsoft.BDD.TaskSequenceModule"
$caller = Split-Path -Path $MyInvocation.PSCommandPath -Leaf
Write-Host "Caller $caller from $deployRoot"

function Get-PSDLocalDataPath
{
    # TODO: Cache the result if possible

    # First look for an existing path

    $localPath = ""
    get-volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\MININT"} | Select-Object -First 1 | % {
        $localPath = "$($_.DriveLetter):\MININT"
    }


    # Not found, create one

    if ($localPath -eq "")
    {
        if ($env:SYSTEMDRIVE -ne "X:")
        {
            $localPath = "$($env:SYSTEMDRIVE)\MININT"
        }
        else
        {
            get-volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | Select-Object -First 1 | % {
                $localPath = "$($_.DriveLetter):\MININT"
                # TODO: Determine an appropriate drive, not just the first
            }

            # Last resort, use X:

            if ($localPath -eq "")
            {
                return "$($env:SYSTEMDRIVE)\MININT"
            }
        }
    }

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

  if ($id -eq "Tools")
  {
    if (Test-Path "X:\Deploy\Tools\$($tsenv:Architecture)") {
      $path = "X:\Deploy\Tools\$($tsenv:Architecture)"
      return $path
    }
    if (Test-Path "$($tsenv:DeployRoot)\Tools\$($tsenv:Architecture)") {
      $path = "$($tsenv:DeployRoot)\Tools\$($tsenv:Architecture)"
    }
    $destSuffix = "Tools\$($tsenv:Architecture)"
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
  }
  return $dest
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
        $v.DocumentElement.SelectNodes("var") | % { Set-Item tsenv:$($_.Attributes["name"]) -Value $_.'#text' } 
    }
}
