# Install-Applications.ps1
# This script serves as a framework for installing multiple applications.
# It executes a list of predefined application installation scripts.

# --- How to Add or Remove Application Installation Scripts ---
# To add a new application installation script:
# 1. Create a new .ps1 file (e.g., Install-NewApp.ps1) containing the installation logic for the new application.
# 2. Add the name of your new script to the $applicationInstallScripts array below.
#
# To remove an application installation script:
# 1. Remove the script name from the $applicationInstallScripts array below.
# 2. Optionally, delete the .ps1 file if it's no longer needed.
# ---

# Define the list of application installation scripts to be executed.
# Ensure these scripts are in the same directory as this main script,
# or provide the full path to each script.
$applicationInstallScripts = @(
    ".\Install-App1.ps1",
    ".\Install-App2.ps1"
    # Add more script paths here, e.g., ".\Install-App3.ps1"
)

Write-Host "Starting application installation process..."

# Loop through the list of application installation scripts and execute each one.
foreach ($scriptPath in $applicationInstallScripts) {
    Write-Host "Attempting to execute script: $scriptPath"
    try {
        # Check if the script file exists before attempting to execute
        if (Test-Path $scriptPath -PathType Leaf) {
            # Execute the script.
            # The '&' call operator is used to invoke the script.
            & $scriptPath -ErrorAction Stop
            Write-Host "Successfully executed script: $scriptPath"
        }
        else {
            Write-Error "Script not found: $scriptPath. Skipping."
        }
    }
    catch {
        # Log an error if the script fails to execute but continue with the next one.
        Write-Error "Error executing script '$scriptPath': $($_.Exception.Message)"
        Write-Warning "Continuing with the next script."
    }
    Write-Host "" # Add a blank line for better readability in logs
}

Write-Host "Application installation process completed."
Write-Host "Please check above for any errors encountered during the installations."
