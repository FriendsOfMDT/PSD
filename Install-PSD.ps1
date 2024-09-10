<#
.SYNOPSIS
.DESCRIPTION
.PARAMETER psDeploymentFolder
    Specify the target MDT/PSD deployment share's physical folder location in the file system.
    The value of this parameter should a legal Windows path. Try to keep the path up to 30 characters with out spaces to be more manageable.
.PARAMETER psDeploymentShare
    Specify the share name that this deployment's solution data will be accessible from the network, by definition all deployment shares are hidden (YourDeploymentShareName$).
    If the parameter is left null then the value of the share will be formed by the machine name that the script is running and the part of the deployment folder.
    e.g. if the deployment folder is F:\MDTDeployments\PSDBuild on a machine called MDTServer  the share will become \\MDTServer\PSDBuild$ 
    This parameter must have a value for an upgrade process.
.PARAMETER Upgrade
    Use this switch to upgrade an existing deployment share.
    In order to use this switch, upgrade an existing deployment share, the parameters psDeploymentFolder and psDeploymentShare must have valid values.
    If this parameter is not used the script asumes that it is a new deployment.
.LINK
.NOTES
          FileName: Install.ps1
          Solution: PowerShell Deployment for MDT
          Purpose: Installer for PSD
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy, @emarkelis, @GSimos
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2021-04-17
          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.0.1 - () - Modified array of folders to be created
          Version - 0.0.2 - () - rework and optimization of script's parameters, help messages.
          Version - 0.0.3 - () - ready for release.
          Version - 0.0.4 - () - Bug with backslash at the end of psDeploymentFolder variable fixed.
          Version - 0.0.5 - () - Refactored script, applied the upgrade and new logic according to cases, applied deterministic checks for the versions. Applied parameter sets.
          Version - 0.0.6 - () - Refactoring
          TODO:
            1. Check if join path can be applied - done 08/01/2022
            2. Implement Validate set for operations [Upgrade,New,Overwrite] to be used also in UI - potponed
	        3. GUI implementation (fool proof) -postponed
            4. Create event log (last-global) - not urgent/postponed
            5. Check if XCopy can be replaced by Robocopy (as it is included since Windows Vista/2008 in the O/S)
            5. Create a PSDrive for the logging folder. - not urgent
.EXAMPLE
    .\Install-PSD.ps1 -psDeploymentFolder F:\DeploymentShares\PSDScriptTest01
    This command is going to create a new deployment called PSDScriptTest01 and a hidden share with the same name (PSDScriptTest01$).
    The MDT persistent drive will have the name PSDxxx.
.EXAMPLE
    .\Install-PSD.ps1 -psDeploymentFolder F:\DeploymentShares\PSDScriptTest01 -psDeploymentShare Test01
    This command is going to create a new deployment called PSDScriptTest01 and a hidden share with the name Test01$.
    The MDT persistent drive will have the name PSDxxx.
.EXAMPLE
    .\Install-PSD.ps1 -psDeploymentFolder F:\DeploymentShares\PSDScriptTest01 -psDeploymentShare Test01 -Upgrade
    This command is going to upgrade deployment called PSDScriptTest01 and a hidden share with the name Test01$.
    Both psDeploymentFolder and psDeploymentShare parameters are mandatory when upgrading.
    The MDT persistent drive will have the name PSDxxx.
.ROLE
#>

# Requires the script to be run under an administrative account context.
#Requires -RunAsAdministrator

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Specify the target MDT/PSD deployment share's physical folder location in the file system.")]
    [string]$psDeploymentFolder,
    [Parameter(Mandatory = $true, Position = 1,  HelpMessage = "Specify the share name that this deployment's solution data will be accessible from the network.")]
    [string]$psDeploymentShare,
    [Parameter(Mandatory = $false, Position = 2,  HelpMessage = "Use this switch to upgrade an existing deployment share.")]
    [Switch]$Upgrade
)
$Script:DeploymentToolkitVersion = "2.2.8"

# Do not include this in the param block!
# Set PSDDrive prefix.
[string]$script:PSDDrive = 'PSD'
[int]$script:MinADKVersion = 17763
# Set VerboseForegroundColor
$host.PrivateData.VerboseForegroundColor = 'Cyan'
$psDeploymentFolder = $psDeploymentFolder.TrimEnd('\')


function Start-PSDLog {
    [CmdletBinding()]
    param (
        [string]$FilePath
    )
    try {
        if (!(Split-Path $FilePath -Parent | Test-Path)) {
            New-Item (Split-Path $FilePath -Parent) -Type Directory | Out-Null
        }
        # Confirm the provided destination for logging exists if it doesn't then create it.
        if (!(Test-Path $FilePath)) {
            # Create the log file destination if it doesn't exist.
            New-Item $FilePath -Type File | Out-Null
        } else {
            Remove-Item -Path $FilePath -Force
        }
        # Set the global variable to be used as the FilePath for all subsequent write-PSDInstallLog
        # calls in this session
        $global:ScriptLogFilePath = $FilePath
    } catch {
        # In event of an error write an exception
        Write-Error $_.Exception.Message
    }
}
function Write-PSDInstallLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter()]
        [ValidateSet(1, 2, 3)]
        [string]$LogLevel = 1,
        [Parameter(Mandatory = $false)]
        [bool]$writetoscreen = $true   
    )
    $Message =  "$($Message)`nDeployment Tool kit Version:$($Script:DeploymentToolkitVersion)"
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
    $Line = $Line -f $LineFormat
    [system.GC]::Collect()
    Add-Content -Value $Line -Path $global:ScriptLogFilePath
    if ($writetoscreen) {
        switch ($LogLevel) {
            '1' {
                Write-Verbose -Message $Message
            }
            '2' {
                Write-Warning -Message $Message
            }
            '3' {
                $Error.Add($Message) | Out-Null
                [Console]::ForegroundColor = 'Red'
                [Console]::BackgroundColor = 'Black'
                [Console]::Error.WriteLine($Message)
                [Console]::ResetColor()
            }
            Default {
            }
        }
    }
    if ($writetolistbox -eq $true) {
        $result1.Items.Add("$Message")
    }
}
function Set-PSDDefaultLogPath {
    # Function to set the default log path if something is put in the field then it is sent somewhere else. 
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $false)]
        [bool]$defaultLogLocation = $true,
        [parameter(Mandatory = $false)]
        [string]$LogLocation
    )
    if ($defaultLogLocation) {
        $LogPath = Split-Path $script:MyInvocation.MyCommand.Path
        $LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
        Start-PSDLog -FilePath $($LogPath + "\" + $LogFile)
    }
    else {
        $LogPath = $LogLocation
        $LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
        Start-PSDLog -FilePath $($LogPath + "\" + $LogFile)
    }
}
function Copy-PSDFolder {
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        [string] $source,
        [Parameter(Mandatory = $True, Position = 2)]
        [string] $destination
    )

    $s = $source.TrimEnd("\")
    $d = $destination.TrimEnd("\")
    Write-Verbose "Copying folder $source to $destination using XCopy"
    & xcopy $s $d /s /e /v /y /i | Out-Null
}

# Start logging
Set-PSDDefaultLogPath
Write-PSDInstallLog -Message "Starting installation script for $DeploymentToolkitVersion"

##############################################################
## Test-PSDADK
##############################################################
$mdtADK = (Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |  Where-Object {$_.UninstallString -like "*adksetup.exe*"}).DisplayVersion

if ($null -eq $mdtADK){
    Write-PSDInstallLog -Message "ADK not detected/installed! Aborting." -LogLevel 3 -writetoscreen $true
    exit
}

$ADKbuild = [int]([string]$mdtADK.Split('.')[2])
if ($ADKbuild -lt $script:MinADKVersion) {
    Write-PSDInstallLog -Message "Installed ADK is older then $($script:MinADKVersion) ,Aborting." -LogLevel 3 -writetoscreen $true
    exit
} else {
    Write-PSDInstallLog -Message "ADK installed version: $mdtADK" -writetoscreen $true
}

##############################################################
## Test-PSDADK
## End
##############################################################
##############################################################
## Test-PSDADKWinPE
##############################################################
$mdtADKPE = (Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.UninstallString -like "*adkwinpesetup.exe*"}).DisplayVersion
# ADK1809 build:17763
$ADKPEbuild = [int]([string]$mdtADK.Split('.')[2])
if (($null -eq $mdtADKPE) -or ($ADKPEbuild -lt $script:MinADKVersion)) {
    Write-PSDInstallLog -Message "ADKPE not detected/installed! Aborting." -LogLevel 3 -writetoscreen $true
    exit
} else {
    Write-PSDInstallLog -Message "WinPE Addon for ADK(only for ADK1809 or above): $mdtADKPE" -writetoscreen $true
}
##############################################################
## Test-PSDADKWinPE
## End
##############################################################
##############################################################
## Test-PSDMDT
## End
##############################################################
$mdtVer = ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -like "Microsoft Deployment Toolkit*" }).Displayname)
if ($null -eq $mdtVer) {
    Write-PSDInstallLog -Message "MDT not detected/installed! Aborting." -LogLevel 3 -writetoscreen $true
    exit
} else {
    Write-PSDInstallLog -Message "MDT installed version: $mdtVer"
    # Load the MDT PowerShell provider
    $mdtDir = $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir
    Write-PSDInstallLog -Message "Import MDT PowerShell Module from $mdtDir"
    Import-Module "$($mdtDir)Bin\MicrosoftDeploymentToolkit.psd1"
}
##############################################################
## Test-PSDMDT
## End
##############################################################

# SMB share and MDT drive description
$description = "PSD Deployment Share $(Split-Path -Path $psDeploymentFolder -Leaf)"

if (-not ($Upgrade.IsPresent)){
    if (!$psDeploymentShare) {   
        $share = Split-Path -Path $psDeploymentFolder -Leaf
        $psDeploymentShare = "$($share)$('$')"
        Write-PSDInstallLog -Message "You have not specified the parameter psDeploymentShare the default value will be $($psDeploymentShare)" -LogLevel 2
    }
    $msg = "{0}: {1} already exists! This is not an upgrade operation, aborting."
    if (Test-Path $psDeploymentFolder) {
        $logmsg = $msg -f "Folder", $psDeploymentFolder
        Write-PSDInstallLog -Message $logmsg -LogLevel 3 
        exit
    }
    if (Get-SmbShare $psDeploymentShare -ErrorAction "SilentlyContinue") {
        Write-PSDInstallLog -Message ($msg -f "Share", $psDeploymentShare) -LogLevel 3 -writetoscreen $true
        exit
    }
    # Create the folder and the smb share
    Write-PSDInstallLog -Message "Creating deployment share in $psDeploymentFolder" -writetoscreen $true
    try{
        $null = New-Item -Path $psDeploymentFolder -ItemType Directory -ErrorAction Stop
        }
    catch{
        Write-PSDInstallLog -Message "Failed to create the deployment share $psDeploymentFolder" -LogLevel 3 -writetoscreen $true
        Write-Warning -Message "Failed to create the deployment share $psDeploymentFolder"
        Break
    }
  
    $Null = New-SmbShare -Name $psDeploymentShare -Path $psDeploymentFolder -FullAccess Administrators -Description $description -ErrorAction Stop
    Write-PSDInstallLog -Message "Deployment folder has now been shared as $($psDeploymentshare)" -writetoscreen $true
    # Create the deployment share at the specified path
    $script:PSDDrive = "PSD$(([string]((Get-MDTPersistentDrive | Where-Object Name -Like "PSD*").Count+1)).PadLeft(3,'0'))"
    Write-PSDInstallLog -Message "Create PSdrive using MDTProvider with the name of $($script:PSDDrive)" -LogLevel 1 -writetoscreen $true
    New-PSDrive -Name "$($script:PSDDrive)" -PSProvider "MDTProvider" -Root $psDeploymentFolder -Description $description | Add-MDTPersistentDrive | Out-Null

    # Cleanup MDT default files
    $filters =  '*.vbs','*.wsf','DeployWiz*','UDI*','WelcomeWiz_*.xml','Wizard*'
    foreach ($filter in $filters) {
        $Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter $filter
        foreach ($item in $Result) {
            Write-PSDInstallLog -Message "Removing $($item.FullName)"
            Remove-Item -Path $item.FullName
        }
    }
} else {
    Write-PSDInstallLog -Message "Installer running in upgrade mode"
    $msg = "{0}:{1} share does not exist! Please verify the share name. Aborting installer."
    if (-not (Test-Path $psDeploymentFolder)) {
        Write-PSDInstallLog -Message ($msg -f "Folder", $psDeploymentFolder) -LogLevel 3 -writetoscreen $true
        exit
    }
    if (-not (Get-SmbShare $psDeploymentShare -ErrorAction "SilentlyContinue")) {
        Write-PSDInstallLog -Message ($msg -f "Share", $psDeploymentShare) -LogLevel 3 -writetoscreen $true
        exit
    }
    
    Write-PSDInstallLog -Message "Creating the main backup folder if needed"
    New-Item -Path "$($psDeploymentFolder)\Backup" -ItemType Directory -Force | Out-Null

    # PSDRestart backup folder
    [string]$folderCount = (Get-ChildItem -Filter 'PSD_*' -Path "$($psDeploymentFolder)\Backup\" | Measure-Object).Count + 1
    $FoldercountWithPadding = $FolderCount.PadLeft(5,'0')
    $backupFolder = "$($psDeploymentFolder)\Backup\PSD_$($FoldercountWithPadding)"
    # Backup the MDT folder that will be upgraded.
    write-PSDInstallLog -Message "Backup folder $($backupFolder)" -LogLevel 1
    New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
    $FoldersToMove = 'scripts','templates','tools\modules','PSDResources\BGInfo','PSDResources\BootImageFiles','PSDResources\Branding','PSDResources\Certificates','PSDResources\CustomScripts','PSDResources\Plugins','PSDResources\Prestart','PSDResources\UserExitScripts'
    foreach($folder in $FoldersToMove){
        Copy-Item -Path "$($psDeploymentFolder)\$($folder)" -Destination "$($backupFolder)\$($folder)" -Recurse
    }
  }

 # Cleanup MDT files with filters
 $filters =  @(
               '*.vbs'
               '*.wsf'
               'DeployWiz*'
               'UDI*'
               'WelcomeWiz_*.xml'
               '*.gif'
               '*.png'
               '*.jpg'
               'UDIWizard_Config.xml.app'
               'Wizard.hta'
               'Wizard.ico'
               'Wizard.css'
               'Autorun.inf'
               'BDD_Welcome_ENU.xml'
               'Credentials_ENU.xml'
               'Summary_Definition_ENU.xml'
               'DeployWiz_Roles.xsl'
               'ListOfLanguages.xml'
               'ZTITatoo.mof'
               )
foreach ($filter in $filters) {
    $Result = Get-ChildItem -Path "$psDeploymentFolder\Scripts" -Filter $filter
    foreach ($item in $Result) {
        Write-PSDInstallLog -Message "Moving $($item.FullName)"
        Remove-Item -Path $item.FullName -Force
    }
}

# Copy the scripts directly in the scripts folder (no recursive)
'*.ps1','*.xaml','*.xml'| ForEach-Object { 
    Copy-Item "$PSScriptRoot\Scripts\$($_)" "$psDeploymentFolder\Scripts"
    Get-ChildItem -Path "$psDeploymentFolder\Scripts\$($_)" | Unblock-File 
    }

# Copy the Wizard folders
#Copy-PSDFolder "$PSScriptRoot\Scripts\PSDWizard" "$psDeploymentFolder\Scripts\PSDWizard"
Copy-PSDFolder "$PSScriptRoot\Scripts\PSDWizardNew" "$psDeploymentFolder\Scripts\PSDWizardNew"
#Get-ChildItem -Path "$psDeploymentFolder\Scripts\PSDWizard\*" -Recurse | Unblock-File
Get-ChildItem -Path "$psDeploymentFolder\Scripts\PSDWizardNew\*" -Recurse | Unblock-File

# Copy the templates
Copy-PSDFolder "$PSScriptRoot\Templates" "$psDeploymentFolder\Templates"
Get-ChildItem -Path "$psDeploymentFolder\Templates\*" | Unblock-File

# Copy the script modules to the right places
Write-PSDInstallLog -Message "Copying PSD Modules to $psdeploymentfolder......."
$ModuleFiles = "PSDGather", "PSDDeploymentShare", "PSDUtility", "PSDWizard", "PSDWizardNew", "PSDStartLoader" 
Foreach ($ModuleFile in $ModuleFiles) {
    if ((Test-Path "$psDeploymentFolder\Tools\Modules\$($ModuleFile)") -eq $false) {
        $Result = New-Item "$psDeploymentFolder\Tools\Modules\$($ModuleFile)" -ItemType directory
    }
    Write-PSDInstallLog -Message "Copying module $ModuleFile to $psDeploymentFolder\Tools\Modules"
    Copy-Item "$PSScriptRoot\Scripts\$($ModuleFile).psm1" "$psDeploymentFolder\Tools\Modules\$($ModuleFile)"
    Get-ChildItem -Path "$psDeploymentFolder\Tools\Modules\$($ModuleFile)\*" | Unblock-File
}

# Copy the provider module files
Write-PSDInstallLog -Message "Copying MDT provider files to $psDeploymentFolder\Tools\Modules"
if ((Test-Path "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn") -eq $false) {
    New-Item "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -ItemType directory | Out-Null
}
$providerModules = @("Microsoft.BDD.PSSnapIn.dll"
                     "Microsoft.BDD.PSSnapIn.dll.config" 
                     "Microsoft.BDD.PSSnapIn.dll-help.xml" 
                     "Microsoft.BDD.PSSnapIn.Format.ps1xml"
                     "Microsoft.BDD.PSSnapIn.Types.ps1xml"
                     "Microsoft.BDD.Core.dll"
                     "Microsoft.BDD.Core.dll.config"
                     "Microsoft.BDD.ConfigManager.dll")

foreach($providerModule in $providerModules){
    Copy-Item "$($mdtDir)Bin\$($providerModule)" -Destination "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn"
}


# Copy the provider template files
Write-PSDInstallLog -Message "Copying PSD templates to $psDeploymentFolder\Templates"
if ((Test-Path "$psDeploymentFolder\Templates") -eq $false) {
    New-Item "$psDeploymentFolder\Templates" | Out-Null
}

$providerTemplates =@("Groups.xsd"
                      "Medias.xsd"
                      "OperatingSystems.xsd"
                      "Packages.xsd"
                      "SelectionProfiles.xsd"
                      "TaskSequences.xsd"
                      "Applications.xsd"
                      "Drivers.xsd"
                      "Groups.xsd"
                      "LinkedDeploymentShares.xsd")
foreach ($providerTemplate in $providerTemplates) {
    Copy-Item "$($mdtDir)Templates\$providerTemplate" -Destination "$psDeploymentFolder\Templates"     
}

# Copy ZTIGather.XML to correct folder
Write-PSDInstallLog -Message "Adding ZTIGather.XML to correct folder"
Move-Item -Path "$PSScriptRoot\Scripts\ZTIGather.xml" -Destination "$psDeploymentFolder\Tools\Modules\PSDGather" -Force

# Verify/Correct missing UNC path in BootStrap.ini (TBA)

# Create folders
$FoldersToCreate = @(
    "Autopilot"
    "BGInfo"
    "BootImageFiles\X86"
    "BootImageFiles\X64"
    "Branding"
    "Certificates"
    "CustomScripts"
    "DriverPackages"
    "DriverSources"
    "Plugins"
    "Prestart"
    "UserExitScripts"
    "Readiness"
)
foreach ($FolderToCreate in $FoldersToCreate) {
    Write-PSDInstallLog -Message "Creating $FolderToCreate folder in $psdeploymentshare\PSDResources"
    $path = Join-Path -Path "$($psDeploymentFolder)\PSDResources" -ChildPath $FolderToCreate
    New-Item -ItemType directory -Path $path -Force | Out-Null
}

# Copy PSDBackground to Branding folder
Copy-Item -Path $PSScriptRoot\Branding\PSDBackground.bmp -Destination $psDeploymentFolder\PSDResources\Branding\PSDBackground.bmp -Force

# Copy PSD.BGI to BGInfo folder
Copy-Item -Path $PSScriptRoot\Branding\PSD.bgi -Destination $psDeploymentFolder\PSDResources\BGInfo\PSD.bgi -Force

# Copy BGInfo64.exe to BGInfo.exe
Copy-Item -Path $psDeploymentFolder\Tools\x64\BGInfo64.exe $psDeploymentFolder\Tools\x64\BGInfo.exe

# PSDPrestart
Copy-PSDFolder -source $PSScriptRoot\PSDResources\Prestart -destination $psDeploymentFolder\PSDResources\Prestart

# Plugins
Copy-PSDFolder -source $PSScriptRoot\Plugins -destination $psDeploymentFolder\PSDResources\Plugins

# Readiness
Copy-PSDFolder -source $PSScriptRoot\PSDResources\Readiness -destination $psDeploymentFolder\PSDResources\Readiness


if (!($Upgrade)) {
    # Update the DeploymentShare properties
    $property = "$($script:PSDDrive):"
    Write-PSDInstallLog -Message "Update the DeploymentShare properties"
    Set-ItemProperty $property -Name "Boot.x86.LiteTouchISOName" -Value "PSDLiteTouch_x86.iso"
    Set-ItemProperty $property -Name "Boot.x86.LiteTouchWIMDescription" -Value "PowerShell Deployment Boot Image (x86)"
    Set-ItemProperty $property -Name "Boot.x86.BackgroundFile" -Value "%DEPLOYROOT%\PSDResources\Branding\PSDBackground.bmp"
    Set-ItemProperty $property -Name "Boot.x64.LiteTouchISOName" -Value "PSDLiteTouch_x64.iso"
    Set-ItemProperty $property -Name "Boot.x64.LiteTouchWIMDescription" -Value "PowerShell Deployment Boot Image (x64)"
    Set-ItemProperty $property -Name "Boot.x64.BackgroundFile" -Value "%DEPLOYROOT%\PSDResources\Branding\PSDBackground.bmp"
    Set-ItemProperty $property -Name "Description" -Value $description 
    
    # Disable support for x86
    Write-PSDInstallLog -Message "Disable support for x86"
    Set-ItemProperty $property -Name "SupportX86" -Value "False"
    
    # Relax Permissions on DeploymentFolder and DeploymentShare
    Write-PSDInstallLog -Message "Relaxing permissions on $psDeploymentShare"
    icacls $psDeploymentFolder /grant '"Users":(OI)(CI)(RX)' | Out-Null
    icacls $psDeploymentFolder /grant '"Administrators":(OI)(CI)(F)' | Out-Null
    icacls $psDeploymentFolder /grant '"SYSTEM":(OI)(CI)(F)' | Out-Null
    Grant-SmbShareAccess -Name $psDeploymentShare -AccountName "EVERYONE" -AccessRight Change -Force | Out-Null
    Revoke-SmbShareAccess -Name $psDeploymentShare -AccountName "CREATOR OWNER" -Force | Out-Null

    # copy the INI Files
    Copy-Item -Path "$PSScriptRoot\INIFiles\CustomSettings.ini" -Destination "$psDeploymentFolder\Control\CustomSettings.ini" -Force | Out-Null
    Copy-Item -Path "$PSScriptRoot\INIFiles\BootStrap.ini" -Destination "$psDeploymentFolder\Control\BootStrap.ini" -Force | Out-Null
}


Write-Verbose -Message "PSD is installed to $psDeploymentShare" -Verbose
