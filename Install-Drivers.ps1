# Install-Drivers.ps1
# This script provides a framework for installing multiple drivers from .inf files
# located in a specified directory.
# It is designed for use in MDT/PSD task sequences where the driver source path can be supplied.
#
# How to Use:
# 1. If running standalone, ensure driver packages are in the default path (.\Drivers)
#    or provide the -DriverSourcePath parameter.
# 2. In an MDT Task Sequence, the DriverSourcePath can be set using a Task Sequence variable
#    or by passing it as a parameter. For example:
#    -Parameters "-DriverSourcePath '%DeployRoot%\Out-of-Box Drivers\MyModel'"
#    MDT also often sets the %OSDDriverPath% variable, which could be used.
# 3. Place all your driver packages (containing .inf files and associated driver files)
#    into subdirectories within the specified DriverSourcePath.
# 4. Run this script as Administrator.

param(
    # Relative or absolute path to the directory containing driver INF files and their packages.
    [string]$DriverSourcePath = ".\Drivers"
)

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
# Resolve the path in case a relative path like ".\Drivers" is used.
$ResolvedDriverSourcePath = Resolve-Path -Path $DriverSourcePath -ErrorAction SilentlyContinue
if (-not $ResolvedDriverSourcePath) {
    Write-Warning "Could not resolve DriverSourcePath: '$DriverSourcePath'. This might be an issue if it's not a standard path."
    # Attempt to use the path as given if Resolve-Path fails (e.g. if it's on a PSDrive not yet mapped)
    $ResolvedDriverSourcePath = $DriverSourcePath
}


Write-Host "Checking for driver source directory: $ResolvedDriverSourcePath"
if (-not (Test-Path $ResolvedDriverSourcePath -PathType Container)) {
    Write-Error "Driver source directory '$ResolvedDriverSourcePath' not found."
    Write-Error "Please create this directory and place your driver packages (containing .inf files) into it, or provide the correct -DriverSourcePath parameter."
    Write-Error "Script will now exit."
    Start-Sleep -Seconds 5
    exit 1
}
Write-Host "Driver source directory found: $ResolvedDriverSourcePath"

# --- Find and Install Drivers ---
Write-Host "Searching for driver INF files in '$ResolvedDriverSourcePath'..."
$infFiles = Get-ChildItem -Path $ResolvedDriverSourcePath -Filter "*.inf" -Recurse -File

if ($infFiles.Count -eq 0) {
    Write-Warning "No .inf files found in '$ResolvedDriverSourcePath' or its subdirectories."
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

        pnputil.exe /add-driver "$infFilePath" /install

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully added and initiated install for driver: $infFilePath"
            $installedCount++
        } elseif ($LASTEXITCODE -eq 3010) {
            Write-Host "Successfully added and initiated install for driver: $infFilePath. A reboot is required for changes to complete."
            $installedCount++
        } else {
            Write-Error "Failed to install driver '$infFilePath'. PnPUtil exit code: $LASTEXITCODE"
            $failedCount++
        }
    }
    catch {
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
