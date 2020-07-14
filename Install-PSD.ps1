<#
.SYNOPSIS

.DESCRIPTION

.LINK

.NOTES
          FileName: Install.ps1
          Solution: PowerShell Deployment for MDT
          Purpose: Installer for PSD
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2020-05-11

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.0.1 - () - Modified array of folders to be created

          TODO:

.Example
#>

#Requires -RunAsAdministrator
[CmdletBinding()]
Param(
    $psDeploymentFolder = "NA",
    $psDeploymentShare = "NA",
    [Switch]$Upgrade
)

# Remove trailing \ if exists
$psDeploymentFolder = $psDeploymentFolder.TrimEnd("\")

# Set VerboseForegroundColor
$host.PrivateData.VerboseForegroundColor = 'Cyan'

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

# Start logging
set-PSDDefaultLogPath

if($psDeploymentFolder -eq 'NA'){
    Write-PSDInstallLog -Message "You have not specified the -psDeploymentfolder" -LogLevel 3
    Break
}

if($psDeploymentShare -eq 'NA'){
    Write-PSDInstallLog -Message "You have not specified the -psDeploymentShare" -LogLevel 3
    Break
}

if($Upgrade){
    Write-PSDInstallLog -Message "Installer running in upgrade mode"
}

#TODO - Check for ADK installed and version
$mdtADK = (Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "Windows Assessment and Deployment Kit - Windows 10"}).DisplayVersion
Write-PSDInstallLog -Message "ADK installed version: $mdtADK"

$mdtADKPE = (Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "Windows Assessment and Deployment Kit Windows Preinstallation Environment Add-ons - Windows 10"}).DisplayVersion
Write-PSDInstallLog -Message "WinPE Addon for ADK(only for ADK1809 or above): $mdtADKPE"

#TODO - Check for MDT installed and version
$mdtVer = ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "Microsoft Deployment Toolkit*"}).Displayname)
Write-PSDInstallLog -Message "MDT installed version: $mdtVer"

# Create the folder and share
Write-PSDInstallLog -Message "Check if $psDeploymentFolder exists"
if(Test-Path -path $psDeploymentFolder){
    Write-PSDInstallLog -Message "Check if $psDeploymentFolder is shared"
    if((Get-SmbShare | Where-Object {$_.Path -EQ $psDeploymentFolder}) -ne $null){
        if(!($Upgrade)){
            Write-PSDInstallLog -Message "The deployment share already exists" -LogLevel 3
            Break
        }
    }
    elseIf(!(Get-SmbShare | Where-Object {$_.Path -EQ $psDeploymentFolder}))
    {
        Write-PSDInstallLog -Message "Deployment folder was NOT shared already, now attempting to share the folder"
        $Result = New-SmbShare -Name $psDeploymentShare -Path $psDeploymentFolder -FullAccess Administrators
        Write-PSDInstallLog -Message "Deployment folder has now been shared as $($psDeploymentshare)"
    }
}
else{
    Write-PSDInstallLog -Message "Creating deploymentshare in $psDeploymentFolder"
    $Result = New-Item -Path $psDeploymentFolder -ItemType Directory

    Write-PSDInstallLog -Message "Sharing $psDeploymentFolder as $psDeploymentShare"
    $Result = New-SmbShare -Name $psDeploymentShare -Path $psDeploymentFolder -FullAccess Administrators
}

# Load the MDT PowerShell provider
$mdtDir = $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir
Write-PSDInstallLog -Message "Import MDT PowerShell Module from $mdtDir"
Import-Module "$($mdtDir)Bin\MicrosoftDeploymentToolkit.psd1"

# Create the deployment share at the specified path
#TODO - check for existig PSDdrive if a re-run
if(!($Upgrade))
{
    Write-PSDInstallLog -Message "Create PSdrive using MDTProvider with the name of PSD:"
    $Result = New-PSDrive -Name "PSD" -PSProvider "MDTProvider" -Root $psDeploymentFolder -Description "PSD Deployment Share" -NetworkPath "\\$env:COMPUTERNAME\$psDeploymentShare" | add-MDTPersistentDrive
}

Write-PSDInstallLog -Message "Creating backup folder"
$Result = New-Item -Path "$psDeploymentFolder\Backup\Scripts" -ItemType Directory -Force

Write-PSDInstallLog -Message "Moving unneeded files to backup location"
$FilesToRemove = "UDIWizard_Config.xml.app","Wizard.hta","Wizard.ico","Wizard.css","Autorun.inf","BDD_Welcome_ENU.xml","Credentials_ENU.xml","Summary_Definition_ENU.xml","DeployWiz_Roles.xsl"
foreach($item in $FilesToRemove){
    if((Test-Path -Path "$psDeploymentFolder\Scripts\$item") -eq $true){
        Write-PSDInstallLog -Message "Moving $psDeploymentFolder\Scripts\$item"
        Move-Item -Path "$psDeploymentFolder\Scripts\$item" -Destination "$psDeploymentFolder\Backup\Scripts\$item"
    }
}

# Cleanup old stuff from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter *.vbs
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)"
}

# Cleanup old stuff from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter *.wsf
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)"
}

# Cleanup old stuff from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter DeployWiz*
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)"
}

# Cleanup old stuff from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter UDI*
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)"
}

# Cleanup old stuff from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter WelcomeWiz_*.xml
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)"
}

# Copy the scripts
Copy-PSDFolder "$PSScriptRoot\Scripts\*.ps1" "$psDeploymentFolder\Scripts"
Get-ChildItem -Path "$psDeploymentFolder\Scripts\*.ps1" | Unblock-File 
Copy-PSDFolder "$PSScriptRoot\Scripts\*.xaml" "$psDeploymentFolder\Scripts"
Get-ChildItem -Path "$psDeploymentFolder\Scripts\*.xaml" | Unblock-File 

# Copy the templates
Copy-PSDFolder "$PSScriptRoot\Templates" "$psDeploymentFolder\Templates"
Get-ChildItem -Path "$psDeploymentFolder\Templates\*" | Unblock-File

# Copy the script modules to the right places
Write-PSDInstallLog -Message "Copying PSD Modules to $psdeploymentfolder......."
"PSDGather", "PSDDeploymentShare", "PSDUtility", "PSDWizard" | % {
    if ((Test-Path "$psDeploymentFolder\Tools\Modules\$_") -eq $false)
    {
        $Result = New-Item "$psDeploymentFolder\Tools\Modules\$_" -ItemType directory
    }
    Write-PSDInstallLog -Message "Copying module $_ to $psDeploymentFolder\Tools\Modules"
    Copy-Item "$PSScriptRoot\Scripts\$_.psm1" "$psDeploymentFolder\Tools\Modules\$_"
    Get-ChildItem -Path "$psDeploymentFolder\Tools\Modules\$_\*" | Unblock-File
}

# Copy the provider module files
Write-PSDInstallLog -Message "Copying MDT provider files to $psDeploymentFolder\Tools\Modules"
if ((Test-Path "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn") -eq $false)
{
    $Result = New-Item "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -ItemType directory
}
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.PSSnapIn.dll" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn"
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.PSSnapIn.dll.config" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn"
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.PSSnapIn.dll-help.xml" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn"
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.PSSnapIn.Format.ps1xml" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn"
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.PSSnapIn.Types.ps1xml" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn"
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.Core.dll" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn"
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.Core.dll.config" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn"
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.ConfigManager.dll" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn"

# Copy the provider template files
Write-PSDInstallLog -Message "Copying PSD templates to $psDeploymentFolder\Templates"
if ((Test-Path "$psDeploymentFolder\Templates") -eq $false)
{
    $Result = New-Item "$psDeploymentFolder\Templates"
}
Copy-Item "$($mdtDir)Templates\Groups.xsd" "$psDeploymentFolder\Templates"
Copy-Item "$($mdtDir)Templates\Medias.xsd" "$psDeploymentFolder\Templates"
Copy-Item "$($mdtDir)Templates\OperatingSystems.xsd" "$psDeploymentFolder\Templates"
Copy-Item "$($mdtDir)Templates\Packages.xsd" "$psDeploymentFolder\Templates"
Copy-Item "$($mdtDir)Templates\SelectionProfiles.xsd" "$psDeploymentFolder\Templates"
Copy-Item "$($mdtDir)Templates\TaskSequences.xsd" "$psDeploymentFolder\Templates"
Copy-Item "$($mdtDir)Templates\Applications.xsd" "$psDeploymentFolder\Templates"
Copy-Item "$($mdtDir)Templates\Drivers.xsd" "$psDeploymentFolder\Templates"
Copy-Item "$($mdtDir)Templates\Groups.xsd" "$psDeploymentFolder\Templates"
Copy-Item "$($mdtDir)Templates\LinkedDeploymentShares.xsd" "$psDeploymentFolder\Templates"

#Add ZTIGather.XML to correct folder (The file is missing after install) (added by admminy)
Write-PSDInstallLog -Message "Adding ZTIGather.XML to correct folder"
Copy-Item "$($mdtDir)Templates\Distribution\Scripts\ZTIGather.xml" "$psDeploymentFolder\Tools\Modules\PSDGather"

# Verify/Correct missing UNC path in BootStrap.ini (TBA)

#Create folders
$FoldersToCreate = @(
    "Autopilot"
    "BootImageFiles\X86"
    "BootImageFiles\X64"
    "Branding"
    "Certificates"
    "CustomScripts"
    "DriverPackages"
    "DriverSources"
    "UserExitScripts"
)
Foreach ($FolderToCreate in $FoldersToCreate){
    Write-PSDInstallLog -Message "Creating $FolderToCreate folder in $psdeploymentshare\PSDResources"
    $Result = New-Item -ItemType directory -Path $psDeploymentFolder\PSDResources\$FolderToCreate -Force
}

# Copy PSDBackground to Branding folder
Copy-Item -Path $PSScriptRoot\Branding\PSDBackground.bmp -Destination $psDeploymentFolder\PSDResources\Branding\PSDBackground.bmp -Force

# Update the DeploymentShare properties
if(!($Upgrade))
{
    Write-PSDInstallLog -Message "Update the DeploymentShare properties"
    Set-ItemProperty PSD: -Name "Boot.x86.LiteTouchISOName" -Value "PSDLiteTouch_x86.iso"
    Set-ItemProperty PSD: -Name "Boot.x86.LiteTouchWIMDescription" -Value "PowerShell Deployment Boot Image (x86)"
    Set-ItemProperty PSD: -Name "Boot.x86.BackgroundFile" -Value "%DEPLOYROOT%\PSDResources\Branding\PSDBackground.bmp"
    Set-ItemProperty PSD: -Name "Boot.x64.LiteTouchISOName" -Value "PSDLiteTouch_x64.iso"
    Set-ItemProperty PSD: -Name "Boot.x64.LiteTouchWIMDescription" -Value "PowerShell Deployment Boot Image (x64)"
    Set-ItemProperty PSD: -Name "Boot.x64.BackgroundFile" -Value "%DEPLOYROOT%\PSDResources\Branding\PSDBackground.bmp"

    # Disable support for x86
    Write-PSDInstallLog -Message "Disable support for x86"
    Set-ItemProperty PSD: -Name "SupportX86" -Value "False"
}

# Relax Permissions on Deploymentfolder and DeploymentShare
if(!($Upgrade))
{
    Write-PSDInstallLog -Message "Relaxing permissons on $psDeploymentShare"
    $Result = icacls $psDeploymentFolder /grant '"Users":(OI)(CI)(RX)'
    $Result = icacls $psDeploymentFolder /grant '"Administrators":(OI)(CI)(F)'
    $Result = icacls $psDeploymentFolder /grant '"SYSTEM":(OI)(CI)(F)'
    $Result = Grant-SmbShareAccess -Name $psDeploymentShare -AccountName "EVERYONE" -AccessRight Change -Force
    $Result = Revoke-SmbShareAccess -Name $psDeploymentShare -AccountName "CREATOR OWNER" -Force
}

