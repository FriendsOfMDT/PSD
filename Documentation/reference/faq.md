---
id: faq
title: Frequently Asked Questions
sidebar_label: FAQ
sidebar_position: 2
---

# Frequently Asked Questions

---

## Installation

**Q: Does the installer copy over my existing MDT content (applications, drivers, task sequences)?**

> No. Users and administrators must manually copy or re-import existing content (applications, drivers, OS images, task sequences) to the new PSD deployment share using MDT Workbench's built-in content management features. MDT shares that have been PSD-upgraded retain access to any existing objects and artifacts.

---

**Q: Can `Install-PSD.ps1` be run remotely?**

> No. The installer must be run **locally** on the MDT server with local administrative rights. Remote execution is not supported.

---

**Q: Does the installer copy over my existing `Bootstrap.ini` or `CustomSettings.ini`?**

> No. If you created a new PSD deployment share, you must manually copy or recreate your INI files. The installer deploys starter templates from `INIFiles\` to `Control\` for new installs only — existing `CustomSettings.ini` and `Bootstrap.ini` are not overwritten during upgrades.

---

**Q: The installer created a share name with a different format than expected. Why?**

> The PSD installer creates the SMB share name exactly as specified in `-psDeploymentShare`. It does not modify or add the hidden share character (`$`) automatically — include it explicitly if desired (e.g., `dep-psd$`).

---

## Hardware and Environment

**Q: What are the minimum hardware requirements for PSD deployments?**

> - At least **1.5 GB RAM** (WinPE has been extended beyond standard MDT and requires additional memory)
> - At least **1 network adapter**
> - At least **50 GB** hard drive (for bare-metal deployments)
> - x64 processor (x86 is not supported)

---

**Q: Are system clocks synchronized during deployment?**

> Yes. `PSDStart.ps1` attempts to synchronize the system clock on target computers early in the boot process. The deployment server should be NTP-synchronized.

---

## Operations

**Q: Why does the PowerShell window change size during deployment?**

> This is **intentional**. `PSDStart.ps1` resizes the window from full-screen to approximately one-third the screen width early in the boot process. It is expected behavior and not an error.

---

**Q: Do I need to add PowerShell to my WinPE boot images?**

> **No.** PSD and MDT handle this automatically. The `LiteTouchPE.XML` file injects PowerShell into boot media regardless of what is configured in the MDT Workbench WinPE features tab. You do not need to check or uncheck anything in the Workbench.

---

**Q: What is "Transcript Logging"?**

> Transcript logs (different from `PSD.log`) capture everything that appears in the PowerShell console window. They are more comprehensive than explicit log entries and are often the best tool for deep troubleshooting. They can be visually verbose but contain the full execution trace of every script.

---

**Q: What files should NOT be deleted from my PSD deployment share?**

> Do not delete:
> - Any `PSD*.ps1` or `PSD*.psm1` files
> - `ZTIGather.xml` or `ZTIConfigure.xml`
> - `ZTIUtility.vbs` — may be called by legacy application install scripts
>
> Legacy MDT `.wsf` scripts and wizard files can be removed manually to clean up the environment if desired, but the PSD installer handles this during installation/upgrade.

---

**Q: Application GUIDs in my INI file aren't working. What's wrong?**

> Application GUIDs in `Bootstrap.ini` or `CustomSettings.ini` **must** be wrapped in curly braces:
> ```ini
> Applications001={12345678-1234-1234-1234-123456789012}
> ```
> Without the braces, PSD will not recognize the GUID as an application reference.

---

**Q: I added a custom variable in `CustomSettings.ini` but it's not being set. Why?**

> All custom task sequence variables must be **explicitly declared** in the `Properties` line of `[Settings]`:
> ```ini
> [Settings]
> Priority=Default
> Properties=MyCustomVar, AnotherVar
> ```
> Without this declaration, the variable will not be created in the task sequence environment.

---

## Compatibility

**Q: Does PSD work with 2Pint's OSD Toolkit?**

> Yes. See the [BranchCache / P2P guide](../deployment/branchwcache) for integration instructions.

---

**Q: Will PSD work on other versions of MDT or ADK not listed in the supported platforms?**

> PSD has only been developed and tested against the versions listed in [Supported Platforms](./supported-platforms). Community feedback on additional versions is welcome via [GitHub Issues](https://github.com/FriendsOfMDT/PSD/issues).

---

**Q: Can standard MDT task sequences still run after PSD installation?**

> **No.** Once a deployment share is extended with PSD, standard MDT VBScript-based task sequences will no longer work in that share. This is because the PSD installer removes the VBScript files that MDT task sequences depend on. It is strongly recommended to create a separate, new PSD deployment share rather than extending an existing production MDT share.

---

## Boot Media

**Q: Which MDT components are injected into PSD boot media?**

> Via `LiteTouchPE.XML`, the following are injected:
>
> **WinPE Components:** `winpe-hta`, `winpe-scripting`, `winpe-wmi`, `winpe-securestartup`, `winpe-fmapi`, `winpe-netfx`, `winpe-powershell`, `winpe-dismcmdlets`, `winpe-storagewmi`, `winpe-enhancedstorage`, `winpe-securebootcmdlets`
>
> **MDT Tools:** `BDDRUN.exe`, `WinRERUN.exe`, MDT DLLs, TS core files
>
> **PSD Modules:** `PSDUtility.psm1`, `PSDGather.psm1`, `PSDWizardNew.psm1`, `PSDDeploymentShare.psm1`, `ZTIGather.xml`
>
> **PSD Scripts:** `PSDStart.ps1`, `PSDHelper.ps1`
>
> **Config:** `Bootstrap.ini`, `Unattend.xml`, `winpeshl.ini`
