# Install-Drivers.ps1
# This script provides a framework for installing multiple drivers from .inf files
# located in a specified directory.
#
# How to Use:
# 1. Create a directory (e.g., "Drivers" in the same location as this script).
# 2. Place all your driver packages (containing .inf files and associated driver files)
#    into subdirectories within this main "Drivers" directory.
# 3. Run this script as Administrator.

# --- Configuration ---
$driverSourcePath = ".\Drivers" # Relative path to the directory containing driver INF files and their packages.

# --- Administrator Privileges Check ---
Write-Host "Checking for Administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to install drivers. Please re-run this script as Administrator."
    # Pause for a few seconds to allow the user to see the message in a double-click scenario.
    Start-Sleep -Seconds 5
    exit 1
}
Write-Host "Administrator privileges confirmed."

# --- Check if Driver Source Path Exists ---
Write-Host "Checking for driver source directory: $driverSourcePath"
if (-not (Test-Path $driverSourcePath -PathType Container)) {
    Write-Error "Driver source directory '$driverSourcePath' not found."
    Write-Error "Please create this directory and place your driver packages (containing .inf files) into it."
    Write-Error "Script will now exit."
    Start-Sleep -Seconds 5
    exit 1
}
Write-Host "Driver source directory found: $driverSourcePath"

# --- Find and Install Drivers ---
Write-Host "Searching for driver INF files in '$driverSourcePath'..."
$infFiles = Get-ChildItem -Path $driverSourcePath -Filter "*.inf" -Recurse -File

if ($infFiles.Count -eq 0) {
    Write-Warning "No .inf files found in '$driverSourcePath' or its subdirectories."
    Write-Host "Script completed. No drivers to install."
    exit 0
}

Write-Host "Found $($infFiles.Count) .inf file(s). Starting installation process..."
$installedCount = 0
$failedCount = 0

foreach ($infFile in $infFiles) {
    $infFilePath = $infFile.FullName
    Write-Host "" # Newline for readability
    Write-Host "Attempting to install driver from: $infFilePath"

    try {
        # Use pnputil.exe to add and install the driver.
        # The /install flag attempts to install the driver on any matching devices.
        # The /add-driver flag stages the driver in the driver store.
        $pnpArgs = "/add-driver `"$infFilePath`" /install"
        Write-Host "Executing: pnputil.exe $pnpArgs"
        
        # Start-Process can be used, but directly calling and checking $LASTEXITCODE is often simpler for pnputil
        pnputil.exe /add-driver "$infFilePath" /install
        
        # PnPUtil Exit Codes:
        # 0: Success.
        # 3010 (ERROR_SUCCESS_REBOOT_REQUIRED): Success, but a reboot is required.
        # Other non-zero values typically indicate failure.
        # For simplicity, we'll treat 0 and 3010 as success.
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully added and initiated install for driver: $infFilePath"
            $installedCount++
        } elseif ($LASTEXITCODE -eq 3010) {
            Write-Host "Successfully added and initiated install for driver: $infFilePath. A reboot is required for changes to complete."
            $installedCount++
        } else {
            Write-Error "Failed to install driver '$infFilePath'. PnPUtil exit code: $LASTEXITCODE"
            # You might want to log more details from pnputil if possible, but its output redirection can be tricky.
            $failedCount++
        }
    }
    catch {
        # This catch block might catch exceptions from the PowerShell script itself,
        # not necessarily from pnputil.exe if it runs but fails.
        Write-Error "An unexpected error occurred while processing driver '$infFilePath': $($_.Exception.Message)"
        $failedCount++
    }
}

# --- Summary ---
Write-Host ""
Write-Host "--- Driver Installation Summary ---"
Write-Host "Successfully processed $installedCount driver(s)."
Write-Host "Failed to process $failedCount driver(s)."
if ($failedCount -gt 0) {
    Write-Warning "Please review the errors above for any failed driver installations."
}
if ($installedCount -gt 0 -or $failedCount -gt 0) {
     Write-Host "Check the system event logs or Device Manager for more details on driver installation status."
}
Write-Host "Driver installation script completed."
