# Set-DesktopWallpaper.ps1
# This script sets the desktop wallpaper for the current user and attempts
# to set it for the Default User profile (affecting new user accounts).
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

# --- Administrator Privileges Check ---
Write-Host "Checking for Administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required, especially for modifying the Default User profile. Please re-run this script as Administrator."
    Start-Sleep -Seconds 5
    exit 1
}
Write-Host "Administrator privileges confirmed."

# --- Validate Wallpaper Path ---
Write-Host "Validating wallpaper path: '$WallpaperPath'..."
if (-not (Test-Path $WallpaperPath -PathType Leaf)) {
    Write-Error "Wallpaper file '$WallpaperPath' not found or is not a file. Please provide a valid path."
    exit 1
}
# Resolve to absolute path for registry consistency
$AbsoluteWallpaperPath = Resolve-Path -Path $WallpaperPath -ErrorAction Stop
Write-Host "Wallpaper found: '$AbsoluteWallpaperPath'."

# --- Define Registry Settings ---
$regPathCurrentUser = "HKCU:\Control Panel\Desktop"
$regPathDefaultUserHiveLoaded = "HKLM:\DefaultUserHive\Control Panel\Desktop" # Path within the loaded hive
$defaultUserHivePath = "C:\Users\Default\NTUSER.DAT"
$tempHiveName = "DefaultUserHive"

# --- Set Wallpaper for Current User ---
Write-Host "Attempting to set wallpaper for the current user..."
try {
    if (-not (Test-Path $regPathCurrentUser)) {
        New-Item -Path $regPathCurrentUser -Force -ErrorAction Stop | Out-Null
        Write-Host "Created registry path: $regPathCurrentUser"
    }
    Set-ItemProperty -Path $regPathCurrentUser -Name "Wallpaper" -Value $AbsoluteWallpaperPath -Type String -Force -ErrorAction Stop
    Set-ItemProperty -Path $regPathCurrentUser -Name "WallpaperStyle" -Value $WallpaperStyle -Type String -Force -ErrorAction Stop
    Set-ItemProperty -Path $regPathCurrentUser -Name "TileWallpaper" -Value $TileWallpaper -Type String -Force -ErrorAction Stop
    Write-Host "Successfully set wallpaper for the current user."
}
catch {
    Write-Error "Failed to set wallpaper for the current user. Error: $($_.Exception.Message)"
    # Continue to attempt Default User, as this part might be run for a system account where HKCU is less relevant.
}

# --- Attempt to Set Wallpaper for Default User Profile ---
Write-Host "Attempting to set wallpaper for the Default User profile..."
$hiveLoaded = $false
if (-not (Test-Path $defaultUserHivePath -PathType Leaf)) {
    Write-Warning "Default User profile hive '$defaultUserHivePath' not found. Skipping Default User wallpaper configuration."
} else {
    Write-Host "Loading Default User hive from '$defaultUserHivePath' into 'HKLM\$tempHiveName'..."
    try {
        # Ensure hive isn't already loaded from a failed previous run by trying to unload first (ignore error if not loaded)
        reg.exe unload "HKLM\$tempHiveName" # >$null 2>&1

        reg.exe load "HKLM\$tempHiveName" "$defaultUserHivePath"
        if ($LASTEXITCODE -ne 0) {
            Throw "reg.exe load command failed with exit code $LASTEXITCODE."
        }
        $hiveLoaded = $true
        Write-Host "Default User hive loaded successfully."

        Write-Host "Setting wallpaper properties in the loaded Default User hive..."
        if (-not (Test-Path $regPathDefaultUserHiveLoaded)) {
             # The "Control Panel" key should exist, but "Desktop" might not if it's a very clean/new default hive.
            New-Item -Path $regPathDefaultUserHiveLoaded -Force -ErrorAction Stop | Out-Null
            Write-Host "Created registry path: $regPathDefaultUserHiveLoaded"
        }
        Set-ItemProperty -Path $regPathDefaultUserHiveLoaded -Name "Wallpaper" -Value $AbsoluteWallpaperPath -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $regPathDefaultUserHiveLoaded -Name "WallpaperStyle" -Value $WallpaperStyle -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $regPathDefaultUserHiveLoaded -Name "TileWallpaper" -Value $TileWallpaper -Type String -Force -ErrorAction Stop
        Write-Host "Successfully set wallpaper properties in the loaded Default User hive."
    }
    catch {
        Write-Warning "Failed to set wallpaper for the Default User profile. Error: $($_.Exception.Message)"
        if ($_.Exception.Message -like "*reg.exe load*") {
            Write-Warning "This often happens if the hive is in use or permissions are insufficient even for an Administrator."
        }
    }
    finally {
        if ($hiveLoaded) {
            Write-Host "Unloading Default User hive ('HKLM\$tempHiveName')..."
            reg.exe unload "HKLM\$tempHiveName"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Default User hive unloaded successfully."
            } else {
                Write-Warning "Failed to unload Default User hive. Exit code: $LASTEXITCODE. Manual check of 'regedit' under HKLM might be needed to ensure '$tempHiveName' is not present."
            }
        }
    }
}

# --- Apply Changes by Refreshing Desktop for Current User ---
Write-Host "Attempting to refresh desktop settings for the current user..."
try {
    Start-Process -FilePath "RUNDLL32.EXE" -ArgumentList "user32.dll,UpdatePerUserSystemParameters ,1 ,True" -Wait -NoNewWindow
    Write-Host "Desktop refresh command executed. Changes should be visible for the current user shortly."
}
catch {
    Write-Warning "Failed to execute desktop refresh command. Error: $($_.Exception.Message)"
    Write-Warning "A logoff/logon or restart might be required for the current user to see changes."
}

Write-Host "Script 'Set-DesktopWallpaper.ps1' completed."
