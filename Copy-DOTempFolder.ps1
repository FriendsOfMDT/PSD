# Copy-DOTempFolder.ps1
# This script copies a folder named 'DO-Temp' from a deployment server (or any network share)
# to a specified local path on the machine running the script.
#
# How to Use:
# 1. Modify the $sourceFolder variable to point to the correct network path of the 'DO-Temp' folder.
#    Example: $sourceFolder = "\\MyFileServer\DeploymentShare\DO-Temp"
# 2. Modify the $destinationPath variable to the desired local path where the folder should be copied.
#    Example: $destinationPath = "C:\Temp\DO-Temp" or $destinationPath = "$env:TEMP\DO-Temp"
# 3. Ensure the user running the script has read access to the $sourceFolder
#    and write access to the parent of $destinationPath.
# 4. Run this script. Administrator privileges might be required if writing to protected local areas.

# --- Configuration ---
# Define the source path on the deployment server/share.
# !!! IMPORTANT: Update this path to your actual source folder location.
$sourceFolder = "\\DeploymentServer\Share\DO-Temp"

# Define the local destination path.
# !!! IMPORTANT: Update this path if you want to copy it to a different local location.
$destinationPath = "C:\DO-Temp"

# --- Administrator Privileges Check (Recommended) ---
# While not always strictly necessary for all destination paths, it's good practice for deployment scripts.
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
Write-Host "Checking if source folder '$sourceFolder' exists and is accessible..."
if (-not (Test-Path $sourceFolder -PathType Container)) {
    Write-Error "Source folder '$sourceFolder' not found or is not accessible."
    Write-Error "Please ensure the path is correct, the server is reachable, and you have permissions."
    # Pause for a few seconds to allow the user to see the message.
    Start-Sleep -Seconds 5
    exit 1
}
Write-Host "Source folder '$sourceFolder' found and is accessible."

# --- Perform Copy Operation ---
Write-Host "Attempting to copy folder from '$sourceFolder' to '$destinationPath'..."
try {
    # Copy the item. -Recurse copies contents. -Force overwrites if destination exists.
    Copy-Item -Path $sourceFolder -Destination $destinationPath -Recurse -Force -ErrorAction Stop
    Write-Host "Successfully copied folder from '$sourceFolder' to '$destinationPath'."
}
catch {
    Write-Error "Failed to copy folder from '$sourceFolder' to '$destinationPath'."
    Write-Error "Error details: $($_.Exception.Message)"
    # Pause for a few seconds to allow the user to see the message.
    Start-Sleep -Seconds 5
    exit 1
}

Write-Host "Script 'Copy-DOTempFolder.ps1' completed."
