<#
.SYNOPSIS
    Manages the backup and restoration of PowerShell Deployment (PSD) and Microsoft Deployment Toolkit (MDT) configuration files.

.DESCRIPTION
    This module provides functions to export (backup) and import (restore) critical configuration files 
    such as Bootstrap.ini and CustomSettings.ini from/to an MDT/PSD deployment share.
#>

function Export-PSDConfiguration {
<#
.SYNOPSIS
    Exports PSD/MDT configuration files (Bootstrap.ini, CustomSettings.ini) to a backup location.

.DESCRIPTION
    This function copies Bootstrap.ini and CustomSettings.ini from the Control directory of a 
    deployment share to a specified backup path. It creates a subdirectory named 'PSDConfigBackup'
    within the backup path to store these files.

.PARAMETER Path
    Specifies the directory where the configuration files will be backed up.
    This parameter is mandatory. The backup will be stored in a 'PSDConfigBackup' subdirectory.

.PARAMETER DeploymentShare
    Specifies the root of the MDT/PSD deployment share. 
    If not provided, the script assumes the parent directory of the 'Tools' folder (where this module resides) 
    is the deployment share root.

.EXAMPLE
    Export-PSDConfiguration -Path "C:\Backups\MDT"
    This command backs up Bootstrap.ini and CustomSettings.ini from the deployment share (assuming default location)
    to "C:\Backups\MDT\PSDConfigBackup".

.EXAMPLE
    Export-PSDConfiguration -Path "C:\Backups\MDT" -DeploymentShare "D:\DeploymentShare"
    This command backs up Bootstrap.ini and CustomSettings.ini from "D:\DeploymentShare\Control"
    to "C:\Backups\MDT\PSDConfigBackup".
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$DeploymentShare
    )

    try {
        Write-Verbose "Starting configuration export."

        # Determine DeploymentShare root
        if (-not [string]::IsNullOrWhiteSpace($DeploymentShare)) {
            Write-Verbose "DeploymentShare parameter provided: $DeploymentShare"
        }
        else {
            Write-Verbose "DeploymentShare parameter not provided. Determining default from script location."
            # Assumes the module is in a 'Tools' subdirectory of the deployment share
            $DeploymentShare = Split-Path $PSScriptRoot -Parent
            Write-Verbose "Default DeploymentShare determined as: $DeploymentShare"
        }

        # Validate DeploymentShare
        if (-not (Test-Path -Path $DeploymentShare -PathType Container)) {
            throw "Deployment share '$DeploymentShare' not found or is not a directory."
        }

        # Define Control directory path
        $ControlDir = Join-Path -Path $DeploymentShare -ChildPath "Control"
        Write-Verbose "Control directory path: $ControlDir"

        if (-not (Test-Path -Path $ControlDir -PathType Container)) {
            throw "Control directory '$ControlDir' not found. Please ensure the DeploymentShare structure is correct."
        }

        # Define source files
        $BootstrapIniSource = Join-Path -Path $ControlDir -ChildPath "Bootstrap.ini"
        $CustomSettingsIniSource = Join-Path -Path $ControlDir -ChildPath "CustomSettings.ini"

        # Check if source files exist
        if (-not (Test-Path -Path $BootstrapIniSource -PathType Leaf)) {
            throw "Source file '$BootstrapIniSource' not found."
        }
        if (-not (Test-Path -Path $CustomSettingsIniSource -PathType Leaf)) {
            throw "Source file '$CustomSettingsIniSource' not found."
        }

        # Define backup destination
        $BackupSubDir = "PSDConfigBackup"
        $BackupDestination = Join-Path -Path $Path -ChildPath $BackupSubDir
        
        Write-Verbose "Backup destination directory: $BackupDestination"

        # Create backup directory if it doesn't exist
        if (-not (Test-Path -Path $BackupDestination -PathType Container)) {
            Write-Verbose "Creating backup directory: $BackupDestination"
            try {
                New-Item -Path $BackupDestination -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            catch {
                throw "Failed to create backup directory '$BackupDestination'. Error: $($_.Exception.Message)"
            }
        }

        # Copy Bootstrap.ini
        $BootstrapIniDest = Join-Path -Path $BackupDestination -ChildPath "Bootstrap.ini"
        Write-Verbose "Backing up '$BootstrapIniSource' to '$BootstrapIniDest'..."
        try {
            Copy-Item -Path $BootstrapIniSource -Destination $BootstrapIniDest -Force -ErrorAction Stop
            Write-Verbose "Successfully backed up Bootstrap.ini."
        }
        catch {
            throw "Failed to copy '$BootstrapIniSource' to '$BootstrapIniDest'. Error: $($_.Exception.Message)"
        }

        # Copy CustomSettings.ini
        $CustomSettingsIniDest = Join-Path -Path $BackupDestination -ChildPath "CustomSettings.ini"
        Write-Verbose "Backing up '$CustomSettingsIniSource' to '$CustomSettingsIniDest'..."
        try {
            Copy-Item -Path $CustomSettingsIniSource -Destination $CustomSettingsIniDest -Force -ErrorAction Stop
            Write-Verbose "Successfully backed up CustomSettings.ini."
        }
        catch {
            throw "Failed to copy '$CustomSettingsIniSource' to '$CustomSettingsIniDest'. Error: $($_.Exception.Message)"
        }

        Write-Verbose "Configuration export completed successfully."
    }
    catch {
        Write-Error "Error during Export-PSDConfiguration: $($_.Exception.Message)"
    }
}

function Import-PSDConfiguration {
<#
.SYNOPSIS
    Imports PSD/MDT configuration files (Bootstrap.ini, CustomSettings.ini) from a backup location.

.DESCRIPTION
    This function copies Bootstrap.ini and CustomSettings.ini from a specified backup path 
    (specifically from a 'PSDConfigBackup' subdirectory) to the Control directory of a deployment share.
    It will overwrite existing files in the Control directory.

.PARAMETER Path
    Specifies the directory from where the configuration files will be restored.
    This path should contain the 'PSDConfigBackup' subdirectory created by Export-PSDConfiguration.
    This parameter is mandatory.

.PARAMETER DeploymentShare
    Specifies the root of the MDT/PSD deployment share where files will be restored. 
    If not provided, the script assumes the parent directory of the 'Tools' folder (where this module resides) 
    is the deployment share root.

.EXAMPLE
    Import-PSDConfiguration -Path "C:\Backups\MDT"
    This command restores Bootstrap.ini and CustomSettings.ini from "C:\Backups\MDT\PSDConfigBackup"
    to the Control directory of the deployment share (assuming default location).

.EXAMPLE
    Import-PSDConfiguration -Path "C:\Backups\MDT" -DeploymentShare "D:\DeploymentShare"
    This command restores Bootstrap.ini and CustomSettings.ini from "C:\Backups\MDT\PSDConfigBackup"
    to "D:\DeploymentShare\Control".
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$DeploymentShare
    )

    try {
        Write-Verbose "Starting configuration import."

        # Define backup source directory
        $BackupSubDir = "PSDConfigBackup"
        $BackupSourcePath = Join-Path -Path $Path -ChildPath $BackupSubDir
        Write-Verbose "Backup source directory: $BackupSourcePath"

        if (-not (Test-Path -Path $BackupSourcePath -PathType Container)) {
            throw "Backup source directory '$BackupSourcePath' not found. Please ensure the path is correct and contains 'PSDConfigBackup' subdirectory."
        }

        # Define source files from backup
        $BootstrapIniSource = Join-Path -Path $BackupSourcePath -ChildPath "Bootstrap.ini"
        $CustomSettingsIniSource = Join-Path -Path $BackupSourcePath -ChildPath "CustomSettings.ini"

        # Check if source files exist in backup
        if (-not (Test-Path -Path $BootstrapIniSource -PathType Leaf)) {
            throw "Source file '$BootstrapIniSource' not found in backup location."
        }
        if (-not (Test-Path -Path $CustomSettingsIniSource -PathType Leaf)) {
            throw "Source file '$CustomSettingsIniSource' not found in backup location."
        }

        # Determine DeploymentShare root
        if (-not [string]::IsNullOrWhiteSpace($DeploymentShare)) {
            Write-Verbose "DeploymentShare parameter provided: $DeploymentShare"
        }
        else {
            Write-Verbose "DeploymentShare parameter not provided. Determining default from script location."
            $DeploymentShare = Split-Path $PSScriptRoot -Parent
            Write-Verbose "Default DeploymentShare determined as: $DeploymentShare"
        }

        # Validate DeploymentShare
        if (-not (Test-Path -Path $DeploymentShare -PathType Container)) {
            throw "Deployment share '$DeploymentShare' not found or is not a directory."
        }

        # Define Control directory path (destination for restore)
        $ControlDir = Join-Path -Path $DeploymentShare -ChildPath "Control"
        Write-Verbose "Control directory path (destination): $ControlDir"

        if (-not (Test-Path -Path $ControlDir -PathType Container)) {
            # Attempt to create the Control directory if it doesn't exist? Or error out?
            # For a restore operation, the Control directory should ideally exist.
            throw "Control directory '$ControlDir' not found. Cannot restore files to a non-existent Control directory."
        }
        
        # Restore Bootstrap.ini
        $BootstrapIniDest = Join-Path -Path $ControlDir -ChildPath "Bootstrap.ini"
        Write-Verbose "Restoring '$BootstrapIniSource' to '$BootstrapIniDest'..."
        try {
            Copy-Item -Path $BootstrapIniSource -Destination $BootstrapIniDest -Force -ErrorAction Stop
            Write-Verbose "Successfully restored Bootstrap.ini."
        }
        catch {
            throw "Failed to copy '$BootstrapIniSource' to '$BootstrapIniDest'. Error: $($_.Exception.Message)"
        }

        # Restore CustomSettings.ini
        $CustomSettingsIniDest = Join-Path -Path $ControlDir -ChildPath "CustomSettings.ini"
        Write-Verbose "Restoring '$CustomSettingsIniSource' to '$CustomSettingsIniDest'..."
        try {
            Copy-Item -Path $CustomSettingsIniSource -Destination $CustomSettingsIniDest -Force -ErrorAction Stop
            Write-Verbose "Successfully restored CustomSettings.ini."
        }
        catch {
            throw "Failed to copy '$CustomSettingsIniSource' to '$CustomSettingsIniDest'. Error: $($_.Exception.Message)"
        }

        Write-Verbose "Configuration import completed successfully."
    }
    catch {
        Write-Error "Error during Import-PSDConfiguration: $($_.Exception.Message)"
    }
}

# Export module members
Export-ModuleMember -Function Export-PSDConfiguration
Export-ModuleMember -Function Import-PSDConfiguration
