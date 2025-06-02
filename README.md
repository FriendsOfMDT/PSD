# PowerShell Deployment & Configuration Task Sequence

## 1. Overview

This suite of PowerShell scripts provides a framework for automating a sequence of common system deployment and configuration tasks. The main script, `Run-TaskSequence.ps1`, can orchestrate the execution of individual scripts. However, for integration with deployment solutions like Microsoft Deployment Toolkit (MDT), it is generally recommended to call each script as an individual task sequence step. This allows for more granular control and easier parameter passing using MDT variables.

## 2. Scripts Included

The following PowerShell scripts are part of this collection:

*   **`Run-TaskSequence.ps1`**:
    *   **Purpose:** The main orchestrator script. It can run other scripts in a predefined order. When doing so, sub-scripts will use their internal default parameter values, or fail if a mandatory parameter is missing (e.g., `Set-DesktopWallpaper.ps1`).
*   **`Hide-DOAdmin.ps1`**:
    *   **Purpose:** Modifies the registry to hide a specified user account from the Windows lock/login screen.
    *   **Parameters:** `-UserNameToHide` (Default: "DOAdmin")
*   **`Install-Applications.ps1`**:
    *   **Purpose:** A framework script for installing multiple applications. It iterates through a list of subordinate application installation scripts.
    *   Includes placeholder scripts: `Install-App1.ps1` and `Install-App2.ps1`. You need to customize these or add new ones for actual application installations.
*   **`Enable-TipbandVisibility.ps1`**:
    *   **Purpose:** Modifies the registry to enable the "Tipband Visibility" feature, which affects how taskbar buttons are grouped by setting `TaskbarGlomLevel` to `1`. (No parameters)
*   **`Set-ChromeAsDefault.ps1`**:
    *   **Purpose:** Attempts to set Google Chrome as the default web browser by modifying registry settings for HTTP and HTTPS protocols. (No parameters)
*   **`Set-DesktopWallpaper.ps1`**:
    *   **Purpose:** Sets the desktop wallpaper for the current user and attempts to set it for the Default User profile (affecting new user accounts).
    *   **Parameters:**
        *   `-WallpaperPath` (Mandatory, String): Full path to the wallpaper image file.
        *   `-WallpaperStyle` (Optional, String, Default: "2" - Stretch): Style like '0' (Center), '2' (Stretch), '6' (Fit), '10' (Fill).
        *   `-TileWallpaper` (Optional, String, Default: "0" - No Tile): '0' or '1'.
*   **`Install-Drivers.ps1`**:
    *   **Purpose:** Provides a framework for installing multiple drivers from `.inf` files located in a specified directory. It uses `pnputil.exe` for driver installation.
    *   **Parameters:** `-DriverSourcePath` (Default: ".\Drivers")
*   **`Copy-DOTempFolder.ps1`**:
    *   **Purpose:** Copies a folder from a specified network deployment server or share to a local path on the target machine.
    *   **Parameters:**
        *   `-SourcePath` (Default: "\\DeploymentServer\Share\DO-Temp")
        *   `-DestinationPath` (Default: "C:\DO-Temp")

## 3. Prerequisites

*   **PowerShell:** These scripts are generally compatible with PowerShell 5.1 and later.
*   **Administrator Privileges:** Scripts performing system-wide changes (`Run-TaskSequence.ps1`, `Hide-DOAdmin.ps1`, `Install-Drivers.ps1`, `Set-DesktopWallpaper.ps1`) **must** be run with Administrator privileges.
*   **Google Chrome:** For `Set-ChromeAsDefault.ps1` to function, Google Chrome must be installed.
*   **Driver Files:** For `Install-Drivers.ps1`, driver packages must be in the directory specified by `-DriverSourcePath`.
*   **Deployment Server Access:** For `Copy-DOTempFolder.ps1`, the `-SourcePath` must be accessible.
*   **Application Installers:** For `Install-Applications.ps1`, actual application installation scripts must be created and listed correctly.
*   **Wallpaper Image:** For `Set-DesktopWallpaper.ps1`, a valid image file must be provided via the `-WallpaperPath` parameter.

## 4. Setup & Configuration

1.  **Placement:** All `.ps1` script files should generally be placed in the same directory, especially if using `Run-TaskSequence.ps1` or if scripts call each other using relative paths. For MDT, this would be your script package source directory.
2.  **Script-Specific Configuration (Defaults & Parameters):**
    *   Many scripts now use parameters for key paths or settings. These have default values defined within the scripts.
    *   **`Hide-DOAdmin.ps1`:** `-UserNameToHide` (default: "DOAdmin").
    *   **`Install-Drivers.ps1`:** `-DriverSourcePath` (default: ".\Drivers"). Ensure this path contains your driver INF files and packages.
    *   **`Copy-DOTempFolder.ps1`:** `-SourcePath` (default: "\\DeploymentServer\Share\DO-Temp") and `-DestinationPath` (default: "C:\DO-Temp").
    *   **`Set-DesktopWallpaper.ps1`:** `-WallpaperPath` is mandatory. `-WallpaperStyle` (default: "2") and `-TileWallpaper` (default: "0") can be adjusted.
    *   **`Install-Applications.ps1`:** Edit the `$applicationInstallScripts` array internally to list your custom application installation scripts (e.g., `".\Install-Office365.ps1"`). Create these corresponding `.ps1` files.
    *   These parameters can be supplied on the command line when running scripts individually, or via MDT Task Sequence variables (see MDT Integration Guide).

## 5. Execution

*   **Individual Scripts:** Each script can be run standalone. Remember to provide any mandatory parameters.
    *   Example: `.\Set-DesktopWallpaper.ps1 -WallpaperPath "C:\Path\To\Your\Image.jpg"`
*   **Using `Run-TaskSequence.ps1`:**
    *   This script runs a predefined sequence of the other scripts.
    *   It will use the default parameter values defined within each sub-script.
    *   **Important:** Scripts with mandatory parameters without defaults (like `Set-DesktopWallpaper.ps1 -WallpaperPath`) will fail if `Run-TaskSequence.ps1` calls them without a mechanism to provide these parameters. The orchestrator will log this failure.
    *   To run:
        1.  Open PowerShell as Administrator.
        2.  Navigate to the script directory: `cd C:\Path\To\Your\Scripts`
        3.  Execute: `.\Run-TaskSequence.ps1`

## 6. MDT Integration Guide

While `Run-TaskSequence.ps1` can execute the entire suite, for **Microsoft Deployment Toolkit (MDT)** or **PowerShell Deployment (PSD)**, the recommended best practice is to call each utility script as an individual "Run PowerShell Script" step within your Task Sequence. This approach offers:

*   **Granular Control:** Easier to enable/disable specific tasks.
*   **MDT Logging/Error Handling:** Better visibility of success/failure for each step directly in MDT logs.
*   **Simplified Parameter Passing:** Leverage MDT Task Sequence variables effectively.

**General Principles for MDT:**

*   **Script Package:** Create an MDT Package containing all these PowerShell scripts.
*   **Task Sequence Steps:** For each script you want to run, add a new "Run PowerShell Script" step in your Task Sequence.
    *   Point the step to the script within your package (e.g., `%SCRIPTROOT%\YourScriptName.ps1` if running from `Deploy\Scripts`, or referencing the package path).

**Passing Parameters via MDT Task Sequence Variables:**

You can set MDT Task Sequence variables (e.g., in `CustomSettings.ini`, the MDT database, or via "Set Task Sequence Variable" steps) and then pass these to your scripts.

*   **Example for `Copy-DOTempFolder.ps1`:**
    1.  Define MDT variables (e.g., in `CustomSettings.ini` or as TS steps):
        *   `DOTempSource=\\MyServer\Deployment\Staging\DO-Temp`
        *   `DOTempDest=C:\Windows\Temp\DO-Temp`
    2.  In the "Run PowerShell Script" step for `Copy-DOTempFolder.ps1`, set "Parameters":
        *   `-SourcePath "%DOTempSource%" -DestinationPath "%DOTempDest%"`

*   **Example for `Install-Drivers.ps1`:**
    1.  MDT often uses `%OSDDriverPath%` or you can define your own like `MyDriverPath`.
    2.  Parameters: `-DriverSourcePath "%MyDriverPath%"`

*   **Example for `Set-DesktopWallpaper.ps1`:**
    1.  Define an MDT variable: `OSDWallpaper=\\MyServer\Deployment\Branding\wallpaper.jpg`
    2.  Parameters: `-WallpaperPath "%OSDWallpaper%"`
    3.  Optionally add: `-WallpaperStyle "2" -TileWallpaper "0"` if defaults are not desired.

*   **Example for `Hide-DOAdmin.ps1`:**
    1.  Define an MDT variable: `AccountToHide=LocalAdminAccount`
    2.  Parameters: `-UserNameToHide "%AccountToHide%"`

**Using `Run-TaskSequence.ps1` in MDT:**

*   If you choose to run `Run-TaskSequence.ps1` as a single step in MDT:
    *   It will execute its internal sequence.
    *   Sub-scripts will use their *default* parameter values unless you modify those sub-scripts to directly read MDT environment variables (e.g., using `$env:VariableName`). This is a more advanced customization.
    *   **Warning:** `Set-DesktopWallpaper.ps1` will likely fail when called by `Run-TaskSequence.ps1` in this way, as its mandatory `-WallpaperPath` parameter won't be supplied by the orchestrator itself. It's better to call `Set-DesktopWallpaper.ps1` as its own MDT step.

## 7. Logging

*   The main `Run-TaskSequence.ps1` script provides console logging for its orchestration steps.
*   Individual scripts also contain their own `Write-Host`, `Write-Warning`, or `Write-Error` messages.
*   When run via MDT, script output and errors are typically captured in MDT logs (e.g., `BDD.log`, `SMSTS.log`).

## 8. Customization

*   **Adding/Removing Applications (`Install-Applications.ps1`):**
    *   Edit the `$applicationInstallScripts` array within `Install-Applications.ps1`.
    *   Create the corresponding `.ps1` files for silent application installs.
*   **Modifying Task Sequence (`Run-TaskSequence.ps1`):**
    *   Edit the `$scriptsToExecute` array in `Run-TaskSequence.ps1` to change the sequence or remove scripts. Be mindful of potential dependencies.

## 9. Disclaimer

*   **Test Thoroughly:** These scripts make significant system changes. Always test thoroughly in a non-production environment before deployment.
*   **Default Browser Settings:** Programmatically changing default applications (like the browser via `Set-ChromeAsDefault.ps1`) can be unreliable on modern Windows versions. Consider official methods like XML-based default association files for enterprise scenarios.
*   **Use at Your Own Risk:** The authors/contributors are not responsible for any damage or unintended consequences from using these scripts.## MDT Integration Guide

While `Run-TaskSequence.ps1` can execute the entire suite, for **Microsoft Deployment Toolkit (MDT)** or **PowerShell Deployment (PSD)**, the recommended best practice is to call each utility script as an individual "Run PowerShell Script" step within your Task Sequence. This approach offers:

*   **Granular Control:** Easier to enable/disable specific tasks.
*   **MDT Logging/Error Handling:** Better visibility of success/failure for each step directly in MDT logs.
*   **Simplified Parameter Passing:** Leverage MDT Task Sequence variables effectively.

**General Principles for MDT:**

*   **Script Package:** Create an MDT Package containing all these PowerShell scripts. Your scripts will then be accessible during the Task Sequence, typically via a path relative to the script execution location (e.g., using `.` or `%SCRIPTROOT%` if MDT sets the working directory to `Deploy\Scripts`, or a path relative to the package).
*   **Task Sequence Steps:** For each script you want to run, add a new "Run PowerShell Script" step in your Task Sequence.
    *   In the "PowerShell script:" field, specify the name of the script, e.g., `YourScriptName.ps1`. If your package is not `Deploy\Scripts`, you might need to use `.\%TaskSequenceID%\YourScriptName.ps1` or similar, assuming your package is named after the Task Sequence ID, or directly reference the package path.

**Passing Parameters via MDT Task Sequence Variables:**

You can set MDT Task Sequence variables (e.g., in `CustomSettings.ini`, the MDT database, or via "Set Task Sequence Variable" steps during the Task Sequence) and then pass these to your scripts as parameters.

*   **Example for `Copy-DOTempFolder.ps1`:**
    1.  Define MDT variables (e.g., in `CustomSettings.ini` or as separate "Set Task Sequence Variable" steps):
        *   `DOTempSource=\\MyFileServer\DeploymentShare\Staging\DO-Temp`
        *   `DOTempDest=C:\Windows\Temp\DO-TempFromMDT`
    2.  In the "Run PowerShell Script" step for `Copy-DOTempFolder.ps1`, under the "Parameters" field, specify:
        *   `-SourcePath "%DOTempSource%" -DestinationPath "%DOTempDest%"`

*   **Example for `Install-Drivers.ps1`:**
    1.  MDT automatically populates `%OSDDriverPath%` during the "Inject Drivers" phase if you're using MDT's driver handling. Alternatively, you can define your own variable like `MyModelSpecificDriverPath`.
    2.  Parameters: `-DriverSourcePath "%OSDDriverPath%"` or `-DriverSourcePath "%MyModelSpecificDriverPath%"`

*   **Example for `Set-DesktopWallpaper.ps1`:**
    1.  Define an MDT variable for the wallpaper path (ensure the client can access this path during the TS):
        *   `OSDWallpaperPath=\\MyFileServer\DeploymentShare\Branding\OurCompanyWallpaper.jpg`
    2.  Parameters: `-WallpaperPath "%OSDWallpaperPath%"`
    3.  You can also specify other optional parameters: `-WallpaperStyle "2" -TileWallpaper "0"`

*   **Example for `Hide-DOAdmin.ps1`:**
    1.  Define an MDT variable for the account name:
        *   `AccountToHideFromLogin=ServiceAccount01`
    2.  Parameters: `-UserNameToHide "%AccountToHideFromLogin%"`

**Using `Run-TaskSequence.ps1` in MDT:**

*   If you choose to run `Run-TaskSequence.ps1` as a single step in MDT:
    *   It will execute its internal sequence of scripts.
    *   The sub-scripts will use their *default* parameter values as defined within them.
    *   To pass custom values, you would need to modify `Run-TaskSequence.ps1` or the sub-scripts to directly read MDT environment variables (e.g., using `$env:VariableName` which MDT makes available from Task Sequence variables). This is a more advanced customization not covered by default.
    *   **Warning:** `Set-DesktopWallpaper.ps1`, when called by `Run-TaskSequence.ps1`, will likely fail. This is because `Set-DesktopWallpaper.ps1` has a mandatory `-WallpaperPath` parameter, and `Run-TaskSequence.ps1` itself does not provide a mechanism to pass this specific parameter down to it. It's strongly recommended to call `Set-DesktopWallpaper.ps1` as its own MDT step with the `-WallpaperPath` parameter explicitly provided.

## 7. Logging

*   The main `Run-TaskSequence.ps1` script provides console logging for its orchestration steps when run manually.
*   Individual scripts also contain their own `Write-Host`, `Write-Warning`, or `Write-Error` messages for more detailed feedback.
*   When these scripts are run as steps within an MDT Task Sequence, their output (standard output and error streams) is typically captured in the MDT log files (such as `BDD.log`, and detailed execution in `SMSTS.log` under the `ZTIProcessScript.log` or similar for ZTI PowerShell steps). Review these logs for troubleshooting.

## 8. Customization

*   **Adding/Removing Applications (`Install-Applications.ps1`):**
    1.  Open `Install-Applications.ps1` in a PowerShell editor.
    2.  Modify the `$applicationInstallScripts` array to include the relative paths to your actual application installation scripts (e.g., `".\Install-Office365.ps1"`, `".\Install-VSCode.ps1"`).
    3.  Create these corresponding `.ps1` files in the same directory (your MDT script package). These scripts should contain the silent installation commands for each specific application.
    4.  The provided `Install-App1.ps1` and `Install-App2.ps1` are non-functional placeholders and should be replaced or removed.
*   **Modifying Task Sequence (`Run-TaskSequence.ps1`):**
    *   If using `Run-TaskSequence.ps1` directly, you can change the order of execution or remove scripts from the sequence by editing the `$scriptsToExecute` array. However, be mindful of dependencies. (This is less relevant if following the MDT best practice of individual steps).

## 9. Disclaimer

*   **Test Thoroughly:** These scripts make significant changes to system configuration, including registry modifications and software installations. Always test this entire task sequence and each script in a non-production, isolated lab environment or on a virtual machine before deploying to live systems.
*   **Default Browser Settings:** Programmatically changing default application associations (like the default web browser with `Set-ChromeAsDefault.ps1`) has become less reliable on modern Windows versions (Windows 10 and later) due to security measures designed to protect user choice. While the script attempts a common method, it may not always work as expected. For robust enterprise solutions, consider using Microsoft's official methods involving XML-based default association files (e.g., via `Dism.exe /Online /Export-DefaultAppAssociations:"C:\AppAssoc.xml"` and `Dism.exe /Online /Import-DefaultAppAssociations:"C:\AppAssoc.xml"`).
*   **Use at Your Own Risk:** The authors or contributors are not responsible for any damage or unintended consequences that may arise from the use of these scripts. Ensure you understand what each script does before deploying it.
