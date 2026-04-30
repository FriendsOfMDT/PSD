---
id: changelog
title: Changelog
sidebar_label: Changelog
sidebar_position: 4
---

# Changelog

All notable changes to PowerShell Deployment (PSD) are documented here.

---

## v0.2.3.1 — December 2025

**Scripts & Modules**
- Added missing `ZTIGather.xml` (was missing for a long time)
- Updated `PSDStart.ps1`: removed Legacy Wizard support; added UserExitScripts support
- Updated `PSDUtility.psm1`: added new functions to support `PSDStart` changes

**Resources**
- Updated INI files (`Bootstrap.ini`, `CustomSettings.ini` starter templates)
- Added `UserExitScripts` folder to `PSDResources` with sample scripts

---

## v0.2.3.0 — September 2024

**Wizard**
- Updated Deployment Wizard with new panes:
  - Intune enrollment configuration
  - Device role selection

**Task Sequences**
- Improved task sequence templates
- Enhanced prestart menu

**Installer**
- Updated `Install-PSD.ps1`

**Gather**
- Customized `ZTIGather.xml` for improved hardware data collection

---

## v0.2.2.9 — February 2024

**Driver Handling**
- Changed `ModelAlias` for VMware — all VMware models are now normalized to `"VMware"` regardless of specific model string reported by WMI

---

## v0.2.2.8 — September 2022

This was a major release with significant improvements across the board.

**Wizard**
- New PSD Wizard engine (`PSDWizardNew`) enabled via:
  ```ini
  PSDWizard=YES
  PSDWizardTheme=<ThemeName>
  ```

**Disk Handling**
- Improved disk detection and partitioning reliability

**Logging**
- Extended logging coverage across scripts
- Better transcript log handling

**Performance**
- Significant performance improvements across PSDStart and content download

**Code Quality**
- Extensive code cleanup and refactoring

**Drivers**
- Support for driver packages in **WIM format** (in addition to ZIP)

**Logging (Server-Side)**
- Server-side logging support via BITS upload
- Enabled via `SLShare` variable in `CustomSettings.ini`

---

## v0.2.2.7 and earlier

Earlier versions laid the foundation for the PSD architecture including:

- Initial PowerShell-based task sequence engine replacing VBScript
- HTTPS deployment support via IIS
- HTTP WebClient transport layer
- BranchCache/2Pint OSD Toolkit integration
- PSD Wizard (original XAML-based)
- Core module framework (PSDUtility, PSDGather, PSDDeploymentShare)
- x64-only deployments
- CMTrace-compatible logging

---

## Version Numbering

PSD uses semantic-style versioning `Major.Minor.Patch.Build`:

| Segment | Meaning |
|---|---|
| Major | Significant architectural changes |
| Minor | Feature additions |
| Patch | Bug fixes and minor updates |
| Build | Internal build number |

Current version: **0.2.3.1**

---

## Links

- [GitHub Repository](https://github.com/FriendsOfMDT/PSD)
- [Latest Release Setup Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20Latest%20Release%20Setup%20Guide.md)
- [Open Issues](https://github.com/FriendsOfMDT/PSD/issues)
- [Pull Requests](https://github.com/FriendsOfMDT/PSD/pulls)
