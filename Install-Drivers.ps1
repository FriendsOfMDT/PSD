# Install-Drivers.ps1
# This script provides a framework for installing multiple drivers from .inf files
# located in a specified directory.
# It is designed for use in MDT/PSD task sequences where the driver source path can be supplied.
#
# How to Use in an MDT/PSD Task Sequence:
# Add a "Run PowerShell Script" step.
#
# Example 1: Using a specific folder in the Deployment Share
#   -Parameters "-DriverSourcePath '%DEPLOYROOT%\Out-of-Box Drivers\MyModelSpecificDrivers'"
#
# Example 2: Using the path determined by MDT's "Inject Drivers" logic (if %OSDDriverPath% is set)
#   # (This assumes a prior "Inject Drivers" step has set %OSDDriverPath% appropriately
#   # or you have custom logic to set this variable for the current model)
#   -Parameters "-DriverSourcePath '%OSDDriverPath%'"
#
# Example 3: Using a path relative to where scripts are run from (e.g. %SCRIPTROOT%)
#   # (If drivers are packaged with scripts - less common for full driver packages)
#   -Parameters "-DriverSourcePath '%SCRIPTROOT%\Drivers\MyModel'"
#
# Example 4: Using a locally copied driver store
#   # (If a previous step copied drivers to C:\OEMDrivers)
#   -Parameters "-DriverSourcePath 'C:\OEMDrivers\MyModel'"
#
# Place all your driver packages (containing .inf files and associated driver files)
# into subdirectories within the specified DriverSourcePath.
# Run this script as Administrator (typically handled by the Task Sequence).

param(
    # Relative or absolute path to the directory containing driver INF files and their packages.
    [string]$DriverSourcePath = ".\Drivers" # Default can be overridden by explicit parameter.
)

# --- Function to Write Log Messages ---
function Write-Log {
    param([string]$Message, [string]$Severity = "INFO")
    Write-Host "[$Severity] $Message" # Output to console for SMSTS.log visibility
}

Write-Log "Starting script: Install-Drivers.ps1"
Write-Log "DriverSourcePath: $DriverSourcePath"

# --- Administrator Privileges Check ---
Write-Log "Checking for Administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log -Message "Administrator privileges are required to run this script. Please re-run this script as an Administrator." -Severity "ERROR"
    Start-Sleep -Seconds 5
    exit 1
}
Write-Log "Administrator privileges confirmed."

# --- Validate Driver Source Path ---
Write-Log "Validating DriverSourcePath..."
if (-not (Test-Path $DriverSourcePath -PathType Container)) {
    Write-Log -Message "DriverSourcePath '$DriverSourcePath' does not exist or is not a folder. Aborting." -Severity "ERROR"
    exit 1
}
Write-Log "DriverSourcePath '$DriverSourcePath' found."

# --- Install Drivers ---
Write-Log "Searching for .inf files in '$DriverSourcePath' and its subdirectories..."
$infFiles = Get-ChildItem -Path $DriverSourcePath -Recurse -Filter "*.inf"

if ($infFiles.Count -eq 0) {
    Write-Log -Message "No .inf files found in '$DriverSourcePath'. Nothing to install." -Severity "WARN"
    exit 0
}

Write-Log "Found $($infFiles.Count) .inf files. Attempting installation using PnPUtil..."
$overallSuccess = $true
$rebootRequired = $false

foreach ($infFile in $infFiles) {
    Write-Log "Processing driver package: $($infFile.FullName)"
    try {
        # Using pnputil.exe to add and install the driver.
        # /add-driver adds the driver package to the driver store.
        # /install installs the driver on any matching devices.
        # Note: pnputil messages are directly output to console (and thus SMSTS.log)
        pnputil.exe /add-driver "$($infFile.FullName)" /install
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Log "Successfully processed and potentially installed driver package: $($infFile.Name)."
        } elseif ($exitCode -eq 3010) {
            Write-Log "Driver package $($infFile.Name) processed. A REBOOT IS REQUIRED to complete the installation." -Severity "WARN"
            $rebootRequired = $true
        } else {
            Write-Log "PnPUtil reported an error (Exit Code: $exitCode) for driver package: $($infFile.Name). This might indicate a non-critical issue or an unsupported driver." -Severity "WARN"
            # Depending on strictness, you might set $overallSuccess = $false here.
            # For now, we log as warning and continue. Some drivers might be incompatible but not break the sequence.
        }
    }
    catch {
        Write-Log -Message "An exception occurred while processing driver package '$($infFile.Name)': $($_.Exception.Message)" -Severity "ERROR"
        $overallSuccess = $false
    }
}

Write-Log "Driver installation process completed."

if (-not $overallSuccess) {
    Write-Log -Message "One or more errors occurred during driver installation. Review logs above." -Severity "ERROR"
    # Consider exiting with an error code if strict success is required.
    # exit 1
}

if ($rebootRequired) {
    Write-Log "A reboot is required for one or more drivers. Ensure the task sequence handles this." -Severity "IMPORTANT"
    # MDT typically handles exit code 3010 from a step to initiate a reboot.
    # If this script is the last one making such a request, ensure it exits with 3010.
    Write-Log "Script Install-Drivers.ps1 finished. Exiting with code 3010 for reboot."
    exit 3010
}

Write-Log "Script Install-Drivers.ps1 finished successfully."
exit 0
