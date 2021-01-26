<#
.SYNOPSIS

.DESCRIPTION

.LINK

.NOTES
          FileName: Install.ps1
          Solution: PowerShell Deployment for MDT
          Purpose: Installer for PSD
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy, @PowershellCrack
          Primary: @Mikael_Nystrom
          Created:
          Modified: 2021-01-08

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.0.1 - () - Modified array of folders to be created
          Version - 0.0.2 - () - Added force switch and fixed deploymentshare check
          TODO:

.Example
#>

#Requires -RunAsAdministrator
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=0)]
    $psDeploymentFolder,
    [Parameter(Mandatory=$True,Position=1)]
    $psDeploymentShare,
    [Switch]$Upgrade,
    [Switch]$Force
)

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

if(!$PSBoundParameters.ContainsKey('psDeploymentFolder')){
    Write-PSDInstallLog -Message "You have not specified the -psDeploymentfolder" -LogLevel 3
    Break
}

if(!$PSBoundParameters.ContainsKey('psDeploymentShare')){
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
if (Test-Path -path $psDeploymentFolder){
    if(Get-SmbShare | Where-Object {$_.Path -EQ $psDeploymentFolder.TrimEnd("\")})
    {
        if(!($Upgrade))
        {
            Write-PSDInstallLog -Message "The deployment share already exists" -LogLevel 3
            BREAK
        }
    }
    elseIf(!(Get-SmbShare | Where-Object {$_.Path -EQ $psDeploymentFolder.TrimEnd("\")}))
    {
        Write-PSDInstallLog -Message "Deployment folder was NOT shared already, now attempting to share the folder"
        $Result = New-SmbShare -Name $psDeploymentShare -Path $psDeploymentFolder -FullAccess Administrators
        Write-PSDInstallLog -Message "Deployment folder has now been shared as $($psDeploymentshare)"
    }
}
else{
    Write-PSDInstallLog -Message "Creating deploymentshare in $psDeploymentFolder"
    $Result = New-Item -Path $psDeploymentFolder -ItemType Directory -Force:$force

    Write-PSDInstallLog -Message "Sharing $psDeploymentFolder as $psDeploymentShare"
    $Result = New-SmbShare -Name $psDeploymentShare -Path $psDeploymentFolder -FullAccess Administrators
}

# Load the MDT PowerShell provider
$mdtDir = $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir
Write-PSDInstallLog -Message "Import MDT PowerShell Module from $mdtDir"
Import-Module "$($mdtDir)Bin\MicrosoftDeploymentToolkit.psd1"

#detemine if path specified is a full UNC, if not build one from computername
If(([System.Uri]$psDeploymentShare).IsAbsoluteUri){$psDeploymentSharePath = $psDeploymentSharePath}
Else{$psDeploymentSharePath = "\\$env:COMPUTERNAME\$psDeploymentShare"}

# Create the deployment share at the specified path
if(!($Upgrade))
{   
    #Check for existig PSDdrive if a re-run
    If(Test-Path $psDeploymentSharePath){
        Write-PSDInstallLog -Message "The deployment share already exists" -LogLevel 1
    }Else{
        Write-PSDInstallLog -Message "Create PSdrive using MDTProvider with the name of PSD:"
        $Result = New-PSDrive -Name "PSD" -PSProvider "MDTProvider" -Root $psDeploymentFolder -Description "PSD Deployment Share" -NetworkPath $psDeploymentSharePath | Add-MDTPersistentDrive
    }
    
}

#grab just the share name
$psDeploymentShareName = ([System.Uri]$psDeploymentSharePath).AbsolutePath.TrimStart('/')

Write-PSDInstallLog -Message "Creating backup folder"
$Result = New-Item -Path "$psDeploymentFolder\Backup\Scripts" -ItemType Directory -Force

Write-PSDInstallLog -Message "Moving unneeded files to backup location"
$FilesToRemove = "UDIWizard_Config.xml.app","Wizard.hta","Wizard.ico","Wizard.css","Autorun.inf","BDD_Welcome_ENU.xml","Credentials_ENU.xml","Summary_Definition_ENU.xml","DeployWiz_Roles.xsl"
foreach($item in $FilesToRemove){
    if((Test-Path -Path "$psDeploymentFolder\Scripts\$item") -eq $true){
        Write-PSDInstallLog -Message "Moving $psDeploymentFolder\Scripts\$item"
        Move-Item -Path "$psDeploymentFolder\Scripts\$item" -Destination "$psDeploymentFolder\Backup\Scripts\$item" -Force:$force
    }
}

# Cleanup old stuff from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter *.vbs
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)" -Force:$force
}

# Cleanup old stuff from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter *.wsf
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)" -Force:$force
}

# Cleanup old stuff from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter DeployWiz*
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)" -Force:$force
}

# Cleanup old stuff from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter UDI*
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)" -Force:$force
}

# Cleanup old stuff from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter WelcomeWiz_*.xml
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)" -Force:$force
}

# Cleanup old images from DeploymentShare
$Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" | Where {$_.Extension -match 'png|gif|jpg|jpeg|bmp'}
foreach($item in $Result){
    Write-PSDInstallLog -Message "Moving $($item.FullName)"
    Move-Item -Path $item.FullName -Destination "$psDeploymentFolder\Backup\Scripts\$($item.Name)" -Force:$force
}

# Copy the scripts
Copy-PSDFolder "$PSScriptRoot\Scripts\*.ps1" "$psDeploymentFolder\Scripts"
Get-ChildItem -Path "$psDeploymentFolder\Scripts\*.ps1" | Unblock-File 
Copy-PSDFolder "$PSScriptRoot\Scripts\*.xaml" "$psDeploymentFolder\Scripts"
Get-ChildItem -Path "$psDeploymentFolder\Scripts\*.xaml" | Unblock-File 

# Copy the templates
Copy-PSDFolder "$PSScriptRoot\Templates" "$psDeploymentFolder\Templates"
Get-ChildItem -Path "$psDeploymentFolder\Templates\*" | Unblock-File

#Copy PSDWizard Folder Structure and Files
Try{
    New-Item "$psDeploymentFolder\Scripts\PSDWizard" -ItemType directory -Force:$force -ErrorAction Stop | Out-Null
    Copy-PSDFolder "$PSScriptRoot\Scripts\PSDWizard" "$psDeploymentFolder\Scripts\PSDWizard"
    Move-Item "$PSScriptRoot\Scripts\PSDWizard.Initialize.ps1" "$psDeploymentFolder\Scripts\PSDWizard" -Force:$force
    Copy-Item "$PSScriptRoot\Scripts\ListOfTimeZoneIndex.xml" "$psDeploymentFolder\scripts" -Force:$force
    Move-Item "$PSScriptRoot\Scripts\PSDWizard_Definitions_en-US.xml" "$psDeploymentFolder\Scripts\PSDWizard" -ErrorAction SilentlyContinue -Force:$force
}Catch{
    Write-PSDInstallLog -Message ("{0}. Use -Force to force directory" -f $_.Exception.Message) -LogLevel 3
    Break
}
Finally{
    Get-ChildItem "$psDeploymentFolder\Scripts\PSDWizard" -Recurse | Unblock-File
}

# Copy the script modules to the right places
Write-PSDInstallLog -Message "Copying PSD Modules to $psdeploymentfolder......."
$ModuleFiles = "PSDGather", "PSDDeploymentShare", "PSDUtility", "PSDWizard" 
Foreach($ModuleFile in $ModuleFiles){
    if ((Test-Path "$psDeploymentFolder\Tools\Modules\$ModuleFile") -eq $false){
        $Result = New-Item "$psDeploymentFolder\Tools\Modules\$ModuleFile" -ItemType directory -Force:$force
    }
    Write-PSDInstallLog -Message "Copying module $ModuleFile to $psDeploymentFolder\Tools\Modules"
    Copy-Item "$PSScriptRoot\Scripts\$ModuleFile.psm1" "$psDeploymentFolder\Tools\Modules\$ModuleFile" -Force:$force
    Get-ChildItem -Path "$psDeploymentFolder\Tools\Modules\$ModuleFile\*" | Unblock-File
}

# Copy the provider module files
Write-PSDInstallLog -Message "Copying MDT provider files to $psDeploymentFolder\Tools\Modules"
if ((Test-Path "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn") -eq $false){
    $Result = New-Item "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -ItemType directory -Force:$force
}
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.PSSnapIn.dll" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -Force:$force
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.PSSnapIn.dll.config" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -Force:$force
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.PSSnapIn.dll-help.xml" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -Force:$force
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.PSSnapIn.Format.ps1xml" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -Force:$force
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.PSSnapIn.Types.ps1xml" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -Force:$force
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.Core.dll" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -Force:$force
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.Core.dll.config" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -Force:$force
Copy-Item "$($mdtDir)Bin\Microsoft.BDD.ConfigManager.dll" "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -Force:$force

# Copy the provider template files
Write-PSDInstallLog -Message "Copying PSD templates to $psDeploymentFolder\Templates"
if ((Test-Path "$psDeploymentFolder\Templates") -eq $false){
    $Result = New-Item "$psDeploymentFolder\Templates" -ItemType directory -Force:$force
}
Copy-Item "$($mdtDir)Templates\Groups.xsd" "$psDeploymentFolder\Templates" -Force:$force
Copy-Item "$($mdtDir)Templates\Medias.xsd" "$psDeploymentFolder\Templates" -Force:$force
Copy-Item "$($mdtDir)Templates\OperatingSystems.xsd" "$psDeploymentFolder\Templates" -Force:$force
Copy-Item "$($mdtDir)Templates\Packages.xsd" "$psDeploymentFolder\Templates" -Force:$force
Copy-Item "$($mdtDir)Templates\SelectionProfiles.xsd" "$psDeploymentFolder\Templates" -Force:$force
Copy-Item "$($mdtDir)Templates\TaskSequences.xsd" "$psDeploymentFolder\Templates" -Force:$force
Copy-Item "$($mdtDir)Templates\Applications.xsd" "$psDeploymentFolder\Templates" -Force:$force
Copy-Item "$($mdtDir)Templates\Drivers.xsd" "$psDeploymentFolder\Templates" -Force:$force
Copy-Item "$($mdtDir)Templates\Groups.xsd" "$psDeploymentFolder\Templates" -Force:$force
Copy-Item "$($mdtDir)Templates\LinkedDeploymentShares.xsd" "$psDeploymentFolder\Templates" -Force:$force

#Add ZTIGather.XML to correct folder (The file is missing after install) (added by admminy)
Write-PSDInstallLog -Message "Adding ZTIGather.XML to correct folder"
Copy-Item "$($mdtDir)Templates\Distribution\Scripts\ZTIGather.xml" "$psDeploymentFolder\Tools\Modules\PSDGather" -Force:$force

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
    "BGInfo"
    "Prestart"
)
Foreach ($FolderToCreate in $FoldersToCreate){
    Write-PSDInstallLog -Message "Creating $FolderToCreate folder in $psDeploymentFolder\PSDResources"
    $Result = New-Item -ItemType directory -Path $psDeploymentFolder\PSDResources\$FolderToCreate -Force:$force
}

#copy noprompt ISO to CustomScripts; Ran during boot build process in Deployment Workbench (called by PSDUpdateExit.ps1)
Copy-Item -Path $PSScriptRoot\Tools\Create-NoPromptISO.ps1 -Destination $psDeploymentFolder\PSDResources\CustomScripts\Create-NoPromptISO.ps1 -Force:$force

# Copy PSDBackground to Branding folder
Copy-Item -Path $PSScriptRoot\Branding\PSDBackground.bmp -Destination $psDeploymentFolder\PSDResources\Branding\PSDBackground.bmp -Force:$force

# Copy PSDBGI to BGInfo folder
Copy-Item -Path $PSScriptRoot\Branding\PSD.bgi -Destination $psDeploymentFolder\PSDResources\BGInfo\PSD.bgi -Force:$force

# Copy BGInfo64.exe to BGInfo.exe
Copy-Item -Path $psDeploymentFolder\Tools\x64\BGInfo64.exe $psDeploymentFolder\Tools\x64\BGInfo.exe -Force:$force

# PSDRestart
Copy-PSDFolder -source $PSScriptRoot\PSDResources\Prestart -destination $psDeploymentFolder\PSDResources\Prestart

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
    Write-PSDInstallLog -Message "Relaxing permissons on $psDeploymentShareName"
    $Result = icacls $psDeploymentFolder /grant '"Users":(OI)(CI)(RX)'
    $Result = icacls $psDeploymentFolder /grant '"Administrators":(OI)(CI)(F)'
    $Result = icacls $psDeploymentFolder /grant '"SYSTEM":(OI)(CI)(F)'
    $Result = Grant-SmbShareAccess -Name $psDeploymentShareName -AccountName "EVERYONE" -AccessRight Change -Force
    $Result = Revoke-SmbShareAccess -Name $psDeploymentShareName -AccountName "CREATOR OWNER" -Force
}
