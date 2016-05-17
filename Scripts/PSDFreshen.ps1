#
# PSDFreshen.ps1
#

# Load core module
$deployRoot = Split-Path -Path "$PSScriptRoot"
Write-Verbose "Using deploy root $deployRoot, based on $PSScriptRoot"
Import-Module "$deployRoot\Scripts\PSDUtility.psm1" -Force
Import-Module "$deployRoot\Scripts\PSDGather.psm1" -Force
$verbosePreference = "Continue"

# Gather local info to make sure key variables are set (e.g. Architecture)
Get-PSDLocalInfo
