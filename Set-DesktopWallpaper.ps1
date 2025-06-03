# Set-DesktopWallpaper.ps1
# This script sets the desktop wallpaper for the current user and attempts
# to set it for the Default User profile (affecting new user accounts).
#
# How to Use in an MDT/PSD Task Sequence:
# Add a "Run PowerShell Script" step.
#
# Example 1: Setting a wallpaper from the Deployment Share
#   -Parameters "-WallpaperPath '%DEPLOYROOT%\Branding\CorporateWallpaper.jpg' -WallpaperStyle '10'"
#
# Example 2: Setting a wallpaper that might have been copied locally by a previous step
#   -Parameters "-WallpaperPath 'C:\Windows\Temp\MyWallpaper.png' -WallpaperStyle '2'"
#
# Example 3: Using a Task Sequence variable for the wallpaper path
#   # (Ensure TS variable %CustomWallpaperPath% is set, e.g., by Gather or custom script)
#   -Parameters "-WallpaperPath '%CustomWallpaperPath%' -WallpaperStyle '6'"
#
# PARAMETERS:
#   -WallpaperPath (Mandatory): The full path to the wallpaper image file.
#   -WallpaperStyle (Optional): Defines how the wallpaper is displayed. Default is '2' (Stretch).
#       Common Styles: '0' (Center), '1' (Tile - see TileWallpaper), '2' (Stretch),
#                      '6' (Fit), '10' (Fill)
#   -TileWallpaper (Optional): Defines if the wallpaper should be tiled. Default is '0' (No).
#       Set to '1' if using WallpaperStyle '1' (Tile).

param(
    [Parameter(Mandatory=$true)]
    [string]$WallpaperPath,

    [ValidateSet('0', '1', '2', '6', '10')] # Common styles
    [string]$WallpaperStyle = "2", # Default to Stretch

    [ValidateSet('0', '1')]
    [string]$TileWallpaper = "0" # Default to No Tile
)

# --- Function to Write Log Messages ---
function Write-Log {
    param([string]$Message, [string]$Severity = "INFO")
    Write-Host "[$Severity] $Message" # Output to console for SMSTS.log visibility
}

Write-Log "Starting script: Set-DesktopWallpaper.ps1"
Write-Log "Parameters: WallpaperPath='$WallpaperPath', WallpaperStyle='$WallpaperStyle', TileWallpaper='$TileWallpaper'"

# --- Administrator Privileges Check ---
Write-Log "Checking for Administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log -Message "Administrator privileges are required to run this script, especially for Default User Profile modification. Please re-run this script as an Administrator." -Severity "ERROR"
    Start-Sleep -Seconds 5
    exit 1
}
Write-Log "Administrator privileges confirmed."

# --- Validate Wallpaper Path ---
Write-Log "Validating wallpaper path: '$WallpaperPath'..."
if (-not (Test-Path $WallpaperPath -PathType Leaf)) {
    Write-Log -Message "Wallpaper file '$WallpaperPath' not found. Aborting." -Severity "ERROR"
    exit 1
}
Write-Log "Wallpaper file found: '$WallpaperPath'"

# --- Define Registry Paths and Values ---
$regControlPanelDesktop = "Control Panel\Desktop" # For HKCU
$regValueWallpaper = "Wallpaper"
$regValueWallpaperStyle = "WallpaperStyle"
$regValueTileWallpaper = "TileWallpaper"

# --- Function to Apply Wallpaper Settings to a Registry Hive/Path ---
function Set-WallpaperForRegistryPath {
    param(
        [string]$RegistryPathBase, # e.g., "HKCU:\Control Panel\Desktop" or "HKLM:\TempDefaultUser\Control Panel\Desktop"
        [string]$ContextDescription # e.g., "Current User" or "Default User Profile"
    )

    Write-Log "Attempting to set wallpaper for $ContextDescription at $RegistryPathBase."
    try {
        if (-not (Test-Path $RegistryPathBase)) {
             Write-Log "Registry path $RegistryPathBase does not exist. Creating it..." -Severity "WARN"
             New-Item -Path $RegistryPathBase -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $RegistryPathBase -Name $regValueWallpaper -Value $WallpaperPath -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $RegistryPathBase -Name $regValueWallpaperStyle -Value $WallpaperStyle -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $RegistryPathBase -Name $regValueTileWallpaper -Value $TileWallpaper -Type String -Force -ErrorAction Stop
        Write-Log "Successfully set wallpaper properties for $ContextDescription."
    }
    catch {
        Write-Log -Message "Error setting wallpaper properties for $ContextDescription at $RegistryPathBase. Error: $($_.Exception.Message)" -Severity "ERROR"
    }
}

# --- Apply to Current User (primarily for testing, may not be visible in TS SYSTEM context) ---
# Set-WallpaperForRegistryPath -RegistryPathBase "HKCU:\$regControlPanelDesktop" -ContextDescription "Current User (HKCU)"

# --- Apply to Default User Profile ---
$defaultUserHive = "C:\Users\Default\NTUSER.DAT"
$tempHiveKey = "TempDefaultUser_Wallpaper" # Unique temporary key name for loading hive
$defaultUserDesktopRegPathLoaded = "HKLM:\$tempHiveKey\$regControlPanelDesktop"

Write-Log "Validating Default User hive path: '$defaultUserHive'..."
if (-not (Test-Path $defaultUserHive -PathType Leaf)) {
    Write-Log -Message "Default User profile hive '$defaultUserHive' not found. Cannot apply to Default User. Skipping Default User." -Severity "WARN"
} else {
    Write-Log "Default User hive found. Attempting to load and modify."
    $hiveLoaded = $false
    try {
        # Ensure hive isn't already loaded from a failed previous run
        reg.exe unload "HKLM\$tempHiveKey" >$null 2>&1

        reg.exe load "HKLM\$tempHiveKey" "$defaultUserHive"
        if ($LASTEXITCODE -ne 0) {
            Throw "reg.exe load command failed with exit code $LASTEXITCODE for HKLM\$tempHiveKey and $defaultUserHive."
        }
        $hiveLoaded = $true
        Write-Log "Default User hive loaded successfully into HKLM\$tempHiveKey."

        Set-WallpaperForRegistryPath -RegistryPathBase $defaultUserDesktopRegPathLoaded -ContextDescription "Default User Profile (loaded hive)"
    }
    catch {
        Write-Log -Message "Error during Default User hive operations: $($_.Exception.Message)" -Severity "ERROR"
        if ($_.Exception.Message -like "*reg.exe load*") {
            Write-Log "This often happens if the hive is in use or permissions are insufficient." "WARN"
        }
    }
    finally {
        if ($hiveLoaded) {
            Write-Log "Unloading Default User hive ('HKLM\$tempHiveKey')..."
            [System.GC]::Collect() # Trigger garbage collection to release file locks
            Start-Sleep -Milliseconds 200 # Brief pause
            reg.exe unload "HKLM\$tempHiveKey"
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Default User hive unloaded successfully."
            } else {
                Write-Log -Message "Failed to unload Default User hive (HKLM\$tempHiveKey). Exit code: $LASTEXITCODE. Manual check of 'regedit' might be needed." -Severity "WARN"
            }
        }
    }
}

# --- Refresh Desktop (for current interactive user, if any) ---
# This part may not have a visible effect when run as SYSTEM in a TS.
Write-Log "Attempting to refresh desktop settings for the current session..."
try {
    # This command is typically used to make explorer.exe re-read settings.
    RUNDLL32.EXE USER32.DLL, UpdatePerUserSystemParameters 1, True
    Write-Log "Desktop refresh command sent."
}
catch {
    Write-Log -Message "Exception during desktop refresh: $($_.Exception.Message)" -Severity "WARN"
}

Write-Log "Script Set-DesktopWallpaper.ps1 finished."
exit 0
