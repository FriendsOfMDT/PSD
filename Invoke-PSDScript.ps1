<#
.SYNOPSIS
    A generic wrapper script to call other PowerShell scripts within a PSD/MDT environment,
    showcasing parameter passing, error handling, and basic logging.

.DESCRIPTION
    This script executes a target PowerShell script, passing specified parameters to it.
    It's designed to provide a consistent way to call scripts with logging and error capture.
    The caller is responsible for providing all necessary parameters for the TargetScript.

.PARAMETER TargetScriptPath
    The path to the PowerShell script to be executed. This is a mandatory parameter.

.PARAMETER TargetScriptParameters
    A hashtable of parameters to pass to the target script.
    Example: @{ ParameterName1 = "Value1"; ParameterName2 = $TSVariable }
    Default: @{} (empty hashtable)

.PARAMETER LogFile
    Path to a log file where execution details will be appended.
    Default: "C:\Windows\Temp\InvokePSDScript.log"

.EXAMPLE
    .\Invoke-PSDScript.ps1 -TargetScriptPath ".\Set-DesktopWallpaper.ps1" -TargetScriptParameters @{ WallpaperPath = "%DEPLOYROOT%\Branding\MyWallpaper.jpg"; WallpaperStyle = "10" }

.EXAMPLE
    .\Invoke-PSDScript.ps1 -TargetScriptPath ".\Copy-DOTempFolder.ps1" -TargetScriptParameters @{ SourcePath = "%DEPLOYROOT%\MySource"; DestinationPath = "C:\Temp\MyDestination" }

.EXAMPLE
    .\Invoke-PSDScript.ps1 -TargetScriptPath ".\Hide-DOAdmin.ps1" -TargetScriptParameters @{ UserNameToHide = "SomeAdmin" }
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$TargetScriptPath,

    [Parameter(Mandatory=$false)]
    [hashtable]$TargetScriptParameters = @{}, # Default to empty hashtable

    [string]$LogFile = "C:\Windows\Temp\InvokePSDScript.log"
)

# Ensure the log directory exists
$LogDir = Split-Path -Path $LogFile -Parent
if (-not (Test-Path $LogDir)) {
    try {
        New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Warning "Failed to create log directory $LogDir: $($_.Exception.Message)"
        # Continue, will try to log to default temp if C:\Windows\Temp is also problematic.
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] [$($MyInvocation.MyCommand.Name)] $Message"
    Write-Host $logEntry # Also output to console for SMSTS.log visibility
    try {
        Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue # Avoid error if log still fails
    }
    catch {
        # Silently fail log writing if it's problematic after directory check
    }
}

Write-Log -Message "Invoke-PSDScript.ps1 started."
Write-Log -Message "TargetScriptPath: '$TargetScriptPath'"
Write-Log -Message "LogFile: '$LogFile'"

if ($TargetScriptParameters.Count -gt 0) {
    # Avoid logging sensitive data if parameters might contain passwords.
    # For this general script, convert to string for logging. Consider redaction for production use.
    Write-Log -Message "TargetScriptParameters: $($TargetScriptParameters | Out-String | ForEach-Object {$_ -replace '\s+', ' '})"
} else {
    Write-Log -Message "TargetScriptParameters: (None provided)"
}


# Check if the target script exists
if (-not (Test-Path $TargetScriptPath -PathType Leaf)) {
    Write-Log -Message "Target script '$TargetScriptPath' not found. Aborting." -Level "ERROR"
    exit 1
}

try {
    Write-Log -Message "Executing script: & `"$TargetScriptPath`" @TargetScriptParameters"

    # Execute the target script with splatting for parameters
    # If TargetScriptParameters is empty, @TargetScriptParameters effectively passes nothing.
    if ($TargetScriptParameters.Count -gt 0) {
        & $TargetScriptPath @TargetScriptParameters -ErrorAction Stop
    } else {
        & $TargetScriptPath -ErrorAction Stop
    }

    $exitCode = $LASTEXITCODE
    Write-Log -Message "Target script '$TargetScriptPath' executed. Exit code: $exitCode"

    if ($exitCode -ne 0 -and $exitCode -ne 3010) {
        # 3010 is often a success code indicating reboot needed
        Write-Log -Message "Target script exited with a potential error code: $exitCode." -Level "WARN"
    }
    # Pass through the exit code of the target script
    exit $exitCode
}
catch {
    $errorMessage = $_.Exception.Message
    if ($_.Exception.InnerException) {
        $errorMessage += " Inner Exception: " + $_.Exception.InnerException.Message
    }
    Write-Log -Message "Error executing target script '$TargetScriptPath': $errorMessage" -Level "ERROR"
    Write-Log -Message "Script stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1 # Exit with a non-zero code to indicate failure of this wrapper script due to caught error
}

Write-Log -Message "Invoke-PSDScript.ps1 finished (should not be reached if exit called in try/catch)."
