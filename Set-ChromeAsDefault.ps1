# Set-ChromeAsDefault.ps1
# This script attempts to set Google Chrome as the default web browser.
#
# Prerequisites:
# - Google Chrome must be installed on the system.
#
# Important Considerations for Modern Windows Versions:
# - Programmatically changing default browser associations in Windows 10 and later
#   has become increasingly restricted to prevent malicious software from hijacking user choices.
# - While this script attempts common registry manipulations, it may not always work reliably
#   on all systems or Windows versions, especially if UAC is active or specific group policies are in place.
# - Newer Windows versions often rely on an XML file for default application associations
#   (Export-DefaultApplicationAssociation / Import-DefaultApplicationAssociation) or require explicit user confirmation
#   via a system prompt. This script does not implement the XML method.

# --- Configuration ---
$chromeProgId = "ChromeHTML" # The Programmatic Identifier for Chrome

# --- Check for Administrator Privileges ---
# Modifying HKCU UserChoice keys can sometimes require elevation or if run by admin for another user.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script is not running with Administrator privileges. It might fail to change default browser settings."
    # Consider exiting if admin is strictly required for your environment:
    # Write-Error "Administrator privileges are required. Please re-run as Administrator."
    # exit 1
}

# --- Check if Chrome is Installed ---
Write-Host "Checking if Google Chrome is installed..."
$chromePathFound = $false
$chromePaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe" # Also check HKCU
)
$actualChromePath = $null

foreach ($path in $chromePaths) {
    if (Test-Path $path) {
        $chromePathFound = $true
        $actualChromePath = Get-ItemProperty -Path $path -Name "(Default)" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "(Default)"
        if ($actualChromePath -and (Test-Path $actualChromePath -PathType Leaf)) {
            Write-Host "Google Chrome found at: $actualChromePath"
            break
        } else {
            Write-Warning "Registry entry found at $path, but the executable path '$actualChromePath' is invalid or not found. Checking next path."
            $chromePathFound = $false # Reset if executable not found
        }
    }
}

if (-not $chromePathFound -or -not $actualChromePath) {
    Write-Error "Google Chrome installation not found or executable path is invalid. Please install Chrome and try again."
    exit 1
}

# --- Attempt to Set Chrome as Default for HTTP and HTTPS ---
Write-Host "Attempting to set Google Chrome as the default browser for HTTP and HTTPS protocols..."

$protocols = @("http", "https")
$associationsPathBase = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations"

foreach ($protocol in $protocols) {
    $urlAssociationPath = Join-Path -Path $associationsPathBase -ChildPath $protocol
    $userChoicePath = Join-Path -Path $urlAssociationPath -ChildPath "UserChoice"

    Write-Host "Processing protocol: $protocol"

    # Ensure the base UrlAssociations key for the protocol exists
    if (-not (Test-Path $urlAssociationPath)) {
        try {
            New-Item -Path $urlAssociationPath -Force -ErrorAction Stop | Out-Null
            Write-Host "Created registry key: $urlAssociationPath"
        }
        catch {
            Write-Error "Failed to create registry key '$urlAssociationPath'. Error: $($_.Exception.Message)"
            Write-Warning "Skipping $protocol protocol."
            continue
        }
    }
    
    # Attempt to set the UserChoice ProgId
    try {
        # Ensure UserChoice key exists or create it
        if (-not (Test-Path $userChoicePath)) {
            New-Item -Path $userChoicePath -Force -ErrorAction Stop | Out-Null
            Write-Host "Created registry key: $userChoicePath"
        }
        
        Set-ItemProperty -Path $userChoicePath -Name "ProgId" -Value $chromeProgId -Type String -Force -ErrorAction Stop
        Write-Host "Successfully set ProgId for $protocol to $chromeProgId."
        
        # Comment: Regarding the 'Hash' value:
        # Windows uses a hash value in UserChoice to verify the user's selection.
        # Programmatically generating a valid hash that Windows accepts is complex and unreliable.
        # Setting the ProgId is often the first step, but without a valid hash,
        # Windows might ignore this setting or prompt the user.
        # Some sources suggest that if a hash from a previous user choice (even for a different browser)
        # exists, Windows *might* re-evaluate. Others suggest removing the Hash value.
        # For simplicity and to avoid breaking things further if a valid hash exists,
        # this script will not attempt to modify or remove an existing Hash.
        if (Get-ItemProperty -Path $userChoicePath -Name "Hash" -ErrorAction SilentlyContinue) {
            Write-Host "A 'Hash' value exists for $protocol. Windows will use this to validate the choice."
        } else {
            Write-Host "No 'Hash' value found for $protocol. Windows may prompt the user or generate a new hash."
        }
    }
    catch {
        Write-Error "Failed to set ProgId for $protocol. Error: $($_.Exception.Message)"
        Write-Warning "The change for $protocol might not have taken effect."
    }
    Write-Host "" # Newline for readability
}

Write-Host "Script 'Set-ChromeAsDefault.ps1' completed."
Write-Host "Please verify if Google Chrome is now the default browser."
Write-Host "Due to Windows restrictions, manual confirmation or further steps (like XML association) might be needed."
