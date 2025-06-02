# Hide-DOAdmin.ps1
# This script hides the DOAdmin user account from the Windows lock screen.

# Define the registry path for SpecialAccounts\UserList
$specialAccountsPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts"
$userListPath = "$specialAccountsPath\UserList"

# Define the user account to hide
$userNameToHide = "DOAdmin"

# Comment: Check if the script is running with Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

# Comment: Create the SpecialAccounts key if it doesn't exist
if (-not (Test-Path $specialAccountsPath)) {
    try {
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
try {
    Set-ItemProperty -Path $userListPath -Name $userNameToHide -Value 0 -Type DWORD -Force -ErrorAction Stop
    Write-Host "User account '$userNameToHide' hidden successfully from the lock screen."
}
catch {
    Write-Error "Error setting registry value for user '$userNameToHide': $($_.Exception.Message)"
    exit 1
}

Write-Host "Script completed."
