<#
.SYNOPSIS
    A wrapper script to demonstrate calling other PowerShell scripts within a PSD/MDT environment,
    showcasing parameter passing, error handling, and basic logging.

.DESCRIPTION
    This script is intended as an example. It calls a target script (by default, 'Set-DesktopWallpaper.ps1')
    and provides a structured way to pass parameters and handle potential errors.

    In a real PSD/MDT task sequence, you would typically call your target scripts directly
    using a "Run PowerShell Script" step, providing parameters as needed. This wrapper
    is more for illustrating scripting best practices.

.PARAMETER TargetScriptPath
    The path to the PowerShell script to be executed.
    Default: ".\Set-DesktopWallpaper.ps1"

.PARAMETER TargetScriptParameters
    A hashtable of parameters to pass to the target script.
    Example: @{ WallpaperPath = "%DEPLOYROOT%\Branding\MyWallpaper.jpg"; WallpaperStyle = "10" }

.PARAMETER LogFile
    Path to a log file where execution details will be appended.
    Default: "C:\Windows\Temp\InvokePSDScript.log"

.EXAMPLE
    .\Invoke-PSDScript.ps1 -TargetScriptPath ".\Set-DesktopWallpaper.ps1" -TargetScriptParameters @{ WallpaperPath = "%DEPLOYROOT%\Branding\DefaultWallpaper.jpg"; WallpaperStyle = "2" }

.EXAMPLE
    # To be called from Run-TaskSequence.ps1 or another orchestrator:
    # Assuming Invoke-PSDScript.ps1 is in the same directory:
    & ".\Invoke-PSDScript.ps1" -TargetScriptPath ".\Copy-DOTempFolder.ps1" -TargetScriptParameters @{ SourcePath = "%DEPLOYROOT%\MySource"; DestinationPath = "C:\Temp\MyDestination" }
#>
param(
    [string]$TargetScriptPath = ".\Set-DesktopWallpaper.ps1",
    [hashtable]$TargetScriptParameters = @{ WallpaperPath = "" }, # Default requires WallpaperPath for Set-DesktopWallpaper
    [string]$LogFile = "C:\Windows\Temp\InvokePSDScript.log"
)

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Write-Host $logEntry # Also output to console for SMSTS.log visibility
    try {
        Add-Content -Path $LogFile -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file $LogFile: $($_.Exception.Message)"
    }
}

Write-Log -Message "Invoke-PSDScript.ps1 started."
Write-Log -Message "Attempting to execute target script: $TargetScriptPath"

# Check if the target script exists
if (-not (Test-Path $TargetScriptPath -PathType Leaf)) {
    Write-Log -Message "Target script '$TargetScriptPath' not found. Aborting." -Level "ERROR"
    exit 1
}

# Special handling for Set-DesktopWallpaper.ps1 default parameter
# If we are using the default TargetScriptPath (Set-DesktopWallpaper.ps1) and WallpaperPath is empty in TargetScriptParameters,
# try to set a default wallpaper path for demonstration.
# In a real scenario, this path should be correctly supplied via parameters.
if ($TargetScriptPath -eq ".\Set-DesktopWallpaper.ps1" -and ([string]::IsNullOrEmpty($TargetScriptParameters.WallpaperPath))) {
    Write-Log -Message "WallpaperPath not provided for Set-DesktopWallpaper.ps1. Using a default demo path." -Level "WARN"
    # Attempt to use a system wallpaper if available, otherwise, this will likely cause Set-DesktopWallpaper.ps1 to fail.
    # A more robust approach would be to ensure a valid image is always available or skip.
    $defaultWallpaper = Join-Path -Path $env:WINDIR -ChildPath "Web\Wallpaper\Windows\img0.jpg"
    if (Test-Path $defaultWallpaper) {
        $TargetScriptParameters.WallpaperPath = $defaultWallpaper
        Write-Log -Message "Using default wallpaper: $defaultWallpaper"
    } else {
        Write-Log -Message "Default system wallpaper (img0.jpg) not found. Set-DesktopWallpaper.ps1 might fail if it requires a valid path." -Level "WARN"
        # Set a placeholder that will likely cause the target script to error out, demonstrating error handling.
        $TargetScriptParameters.WallpaperPath = "C:\NonExistentWallpaper.jpg"
    }
     Write-Log -Message "Updated TargetScriptParameters: $($TargetScriptParameters | Out-String)"
}


Write-Log -Message "Parameters for target script: $($TargetScriptParameters | Out-String)"

try {
    Write-Log -Message "Executing script: & `"$TargetScriptPath`" @TargetScriptParameters"

    # Execute the target script with splatting for parameters
    & $TargetScriptPath @TargetScriptParameters -ErrorAction Stop

    $exitCode = $LASTEXITCODE
    Write-Log -Message "Target script '$TargetScriptPath' executed. Exit code: $exitCode"

    if ($exitCode -ne 0 -and $exitCode -ne 3010) {
        # 3010 is often a success code indicating reboot needed
        Write-Log -Message "Target script exited with a potential error code: $exitCode." -Level "WARN"
        # Depending on requirements, you might want to treat this as a script failure
        # For this demo, we just log it.
    }
}
catch {
    $errorMessage = $_.Exception.Message
    if ($_.Exception.InnerException) {
        $errorMessage += " Inner Exception: " + $_.Exception.InnerException.Message
    }
    Write-Log -Message "Error executing target script '$TargetScriptPath': $errorMessage" -Level "ERROR"
    Write-Log -Message "Script stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    # Exit with a non-zero code to indicate failure of this wrapper script
    exit 1
}

Write-Log -Message "Invoke-PSDScript.ps1 finished."
exit 0 # Ensure this wrapper script exits with 0 if the target script didn't cause a terminating error here.
```
