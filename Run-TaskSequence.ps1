# Run-TaskSequence.ps1
# This script orchestrates the execution of a sequence of PowerShell scripts
# using a wrapper script (Invoke-PSDScript.ps1) for enhanced logging and parameter handling.
#
# It requires Administrator privileges to run.
#
# MDT/PSD Integration Notes:
# - This script now calls Invoke-PSDScript.ps1 for each actual task script.
# - Invoke-PSDScript.ps1 handles its own logging.
# - For actual MDT/PSD deployments, calling individual target scripts (or Invoke-PSDScript.ps1 per target)
#   as separate Task Sequence steps is generally recommended. This allows for direct use of
#   Task Sequence Variables (e.g., %DEPLOYROOT%) for parameters. This script serves as an
#   example of how such an orchestrator *could* be structured if needed.

# --- Function to Write Log Messages (for this script's own logging) ---
function Write-OrchestratorLog {
    param([string]$Message, [string]$Severity = "INFO")
    Write-Host "[$Severity] [Run-TaskSequence] $Message"
}

# --- Administrator Privileges Check ---
Write-OrchestratorLog "---------------------------------------------------------------------"
Write-OrchestratorLog "Checking for Administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-OrchestratorLog "Administrator privileges are required. Please re-run this script as Administrator." "ERROR"
    Write-OrchestratorLog "Script will exit in 5 seconds."
    Start-Sleep -Seconds 5
    exit 1
}
Write-OrchestratorLog "Administrator privileges confirmed."
Write-OrchestratorLog "---------------------------------------------------------------------"


# --- Define the sequence of scripts to execute ---
# Each item is a hashtable: @{ Name = "ScriptName.ps1"; Parameters = @{...} }
# Parameters provided here will be passed to Invoke-PSDScript.ps1's -TargetScriptParameters
# For paths, in a real TS, you'd use variables like %DEPLOYROOT%. Here we use relative or example paths.
$scriptsToExecute = @(
    @{ Name = "Hide-DOAdmin.ps1"; Parameters = @{ UserNameToHide = "DOAdmin" } },
    @{ Name = "Copy-DOTempFolder.ps1"; Parameters = @{ SourcePath = ".\Branding"; DestinationPath = "C:\Windows\Temp\Branding_Demo" } }, # Example source
    @{ Name = "Install-Applications.ps1"; Parameters = @{} }, # This script calls others, assumes they are in same dir
    @{ Name = "Enable-TipbandVisibility.ps1"; Parameters = @{} }, # Now targets Default User, no params needed from caller
    @{ Name = "Set-ChromeAsDefault.ps1"; Parameters = @{} }, # Now targets Default User, no params needed from caller
    @{ Name = "Set-DesktopWallpaper.ps1"; Parameters = @{ WallpaperPath = ".\Branding\PSDBackground.bmp"; WallpaperStyle = "2" } }, # MANDATORY WallpaperPath
    @{ Name = "Install-Drivers.ps1"; Parameters = @{ DriverSourcePath = ".\Tools" } } # Example source, real path needed
)

$basePath = $PSScriptRoot
$invokePSDScriptPath = Join-Path -Path $basePath -ChildPath "Invoke-PSDScript.ps1"
$globalLogFile = "C:\Windows\Temp\InvokePSDScript.log" # Central log for all Invoke-PSDScript calls from here

Write-OrchestratorLog "Starting Task Sequence Orchestration..."
Write-OrchestratorLog "Base path for scripts: $basePath"
Write-OrchestratorLog "Wrapper script: $invokePSDScriptPath"
Write-OrchestratorLog "Global log for Invoke-PSDScript calls: $globalLogFile"
Write-OrchestratorLog "---------------------------------------------------------------------"

# Check if Invoke-PSDScript.ps1 exists
if (-not (Test-Path $invokePSDScriptPath -PathType Leaf)) {
    Write-OrchestratorLog "CRITICAL: The wrapper script 'Invoke-PSDScript.ps1' was not found at '$invokePSDScriptPath'." "ERROR"
    Write-OrchestratorLog "This script relies on Invoke-PSDScript.ps1 to execute target scripts." "ERROR"
    Write-OrchestratorLog "Please ensure Invoke-PSDScript.ps1 is in the same directory as Run-TaskSequence.ps1." "ERROR"
    Write-OrchestratorLog "Script will exit in 10 seconds."
    Start-Sleep -Seconds 10
    exit 1 # Critical failure
}

$totalScripts = $scriptsToExecute.Count
$successCount = 0
$failureCount = 0
$skippedCount = 0

# --- Loop through and execute each script using Invoke-PSDScript.ps1 ---
for ($i = 0; $i -lt $totalScripts; $i++) {
    $scriptEntry = $scriptsToExecute[$i]
    $scriptName = $scriptEntry.Name
    $targetScriptParameters = $scriptEntry.Parameters
    $targetScriptFullPath = Join-Path -Path $basePath -ChildPath $scriptName

    Write-OrchestratorLog ""
    Write-OrchestratorLog "($($i+1)/$totalScripts) Preparing to call Invoke-PSDScript.ps1 for target: '$scriptName'"
    Write-OrchestratorLog "Target script path: '$targetScriptFullPath'"
    Write-OrchestratorLog "---------------------------------------------------------------------"

    if (-not (Test-Path $targetScriptFullPath -PathType Leaf)) {
        Write-OrchestratorLog "Target script '$scriptName' not found at '$targetScriptFullPath'. Skipping." "WARN"
        $skippedCount++
        $failureCount++ # Counting skipped as a failure for the sequence
        Write-OrchestratorLog "---------------------------------------------------------------------"
        continue
    }

    $paramsForInvoke = @{
        TargetScriptPath = $targetScriptFullPath
        TargetScriptParameters = $targetScriptParameters # Pass the defined parameters
        LogFile = $globalLogFile # Use the same log file for all invocations from this orchestrator
    }

    Write-OrchestratorLog "Calling Invoke-PSDScript.ps1 for '$scriptName'..."

    try {
        # Using -File with powershell.exe ensures $LASTEXITCODE is from Invoke-PSDScript.ps1
        # This is a more robust way to capture exit codes from external scripts.
        # However, direct invocation & $invokePSDScriptPath @paramsForInvoke is cleaner if LASTEXITCODE behaves as expected.
        # For this revision, revert to direct invocation for simplicity and better error object capture.
        & $invokePSDScriptPath @paramsForInvoke -ErrorAction Stop
        $lastExitCode = $LASTEXITCODE

        if ($lastExitCode -eq 0) {
            Write-OrchestratorLog "Invoke-PSDScript.ps1 successfully executed '$scriptName'."
            $successCount++
        } elseif ($lastExitCode -eq 3010) {
            Write-OrchestratorLog "Invoke-PSDScript.ps1 successfully executed '$scriptName' and requested a reboot (3010)."
            $successCount++
            # Optionally, set a flag here if this orchestrator needs to signal a reboot upwards
        } else {
            Write-OrchestratorLog "Invoke-PSDScript.ps1 reported a non-zero exit code ($lastExitCode) for '$scriptName'. See logs from $globalLogFile for details." "ERROR"
            $failureCount++
        }
    }
    catch {
        Write-OrchestratorLog "A terminating error occurred in Run-TaskSequence.ps1 while attempting to execute '$scriptName' via Invoke-PSDScript.ps1." "ERROR"
        Write-OrchestratorLog "Error details: $($_.Exception.Message)" "ERROR"
        if ($_.Exception.InnerException) {
            Write-OrchestratorLog "Inner Exception: $($_.Exception.InnerException.Message)" "ERROR"
        }
        $failureCount++
    }
    finally {
        Write-OrchestratorLog "Finished processing call to Invoke-PSDScript.ps1 for '$scriptName'."
        Write-OrchestratorLog "---------------------------------------------------------------------"
    }
}

# --- Task Sequence Summary ---
Write-OrchestratorLog ""
Write-OrchestratorLog "====================================================================="
Write-OrchestratorLog "Task Sequence Orchestration Completed."
Write-OrchestratorLog "Summary:"
Write-OrchestratorLog " - Total target scripts in sequence: $totalScripts"
Write-OrchestratorLog " - Successfully orchestrated: $successCount"
Write-OrchestratorLog " - Failed or reported errors: $failureCount"
Write-OrchestratorLog " - Skipped (target script not found): $skippedCount"
Write-OrchestratorLog "====================================================================="

if ($failureCount -gt 0 -or $skippedCount -gt 0) {
    Write-OrchestratorLog "One or more scripts reported errors, failed, or were skipped. Please review this log and '$globalLogFile'." "WARN"
} else {
    Write-OrchestratorLog "All target scripts in the sequence were orchestrated successfully."
}

# Propagate overall status via exit code.
if ($failureCount -gt 0 -or $skippedCount -gt 0) {
    exit 1
} else {
    exit 0
}
