# Copy-DOTempFolder.ps1
# This script copies a specified folder from a source (e.g., deployment server)
# to a specified local path on the machine running the script.
# It is designed for use in MDT/PSD task sequences where parameters can be supplied.
#
# How to Use:
# 1. If running standalone, you can modify the default parameter values below.
# 2. In an MDT/PSD Task Sequence, these parameters can be set using Task Sequence variables.
#    For example, in a "Run PowerShell Script" step:
#
#    Example 1: Copying tools from the deployment share to a temp folder on C:
#    -Parameters "-SourcePath '%DEPLOYROOT%\Applications\MyCustomTools' -DestinationPath 'C:\Temp\MyCustomTools'"
#
#    Example 2: Using %SCRIPTROOT% if the source is within the scripts folder (less common for general files)
#    # (Ensure MySourceFolder is under the directory MDT considers SCRIPTROOT)
#    -Parameters "-SourcePath '%SCRIPTROOT%\MySourceFolder' -DestinationPath 'C:\LocalTemp\MySourceFolder'"
#
#    Example 3: Using a variable for the destination path
#    # (Assuming you've set a TSVariable MyDestination earlier)
#    -Parameters "-SourcePath '%DEPLOYROOT%\StagingArea' -DestinationPath '%MyDestination%\Staging'"
#
# 3. Ensure the user/context running the script has read access to the SourcePath
#    and write access to the parent of DestinationPath.
# 4. Administrator privileges might be required if writing to protected local areas.

param(
    # Define the source path on the deployment server/share or other location.
    # Example TS Variable Usage: "%DEPLOYROOT%\MyFiles"
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,

    # Define the local destination path.
    # Example TS Variable Usage: "C:\Windows\Temp\MyCopiedFiles" or "%SystemDrive%\Temp\MyStuff"
    [Parameter(Mandatory=$true)]
    [string]$DestinationPath
)

# --- Function to Write Log Messages ---
function Write-Log {
    param([string]$Message, [string]$Severity = "INFO")
    Write-Host "[$Severity] $Message" # Output to console for SMSTS.log visibility
}

Write-Log "Starting script: Copy-DOTempFolder.ps1"

# --- Administrator Privileges Check ---
Write-Log "Checking for Administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log -Message "Administrator privileges are required to run this script. Please re-run this script as an Administrator." -Severity "ERROR"
    Start-Sleep -Seconds 5
    exit 1
}
Write-Log "Administrator privileges confirmed."

# --- Validate Parameters ---
Write-Log "Validating parameters..."
Write-Log "SourcePath: $SourcePath"
Write-Log "DestinationPath: $DestinationPath"

if (-not (Test-Path $SourcePath -PathType Container)) {
    Write-Log -Message "SourcePath '$SourcePath' does not exist or is not a folder. Aborting." -Severity "ERROR"
    exit 1
}
Write-Log "SourcePath '$SourcePath' validation successful."

# Check if destination parent exists, if not, create it (basic check)
$DestinationParent = Split-Path -Path $DestinationPath -Parent
if ($DestinationParent -and (-not (Test-Path $DestinationParent -PathType Container))) { # Ensure $DestinationParent is not null (e.g. for C:\Test)
    Write-Log -Message "Destination parent folder '$DestinationParent' does not exist. Attempting to create it." -Severity "WARN"
    try {
        New-Item -Path $DestinationParent -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Log "Successfully created destination parent folder: $DestinationParent"
    }
    catch {
        Write-Log -Message "Failed to create destination parent folder '$DestinationParent'. Error: $($_.Exception.Message). Aborting." -Severity "ERROR"
        exit 1
    }
}

# --- Perform Copy Operation ---
Write-Log "Attempting to copy folder from '$SourcePath' to '$DestinationPath'..."
try {
    # Using Copy-Item with -Recurse to copy folder contents and -Force to overwrite if destination exists.
    # If $DestinationPath itself is a folder that already exists, Copy-Item will copy the *source folder* INTO it.
    # To copy the *contents* of SourcePath into DestinationPath, ensure DestinationPath exists as a directory first.

    if (Test-Path $DestinationPath -PathType Leaf) { # It's a file
        Write-Log -Message "DestinationPath '$DestinationPath' exists and is a file. This script is intended to copy to a folder. Aborting." -Severity "ERROR"
        exit 1
    }
    if (-not (Test-Path $DestinationPath -PathType Container)) { # It doesn't exist as a folder
         Write-Log "DestinationPath '$DestinationPath' does not exist. Creating it as a directory."
         New-Item -Path $DestinationPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    Copy-Item -Path (Join-Path $SourcePath "*") -Destination $DestinationPath -Recurse -Force -ErrorAction Stop
    Write-Log "Folder copy operation completed successfully."
}
catch {
    Write-Log -Message "Error during folder copy operation: $($_.Exception.Message)" -Severity "ERROR"
    exit 1
}

Write-Log "Script Copy-DOTempFolder.ps1 finished successfully."
exit 0
