# Run-TaskSequence.ps1
# This script orchestrates the execution of a sequence of PowerShell scripts
# using a wrapper script (Invoke-PSDScript.ps1) for enhanced logging and parameter handling.
#
# It requires Administrator privileges to run.
#
# MDT/PSD Integration Notes:
# - This script now calls Invoke-PSDScript.ps1 for each actual task script.
# - Invoke-PSDScript.ps1 handles parameter passing and its own logging.
# - For MDT/PSD, individual calls to target scripts (or Invoke-PSDScript.ps1 per target)
#   as separate Task Sequence steps can offer more granular control and direct use of TS Variables.

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
# These are the *target* scripts. Invoke-PSDScript.ps1 will be used to call them.
$scriptsToExecute = @(
    "Hide-DOAdmin.ps1",
    "Install-Applications.ps1",
    "Enable-TipbandVisibility.ps1",
    "Set-ChromeAsDefault.ps1",
    "Set-DesktopWallpaper.ps1",
    "Install-Drivers.ps1",
    "Copy-DOTempFolder.ps1"
)

# Get the directory where this script is located. Sub-scripts and Invoke-PSDScript.ps1 are expected to be here.
$basePath = $PSScriptRoot
$invokePSDScriptPath = Join-Path -Path $basePath -ChildPath "Invoke-PSDScript.ps1"

Write-Host "Starting Task Sequence..."
Write-Host "Base path for scripts: $basePath"
Write-Host "Wrapper script: $invokePSDScriptPath"
Write-Host "---------------------------------------------------------------------"

# Check if Invoke-PSDScript.ps1 exists
if (-not (Test-Path $invokePSDScriptPath -PathType Leaf)) {
    Write-Error "CRITICAL: The wrapper script 'Invoke-PSDScript.ps1' was not found at '$invokePSDScriptPath'."
    Write-Error "This script relies on Invoke-PSDScript.ps1 to execute target scripts."
    Write-Error "Please ensure Invoke-PSDScript.ps1 is in the same directory as Run-TaskSequence.ps1."
    Write-Host "Script will exit in 10 seconds."
    Start-Sleep -Seconds 10
    exit 1 # Critical failure
}

$totalScripts = $scriptsToExecute.Count
$successCount = 0
$failureCount = 0
$skippedCount = 0

# --- Loop through and execute each script using Invoke-PSDScript.ps1 ---
for ($i = 0; $i -lt $totalScripts; $i++) {
    $scriptName = $scriptsToExecute[$i]
    $targetScriptFullPath = Join-Path -Path $basePath -ChildPath $scriptName

    Write-Host ""
    Write-Host "($($i+1)/$totalScripts) Preparing to call Invoke-PSDScript.ps1 for target: $scriptName"
    Write-Host "Target script path: $targetScriptFullPath"
    Write-Host "---------------------------------------------------------------------"

    if (-not (Test-Path $targetScriptFullPath -PathType Leaf)) {
        Write-Warning "Target script '$scriptName' not found at '$targetScriptFullPath'. Skipping."
        $skippedCount++
        $failureCount++ # Counting skipped as a failure for the sequence
        Write-Host "---------------------------------------------------------------------"
        continue
    }

    # Default parameters for Invoke-PSDScript.ps1
    $paramsForInvoke = @{
        TargetScriptPath = $targetScriptFullPath
        TargetScriptParameters = @{} # Default to empty hashtable for target script parameters
    }

    # Customize TargetScriptParameters for Invoke-PSDScript.ps1 based on the specific target script
    if ($scriptName -eq "Set-DesktopWallpaper.ps1") {
        Write-Host "For $scriptName: Configuring Invoke-PSDScript.ps1 to use its internal default wallpaper logic."
        # Pass WallpaperPath as empty; Invoke-PSDScript.ps1 has logic to set a default if this is empty.
        $paramsForInvoke.TargetScriptParameters = @{ WallpaperPath = "" }
    }
    elseif ($scriptName -eq "Copy-DOTempFolder.ps1") {
        Write-Host "For $scriptName: No specific parameters passed to Invoke-PSDScript.ps1. Target script will use its defaults."
        # Example of how you *could* pass parameters:
        # $paramsForInvoke.TargetScriptParameters = @{ SourcePath = (Join-Path $basePath "YourSourceSubFolder"); DestinationPath = "C:\Temp\CopiedFiles" }
    }
    elseif ($scriptName -eq "Hide-DOAdmin.ps1") {
        Write-Host "For $scriptName: No specific parameters passed to Invoke-PSDScript.ps1. Target script will use its default UserNameToHide ('DOAdmin')."
        # Example: $paramsForInvoke.TargetScriptParameters = @{ UserNameToHide = "TempAdmin" }
    }
    elseif ($scriptName -eq "Install-Drivers.ps1") {
        Write-Host "For $scriptName: No specific parameters passed to Invoke-PSDScript.ps1. Target script will use its default DriverSourcePath ('.\Drivers')."
        # Example: $paramsForInvoke.TargetScriptParameters = @{ DriverSourcePath = (Join-Path $basePath "AllDrivers") }
    }
    # Scripts like Install-Applications.ps1, Enable-TipbandVisibility.ps1, Set-ChromeAsDefault.ps1
    # currently do not require parameters to be passed via this orchestrator.

    Write-Host "Calling Invoke-PSDScript.ps1 for '$scriptName'..."
    # For debugging, show parameters being sent to Invoke-PSDScript.ps1
    # Write-Host "Invoke-PSDScript parameters: $($paramsForInvoke | Out-String)"

    try {
        & $invokePSDScriptPath @paramsForInvoke -ErrorAction Stop
        $lastExitCode = $LASTEXITCODE # Exit code from Invoke-PSDScript.ps1

        if ($lastExitCode -eq 0) {
            Write-Host "Invoke-PSDScript.ps1 successfully executed '$scriptName'."
            $successCount++
        } else {
            Write-Error "Invoke-PSDScript.ps1 reported a non-zero exit code ($lastExitCode) for '$scriptName'. See logs from Invoke-PSDScript.log for details."
            $failureCount++
        }
    }
    catch {
        Write-Error "A terminating error occurred in Run-TaskSequence.ps1 while attempting to execute '$scriptName' via Invoke-PSDScript.ps1."
        Write-Error "Error details: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-Error "Inner Exception: $($_.Exception.InnerException.Message)"
        }
        Write-Error "ScriptStackTrace: $($_.ScriptStackTrace)"
        $failureCount++
    }
    finally {
        Write-Host "Finished processing call to Invoke-PSDScript.ps1 for '$scriptName'."
        Write-Host "---------------------------------------------------------------------"
        $Error.Clear() # Clear error state for the next iteration
    }
}

# --- Task Sequence Summary ---
Write-Host ""
Write-Host "====================================================================="
Write-Host "Task Sequence Orchestration Completed."
Write-Host "Summary:"
Write-Host " - Total target scripts in sequence: $totalScripts"
Write-Host " - Successfully orchestrated by Invoke-PSDScript.ps1: $successCount"
Write-Host " - Failed or reported errors by Invoke-PSDScript.ps1: $failureCount"
Write-Host " - Skipped (target script not found): $skippedCount"
Write-Host "====================================================================="

if ($failureCount -gt 0 -or $skippedCount -gt 0) {
    Write-Warning "One or more scripts reported errors, failed, or were skipped. Please review the logs above and InvokePSDScript.log."
} else {
    Write-Host "All target scripts in the sequence were orchestrated successfully by Invoke-PSDScript.ps1."
}
