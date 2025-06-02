# Enable-TipbandVisibility.ps1
# This script modifies the registry to enable the "Tipband Visibility" feature,
# which can affect how taskbar buttons are grouped or combined.
# Specifically, it sets the TaskbarGlomLevel to 1.

# Define the registry path and value name
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$valueName = "TaskbarGlomLevel"
$valueData = 1 # DWORD value 1 typically means "Combine when taskbar is full"

# Comment: Check if the script is running with Administrator privileges.
# While HKCU modifications for the current user might not always strictly require admin,
# it's good practice for registry modification scripts and essential if run under a different context.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script is not running with Administrator privileges. HKCU modifications for the current user might work, but issues can occur in restricted environments or if targeting other users."
    # For HKCU, we might not want to exit, but rather warn.
    # If strict admin rights are required for a specific scenario, uncomment the next two lines:
    # Write-Error "This script must be run as Administrator for full reliability."
    # exit 1
}

# Comment: Check if the registry path exists.
# The path is split to check for 'Explorer' and then 'Advanced' separately
# to handle cases where intermediate keys might be missing.
$explorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"

if (-not (Test-Path $explorerPath)) {
    Write-Warning "Registry path '$explorerPath' does not exist. This is unusual."
    # Attempting to create the 'Explorer' key if it's missing. This is a fallback.
    try {
        New-Item -Path $explorerPath -Force -ErrorAction Stop | Out-Null
        Write-Host "Registry key '$explorerPath' created successfully."
    }
    catch {
        Write-Error "Error creating registry key '$explorerPath': $($_.Exception.Message)"
        Write-Error "Cannot proceed without the '$explorerPath' key."
        exit 1
    }
}

if (-not (Test-Path $registryPath)) {
    Write-Host "Registry path '$registryPath' does not exist. Creating it..."
    try {
        New-Item -Path $registryPath -Force -ErrorAction Stop | Out-Null
        Write-Host "Registry key '$registryPath' created successfully."
    }
    catch {
        Write-Error "Error creating registry key '$registryPath': $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Host "Registry path '$registryPath' already exists."
}

# Comment: Set the TaskbarGlomLevel DWORD value to 1.
# This will create the value if it doesn't exist or overwrite it if it does.
Write-Host "Setting '$valueName' to '$valueData' at '$registryPath'."
try {
    Set-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -Type DWORD -Force -ErrorAction Stop
    Write-Host "'$valueName' has been successfully set to '$valueData'."
}
catch {
    Write-Error "Error setting registry value '$valueName': $($_.Exception.Message)"
    exit 1
}

Write-Host "Script 'Enable-TipbandVisibility.ps1' completed."
Write-Host "A restart of Explorer.exe or a logoff/logon might be required for changes to take effect."
