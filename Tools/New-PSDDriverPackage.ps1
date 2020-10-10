<#
.Synopsis
    This script creates a self-signed certificate for PSD
    
.Description
    This script was written by Johan Arwidmark @jarwidmark and Mikael Nystrom @mikael_nystrom. This script is for the friends of MDT deployment tools 
    and is responsible for creating a self-signed certificate.

.LINK
    https://github.com/FriendsOfMDT/PSD

.NOTES
          FileName: New-MDTDriverPackage.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark
          Primary: @Mikael_Nystrom 
          Created: 2019-05-09
          Modified: 2020-07-03

          Version - 0.0.0 - () - Finalized functional version 1.


          # TODO
          Speed up, remove stuff not needed
          Condense script, make one flow
          Use $Env:temp

.EXAMPLE
	.\New-MDTDriverPackage.ps1 -psDeploymentFolder E:\PSDProduction
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
Param(
    [string]$psDeploymentFolder = "NA"
)

$psDeploymentFolder = $psDeploymentFolder.TrimEnd("\")

function Start-PSDLog{
	[CmdletBinding()]
    param (
    #[ValidateScript({ Split-Path $_ -Parent | Test-Path })]
	[string]$FilePath
 	)
    try
    	{
			if(!(Split-Path $FilePath -Parent | Test-Path))
			{
				New-Item (Split-Path $FilePath -Parent) -Type Directory | Out-Null
			}
			#Confirm the provided destination for logging exists if it doesn't then create it.
			if (!(Test-Path $FilePath)){
	    			## Create the log file destination if it doesn't exist.
                    New-Item $FilePath -Type File | Out-Null
			}
            else{
                Remove-Item -Path $FilePath -Force
            }
				## Set the global variable to be used as the FilePath for all subsequent write-PSDInstallLog
				## calls in this session
				$global:ScriptLogFilePath = $FilePath
    	}
    catch
    {
		#In event of an error write an exception
        Write-Error $_.Exception.Message
    }
}
function Write-PSDInstallLog{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [Parameter()]
    [ValidateSet(1, 2, 3)]
	[string]$LogLevel=1,
	[Parameter(Mandatory = $false)]
    [bool]$writetoscreen = $true   
   )
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
	$Line = $Line -f $LineFormat
	[system.GC]::Collect()
    Add-Content -Value $Line -Path $global:ScriptLogFilePath
	if($writetoscreen)
	{
        switch ($LogLevel)
        {
            '1'{
                Write-Verbose -Message $Message
                }
            '2'{
                Write-Warning -Message $Message
                }
            '3'{
                Write-Error -Message $Message
                }
            Default {
            }
        }
    }
	if($writetolistbox -eq $true)
	{
        $result1.Items.Add("$Message")
    }
}
function set-PSDDefaultLogPath{
	#Function to set the default log path if something is put in the field then it is sent somewhere else. 
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $false)]
		[bool]$defaultLogLocation = $true,
		[parameter(Mandatory = $false)]
		[string]$LogLocation
	)
	if($defaultLogLocation)
	{
		$LogPath = Split-Path $script:MyInvocation.MyCommand.Path
		$LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
		Start-PSDLog -FilePath $($LogPath + "\" + $LogFile)
	}
	else 
	{
		$LogPath = $LogLocation
		$LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
		Start-PSDLog -FilePath $($LogPath + "\" + $LogFile)
	}
}
function Copy-PSDFolder{
    param (
        [Parameter(Mandatory=$True,Position=1)]
        [string] $source,
        [Parameter(Mandatory=$True,Position=2)]
        [string] $destination
    )

    $s = $source.TrimEnd("\")
    $d = $destination.TrimEnd("\")
    Write-Verbose "Copying folder $source to $destination using XCopy"
    & xcopy $s $d /s /e /v /y /i | Out-Null
}

# Set VerboseForegroundColor
$host.PrivateData.VerboseForegroundColor = 'Cyan'

# Start logging
set-PSDDefaultLogPath

if($psDeploymentFolder -eq "NA"){
    Write-PSDInstallLog -Message "You need to specify a psDeploymentFolder" -LogLevel 2
    $Fail = $True
}

if($Fail -eq $True){
    Write-PSDInstallLog -Message "Exiting" -LogLevel 2
    Exit
}

if((Test-Path -Path $psDeploymentFolder ) -eq $false){
    Write-PSDInstallLog -Message "Unable to access $psDeploymentFolder, exiting" -LogLevel 2
    Exit
}

# Hard Coded Variables
$PSDriveName = "PSD"

# Add MDT Snapin
$mdtDir = $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir
Write-PSDInstallLog -Message "Import MDT PowerShell Module from $mdtDir"
Import-Module "$($mdtDir)Bin\MicrosoftDeploymentToolkit.psd1"

Write-PSDInstallLog -Message "Create PSdrive using MDTProvider with the name of PSD:"
$result = New-PSDrive -Name "$PSDriveName" -PSProvider MDTProvider -Root $psDeploymentFolder -ErrorAction SilentlyContinue

$RootDriverPath = "$PSDriveName" + ":\Out-Of-Box Drivers"
Write-PSDInstallLog -Message "Setting location of drivers to $RootDriverPath"


$DriverSources = Get-ChildItem -Path "$psDeploymentFolder\PSDResources\DriverSources" -Recurse
foreach($DriverSource in $DriverSources){
    Write-PSDInstallLog -Message "Trying to remove $($DriverSource.fullname)"
    Remove-Item -Path $DriverSource.fullname -ErrorAction SilentlyContinue -Recurse
}

$RootDrivers = Get-ChildItem -Path $RootDriverPath -Recurse
$AllDrivers = $RootDrivers | Where-Object NodeType -EQ Driver
foreach($Driver in $AllDrivers){

    # Determine source folder
    $SourceFolderPath = $Driver.GetPhysicalSourcePath() | Split-Path

    # Determine destination folder
    $RemoveMe = "MicrosoftDeploymentToolkit\MDTProvider::$($PSDriveName):\Out-Of-Box Drivers\"
    $DestinationFolderName = ($Driver.PsParentPath).Replace("$RemoveMe","").Replace("\","-")
    
    # Create package folder
    $DestinationFolderPath = $psDeploymentFolder + "\PSDResources\DriverSources\" + $DestinationFolderName
    if(!(Test-Path -Path $DestinationFolderPath)){
        Write-PSDInstallLog -Message "Creating driver package folder: $DestinationFolderPath"
        $result = New-Item -Path $DestinationFolderPath -ItemType Directory -Force
    }

    # Copy source to destionation
    $DestinationDriverFolderName = ($SourceFolderPath | Split-Path -Leaf).Replace("_$($Driver.Hash)","")
    New-Item -Path $($DestinationFolderPath + "\" + $($driver.Class) + "\" + $DestinationDriverFolderName) -ItemType Directory -Force | Out-Null
    Copy-Item -Path $SourceFolderPath\* -Destination $($DestinationFolderPath + "\" + $($driver.Class) + "\" + $DestinationDriverFolderName) -Recurse -Force
}
Write-PSDInstallLog -Message "Removing old ZIP Archives"

$DriverZIPs = Get-ChildItem -Path "$psDeploymentFolder\PSDResources\DriverPackages" -Recurse
foreach($DriverZIP in $DriverZIPs){
    Write-PSDInstallLog -Message "Trying to remove $($DriverZIP.fullname)"
    Remove-Item -Path $DriverZIP.fullname -ErrorAction SilentlyContinue -Recurse
}

Write-PSDInstallLog -Message "Creating ZIP archives"
$DriverFolders = Get-ChildItem -Path "$psDeploymentFolder\PSDResources\DriverSources"
foreach($DriverFolder in $DriverFolders){
    $FileName = ($DriverFolder.BaseName).replace(" ","_") + ".zip"
    $DestinationFolderPath = $psDeploymentFolder + "\PSDResources\DriverPackages"
    Write-PSDInstallLog -Message "Creating $DestinationFolderPath"
    $Result = New-Item -Path $DestinationFolderPath -ItemType Directory -Force
    Add-Type -Assembly ‘System.IO.Compression.FileSystem’ -PassThru | Select -First 1 | foreach {
        $DestFile = "$($DestinationFolderPath)" + "\" + $FileName
        Write-PSDInstallLog -Message "Creating $DestFile"
        [IO.Compression.ZIPFile]::CreateFromDirectory("$($DriverFolder.fullname)", $DestFile)
    }
}

$DriverSources = Get-ChildItem -Path "$psDeploymentFolder\PSDResources\DriverSources"
foreach($DriverSource in $DriverSources){
    Write-PSDInstallLog -Message "Trying to remove $($DriverSource.fullname)"
    Remove-Item -Path $DriverSource.fullname -ErrorAction SilentlyContinue -Recurse -Force
}