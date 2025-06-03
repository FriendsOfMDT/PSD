# Hide-DOAdmin.ps1
# This script hides a specified user account from the Windows lock screen
# by modifying the registry.
# Designed for use in MDT/PSD, allowing the username to be parameterized.
#
# How to Use in an MDT/PSD Task Sequence:
# Add a "Run PowerShell Script" step.
#
# Example 1: Hiding the default "DOAdmin" account
#   -Parameters ""
#   (No parameters needed if hiding "DOAdmin", as it's the default)
#
# Example 2: Hiding a specific account, e.g., "LocalAdmin"
#   -Parameters "-UserNameToHide 'LocalAdmin'"
#
# Example 3: Hiding an account name stored in a Task Sequence variable
#   # (Ensure TS variable %CustomAdminAccount% is set prior to this step)
#   -Parameters "-UserNameToHide '%CustomAdminAccount%'"
#
# Example 4: Using %OSDComputerName% to create a unique admin name to hide (less common to hide directly)
#   # (If you had created an admin account like "Admin-%OSDComputerName%")
#   -Parameters "-UserNameToHide 'Admin-%OSDComputerName%'"

param(
    # Define the user account to hide
    [string]$UserNameToHide = "DOAdmin"
)

# --- Function to Write Log Messages ---
function Write-Log {
    param([string]$Message, [string]$Severity = "INFO")
    Write-Host "[$Severity] $Message" # Output to console for SMSTS.log visibility
}

Write-Log "Starting script: Hide-DOAdmin.ps1"
Write-Log "Attempting to hide user: $UserNameToHide"

# --- Administrator Privileges Check ---
Write-Log "Checking for Administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log -Message "Administrator privileges are required to run this script. Please re-run this script as an Administrator." -Severity "ERROR"
    Start-Sleep -Seconds 5
    exit 1
}
Write-Log "Administrator privileges confirmed."

# --- Define Registry Path ---
$specialAccountsPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts"
$userListPath = Join-Path -Path $specialAccountsPath -ChildPath "UserList"

# --- Ensure Registry Paths Exist ---
Write-Log "Ensuring registry paths exist..."
try {
    if (-not (Test-Path $specialAccountsPath)) {
        Write-Log "Creating registry key: $specialAccountsPath"
        New-Item -Path $specialAccountsPath -Force -ErrorAction Stop | Out-Null
    }
    if (-not (Test-Path $userListPath)) {
        Write-Log "Creating registry key: $userListPath"
        New-Item -Path $userListPath -Force -ErrorAction Stop | Out-Null
    }
    Write-Log "Registry paths ensured."
}
catch {
    Write-Log -Message "Error creating necessary registry paths: $($_.Exception.Message)" -Severity "ERROR"
    exit 1
}

# --- Hide User Account ---
Write-Log "Setting registry value to hide '$UserNameToHide'..."
try {
    Set-ItemProperty -Path $userListPath -Name $UserNameToHide -Value 0 -Type DWORD -Force -ErrorAction Stop
    Write-Log "User '$UserNameToHide' has been successfully hidden from the login screen."
}
catch {
    Write-Log -Message "Error setting registry value to hide user '$UserNameToHide': $($_.Exception.Message)" -Severity "ERROR"
    exit 1
}

Write-Log "Script Hide-DOAdmin.ps1 finished successfully."
exit 0
