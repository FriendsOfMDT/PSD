# Operations Guide

This guid is for standard operational guide when using PSD. For the latest updates refer to the [PowerShell Deployment - Latest Release Setup Guide.md](./PowerShell%20Deployment%20-%20Latest%20Release%20Setup%20Guide.md)

## Introduction

PSD enabled deployments works the same as standard MDT Lite Touch Deployments. They can be initiated via PXE, or via Boot Media (ISO/USB). Here follows a list of common operations actions for the PSD solution

### Import Operating Systems

Within MDT Deployment workbench, on the newly created PSD Deployment share, import/create/copy any desired Operating Systems. Follow MDT-provided instructions and techniques.

>PRO TIP: You can copy Operating Systems from other MDT deployment shares within the Deployment Workbench.

### Create PSD Task Sequence

You **MUST** create a new Task Sequence from the PSD Templates within the workbench. PSD will fail otherwise. Do not attempt to clone/copy/import or otherwise work around this step. Some steps are required for PSD functionality. Do not delete any of the PSD task sequence steps - you may disable steps in the PSD Template task sequences if you choose.

>PRO TIP: If you upgrade PSD version at a later date, **expect** to recreate your task sequences from the new PSD templates.


### Create Applications

Within MDT Deployment workbench, on the newly created PSD Deployment share, import/create/copy any desired Applications. Follow MDT-provided instructions and techniques. Make note of application's unique GUIDs for use automating application installation with CustomSettings.ini.

>PRO TIP: You can copy Applications from other MDT deployment shares within the Deployment Workbench.

>BUG: Be sure to add a dummy app to `customsettings.ini`. THere is a glitch if you want to use application selection in the new PSDWizard

### Import/Add Drivers

Within MDT Deployment workbench, on the newly created PSD Deployment share, import/create/copy any desired drivers. After adding new drivers to MDT using the "total control method" (OS/Make/Model, or OS/Model, etc. ), you need to run the New-PSDDriverPackage.ps1 to generate the ZIP or WIM archives. One ZIP or WIM archive is created for each OS and Model.

>PRO TIP: You can copy drivers from other MDT deployment shares. PSD also supports adding existing WIM or ZIP driver packages to the platform for seamless integration.

Sample syntax:
```powershell
.\New-MDTDriverPackage.ps1 -psDeploymentFolder "E:\PSDProduction" -CompressionType WIM

.\New-MDTDriverPackage.ps1 -psDeploymentFolder "E:\PSDProduction" -CompressionType ZIP
```

### Check Deployment Share Permissions

By default, the PSD installer creates an MDT folder structure for PSD. PSD-specific files , scripts and templates are added and a new SMB share is created if specified. Ensure that the necessary domain and/or local computer user accounts have access to the PSD Share.

>PRO TIP: Only grant the *minimum necessary rights* to write logs in the PSD share. Only **READ** rights are required for the PSD/MDT share.

### Update Windows PE settings

Update the MDT WinPE configurations panels including the following settings:

- WinPE Custom Wallpaper (see notes below)
- WinPE Extra Directory (configured by default)
- ISO File name and generation
- WIM file name and generation

### Enable MDT monitoring

Enable MDT Event Monitoring and specify the MDT server name and ports to be used.

### Update CustomSettings.ini

> **Note:** For `CustomSettings.ini` to be processed, `Bootstrap.ini` must be correctly configured first to allow PSD to connect to and access the deployment share. Refer to the "Update BootStrap.ini" section for details.

Edit and Customize `customsettings.ini` to perform the necessary and desired automation and configuration of your OSD deployments. These should be settings to affect the installed OS typically. Be sure to configure new PSD properties and variables.

> PRO TIP: Recommend using the latest `customsettings.ini` provided in repo. This requires that your sections and settings will have to be migrated and tested as well

### Update BootStrap.ini

The `Bootstrap.ini` file (located in the `Control` folder of your deployment share) is processed by `PSDStart.ps1` very early in the WinPE phase. It's crucial for telling PSD how to connect to your deployment share and for setting any other pre-gather properties.

**Key Configuration:**

*   **`PSDDeployRoots` (Recommended Method):**
    *   This property in the `[Default]` or a custom section (referenced in `[Settings]` `Priority`) specifies one or more locations for your deployment share. PSD will attempt to connect to them in the order listed.
    *   **Format:** Comma-separated list of UNC paths or HTTP/HTTPS URLs.
    *   **Examples:**
        *   UNC: `PSDDeployRoots=\\SERVER\DeploymentShare$\PSDProduction`
        *   HTTP: `PSDDeployRoots=http://server.domain.com/PSDProduction`
        *   HTTPS: `PSDDeployRoots=https://server.domain.com/PSDProduction`
        *   Multiple (failover): `PSDDeployRoots=https://primary.corp.com/PSD, \\backupds\PSDShare$`
    *   **Important:** If you use `PSDDeployRoots`, you should remove or comment out any legacy `DeployRoot` property from your `Bootstrap.ini` to avoid conflicts.

*   **Credentials for Network Access:**
    *   If your `PSDDeployRoots` require authentication (most UNC shares, and HTTP/S shares if not allowing anonymous access for GET/PROPFIND), you must specify credentials in `Bootstrap.ini`. These are typically placed in the same section as `PSDDeployRoots`.
    *   `UserID=your_username`
    *   `UserDomain=your_domain_or_server_name` (for domain accounts or local accounts on the deployment server)
    *   `UserPassword=your_password`
    *   **Security Note:** Storing passwords in `Bootstrap.ini` is a security consideration. Ensure access to your deployment share (and especially the `Control` folder) is appropriately restricted. For HTTP/S, consider using application pools with specific service accounts and Windows Authentication if anonymous access is not desired.

*   **`[Settings]` Section:**
    *   Ensure your `Priority` line in `[Settings]` correctly references the section(s) containing `PSDDeployRoots` and your credentials (e.g., `Priority=Default`).

**Example `Bootstrap.ini` Snippet (for HTTPS):**
```ini
[Settings]
Priority=Default
Properties=MyCustomProperty

[Default]
PSDDeployRoots=https://psdserver.corp.com/PSDShare
UserID=deployaccess
UserDomain=CORP
UserPassword=SecurePassword123
PSDDebug=NO
SkipBDDWelcome=YES
```

Correct configuration of `Bootstrap.ini` is essential for PSD to locate and access `CustomSettings.ini` and other deployment resources. An incorrect or inaccessible `PSDDeployRoots` path or invalid credentials will lead to failures early in the deployment process, often manifesting as an inability to find `CustomSettings.ini`.

### Understanding PSD Caching (for HTTP/S Deployments)

When you use an HTTP or HTTPS path in `PSDDeployRoots`, PowerShell Deployment employs a local caching mechanism to make deployment files available to the client in WinPE and the full OS.

*   **Cache Location:** Files are typically downloaded to a `Cache` subdirectory within the `MININT` folder (e.g., `X:\MININT\Cache` in WinPE, or `C:\MININT\Cache` in the full OS). The exact root (`X:\MININT` or `C:\MININT`) is determined by the `Get-PSDLocalDataPath` function.
*   **Initial Download:** When `PSDStart.ps1` first connects to an HTTP/S deployment share (via the `Get-PSDConnection` function):
    1.  It downloads the entire `Control` and `Templates` folders from your deployment share into this local `MININT\Cache` directory.
    2.  The `DeploymentShare:` PSDrive (a virtual drive used by PSD to access deployment resources) is then mapped to this local cache (specifically, to the parent of the cached `Control` folder, e.g., `X:\MININT\Cache`).
*   **Consequences of Failure:** If the initial download of the `Control` folder (or other critical content) via HTTP/S fails (e.g., due to incorrect URL in `PSDDeployRoots`, WebDAV configuration issues on the server, network problems, or authentication failures), the local cache at `MININT\Cache\Control` will be incomplete or empty.
*   **Impact on `CustomSettings.ini`:** Since the `DeploymentShare:` drive points to this local cache for HTTP/S, a failure to download `Control\CustomSettings.ini` into the cache means PSD will not find it, leading to errors indicating `CustomSettings.ini` cannot be accessed.

Ensuring your IIS server (with WebDAV) is correctly configured and accessible, and that `PSDDeployRoots` and credentials in `Bootstrap.ini` are accurate, is vital for this caching mechanism and the overall success of HTTP/S deployments.

## Configuration Backup and Restore

For managing the critical configuration files of your PSD/MDT deployment share, such as `Bootstrap.ini` and `CustomSettings.ini`, a PowerShell module named `PSDConfigManager.psm1` is provided in the `Tools` directory of your deployment share. This module offers functions to easily export (backup) and import (restore) these configurations.

This is particularly useful for:
- Creating backups before making significant changes to `Bootstrap.ini` or `CustomSettings.ini`.
- Migrating configurations between different deployment shares.
- Restoring a last known good configuration in case of issues.

To use the module, you'll first need to import it into your PowerShell session:
```powershell
Import-Module -Name "D:\DeploymentShareRoot\Tools\PSDConfigManager.psm1" # Adjust path as necessary
```

### Exporting Configuration (`Export-PSDConfiguration`)

The `Export-PSDConfiguration` function backs up your `Bootstrap.ini` and `CustomSettings.ini` files from the `Control` directory of your deployment share to a specified backup location.

**Parameters:**

*   `-Path <String>`: (Mandatory) Specifies the directory where the configuration files will be backed up. The files will be stored in a subdirectory named `PSDConfigBackup` within this path.
*   `-DeploymentShare <String>`: (Optional) Specifies the root of the MDT/PSD deployment share. If not provided, the function assumes the parent directory of the `Tools` folder (where the module resides) is the deployment share root.

**Example:**

To back up the configuration files from `D:\DeploymentShareRoot` to `D:\Backups\PSDConfigs`:

```powershell
Export-PSDConfiguration -Path "D:\Backups\PSDConfigs" -DeploymentShare "D:\DeploymentShareRoot"
```

This will create `D:\Backups\PSDConfigs\PSDConfigBackup` and copy `Bootstrap.ini` and `CustomSettings.ini` into it.

### Importing Configuration (`Import-PSDConfiguration`)

The `Import-PSDConfiguration` function restores `Bootstrap.ini` and `CustomSettings.ini` from a backup location (created by `Export-PSDConfiguration`) to the `Control` directory of your deployment share.

**Important:** This function will overwrite the existing `Bootstrap.ini` and `CustomSettings.ini` files in the target `Control` directory.

**Parameters:**

*   `-Path <String>`: (Mandatory) Specifies the directory containing the `PSDConfigBackup` subdirectory from which the configuration files will be restored.
*   `-DeploymentShare <String>`: (Optional) Specifies the root of the MDT/PSD deployment share where the files will be restored. If not provided, the function assumes the parent directory of the `Tools` folder is the deployment share root.

**Example:**

To restore configuration files to `D:\DeploymentShareRoot` from a backup located at `D:\Backups\PSDConfigs`:

```powershell
Import-PSDConfiguration -Path "D:\Backups\PSDConfigs" -DeploymentShare "D:\DeploymentShareRoot"
```

This will copy `Bootstrap.ini` and `CustomSettings.ini` from `D:\Backups\PSDConfigs\PSDConfigBackup` to `D:\DeploymentShareRoot\Control`.

### Verbose Logging

Both functions use `Write-Verbose` to output detailed information about their operations. To see this detailed logging, use the `-Verbose` common parameter when running the functions:

```powershell
Export-PSDConfiguration -Path "D:\Backups\PSDConfigs" -Verbose
Import-PSDConfiguration -Path "D:\Backups\PSDConfigs" -Verbose
```

## Using the PSD Environment Configuration Tool (`PSDEnvironmentConfigurator.ps1`)

To simplify common setup and maintenance tasks for your PowerShell Deployment environment, a menu-driven PowerShell script named `PSDEnvironmentConfigurator.ps1` is provided.

**Location:** This script is located in the `Tools` directory of your PSD deployment share (e.g., `X:\DeploymentShare\Tools\PSDEnvironmentConfigurator.ps1`).

**How to Launch:**
To run the tool, open a PowerShell console, navigate to your deployment share's `Tools` directory, and execute the script:
```powershell
cd X:\DeploymentShare\Tools
.\PSDEnvironmentConfigurator.ps1
```
Ensure you run this script with appropriate permissions for the tasks you intend to perform (some options may require Administrator rights).

**Menu Options Overview:**

The configurator provides the following options:

1.  **Validate PSD Prerequisites:**
    *   *Purpose:* Intended to check your environment for necessary roles, features, and settings required for PSD to function correctly.
    *   *Current Status:* This is currently a placeholder. The underlying checks are yet to be implemented.

2.  **Guided IIS Setup for PSD:**
    *   *Purpose:* Designed to walk you through the configuration of Internet Information Services (IIS) if you plan to use HTTP or HTTPS for your deployments.
    *   *Current Status:* This is currently a placeholder.

3.  **Guided BranchCache Setup for PSD:**
    *   *Purpose:* Intended to assist in setting up BranchCache for peer-to-peer content distribution, which can significantly reduce WAN traffic in distributed environments.
    *   *Current Status:* This is currently a placeholder.

4.  **Backup Deployment Share Configuration:**
    *   *Purpose:* Provides an interactive way to back up your critical deployment share configuration files (`Bootstrap.ini` and `CustomSettings.ini`).
    *   *Functionality:* This option utilizes the `Export-PSDConfiguration` function from the `PSDConfigManager.psm1` module (also located in the `Tools` directory). You will be prompted for a backup path.

5.  **Restore Deployment Share Configuration:**
    *   *Purpose:* Allows you to restore `Bootstrap.ini` and `CustomSettings.ini` from a previous backup.
    *   *Functionality:* This option uses the `Import-PSDConfiguration` function from the `PSDConfigManager.psm1` module. You will be prompted for the path containing the `PSDConfigBackup` folder.

**Note on Development Status:**
Please be aware that the `PSDEnvironmentConfigurator.ps1` tool is currently under development. While the configuration backup and restore functionalities are operational (leveraging `PSDConfigManager.psm1`), several other menu options are placeholders for future enhancements.

### Update Background wallpaper

By default, a new PSD themed background wallpaper (PSDBackground.bmp) is provided. It can be found at Samples folder of the MDT installation. Adjust the MDT WinPE Customizations tab to reflect this new bmp (or use your own).

### Configure Extra Files

Create and populate an ExtraFiles folder that contains anything you want to add to WinPE or images. Things like CMTRACE.EXE, wallpapers, etc.

>PRO TIP: Create the same folder structure as where you want the files to land (e.g. \Windows\System32)

### Readiness

PSD now runs a default script _Computer_Readiness.ps1_ from PSDResources\Readiness folder. Edit this file with new functions or create a new readiness script. Be sure to update the property in CustomSetting.ini. If Deployment Readiness page is enabled, a valid file path **must** be used.

### Certificates

Be sure to export the full chain of certificates to PSDResources\Certificates folder. This is required for HTTPS PSD shares

### Configure WinPE Drivers

Using MDT Selection Profiles, customize your WinPE settings to utilize an appropriate set of MDT objects. Be sure to consider Applications, Drivers, Packages, and Task Sequences.

### Generate new Boot Media

Using MDT Deployment workbench techniques, generate new boot media. By default the installer, will configure NEW PSD deployment shares to be PSDLiteTouch_x64.iso and PSDLiteTouch_x86.iso. Rename these if necessary.

### Content Caching and Peer to Peer support

Please see the BranchCache Installation Guide for information on how to enable P2P support.