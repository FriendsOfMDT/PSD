<#
    .SYNOPSIS
        This script creates driver packages from drivers imported in MDT. 
        
    .DESCRIPTION
        This script creates driver packages from drivers imported in MDT. The script will create a driver package for each driver class in the Out-Of-Box Drivers folder. 
        The driver packages will be created in the DriverPackages folder. The script will also create a source folder for each driver package in the DriverSources folder. 
        The source folder will contain the drivers for the package. The script will create the driver packages in either WIM or ZIP format. The default format is WIM.

    .PARAMETER psDeploymentFolder
        The path to the deployment folder. This is the root folder for the MDT deployment share.

    .PARAMETER CompressionType
        The compression type for the driver packages. The script supports WIM and ZIP. The default is WIM.

    .EXAMPLE
        .\New-MDTDriverPackage.ps1 -psDeploymentFolder E:\PSDProduction -CompressionType WIM
    
    .EXAMPLE
        .\New-MDTDriverPackage.ps1 -psDeploymentFolder E:\PSDProduction -CompressionType ZIP

    .LINK
        https://github.com/FriendsOfMDT/PSD

    .NOTES
        FileName: New-MDTDriverPackage.ps1
        Solution: PowerShell Deployment for MDT
        Author: PSD Development Team
        Contact: @Mikael_Nystrom , @jarwidmark
        Primary: @Mikael_Nystrom 
        Created: 2019-05-09
        Modified: 2025-01-19

        Version - 0.0.0 - () - Finalized functional version 1
        Version - 0.0.1 - () - Added support for WIM compression, and improved error handling
        Version - 0.0.2 - (@PowerShellCrack) - Cleaned up Synopsys and made parameters mandatory instead of checks. Fixed missed spelled words and added blocks for cleaner code.
#>

#Requires -RunAsAdministrator

## =========================================================================================
## PARAMETER DECLARATION
## =========================================================================================
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,HelpMessage = "REQUIRED: Specify the path to the deployment folder")]
    [string]$psDeploymentFolder,

    [Parameter(Mandatory=$false,HelpMessage = "OPTIONAL: Specify the compression type for the driver packages. Default is WIM")]
	[ValidateSet("ZIP", "WIM")]
	[string]$CompressionType = "WIM"
)

## =========================================================================================
## FUNCTION HELPERS
## =========================================================================================

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
function Set-PSDDefaultLogPath{
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


## =========================================================================================
## MAIN LOGIC
## =========================================================================================    
# Set VerboseForegroundColor
$host.PrivateData.VerboseForegroundColor = 'Cyan'

# Start logging
Set-PSDDefaultLogPath

$psDeploymentFolder = $psDeploymentFolder.TrimEnd("\")

# Hard Coded Variables
$PSDriveName = "PSD"

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
