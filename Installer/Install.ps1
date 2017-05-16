#
# Install.ps1
#

$verbosePreference = "Continue"

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

# Location and share name for the new deployment share
$psDeploymentFolder = "C:\PSDeploymentShare"
$psDeploymentShare = "PSDeploymentShare$"

# Create the folder and share
New-Item -Path $psDeploymentFolder -ItemType directory
New-SmbShare -Name $psDeploymentShare -Path $psDeploymentFolder -FullAccess Administrators

# Find the folder this script is in
$install = Split-Path -Path "$PSScriptRoot"

# Load the MDT PowerShell provider
$mdtDir = $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir
Write-Verbose "MDT installation directory: $mdtDir"
Import-Module "$($mdtDir)Bin\MicrosoftDeploymentToolkit.psd1"

# Create the deployment share at the specified path
$null = New-PSDrive -Name PSD -PSProvider MDTProvider -Root $psDeploymentFolder

# Copy the scripts
Copy-PSDFolder "$install\Scripts\*.ps1" "$psDeploymentFolder\Scripts"
Dir "$psDeploymentFolder\Scripts\*.ps1" | Unblock-File 
Copy-PSDFolder "$install\Scripts\*.xaml" "$psDeploymentFolder\Scripts"
Dir "$psDeploymentFolder\Scripts\*.xaml" | Unblock-File 

# Copy the templates
Copy-PSDFolder "$install\Templates" "$psDeploymentFolder\Templates"
Dir "$psDeploymentFolder\Templates\*" | Unblock-File

# Copy the script modules to the right places
"PSDUtility", "PSDDeploymentShare", "PSDGather", "PSDWizard" | % {
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
Write-Verbose "Copying templates to $psDeploymentFolder\Templates"
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
Set-ItemProperty PSD: -Name "Boot.x86.LiteTouchISOName" -Value "PSDLiteTouch_x86.iso"
Set-ItemProperty PSD: -Name "Boot.x86.LiteTouchWIMDescription" -Value "PowerShell Deployment Boot Image (x86)"
Set-ItemProperty PSD: -Name "Boot.x64.LiteTouchISOName" -Value "PSDLiteTouch_x64.iso"
Set-ItemProperty PSD: -Name "Boot.x64.LiteTouchWIMDescription" -Value "PowerShell Deployment Boot Image (x64)"
