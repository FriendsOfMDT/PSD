---
id: installation
title: Installation
sidebar_label: Installation
sidebar_position: 3
---

# Installing PSD

Tim is here!

This guide walks through installing PSD onto a new MDT deployment share using the `Install-PSD.ps1` script.

:::warning
We **strongly recommend** creating a **new** deployment share for PSD. Once a share is extended with PSD, standard MDT task sequences will **no longer work** in that share. Copy your existing applications, drivers, and images to the new share manually after installation.
:::

---

## Before You Begin

Ensure all [Prerequisites](./prerequisites) are met:
- Windows ADK and WinPE Add-on installed (build ≥ 17763)
- MDT 8456 with KB4564442 HotFix installed
- The MDT Deployment Workbench is **closed**
- You have local Administrator rights

---

## Step 1: Obtain PSD

**Option A — Git Clone (recommended):**

```powershell
git clone https://github.com/FriendsOfMDT/PSD.git
```

**Option B — Download ZIP:**

1. Go to [https://github.com/FriendsOfMDT/PSD](https://github.com/FriendsOfMDT/PSD)
2. Click **Code → Download ZIP**
3. After downloading, **unblock the ZIP** before extracting:
   - Right-click the file → **Properties** → Check **Unblock** → **OK**
4. Extract the contents

---

## Step 2: Run the Installer

Open an **elevated PowerShell prompt** and navigate to the PSD folder:

```powershell
cd C:\path\to\PSD
```

### New Installation

```powershell
.\Install-PSD.ps1 -psDeploymentFolder "D:\PSD" -psDeploymentShare "dep-psd$"
```

### Installer Parameters

| Parameter | Required | Description |
|---|---|---|
| `-psDeploymentFolder` | **Yes** | Absolute path for the new deployment share. Keep under 30 chars, no spaces recommended. |
| `-psDeploymentShare` | **Yes** | SMB share name. Use `$` suffix for hidden shares (e.g., `dep-psd$`). |
| `-Upgrade` | No | Switch to upgrade an existing PSD/MDT share. See [Upgrade guide](./upgrade). |
| `-Verbose` | No | Show verbose output during installation. |

### Example Scenarios

```powershell
# Create new deployment at D:\DeploymentShares\PSD with share name PSD$
.\Install-PSD.ps1 -psDeploymentFolder "D:\DeploymentShares\PSD" `
                  -psDeploymentShare "PSD$"

# Create with custom share name
.\Install-PSD.ps1 -psDeploymentFolder "D:\DeploymentShares\PSDProd" `
                  -psDeploymentShare "PSDProd$"
```

---

## Step 3: Review the Installation Log

The installer writes a log file to the same directory as `Install-PSD.ps1`:

```
Install-PSD.log
```

Open it with **CMTrace** or a text editor. Look for any `LogLevel 3` (error) entries.

---

## Step 4: Review the Latest Release Setup Guide

After installation, review the [Latest Release Setup Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20Latest%20Release%20Setup%20Guide.md) which contains version-specific post-install steps.

---

## What the Installer Does

The installer performs the following actions in sequence:

### Validation Checks
1. Detects installed ADK version (aborts if below build 17763)
2. Detects installed WinPE Add-on (aborts if missing or too old)
3. Detects installed MDT version (aborts if not found)

### Deployment Share Creation
4. Creates the deployment share folder on disk
5. Creates an SMB share with the specified name
6. Creates an MDT persistent PSDrive named `PSDxxx`

### File Cleanup
7. Removes legacy MDT VBScript/wizard files from `Scripts\`:
   - `*.vbs`, `*.wsf`, `DeployWiz*`, `UDI*`, `WelcomeWiz_*.xml`
   - Legacy gif/png/jpg, wizard `.hta`, `.ico`, `.css` files

### PSD File Deployment
8. Copies all PSD scripts to `Scripts\`
9. Copies new PSD Wizard files to `Scripts\PSDWizardNew\`
10. Copies templates to `Templates\`
11. Copies PowerShell modules to `Tools\Modules\`:
    - `PSDGather`, `PSDDeploymentShare`, `PSDUtility`
    - `PSDWizard`, `PSDWizardNew`, `PSDStartLoader`
12. Copies MDT provider DLLs to `Tools\Modules\Microsoft.BDD.PSSnapIn\`
13. Copies `ZTIGather.xml` to `Tools\Modules\PSDGather\`

### PSDResources Structure
14. Creates `PSDResources\` with subdirectories:
    ```
    Autopilot, BGInfo, BootImageFiles\X86, BootImageFiles\X64
    Branding, Certificates, CustomScripts, DriverPackages
    DriverSources, Plugins, Prestart, UserExitScripts, Readiness
    ```
15. Copies branding files (`PSDBackground.bmp`, `PSD.bgi`)
16. Copies prestart, plugin, readiness, and user exit script files

### Deployment Share Properties
17. Sets boot image properties:
    - x64 ISO name: `PSDLiteTouch_x64.iso`
    - x64 WIM description: `PowerShell Deployment Boot Image (x64)`
    - Background: `PSDBackground.bmp`
18. Disables x86 boot support
19. Sets NTFS permissions (Users: RX, Administrators: F, SYSTEM: F)
20. Sets SMB share access (EVERYONE: Change; removes CREATOR OWNER)
21. Copies starter `Bootstrap.ini` and `CustomSettings.ini` to `Control\`

---

## Step 5: Open the MDT Workbench

After installation:
1. Open the **MDT Deployment Workbench**
2. The new PSD deployment share should appear under **Deployment Shares**
3. If it does not appear, click **Refresh** or manually add the share via **Open Deployment Share**

---

## Next Steps

1. **Import content** — Add OS images, applications, and driver packages to your new share
2. **Configure INI files** — Set up [Bootstrap.ini](../configuration/bootstrap-ini) and [CustomSettings.ini](../configuration/customsettings-ini)
3. **Set up IIS** — Follow the [IIS Configuration Guide](../deployment/iis-setup) for HTTPS deployments
4. **Build and deploy** — Update the deployment share and boot images in the Workbench, then test your first deployment
