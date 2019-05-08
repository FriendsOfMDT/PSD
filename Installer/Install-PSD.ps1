#
# Install.ps1
# version 1.0

#Requires -RunAsAdministrator

Param(
    $psDeploymentFolder = "NA",
    $psDeploymentShare = "NA",
    [Switch]$Upgrade
)

if($psDeploymentFolder -eq 'NA'){
    Write-Error "You have not specified the -psDeploymentfolder"
    Write-Error "Run the installer script again and specify -psDeploymentFolder and -psDeploymentShare"
    Break
}

if($psDeploymentShare -eq 'NA'){
    Write-Error "You have not specified the -psDeploymentfolder"
    Write-Error "Run the installer script again and specify -psDeploymentFolder and -psDeploymentShare"
    Break
}

# Set vars
$install = Split-Path -Path "$PSScriptRoot"
$verbosePreference = "Continue"

if($Upgrade)
{
    Write-Verbose "Installer running in upgrade mode"
}


# Utility function to copy folders (using XCOPY)
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

#TODO - Check for ADK installed and version
$mdtADK = (Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "Windows Assessment and Deployment Kit*"}).DisplayVersion
Write-Verbose "ADK installed version== $mdtADK"

$mdtADKPE = (Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "Windows Assessment and Deployment Kit Windows*"}).DisplayVersion
Write-Verbose "WinPE Addon for ADK(only for ADK1809 or above)== $mdtADKPE"

#TODO - Check for MDT installed and version
$mdtVer = ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "Microsoft Deployment Toolkit*"}).Displayname)
Write-Verbose "MDT installed version== $mdtVer"

# Create the folder and share
if (Test-Path -path $psDeploymentFolder)
{
    if(!($Upgrade))
    {
        Write-Warning "PSD Folder already exist, will break"
        BREAK
    }
}
else
{
    New-Item -Path $psDeploymentFolder -ItemType Directory
    New-SmbShare -Name $psDeploymentShare -Path $psDeploymentFolder -FullAccess Administrators
}


# Load the MDT PowerShell provider
$mdtDir = $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir
Write-Verbose "MDT installation directory: $mdtDir"
Import-Module "$($mdtDir)Bin\MicrosoftDeploymentToolkit.psd1"

# Create the deployment share at the specified path
#TODO - check for existig PSDdrive if a re-run
if(!($Upgrade))
{
    New-PSDrive -Name "PSD" -PSProvider "MDTProvider" -Root $psDeploymentFolder -Description "PSD Deployment Share" -NetworkPath "\\$env:COMPUTERNAME\$psDeploymentShare" | add-MDTPersistentDrive
}

# Copy the scripts
Copy-PSDFolder "$install\Scripts\*.ps1" "$psDeploymentFolder\Scripts"
Dir "$psDeploymentFolder\Scripts\*.ps1" | Unblock-File 
Copy-PSDFolder "$install\Scripts\*.xaml" "$psDeploymentFolder\Scripts"
Dir "$psDeploymentFolder\Scripts\*.xaml" | Unblock-File 

# Copy the templates
Copy-PSDFolder "$install\Templates" "$psDeploymentFolder\Templates"
Dir "$psDeploymentFolder\Templates\*" | Unblock-File

# Copy the script modules to the right places
write-verbose "Copying PSD Modules to $psdeploymentfolder......."
"PSDGather", "PSDDeploymentShare", "PSDUtility", "PSDWizard" | % {
    if ((Test-Path "$psDeploymentFolder\Tools\Modules\$_") -eq $false)
    {
        $null = New-Item "$psDeploymentFolder\Tools\Modules\$_" -ItemType directory
    }
    Write-Verbose "Copying module $_ to $psDeploymentFolder\Tools\Modules"
    Copy-Item "$install\Scripts\$_.psm1" "$psDeploymentFolder\Tools\Modules\$_"
    Dir "$psDeploymentFolder\Tools\Modules\$_\*" | Unblock-File
}

# Copy the provider module files
Write-Verbose "Copying MDT provider files to $psDeploymentFolder\Tools\Modules"
if ((Test-Path "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn") -eq $false)
{
    $null = New-Item "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -ItemType directory
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
Write-Verbose "Copying PSD templates to $psDeploymentFolder\Templates"
if ((Test-Path "$psDeploymentFolder\Templates") -eq $false)
{
    $null = New-Item "$psDeploymentFolder\Templates"
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

# Update the ISO properties
if(!($Upgrade))
{
    Write-Verbose "Updating PSD ISO properties"
    Set-ItemProperty PSD: -Name "Boot.x86.LiteTouchISOName" -Value "PSDLiteTouch_x86.iso"
    Set-ItemProperty PSD: -Name "Boot.x86.LiteTouchWIMDescription" -Value "PowerShell Deployment Boot Image (x86)"
    Set-ItemProperty PSD: -Name "Boot.x64.LiteTouchISOName" -Value "PSDLiteTouch_x64.iso"
    Set-ItemProperty PSD: -Name "Boot.x64.LiteTouchWIMDescription" -Value "PowerShell Deployment Boot Image (x64)"
}

#Add ZTIGather.XML to correct folder (The file is missing after install) (added by admminy)
Write-verbose "Adding ZTIGather.XML to correct folder"
Copy-Item "$($mdtDir)Templates\Distribution\Scripts\ZTIGather.xml" "$psDeploymentFolder\Tools\Modules\PSDGather"

#Add UNC Path to DeploymentShare (TBA)

#Create folders
Write-verbose "Creating Logs folder in $psdeploymentshare"
$null = New-Item -ItemType directory -Path $psDeploymentFolder\Logs -Force

Write-verbose "Creating Dynamics Logs sub-folder in $psdeploymentshare"
$null = New-Item -ItemType directory -Path $psDeploymentFolder\Logs\Dyn -Force

Write-verbose "Creating DriverSources folder in $psdeploymentshare"
$null = New-Item -ItemType directory -Path $psDeploymentFolder\DriverSources -Force

Write-verbose "Creating DriverPackages folder in $psdeploymentshare"
$null = New-Item -ItemType directory -Path $psDeploymentFolder\DriverPackages -Force

#Relax Permissions on DeploymentShare (added admminy)
if(!($Upgrade))
{
    Write-verbose "Relaxing permissons on $psDeploymentShare"
    $null = icacls $psDeploymentFolder /grant '"Users":(OI)(CI)(RX)'
    $null = icacls $psDeploymentFolder /grant '"Administrators":(OI)(CI)(F)'
    $null = icacls $psDeploymentFolder /grant '"SYSTEM":(OI)(CI)(F)'
    Grant-SmbShareAccess -Name $psDeploymentShare -AccountName "EVERYONE" -AccessRight Change -Force
    Revoke-SmbShareAccess -Name $psDeploymentShare -AccountName "CREATOR OWNER" -Force
}

