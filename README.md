# PowerShell Deployment & Configuration Task Sequence

## 1. Overview

This suite of PowerShell scripts provides a framework for automating a sequence of common system deployment and configuration tasks. The main script, `Run-TaskSequence.ps1`, orchestrates the execution of individual scripts, each responsible for a specific setup step. This allows for modularity and easier customization of the deployment process.

## 2. Scripts Included

The following PowerShell scripts are part of this collection:

*   **`Run-TaskSequence.ps1`**:
    *   **Purpose:** The main orchestrator script. It runs all other relevant scripts in a predefined order, providing logging and error handling for the sequence.
*   **`Hide-DOAdmin.ps1`**:
    *   **Purpose:** Modifies the registry to hide the 'DOAdmin' user account (or any specified account) from the Windows lock/login screen.
*   **`Install-Applications.ps1`**:
    *   **Purpose:** A framework script for installing multiple applications. It iterates through a list of subordinate application installation scripts.
    *   Includes placeholder scripts: `Install-App1.ps1` and `Install-App2.ps1`. You need to customize these or add new ones for actual application installations.
*   **`Enable-TipbandVisibility.ps1`**:
    *   **Purpose:** Modifies the registry to enable the "Tipband Visibility" feature, which affects how taskbar buttons are grouped by setting `TaskbarGlomLevel` to `1`.
*   **`Set-ChromeAsDefault.ps1`**:
    *   **Purpose:** Attempts to set Google Chrome as the default web browser by modifying registry settings for HTTP and HTTPS protocols.
*   **`Install-Drivers.ps1`**:
    *   **Purpose:** Provides a framework for installing multiple drivers from `.inf` files located in a specified directory (default: `.\Drivers`). It uses `pnputil.exe` for driver installation.
*   **`Copy-DOTempFolder.ps1`**:
    *   **Purpose:** Copies a folder (default: 'DO-Temp') from a specified network deployment server or share to a local path on the target machine.

## 3. Prerequisites

*   **PowerShell:** These scripts are generally compatible with PowerShell 5.1 and later. No highly specific version features are intentionally used.
*   **Administrator Privileges:** The main `Run-TaskSequence.ps1` script **must** be run with Administrator privileges, as many of the sub-scripts perform actions requiring elevation (e.g., registry modifications, driver installations).
*   **Google Chrome:** For `Set-ChromeAsDefault.ps1` to function correctly and set Chrome as the default, Google Chrome must already be installed on the system.
*   **Driver Files:** For `Install-Drivers.ps1`, actual driver packages (containing `.inf` files and associated binaries) must be placed in the directory specified by the `$driverSourcePath` variable within that script (default is a folder named `Drivers` in the same location as the script).
*   **Deployment Server Access:** For `Copy-DOTempFolder.ps1`, the `$sourceFolder` path must be correctly configured to point to an accessible network share and folder. The machine running the script needs appropriate network and permission access.
*   **Application Installers:** For `Install-Applications.ps1`, you must create or provide actual application installation scripts (e.g., for silent installs) and list them correctly in the `$applicationInstallScripts` array within `Install-Applications.ps1`.

## 4. Setup & Configuration

1.  **Placement:** It is recommended to place all `.ps1` script files in the same directory. `Run-TaskSequence.ps1` expects sub-scripts to be in its execution directory (`$PSScriptRoot`).
2.  **Script-Specific Configuration:**
    *   **`Install-Drivers.ps1`:**
        *   Modify the `$driverSourcePath` variable if your driver files are not in a sub-folder named `Drivers`.
        *   Populate this source directory with your driver packages.
    *   **`Copy-DOTempFolder.ps1`:**
        *   Update `$sourceFolder` to the correct UNC path of your network share (e.g., `\\MyServer\Deployments\DO-Temp`).
        *   Update `$destinationPath` if you need the folder copied to a location other than `C:\DO-Temp`.
    *   **`Install-Applications.ps1`:**
        *   Edit the `$applicationInstallScripts` array to include the names of your actual application installation scripts (e.g., `".\Install-Office365.ps1"`, `".\Install-VSCode.ps1"`).
        *   Create these corresponding `.ps1` files with the logic to install each application silently. The provided `Install-App1.ps1` and `Install-App2.ps1` are non-functional placeholders.
    *   **`Hide-DOAdmin.ps1`:**
        *   If you need to hide a user account other than "DOAdmin", modify the `$userNameToHide` variable within the script.

## 5. Execution

1.  **Open PowerShell as Administrator:**
    *   Search for "PowerShell" in the Start Menu.
    *   Right-click on "Windows PowerShell" (or "PowerShell 7").
    *   Select "Run as administrator".
2.  **Navigate to the script directory:**
    *   Use the `cd` command to change to the directory where you've placed all the scripts.
    *   Example: `cd C:\Path\To\Your\Scripts`
3.  **Run the main task sequence script:**
    *   Execute the command: `.\Run-TaskSequence.ps1`

## 6. Logging

*   The main `Run-TaskSequence.ps1` script provides real-time logging to the PowerShell console, indicating which script is currently being executed, and whether it succeeded or failed (based on terminating errors).
*   Individual scripts also contain their own `Write-Host`, `Write-Warning`, or `Write-Error` messages for more detailed feedback on their specific operations.
*   Review the console output carefully for any errors or warnings.

## 7. Customization

*   **Adding/Removing Applications (`Install-Applications.ps1`):**
    1.  Open `Install-Applications.ps1` in a PowerShell editor (like VS Code or PowerShell ISE).
    2.  Modify the `$applicationInstallScripts` array:
        *   To add an application, add the relative path to its installation script (e.g., `".\Install-MyNewApp.ps1"`).
        *   To remove an application, delete its entry from the array.
    3.  Create the actual `.ps1` script file (e.g., `Install-MyNewApp.ps1`) in the same directory. This script should contain the silent installation commands for that specific application.
    4.  The provided `Install-App1.ps1` and `Install-App2.ps1` are placeholders and should be replaced or removed.
*   **Modifying Task Sequence (`Run-TaskSequence.ps1`):**
    *   You can change the order of execution or remove scripts from the sequence by editing the `$scriptsToExecute` array in `Run-TaskSequence.ps1`. However, be mindful of dependencies (e.g., copying files before trying to install from them, though not explicitly the case in the current setup).

## 8. Disclaimer

*   **Test Thoroughly:** These scripts make changes to system configuration, including registry modifications and software installations. Always test this entire task sequence in a non-production environment or on a virtual machine before deploying it to live systems.
*   **Default Browser Settings:** Programmatically changing default application associations (like the default web browser with `Set-ChromeAsDefault.ps1`) has become less reliable on modern Windows versions (Windows 10 and later) due to security measures. While the script attempts a common method, it may not always work as expected, and Windows might still require explicit user confirmation or ignore the programmatic change. For robust enterprise solutions, consider using Microsoft's official methods involving XML-based default association files (e.g., via `Export-DefaultApplicationAssociation` and `Import-DefaultApplicationAssociation` with Group Policy).
*   **Use at Your Own Risk:** The authors or contributors are not responsible for any damage or unintended consequences that may arise from the use of these scripts.
