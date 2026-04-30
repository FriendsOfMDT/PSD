---
id: intro
title: Introduction to PowerShell Deployment
sidebar_label: Introduction
slug: /intro
---

# Introduction to PowerShell Deployment (PSD)

**PowerShell Deployment (PSD)** is a modern extension for **Microsoft Deployment Toolkit (MDT)** that replaces the legacy VBScript-based deployment engine with a fully PowerShell-driven framework. PSD adds native support for **HTTP/HTTPS-based deployments**, enabling cloud imaging, remote provisioning, and peer-to-peer (BranchCache) scenarios that are not possible with standard MDT.

> **Repository:** [https://github.com/FriendsOfMDT/PSD](https://github.com/FriendsOfMDT/PSD)  
> **License:** MIT  
> **Current Version:** 0.2.3.1 (December 2025)

---

## Background

The standard MDT task sequence engine has its origins in the OSD Feature Pack for SMS 2003. PSD was created to modernize this foundation — replacing VBScripts with PowerShell, updating the deployment transport from SMB-only to HTTP/HTTPS, and simplifying task sequences for modern Windows environments.

PSD is built on top of MDT and still leverages the **MDT Deployment Workbench** for managing deployment shares, applications, drivers, and operating system images. It is not a replacement for MDT — it is an extension of it.

---

## What PSD Changes

| Aspect | Standard MDT | PSD-Extended MDT |
|---|---|---|
| Client automation engine | VBScript (`.wsf`, `.vbs`) | PowerShell (`.ps1`, `.psm1`) |
| Network transport | UNC (SMB) only | UNC, HTTP, or HTTPS |
| Deployment share connection | Direct SMB drive mapping | PowerShell PSDrive via `PSDDeploymentShare.psm1` |
| Driver handling | Individual files imported into Workbench | Per-model WIM or ZIP archives |
| Task sequence complexity | Complex, legacy MDT structure | Simplified and modernized |
| Wizard | MDT XAML wizard | New PSD Wizard with Intune/role panes |

---

## Supported Transport Methods

- **IIS over HTTPS** using native PowerShell `WebClient`
- **IIS over HTTPS with BITS & BranchCache** using [2Pint Software's OSD Toolkit](https://2pintsoftware.com/)

---

## Deployment Flow

```
WinPE Boot (PXE / ISO)
        │
        ▼
  PSDStart.ps1  ──── Connects to deployment share (SMB / HTTP / HTTPS)
        │           Synchronizes system clock
        ▼
  PSDGather.ps1 ──── Collects hardware info
                     Processes Bootstrap.ini and CustomSettings.ini
        │
        ▼
  PSD Wizard    ──── (Optional) End-user interaction
        │
        ▼
  Task Sequence:
    PSDPartition.ps1      – Partition and format disks
    PSDApplyOS.ps1        – Apply OS image + inject drivers (DISM)
    PSDConfigure.ps1      – Generate Unattend.xml
    PSDDrivers.ps1        – Download driver packages to local cache
    PSDWindowsUpdate.ps1  – Run Windows Update
    PSDApplications.ps1   – Install applications
    PSDRoleInstall.ps1    – Install Windows roles/features
    PSDTattoo.ps1         – Record deployment metadata
    PSDFinal.ps1          – Clean up and finalize
```

---

## The Team

PSD is developed and maintained by:

| Name | Handle |
|---|---|
| Mikael Nystrom | [@mikael_nystrom](https://twitter.com/mikael_nystrom) |
| Johan Arwidmark | [@jarwidmark](https://github.com/arwidmark) |
| Michael Niehaus | [@mniehaus](https://github.com/mtniehaus) |
| Steve Campbell | [@SoupAtWork](https://github.com/soupman98) |
| Jordan Benzing | [@JordanTheItGuy](https://github.com/JordanTheITGuy) |
| Andreas Hammarskjold | [@AndHammarskjold](https://github.com/Hammarskjold) |
| Richard "Dick" Tracy | [@PowerShellCrack](https://github.com/PowerShellCrack) |
| George Simos | [@GSimos](https://github.com/GeoSimos) |
| Elias Markelis | [@emarkelis](https://github.com/emarkelis) |

---

## Next Steps

Follow the documentation in order for a first-time setup:

1. [Prerequisites](./getting-started/prerequisites) — Required software and accounts
2. [Installation](./getting-started/installation) — Install PSD onto your MDT server
3. [IIS Setup](./deployment/iis-setup) — Configure HTTPS transport
4. [Configuration](./configuration/bootstrap-ini) — Set up `Bootstrap.ini` and `CustomSettings.ini`
