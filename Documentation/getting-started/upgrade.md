---
id: upgrade
title: Upgrading PSD
sidebar_label: Upgrade
sidebar_position: 4
---

# Upgrading an Existing PSD Installation

Use the `-Upgrade` switch to update an existing MDT/PSD deployment share to the latest version of PSD without losing your existing content.

---

## Before Upgrading

- **Close** the MDT Deployment Workbench
- **Back up** your deployment share (the installer creates a backup, but an additional manual backup is always prudent)
- Review the [Latest Release Setup Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20Latest%20Release%20Setup%20Guide.md) for version-specific notes

---

## Running the Upgrade

```powershell
.\Install-PSD.ps1 -psDeploymentFolder "D:\PSD" `
                  -psDeploymentShare "dep-psd$" `
                  -Upgrade
```

:::note
Both `-psDeploymentFolder` and `-psDeploymentShare` are **mandatory** when upgrading. The installer needs both to locate and verify the existing share before making changes.
:::

---

## What the Upgrade Does

### 1. Validation
- Verifies the specified folder and SMB share both exist
- Aborts with an error if either is missing

### 2. Automatic Backup
The installer creates a timestamped backup of the folders that will be replaced:

```
<DeploymentFolder>\Backup\PSD_00001\
<DeploymentFolder>\Backup\PSD_00002\
...
```

The following are backed up:

| Source Folder | Backed Up |
|---|---|
| `Scripts\` | ✅ |
| `Templates\` | ✅ |
| `Tools\Modules\` | ✅ |
| `PSDResources\BGInfo\` | ✅ |
| `PSDResources\BootImageFiles\` | ✅ |
| `PSDResources\Branding\` | ✅ |
| `PSDResources\Certificate\` | ✅ |
| `PSDResources\CustomScripts\` | ✅ |
| `PSDResources\Plugins\` | ✅ |
| `PSDResources\Prestart\` | ✅ |
| `PSDResources\UserExitScripts\` | ✅ |

### 3. Legacy File Cleanup
Removes outdated MDT files from `Scripts\`:

```
*.vbs, *.wsf, DeployWiz*, UDI*, WelcomeWiz_*.xml
*.gif, *.png, *.jpg, *.hta, *.ico, *.css
Autorun.inf, BDD_Welcome_ENU.xml, Credentials_ENU.xml
Summary_Definition_ENU.xml, DeployWiz_Roles.xsl
ListOfLanguages.xml, ZTITatoo.mof
```

### 4. Updated PSD Files Deployed
All updated PSD scripts, modules, templates, and resources are deployed identically to a fresh installation — except:
- `Bootstrap.ini` and `CustomSettings.ini` are **not** overwritten
- Applications, drivers, OS images, and task sequences are **not** touched

---

## After Upgrading

1. **Review the backup** at `<DeploymentFolder>\Backup\PSD_XXXXX\` and verify your customizations from the previous version
2. **Port customizations** — If you had modified any PSD scripts or modules in the previous version, re-apply those changes to the new versions carefully
3. **Open the Workbench** — Refresh or reopen the deployment share; rebuild boot images
4. **Test** — Run a test deployment before rolling out to production

---

## Rollback

If the upgrade causes issues, the automatic backup allows a manual rollback:

```powershell
# Example: restore Scripts folder from backup
Copy-Item -Path "D:\PSD\Backup\PSD_00001\Scripts\*" `
          -Destination "D:\PSD\Scripts\" `
          -Recurse -Force
```

Repeat for each backed-up folder as needed.
