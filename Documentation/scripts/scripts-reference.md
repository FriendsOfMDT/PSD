---
id: scripts-reference
title: Scripts Reference
sidebar_label: Scripts Reference
sidebar_position: 1
---

# PSD Scripts Reference

All PSD scripts reside in the `Scripts\` folder of the deployment share and are executed as task sequence steps. Each script is the PowerShell equivalent of a legacy MDT VBScript.

---

## Entry Point

### PSDStart.ps1

**MDT equivalent:** `LiteTouch.wsf`

The main entry point for every PSD deployment. Called from `winpeshl.ini` in WinPE and re-invoked at each restart by `SetupComplete.cmd`.

**Responsibilities:**
- Imports core PSD modules
- Connects to the deployment share (SMB, HTTP, or HTTPS)
- Synchronizes the system clock
- Starts or resumes an in-progress task sequence
- Launches the PSD Wizard (if enabled)
- Manages restart handling across task sequence phases
- Supports **UserExitScripts** *(v0.2.3.1+)*

```powershell
# Example: manually invoke PSDStart in WinPE for testing
.\PSDStart.ps1 -Debug
```

---

## Task Sequence Scripts

### PSDGather.ps1

**MDT equivalent:** `ZTIGather.wsf`

Invokes `PSDGather.psm1` to collect hardware, OS, and environment information. Processes `Bootstrap.ini` and `CustomSettings.ini` rules. All collected data is stored in task sequence variables for use by subsequent scripts.

**Key data collected:**
- Hardware: make, model, serial number, UUID, asset tag
- Memory, CPU, disk, BIOS/UEFI type
- Network: MAC address, IP, DHCP info
- OS: current OS details (for refresh scenarios)

---

### PSDPartition.ps1

**MDT equivalent:** `ZTIDiskpart.wsf`

Partitions and formats the target disk. The disk layout supports both **BIOS (MBR)** and **UEFI (GPT)** systems.

:::warning
Disk partitioning details are hardcoded in this script. Do **not** modify the partition layout unless you fully understand the implications.
:::

**UEFI partition layout (default):**
- ESP (EFI System Partition) — FAT32, 499 MB
- MSR (Microsoft Reserved) — 16 MB
- OS partition — NTFS, remaining space

---

### PSDApplyOS.ps1

**MDT equivalent:** `LTIApply.wsf`

- Sets the power profile to **High Performance** for the duration of the task sequence
- Applies the selected OS image using `DISM /Apply-Image`
- Injects driver packages into the offline OS using `DISM /Add-Driver`
- Configures BCD boot entries for the deployed OS

---

### PSDConfigure.ps1

**MDT equivalent:** `ZTIConfigure.wsf`

Reads task sequence variables and generates the `Unattend.xml` file used by Windows Setup (OOBE) for:
- Computer name
- Local administrator password
- Regional settings and locale
- Domain/workgroup join

---

### PSDDrivers.ps1

**MDT equivalent:** `ZTIDrivers.wsf`

Identifies the target hardware model and downloads the appropriate driver package (WIM or ZIP) from the deployment share to the local PSD cache. Drivers are injected offline by `PSDApplyOS.ps1`.

**Driver package resolution logic:**
1. Reads `Make` and `Model` from task sequence variables
2. Maps to a driver package folder under `DriverPackages\`
3. Downloads the WIM or ZIP archive
4. Stages for injection during OS apply

See [Driver Packaging](../advanced/driver-packaging) for instructions on preparing driver packages.

---

### PSDApplications.ps1

**MDT equivalent:** `ZTIApplications.wsf`

Installs applications listed in the `Applications` and `MandatoryApplications` task sequence variables.

**Supported install types:**
- `msiexec.exe` — MSI packages
- `.CMD` — Batch command scripts
- `cscript` — VBScript-based installers

**Logic:**
1. Validates the application's supported platforms against the target
2. Checks registry for existing or previous installation
3. Downloads application source to PSD cache
4. Runs the installer command

---

### PSDWindowsUpdate.ps1

**MDT equivalent:** `ZTIWindowsUpdate.wsf`

Triggers Windows Update on the deployed OS. Supports running in the full OS phase of the task sequence.

---

### PSDRoleInstall.ps1 / PSDRoleUnInstall.ps1

Installs or uninstalls Windows Server roles and features using `Install-WindowsFeature` / `Uninstall-WindowsFeature`.

---

### PSDSetVariable.ps1

**MDT equivalent:** `ZTISetVariable.wsf`

Sets a task sequence variable to a specified value. Used as an inline TS step.

---

### PSDValidate.ps1

**MDT equivalent:** `ZTIValidate.wsf`

Validates system requirements before deployment proceeds:
- Minimum RAM
- Network adapter presence
- Disk size

---

### PSDTattoo.ps1

Records deployment metadata to the Windows registry of the deployed OS for auditing and reporting:
- Deployment date and time
- Task sequence ID and name
- PSD version

---

### PSDFinal.ps1

Performs end-of-deployment cleanup:
- Removes PSD deployment cache
- Reverts power profile
- Finalizes logs

---

### PSDCopyLogs.ps1

Copies deployment logs to the `SLShare` path specified in `CustomSettings.ini` (if configured). Runs at the end of the task sequence.

---

### PSDCustomization.ps1

Applies post-deployment customizations. Used for system-level configurations that need to run in the full OS context after Windows Setup completes.

---

### PSDPrestart.ps1

Executed from the WinPE Prestart phase before `PSDStart.ps1`. Used for early network configuration or hardware detection tasks.

---

## Utility Scripts

### PSDHelper.ps1

Import helper for **development and testing only**. Loads the main PSD modules into an interactive PowerShell session so you can test module functions without running a full deployment.

```powershell
# Load PSD modules in an interactive WinPE session
.\PSDHelper.ps1
```

### PSDTest.ps1

Test validation script for verifying PSD component functionality.

### PSDTBA.ps1

Placeholder script for task sequence steps that are not yet converted from MDT. Steps using this script are logged but perform no action.

---

## Command Scripts

| Script | Description |
|---|---|
| `SetupComplete.cmd` | Runs at the start of OOBE to re-invoke `PSDStart.ps1` after the first reboot |
| `SetupRollback.cmd` | Runs if Windows Setup fails, initiating a rollback |

---

## XML Configuration Files

| File | Description |
|---|---|
| `ZTIGather.xml` | Rules and property mappings for environment data collection |
| `ZTIConfigure.xml` | Mappings for `Unattend.xml` property substitution |
| `ZTIBIOSCheck.xml` | BIOS firmware version check rules |
| `ZTISupportedPlatforms.xml` | Supported hardware platform definitions |
| `LiteTouchPE.XML` | Defines WinPE components and files injected into boot media |
| `NICSettings_Definition_ENU.xml` | NIC configuration definitions for the wizard |
