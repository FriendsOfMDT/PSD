#
# Install.ps1
#

[CmdletBinding()]
Param (
    [Parameter(Position=0)][Alias("Path")][String]$psDeploymentFolder = "C:\PSDeploymentShare",   # Deployment share location
    [Parameter(Position=1)][Alias("ShareName")][String]$psDeploymentShare = "PSDeploymentShare$", # Deployment share name
    [Parameter()][Alias("FullAccess")][String[]]$psShareFullAccess = @(, 'Administrators')        # Users/Groups to be given full share access
)

# Create the folder and share
$null = New-Item -Path $psDeploymentFolder -ItemType Directory
$null = New-SmbShare -Name $psDeploymentShare -Path $psDeploymentFolder -FullAccess $psShareFullAccess

# Find the folder this script is in
$install = Split-Path -Path "$PSScriptRoot"

# Load the MDT PowerShell provider
$mdtDir = $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir
Write-Verbose "MDT installation directory: $mdtDir"
Import-Module "$($mdtDir)Bin\MicrosoftDeploymentToolkit.psd1"

# Create the deployment share at the specified path
$null = New-PSDrive -Name PSD -PSProvider MDTProvider -Root $psDeploymentFolder

# Copy the scripts
Copy-Item -Path "$install\Scripts\*.*" -Destination "$psDeploymentFolder\Scripts" -Recurse
Get-ChildItem -Path "$psDeploymentFolder\Scripts\*.ps*" | Unblock-File 

# Copy the templates
Copy-Item -Path "$install\Templates\*.*" -Destination "$psDeploymentFolder\Templates" -Recurse
Get-ChildItem -Path "$psDeploymentFolder\Templates\*.*" | Unblock-File

# Copy the provider module files
if ((Test-Path -Path "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn") -eq $false)
{
    $null = New-Item -Path "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn" -ItemType Directory
}

'Microsoft.BDD.PSSnapIn.dll',
'Microsoft.BDD.PSSnapIn.dll.config',
'Microsoft.BDD.PSSnapIn.dll-help.xml',
'Microsoft.BDD.PSSnapIn.Format.ps1xml',
'Microsoft.BDD.PSSnapIn.Types.ps1xml',
'Microsoft.BDD.Core.dll',
'Microsoft.BDD.Core.dll.config',
'Microsoft.BDD.ConfigManager.dll' | ForEach-Object {
    
    Copy-Item -Path "$($mdtDir)Bin\$_" -Destination "$psDeploymentFolder\Tools\Modules\Microsoft.BDD.PSSnapIn"
}

# Copy the provider template files
if ((Test-Path -Path "$psDeploymentFolder\Templates") -eq $false)
{
    $null = New-Item -Path "$psDeploymentFolder\Templates" -ItemType Directory
}

'Groups.xsd',
'Medias.xsd',
'OperatingSystems.xsd',
'Packages.xsd',
'SelectionProfiles.xsd',
'TaskSequences.xsd',
'Applications.xsd',
'Drivers.xsd',
'Groups.xsd' | ForEach-Object {
    
    Copy-Item -Path "$($mdtDir)Templates\$_" -Destination "$psDeploymentFolder\Templates"
}

# Update the ISO properties
Set-ItemProperty -Path PSD: -Name "Boot.x86.LiteTouchISOName" -Value "PSDLiteTouch_x86.iso"
Set-ItemProperty -Path PSD: -Name "Boot.x86.LiteTouchWIMDescription" -Value "PowerShell Deployment Boot Image (x86)"
Set-ItemProperty -Path PSD: -Name "Boot.x64.LiteTouchISOName" -Value "PSDLiteTouch_x64.iso"
Set-ItemProperty -Path PSD: -Name "Boot.x64.LiteTouchWIMDescription" -Value "PowerShell Deployment Boot Image (x64)"