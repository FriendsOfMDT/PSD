#
# PSDProvider.psm1
#

$deployRoot = Split-Path -Path $PSScriptRoot

# Set an install directory if necessary (needed so the provider can find templates
if ((Test-Path "HKLM:\Software\Microsoft\Deployment 4") -eq $false)
{
    New-Item "HKLM:\Software\Microsoft\Deployment 4"
    Set-ItemProperty "HKLM:\Software\Microsoft\Deployment 4" -Name "Install_Dir" -Value "$deployRoot\"
    Write-Verbose "Set MDT Install_Dir to $deployRoot\ for MDT Provider."
}

# Load the module
Import-Module "$deployRoot\Tools\Modules\Microsoft.BDD.PSSnapIn"

# Create the PSDrive
New-PSDrive -Name DeploymentShare -PSProvider MDTProvider -Root $deployRoot -Scope Global