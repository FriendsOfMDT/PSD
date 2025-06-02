# Run-TaskSequence.ps1
# This script orchestrates the execution of a sequence of PowerShell scripts
# designed for system setup and configuration tasks.
#
# It requires Administrator privileges to run, as many of the sub-scripts
# perform actions that need elevation (e.g., registry modification, driver installation).
#
# MDT/PSD Integration Notes:
# - This script can be used as a general sequencer.
# - However, for MDT/PSD, it's often more flexible to call each sub-script
#   as an individual Task Sequence step. This allows MDT/PSD to directly pass
#   Task Sequence variables as parameters to each script (e.g., wallpaper path, source folders).
# - If this orchestrator calls scripts that have mandatory parameters without defaults,
#   those scripts will error out if not provided, and this script will log that error.
#   For example, Set-DesktopWallpaper.ps1 requires -WallpaperPath.

# --- Administrator Privileges Check ---
Write-Host "---------------------------------------------------------------------"
Write-Host "Checking for Administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to run this task sequence. Please re-run this script as Administrator."
    Write-Host "Script will exit in 5 seconds."
    Start-Sleep -Seconds 5
    exit 1
}
Write-Host "Administrator privileges confirmed."
Write-Host "---------------------------------------------------------------------"


# --- Define the sequence of scripts to execute ---
# Ensure these script files are located in the same directory as this main script.
# Some scripts have parameters; if run via this orchestrator without specifying them,
# their internal defaults will be used, or they will error if a mandatory parameter is missing.
$scriptsToExecute = @(
    "Hide-DOAdmin.ps1",             # Parameter: -UserNameToHide (default: DOAdmin)
    "Install-Applications.ps1",     # No specific parameters for this orchestrator to pass; manages its own list.
    "Enable-TipbandVisibility.ps1", # No parameters.
    "Set-ChromeAsDefault.ps1",      # No parameters.
    "Set-DesktopWallpaper.ps1",     # MANDATORY parameter: -WallpaperPath. Will error if not supplied.
                                    # This script expects -WallpaperPath. If not provided, it will fail and be logged.
                                    # For MDT, call this script directly with the path as a parameter.
    "Install-Drivers.ps1",          # Parameter: -DriverSourcePath (default: .\Drivers)
    "Copy-DOTempFolder.ps1"         # Parameters: -SourcePath (default), -DestinationPath (default)
)

# Get the directory where this script is located. Sub-scripts are expected to be here.
$basePath = $PSScriptRoot

Write-Host "Starting Task Sequence..."
Write-Host "Base path for scripts: $basePath"
Write-Host "Review MDT/PSD Integration Notes at the top of this script regarding parameter handling."
Write-Host "---------------------------------------------------------------------"

$totalScripts = $scriptsToExecute.Count
$successCount = 0
$failureCount = 0
$skippedCount = 0

# --- Loop through and execute each script ---
for ($i = 0; $i -lt $totalScripts; $i++) {
    $scriptName = $scriptsToExecute[$i]
    $scriptPath = Join-Path -Path $basePath -ChildPath $scriptName

    Write-Host ""
    Write-Host "($($i+1)/$totalScripts) Processing script: $scriptName"
    Write-Host "---------------------------------------------------------------------"

    if (-not (Test-Path $scriptPath -PathType Leaf)) {
        Write-Error "Script '$scriptName' not found at '$scriptPath'. Skipping."
        $skippedCount++
        $failureCount++ # Counting skipped as a failure for the sequence
        Write-Host "---------------------------------------------------------------------"
        continue
    }

    Write-Host "Starting execution of '$scriptName'..."
    if ($scriptName -eq "Set-DesktopWallpaper.ps1") {
        Write-Warning "Executing '$scriptName'. This script requires the '-WallpaperPath' parameter."
        Write-Warning "If called directly by this orchestrator without a mechanism to provide this parameter,"
        Write-Warning "it will fail and log an error, which is expected in this generic execution context."
        Write-Warning "For proper use, call '$scriptName' as a separate step in MDT with the parameter specified,"
        Write-Warning "or modify this orchestrator to provide the parameter if used standalone."
    }

    try {
        # Execute the script.
        # Using '&' (call operator) to execute the script in the current scope/session.
        # If the called script has mandatory parameters, they must be provided or it will throw an error.
        & $scriptPath -ErrorAction Stop # Ensure terminating errors are caught

        if ($Error.Count -gt 0 -and $Error[0].TargetObject -match $scriptName) {
             Write-Warning "Script '$scriptName' completed, but may have produced non-terminating errors. Review logs from the script itself."
        }

        Write-Host "Successfully completed execution of '$scriptName'."
        $successCount++
    }
    catch {
        Write-Error "An error occurred during the execution of script '$scriptName'."
        Write-Error "Error details: $($_.Exception.Message)"
        # This will catch errors, including missing mandatory parameters from called scripts.
        $failureCount++
    }
    finally {
        Write-Host "Finished processing '$scriptName'."
        Write-Host "---------------------------------------------------------------------"
        $Error.Clear()
    }
}

# --- Task Sequence Summary ---
Write-Host ""
Write-Host "====================================================================="
Write-Host "Task Sequence Completed."
Write-Host "Summary:"
Write-Host " - Total scripts in sequence: $totalScripts"
Write-Host " - Successfully executed: $successCount"
Write-Host " - Failed to execute (or error during execution): $failureCount"
Write-Host " - Skipped (not found): $skippedCount"
Write-Host "====================================================================="

if ($failureCount -gt 0 -or $skippedCount -gt 0) {
    Write-Warning "One or more scripts in the sequence reported errors or were skipped. Please review the logs above."
} else {
    Write-Host "All scripts in the sequence executed successfully."
}
