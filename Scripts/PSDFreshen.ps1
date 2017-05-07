# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDFreshen.ps1
# // 
# // Purpose:   Update gathered information in the task sequence environment.
# // 
# // ***************************************************************************

# Load core module
Import-Module PSDUtility
Import-Module PSDGather
$verbosePreference = "Continue"

# Gather local info to make sure key variables are set (e.g. Architecture)
Get-PSDLocalInfo
