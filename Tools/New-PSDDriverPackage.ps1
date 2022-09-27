<#
.Synopsis
    This script creates driver packages from drivers imported in MDT. 
    
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
          Modified: 2022-09-25

          Version - 0.0.0 - () - Finalized functional version 1
          Version - 0.0.1 - () - Added support for WIM compression, and improved error handling

.EXAMPLE
	.\New-MDTDriverPackage.ps1 -psDeploymentFolder E:\PSDProduction -CompressionType WIM
	.\New-MDTDriverPackage.ps1 -psDeploymentFolder E:\PSDProduction -CompressionType ZIP
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
Param(
    [string]$psDeploymentFolder = "NA",
	[ValidateSet("ZIP", "WIM")]
	[string]$CompressionType
)

$psDeploymentFolder = $psDeploymentFolder.TrimEnd("\")

# Hard Coded Variables
$PSDriveName = "PSD"

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

# Add MDT Snapin
$mdtDir = $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir
Write-PSDInstallLog -Message "Import MDT PowerShell Module from $mdtDir"
Import-Module "$($mdtDir)Bin\MicrosoftDeploymentToolkit.psd1"

Write-PSDInstallLog -Message "Create PSdrive using MDTProvider with the name of PSD:"
New-PSDrive -Name $PSDriveName -PSProvider MDTProvider -Root $psDeploymentFolder -ErrorAction SilentlyContinue | Out-Null
if (-not (Get-PSDrive -Name $PSDriveName)){
    Write-PSDInstallLog -Message "Creating PSdrive $PSDriveName failed."
    Write-PSDInstallLog -Message "Exiting" -LogLevel 2
}

$RootDriverPath = $PSDriveName + ":\Out-Of-Box Drivers"
Write-PSDInstallLog -Message "Driver location is: $RootDriverPath"

# Empty the DriverSources folder to make sure we are in sync with Out-Of-Box Drivers
$DriverSources = Get-ChildItem -Path "$psDeploymentFolder\PSDResources\DriverSources" -Recurse
foreach($DriverSource in $DriverSources){
    Write-PSDInstallLog -Message "Trying to remove $($DriverSource.fullname)"
    Remove-Item -Path $DriverSource.fullname -ErrorAction SilentlyContinue -Recurse | Out-Null
}

# Make sure we could empty the DriverSources folder, abort if not empty
$DriverSources = Get-ChildItem -Path "$psDeploymentFolder\PSDResources\DriverSources" -Recurse
If (($DriverSources | Measure-Object).count -gt 0){
    Write-PSDInstallLog -Message "DriverSources folder cleanup failed. Please do a manual cleanup, and run the script again" -LogLevel 2
}

# Get a list of all drivers and copy to source folder
$RootDrivers = Get-ChildItem -Path $RootDriverPath -Recurse
$AllDrivers = $RootDrivers | Where-Object NodeType -EQ Driver 
foreach($Driver in $AllDrivers){

    # Determine source folder
    $SourceFolderPath = $Driver.GetPhysicalSourcePath() | Split-Path

    # Determine destination folder
    $RemoveMe = "MicrosoftDeploymentToolkit\MDTProvider::$($PSDriveName):\Out-Of-Box Drivers\"
    $DestinationFolderName = ($Driver.PsParentPath).Replace("$RemoveMe","").Replace("\","-")
    
    # Create source folder for the package
    $DestinationFolderPath = $psDeploymentFolder + "\PSDResources\DriverSources\" + $DestinationFolderName
    if(!(Test-Path -Path $DestinationFolderPath)){
        Write-PSDInstallLog -Message "Creating driver package folder: $DestinationFolderPath"
        New-Item -Path $DestinationFolderPath -ItemType Directory -Force | Out-Null
    }

    # Copy source to destination
    $DestinationDriverFolderName = ($SourceFolderPath | Split-Path -Leaf).Replace("_$($Driver.Hash)","")
    New-Item -Path $($DestinationFolderPath + "\" + $($driver.Class) + "\" + $DestinationDriverFolderName) -ItemType Directory -Force | Out-Null
    Copy-Item -Path $SourceFolderPath\* -Destination $($DestinationFolderPath + "\" + $($driver.Class) + "\" + $DestinationDriverFolderName) -Recurse -Force
}

# Making sure no temporary archives exist in DriverPackages
# New packages are created in the root of DriverPackages and then moved their target folder
Write-PSDInstallLog -Message "Cleanup any old temporary archives in the root of DriverPackages"
$TempArchives = Get-ChildItem -Path "$psDeploymentFolder\PSDResources\DriverPackages" | Where-Object { $_.Name -match '^*.zip|^*.wim' }
foreach($Archive in $TempArchives){
    Write-PSDInstallLog -Message "Trying to remove $($Archive.fullname)"
    Remove-Item -Path $Archive.fullname -ErrorAction SilentlyContinue | Out-Null
}

# Set default compresion type to WIM if not specified on the command line
If ([string]::IsNullOrEmpty($CompressionType)){
    $CompressionType = "WIM"
}

# Creating the drivers packages. 
Write-PSDInstallLog -Message "Creating archives using $CompressionType"
$DriverFolders = Get-ChildItem -Path "$psDeploymentFolder\PSDResources\DriverSources"
foreach($DriverFolder in $DriverFolders){
    $FileName = ($DriverFolder.BaseName).replace(" ","_") + ".$($CompressionType.ToLower())"
    $DestinationFolderPath = $psDeploymentFolder + "\PSDResources\DriverPackages"
    $DestFile = "$($DestinationFolderPath)" + "\" + $FileName
    Write-PSDInstallLog -Message "Creating $DestinationFolderPath"
    New-Item -Path $DestinationFolderPath -ItemType Directory -Force | Out-Null

    If ($CompressionType -eq "WIM"){
        # Create WIM format archive
        New-WindowsImage -CapturePath $DriverFolder.fullname -ImagePath $DestFile -Name "Driver Package" | Out-Null
    }
    Else {
        # Create ZIP format archive
        Add-Type -Assembly 'System.IO.Compression.FileSystem' -PassThru | Select -First 1 | ForEach {
            Write-PSDInstallLog -Message "Creating $DestFile"
            [IO.Compression.ZIPFile]::CreateFromDirectory("$($DriverFolder.fullname)", $DestFile)
        }
    }

}

# Delete the temporary driver sources 
$DriverSources = Get-ChildItem -Path "$psDeploymentFolder\PSDResources\DriverSources"
foreach($DriverSource in $DriverSources){
    Write-PSDInstallLog -Message "Trying to remove $($DriverSource.fullname)"
    Remove-Item -Path $DriverSource.fullname -ErrorAction SilentlyContinue -Recurse -Force
}

# Move the driver package to the correct folder. Existing driver packages will be overwritten
$Archives = Get-ChildItem -Path "$psDeploymentFolder\PSDResources\DriverPackages" | Where-Object { $_.Name -match '^*.zip|^*.wim' }
foreach($Archive in $Archives){
    $FolderPath = New-Item -Path "$psDeploymentFolder\PSDResources\DriverPackages\$($Archive.BaseName)" -ItemType Directory -Force
    Move-Item -Path $($Archive.FullName) -Destination $($FolderPath.FullName) -Force
}
