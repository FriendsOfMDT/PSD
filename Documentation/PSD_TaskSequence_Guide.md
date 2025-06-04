# PowerShell Deployment (PSD) Task Sequence Guide

This guide outlines a standard task sequence structure for operating system deployment using the PowerShell Deployment (PSD) framework. This task sequence can be created and customized within the Microsoft Deployment Toolkit (MDT) Workbench.

## General Recommendations

*   **MDT Workbench:** Use the MDT Workbench to create your task sequence.
*   **"Run PowerShell Script" Steps:** Most PSD steps will be implemented using MDT's "Run PowerShell Script" task sequence step type.
*   **Script Location:** Ensure your PSD scripts (from the deployment share's `Scripts` folder) are correctly referenced in each step (e.g., using `%SCRIPTROOT%\YourPSDScript.ps1`).
*   **Error Handling:** For critical PSD script steps, ensure the "Continue on error" checkbox is **unchecked** on the "Options" tab of the task sequence step. This will cause the task sequence to fail if the script encounters a terminating error.
*   **Task Sequence Variables:** PSD scripts heavily rely on MDT/PSD Task Sequence Variables for configuration and state management. Many of these are set by `PSDGather.ps1` or defined in `CustomSettings.ini`.

## Task Sequence Structure

The following is a recommended structure, organized by phase:

### 1. Preinstall Phase

This phase prepares the system for OS installation, running in Windows PE.

*   **(Optional) Pre-Preinstall Group:**
    *   Conditional steps for BIOS/UEFI configuration, firmware updates, etc. (Often hardware-specific, may use vendor tools).

*   **Gather & Validate Group:**
    *   **Step: Gather (Initial)**
        *   **Script:** `PSDGather.ps1`
        *   **Purpose:** Collects initial hardware/software information and processes `CustomSettings.ini` to populate Task Sequence Variables.
        *   **Key Variables Used:** Reads `CustomSettings.ini`, `Bootstrap.ini`.
        *   **Key Variables Set:** Many, including `IsUEFI`, `AssetTag`, `Make`, `Model`, `OSDComputerName` (potential initial value), `DeployRoot`, `SLShare`, etc.
    *   **Step: Validate Deployment Readiness**
        *   **Script:** `PSDValidate.ps1`
        *   **Purpose:** Checks system readiness based on rules defined by `PSDReadinessScript` and `PSDReadinessCheck` variables (from `CustomSettings.ini`). Examples: UEFI, TPM, ADDS connectivity, disk space.
        *   **Key Variables Used:** `PSDReadinessScript`, `PSDReadinessCheck*`, `PSDReadinessAllowBypass`.

*   **Partition Disk(s) Group:**
    *   **Step: Format and Partition Disk**
        *   **Script:** `PSDPartition.ps1`
        *   **Purpose:** Formats the destination disk and creates necessary partitions (e.g., Boot, OS, Recovery) based on whether the system is BIOS or UEFI.
        *   **Key Variables Used:** `DestinationDisk`, `IsUEFI`, `WipeDisk`.
        *   **Key Variables Set:** `OSVolume`, `BootVolume`, `RecoveryVolume` (letters/paths for the created partitions).

*   **(Optional) Pre-OS Apply Custom Tasks Group:**
    *   User-defined steps, e.g., running `PSDPrestart.ps1` if it performs actions beyond just displaying a UI (which might be called by `PSDGather.ps1` or `PSDValidate.ps1` if it's a wizard).

### 2. Install Operating System Phase

This phase applies the OS image and configures it. Continues in Windows PE.

*   **Step: Apply Operating System Image**
    *   **Script:** `PSDApplyOS.ps1`
    *   **Purpose:** Applies the WIM image to the target OS volume.
    *   **Key Variables Used:** `OSGUID` (from MDT Workbench OS selection), `DestinationDisk`, `DestinationPartition` (less common, `OSVolume` is preferred), `OSVolume` (target for OS).
*   **Step: Apply Unattend.xml Configuration**
    *   **Script:** `PSDConfigure.ps1`
    *   **Purpose:** Modifies the `unattend.xml` file (associated with the Task Sequence in MDT) with dynamic values from Task Sequence Variables, then applies it to the offline OS image.
    *   **Key Variables Used:** Many variables from `CustomSettings.ini` (e.g., `AdminPassword`, `TimeZone`, `JoinDomain`, `ComputerName`). Uses `ZTIConfigure.xml` as a mapping file.
    *   **Key Variables Set:** Potentially updates some TS vars if ZTIConfigure rules dictate.
*   **Step: Inject Drivers**
    *   **Script:** `PSDDrivers.ps1`
    *   **Purpose:** Injects necessary drivers into the offline OS image based on make/model or selection profiles.
    *   **Key Variables Used:** `DriverSelectionProfile` (e.g., "All Drivers", or a specific profile), `DriverGroup001` (for specific driver paths), `OSVersion`, `OSArchitecture`.

### 3. Postinstall Phase (Full OS)

This phase runs after the first boot into the newly installed operating system.

*   **Initial Setup Group:**
    *   *Note: The transition from WinPE to Full OS is handled by Setup. `PSDStart.ps1` is often configured via `SetupComplete.cmd` or an equivalent mechanism to run on first boot, copy necessary PSD files to the full OS (e.g., C:\MININT), and then resume the task sequence.*
    *   **Step: Gather (Full OS)**
        *   **Script:** `PSDGather.ps1`
        *   **Purpose:** Refreshes Task Sequence Variables, now running in the context of the full OS.
        *   **Key Variables Used:** `CustomSettings.ini`, `Bootstrap.ini`.
*   **System Configuration Group:**
    *   **(Optional) Step: Install Roles and Features**
        *   **Script:** `PSDRoleInstall.ps1`
        *   **Purpose:** Installs Windows roles and features specified by Task Sequence Variables (e.g., `OSRoles`, `OSRoleServices`, `OSFeatures`).
        *   **Key Variables Used:** `OSRoles`, `OSRoleServices`, `OSFeatures`.
    *   **(Optional) Step: Windows Update (Pre-Applications)**
        *   **Script:** `PSDWindowsUpdate.ps1`
        *   **Purpose:** Scans for and installs Windows Updates.
        *   **Key Variables Used:** `WUServer` (optional WSUS server).
*   **Application Installation Group:**
    *   **Step: Install Applications**
        *   **Script:** `PSDApplications.ps1`
        *   **Purpose:** Orchestrates the installation of multiple applications. This script typically calls other, individual application installation scripts.
        *   **Key Variables Used:** `Applications` (from MDT database or `CustomSettings.ini` defining which apps to install).
*   **System Customization & Final Updates Group:**
    *   **(Optional) Step: Windows Update (Post-Applications)**
        *   **Script:** `PSDWindowsUpdate.ps1`
        *   **Purpose:** Another pass for updates after applications are installed.
    *   **(Optional) Step: Apply Computer Name (if not set by Unattend.xml or earlier)**
        *   **Script:** `PSDSetVariable.ps1` (to set `OSDComputerName`) followed by a script/command to apply it if deferred. Or rely on `PSDTattoo.ps1`.
    *   **Step: Apply Branding/Tattoo**
        *   **Script:** `PSDTattoo.ps1`
        *   **Purpose:** Applies OEM information, sets registry keys for support info, potentially sets computer name if not already done.
        *   **Key Variables Used:** `AssetTag`, `SerialNumber`, `Make`, `Model`, `OSDComputerName`.

### 4. State Restore & Finalization Phase

This phase handles final cleanup, log copying, and user state restoration if applicable.

*   **(Optional) User State Restore Group:**
    *   Standard MDT USMT "Restore User State" steps would go here if USMT was used in a refresh scenario.
*   **Finalization Group:**
    *   **(Optional) Step: Restart Computer** (Standard MDT step, if needed before final cleanup).
    *   **Step: Gather (Final Log Collection)**
        *   **Script:** `PSDGather.ps1`
        *   **Purpose:** Final gather to ensure all latest variable states are logged.
    *   **Step: Copy Logs**
        *   **Script:** `PSDCopyLogs.ps1`
        *   **Purpose:** Collects all relevant logs (including `ZTIGather.xml` from the log path) and copies them to the `SLShare`.
        *   **Key Variables Used:** `SLShare`, `LogUserDomain`, `LogUserID`, `LogUserPassword`.
    *   **(Optional) Step: Final Custom Tasks** (User-defined cleanup or notification scripts).
    *   **Step: Final Actions (Cleanup & Reboot/Shutdown)**
        *   **Script:** `PSDFinal.ps1`
        *   **Purpose:** Performs final cleanup (e.g., removes MININT folder, clears autologon), and then executes the `FinishAction` (e.g., REBOOT, SHUTDOWN) defined in `CustomSettings.ini`.
        *   **Key Variables Used:** `FinishAction`.

This guide provides a robust template. Remember to customize it based on your specific deployment needs and the features of PSD you intend to use.
