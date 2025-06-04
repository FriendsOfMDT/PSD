# PowerShell Deployment (PSD) Installation Guide

This guide provides step-by-step instructions for installing and configuring the PowerShell Deployment (PSD) solution, which enhances Microsoft Deployment Toolkit (MDT) with PowerShell-driven capabilities.

## 1. Prerequisites

Before installing PSD, ensure your environment meets the following prerequisites:

*   **Windows Assessment and Deployment Kit (ADK):**
    *   A compatible version of the Windows ADK must be installed. `Install-PSD.ps1` checks for a minimum ADK build (typically 17763 or higher, see script for exact version).
    *   **Windows PE (WinPE) Add-on:** The WinPE add-on for the installed ADK version is also required.
*   **Microsoft Deployment Toolkit (MDT):**
    *   A compatible version of MDT must be installed. `Install-PSD.ps1` will check for its presence.
*   **PowerShell:**
    *   PowerShell 5.1 or later is recommended for both the server running MDT and for client execution during deployment.
*   **Administrative Privileges:** You will need local administrator privileges on the MDT server to run `Install-PSD.ps1` and configure the deployment share.

## 2. Obtaining PSD Source Files

Download or clone the PSD project files from the official repository (e.g., GitHub). This will typically include:
*   `Install-PSD.ps1` (the main installer script)
*   The `Scripts` directory (containing core PSD scripts and modules)
*   The `Templates` directory (PSD-specific unattend.xml templates, etc.)
*   The `INIFiles` directory (default `Bootstrap.ini` and `CustomSettings.ini`)
*   The `PSDResources` directory (branding, tools, prestart files)
*   The `Branding` directory (source for some branding files)
*   The `Plugins` directory

Place these files in a known location on your MDT server from where you will run the installation.

## 3. Running the Installer (`Install-PSD.ps1`)

`Install-PSD.ps1` automates the creation of a new PSD-enabled deployment share or upgrades an existing one.

1.  **Open PowerShell as Administrator:** On your MDT server, open an elevated PowerShell console.
2.  **Navigate to Source Directory:** Change to the directory where you placed the PSD source files, specifically where `Install-PSD.ps1` is located.
3.  **Execute `Install-PSD.ps1`:**

    *   **Parameters:**
        *   `-psDeploymentFolder <PhysicalPath>`: **Mandatory.** The full physical path where the deployment share will be created (e.g., `D:\PSDShare`).
        *   `-psDeploymentShare <ShareName>`: **Mandatory.** The name for the network share (e.g., `PSDShare$`). It's recommended to make it a hidden share by appending `$`.
        *   `[-Upgrade]`: **Optional.** Switch parameter. If specified, the script attempts to upgrade an existing deployment share at the given path and share name.
        *   `[-Silent]`: **Optional.** Switch parameter. If specified, the script will bypass interactive prompts for `Bootstrap.ini` and `CustomSettings.ini` settings and will instead use the default files from the `INIFiles` source directory.

    *   **Example (New Installation - Interactive):**
        ```powershell
        .\Install-PSD.ps1 -psDeploymentFolder D:\MDTProduction -psDeploymentShare MDTProduction$
        ```

    *   **Example (New Installation - Silent):**
        ```powershell
        .\Install-PSD.ps1 -psDeploymentFolder D:\MDTProduction -psDeploymentShare MDTProduction$ -Silent
        ```

    *   **Example (Upgrade an Existing Share - Usually Interactive):**
        ```powershell
        .\Install-PSD.ps1 -psDeploymentFolder D:\MDTProduction -psDeploymentShare MDTProduction$ -Upgrade
        ```

### 3.1. Interactive Mode Prompts (if `-Silent` is NOT used)

If you run `Install-PSD.ps1` without the `-Silent` switch, you will be prompted to configure initial settings for `Bootstrap.ini` and `CustomSettings.ini`. This helps tailor the deployment share to your environment quickly.

*   **Bootstrap.ini Prompts:**
    *   **DeployRoot Override:** The network path clients will use to connect (e.g., `\\SERVERNAME\PSDShare$`). Defaults to a path based on the server's name and the share name you provided.
    *   **UserID, UserDomain, UserPassword:** Credentials for connecting to the deployment share.
        *   *Warning:* Storing passwords in `Bootstrap.ini` is a security risk. For production, consider domain-joined clients with appropriate share permissions or other secure access methods. You can leave these blank to be prompted in WinPE.
    *   **SkipBootstrap:** Whether to skip the Bootstrap phase (rarely Yes).

*   **CustomSettings.ini Prompts:**
    *   **AdminPassword:** Password for the local Administrator account on deployed clients.
    *   **TimeZone:** The time zone for deployed clients (e.g., "Pacific Standard Time").
    *   **SkipProductKey:** (Y/N)
    *   **SkipComputerName:** (Y/N) - If No, prompts in WinPE.
    *   **SkipDomainMembership:** (Y/N) - If No, prompts in WinPE for domain details.
    *   **SkipUserData:** (Y/N)
    *   **SkipLocaleSelection:** (Y/N) - If No, prompts in WinPE.
    *   **SkipTimeZone:** (Y/N) - If No, uses the TimeZone value set above.

The script will use your answers to generate these INI files in the `Control` folder of your new deployment share.

### 3.2. What `Install-PSD.ps1` Does

*   Checks for ADK and MDT prerequisites.
*   Creates the specified deployment folder and SMB share.
*   Establishes an MDT PSDrive for the new share.
*   Cleans out default VBScripts and some XML files from a standard MDT share.
*   Copies PSD scripts, modules, templates, and resources into the appropriate folders within the new deployment share (`Scripts`, `Tools\Modules`, `Templates`, `PSDResources`).
*   Sets default PSD-specific properties on the deployment share (e.g., boot image names, background).
*   Adjusts permissions on the deployment share folder for typical access.
*   Creates/Copies `Bootstrap.ini` and `CustomSettings.ini` into the `Control` folder (either generated from prompts or copied from `INIFiles` if `-Silent`).

## 4. Post-`Install-PSD.ps1` Configuration (MDT Workbench)

After `Install-PSD.ps1` completes successfully, you need to further populate and configure your deployment share using the MDT Deployment Workbench:

1.  **Open Deployment Workbench:** Launch the MDT Deployment Workbench console.
2.  **Add/Open Deployment Share:**
    *   If it's a new share, right-click "Deployment Shares" and select "New Deployment Share." Point it to the physical path you provided to `Install-PSD.ps1` (e.g., `D:\PSDShare`). MDT will recognize it.
    *   If you upgraded, simply open the existing share.
3.  **Import Operating Systems:**
    *   Navigate to the "Operating Systems" node in your deployment share.
    *   Right-click and select "Import Operating System." Follow the wizard to import your OS WIM files (custom images or full source files).
4.  **Import Applications (Optional):**
    *   Navigate to the "Applications" node.
    *   Right-click and select "New Application." Follow the wizard to add applications you want to deploy. PSD's `PSDApplications.ps1` will rely on these MDT application objects.
5.  **Import Drivers (Optional but Recommended):**
    *   Navigate to the "Out-of-Box Drivers" node.
    *   Create a folder structure that makes sense for your driver management (e.g., by Make/Model/OS).
    *   Right-click the appropriate folder and select "Import Drivers." Follow the wizard to import your driver source files.
6.  **Review Deployment Share Properties:**
    *   Right-click your deployment share in the Workbench and select "Properties."
    *   Review settings on tabs like "Rules" (which shows `CustomSettings.ini` and `Bootstrap.ini`), "Windows PE" (for boot image settings, drivers, features), and "Monitoring" (if you plan to use MDT monitoring). `Install-PSD.ps1` sets some PE defaults like the branding image.

## 5. Next Steps

Once your deployment share is created by `Install-PSD.ps1` and populated with your OS, applications, and drivers:

*   **Create a Task Sequence:** Refer to the `PSD_TaskSequence_Guide.md` for detailed instructions on building a task sequence that utilizes the PSD scripts.
*   **Update Boot Images:** After configuring task sequences and potentially adding drivers to WinPE in the Workbench, update your Lite Touch Boot Images.
*   **Test Deployment:** Thoroughly test your deployments to a test client machine.

This guide should help you get PSD installed and configured. Refer to other documents in this `Documentation` folder for more specific guidance on task sequences and other PSD features.
