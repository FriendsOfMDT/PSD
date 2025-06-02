# Hide-DOAdmin.ps1
# This script hides a specified user account from the Windows lock screen
# by modifying the registry.
# Designed for use in MDT/PSD, allowing the username to be parameterized.

param(
    # Define the user account to hide
    [string]$UserNameToHide = "DOAdmin"
)

# Define the registry path for SpecialAccounts\UserList
$specialAccountsPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts"
$userListPath = "$specialAccountsPath\UserList"

# Comment: Check if the script is running with Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator to modify HKLM registry keys."
    Start-Sleep -Seconds 3
    exit 1
}

# Comment: Create the SpecialAccounts key if it doesn't exist
if (-not (Test-Path $specialAccountsPath)) {
    try {
        Write-Host "Creating registry key '$specialAccountsPath'..."
        New-Item -Path $specialAccountsPath -Force -ErrorAction Stop | Out-Null
        Write-Host "Registry key '$specialAccountsPath' created successfully."
    }
    catch {
        Write-Error "Error creating registry key '$specialAccountsPath': $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Host "Registry key '$specialAccountsPath' already exists."
}

# Comment: Create the UserList key if it doesn't exist
if (-not (Test-Path $userListPath)) {
    try {
        Write-Host "Creating registry key '$userListPath'..."
        New-Item -Path $userListPath -Force -ErrorAction Stop | Out-Null
        Write-Host "Registry key '$userListPath' created successfully."
    }
    catch {
        Write-Error "Error creating registry key '$userListPath': $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Host "Registry key '$userListPath' already exists."
}

# Comment: Set the DWORD value for the user account to 0 (hide)
Write-Host "Attempting to hide user '$UserNameToHide' from the lock screen..."
try {
    Set-ItemProperty -Path $userListPath -Name $UserNameToHide -Value 0 -Type DWORD -Force -ErrorAction Stop
    Write-Host "User account '$UserNameToHide' hidden successfully from the lock screen."
}
catch {
    Write-Error "Error setting registry value for user '$UserNameToHide': $($_.Exception.Message)"
    # Common issue: Key name contains invalid characters or is too long.
    # Or permissions issue if somehow previous checks passed but this fails.
    exit 1
}

Write-Host "Script 'Hide-DOAdmin.ps1' completed for user '$UserNameToHide'."
