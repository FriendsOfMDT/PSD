# Copy-DOTempFolder.ps1
# This script copies a specified folder from a source (e.g., deployment server)
# to a specified local path on the machine running the script.
# It is designed for use in MDT/PSD task sequences where parameters can be supplied.
#
# How to Use:
# 1. If running standalone, you can modify the default parameter values below.
# 2. In an MDT Task Sequence, these parameters can be set using Task Sequence variables.
#    For example, in a "Run PowerShell Script" step, you can specify:
#    -Parameters "-SourcePath '%DeployRoot%\MyCustomFolder' -DestinationPath 'C:\Temp\MyCustomFolder'"
#    (Assuming %DeployRoot% is an MDT variable pointing to your deployment share)
# 3. Ensure the user/context running the script has read access to the SourcePath
#    and write access to the parent of DestinationPath.
# 4. Administrator privileges might be required if writing to protected local areas.

param(
    # Define the source path on the deployment server/share.
    [string]$SourcePath = "\\DeploymentServer\Share\DO-Temp",

    # Define the local destination path.
    [string]$DestinationPath = "C:\DO-Temp"
)

# --- Administrator Privileges Check (Recommended) ---
# Writing to C:\ root or Program Files typically requires admin rights.
Write-Host "Checking for Administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Running without Administrator privileges. The script might fail if writing to a protected local path (e.g., C:\ root)."
    # You might choose to enforce admin rights by uncommenting the lines below:
    # Write-Error "Administrator privileges are recommended for this script. Please re-run as Administrator."
    # Start-Sleep -Seconds 3
    # exit 1
} else {
    Write-Host "Administrator privileges confirmed (or not strictly required for the current configuration)."
}


# --- Check if Source Folder Exists and is Accessible ---
Write-Host "Checking if source folder '$SourcePath' exists and is accessible..."
if (-not (Test-Path $SourcePath -PathType Container)) {
    Write-Error "Source folder '$SourcePath' not found or is not accessible."
    Write-Error "Please ensure the path is correct, the server is reachable, and you have permissions."
    # Pause for a few seconds to allow the user to see the message.
    Start-Sleep -Seconds 5
    exit 1
}
Write-Host "Source folder '$SourcePath' found and is accessible."

# --- Perform Copy Operation ---
Write-Host "Attempting to copy folder from '$SourcePath' to '$DestinationPath'..."
try {
    # Copy the item. -Recurse copies contents. -Force overwrites if destination exists.
    Copy-Item -Path $SourcePath -Destination $DestinationPath -Recurse -Force -ErrorAction Stop
    Write-Host "Successfully copied folder from '$SourcePath' to '$DestinationPath'."
}
catch {
    Write-Error "Failed to copy folder from '$SourcePath' to '$DestinationPath'."
    Write-Error "Error details: $($_.Exception.Message)"
    # Pause for a few seconds to allow the user to see the message.
    Start-Sleep -Seconds 5
    exit 1
}

Write-Host "Script 'Copy-DOTempFolder.ps1' completed."
