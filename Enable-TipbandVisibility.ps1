# Enable-TipbandVisibility.ps1
# This script modifies the registry to enable the "Tipband Visibility" feature
# for the Default User Profile, affecting all new users.
# Specifically, it sets TaskbarGlomLevel to 1.

# Define the registry path components and value
$regSubPath = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$valueName = "TaskbarGlomLevel"
$valueData = 1 # DWORD value 1 typically means "Combine when taskbar is full"

$defaultUserHivePath = "C:\Users\Default\NTUSER.DAT"
$tempHiveKeyName = "TempDefaultUser_Tipband" # Unique temporary key name
$regPathDefaultUserHiveLoaded = "HKLM:\$tempHiveKeyName\$regSubPath"

# Function to write messages to host (visible in TS logs)
function Write-Log {
    param([string]$Message, [string]$Severity = "INFO")
    Write-Host "[$Severity] $Message"
}

Write-Log "Starting Enable-TipbandVisibility.ps1 for Default User Profile."

# --- Administrator Privileges Check ---
Write-Log "Checking for Administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Administrator privileges are required to modify the Default User profile. Aborting." "ERROR"
    Start-Sleep -Seconds 5
    exit 1
}
Write-Log "Administrator privileges confirmed."

# --- Validate Default User Hive Path ---
Write-Log "Validating Default User hive path: '$defaultUserHivePath'..."
if (-not (Test-Path $defaultUserHivePath -PathType Leaf)) {
    Write-Log "Default User profile hive '$defaultUserHivePath' not found. Cannot apply settings. Aborting." "ERROR"
    exit 1
}
Write-Log "Default User hive found."

# --- Load Default User Hive, Modify, and Unload ---
$hiveLoaded = $false
Write-Log "Attempting to load Default User hive from '$defaultUserHivePath' into 'HKLM\$tempHiveKeyName'..."
try {
    # Ensure hive isn't already loaded from a failed previous run
    # Suppress errors for unload if the key doesn't exist
    reg.exe unload "HKLM\$tempHiveKeyName" >$null 2>&1

    reg.exe load "HKLM\$tempHiveKeyName" "$defaultUserHivePath"
    if ($LASTEXITCODE -ne 0) {
        Throw "reg.exe load command failed with exit code $LASTEXITCODE for HKLM\$tempHiveKeyName and $defaultUserHivePath."
    }
    $hiveLoaded = $true
    Write-Log "Default User hive loaded successfully into HKLM\$tempHiveKeyName."

    # Check if the target registry path exists within the loaded hive, create if not
    if (-not (Test-Path $regPathDefaultUserHiveLoaded)) {
        Write-Log "Registry path '$regPathDefaultUserHiveLoaded' does not exist. Creating it..."
        New-Item -Path $regPathDefaultUserHiveLoaded -Force -ErrorAction Stop | Out-Null
        Write-Log "Registry path '$regPathDefaultUserHiveLoaded' created successfully."
    } else {
        Write-Log "Registry path '$regPathDefaultUserHiveLoaded' already exists."
    }

    # Set the TaskbarGlomLevel DWORD value
    Write-Log "Setting '$valueName' to '$valueData' at '$regPathDefaultUserHiveLoaded'."
    Set-ItemProperty -Path $regPathDefaultUserHiveLoaded -Name $valueName -Value $valueData -Type DWORD -Force -ErrorAction Stop
    Write-Log "'$valueName' has been successfully set to '$valueData' in the loaded Default User hive."

}
catch {
    Write-Log "Error during Default User hive operations: $($_.Exception.Message)" "ERROR"
    if ($_.Exception.Message -like "*reg.exe load*") {
        Write-Log "This often happens if the hive is in use or permissions are insufficient even for an Administrator." "WARN"
    }
    # We still want to try to unload the hive in the finally block
}
finally {
    if ($hiveLoaded) {
        Write-Log "Unloading Default User hive ('HKLM\$tempHiveKeyName')..."
        # Flush changes before unloading
        [GC]::Collect()
        Start-Sleep -Milliseconds 200 # Brief pause to help ensure flush completes
        reg.exe unload "HKLM\$tempHiveKeyName"
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Default User hive unloaded successfully."
        } else {
            Write-Log "Failed to unload Default User hive (HKLM\$tempHiveKeyName). Exit code: $LASTEXITCODE. Manual check of 'regedit' might be needed." "WARN"
        }
    }
}

Write-Log "Script 'Enable-TipbandVisibility.ps1' for Default User Profile completed."
Write-Log "Changes will apply to new user accounts created on this system."
# Note: No immediate effect on current users or existing profiles other than Default.
