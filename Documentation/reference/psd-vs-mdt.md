---
id: psd-vs-mdt
title: PSD vs MDT
sidebar_label: PSD vs MDT
sidebar_position: 3
---

# PSD vs Standard MDT

This page provides a detailed comparison between standard Microsoft Deployment Toolkit (MDT) and PSD-extended MDT to help you understand when to use each and what changes when PSD is applied.

---

## Summary

| Feature | Standard MDT | PSD-Extended MDT |
|---|---|---|
| **Automation Language** | VBScript (`.wsf`, `.vbs`) | PowerShell (`.ps1`, `.psm1`) |
| **Network Transport** | SMB/UNC only | SMB, HTTP, HTTPS |
| **Content Delivery** | Individual file copy over SMB | Single archive download (HTTP/HTTPS) |
| **Driver Handling** | Individual `.inf` files | Per-model WIM/ZIP archives |
| **Task Sequence Complexity** | Complex, multi-step legacy sequences | Simplified, modern sequences |
| **Wizard** | MDT XAML Wizard | PSD Wizard (new panes, themes) |
| **P2P / BranchCache** | Not supported | Supported (via 2Pint OSD Toolkit) |
| **Internet Deployment** | Not supported | Supported (HTTPS) |
| **Script Debuggability** | Difficult (VBScript) | Easy (PowerShell debugger) |
| **Log Format** | CMTrace `.log` | CMTrace `.log` + Transcript logs |
| **x86 Support** | Supported | Disabled by default |
| **MDT Workbench** | Full use | Full use (management only) |

---

## Task Sequence Script Mapping

When PSD is installed, the following MDT VBScripts are replaced by PowerShell equivalents:

| MDT Script | PSD Equivalent | Function |
|---|---|---|
| `LiteTouch.wsf` | `PSDStart.ps1` | Entry point / TS orchestration |
| `ZTIGather.wsf` | `PSDGather.ps1` | Environment data collection |
| `ZTIDiskpart.wsf` | `PSDPartition.ps1` | Disk partitioning |
| `LTIApply.wsf` | `PSDApplyOS.ps1` | OS image application |
| `ZTIConfigure.wsf` | `PSDConfigure.ps1` | Unattend.xml generation |
| `ZTIDrivers.wsf` | `PSDDrivers.ps1` | Driver staging |
| `ZTIApplications.wsf` | `PSDApplications.ps1` | Application installation |
| `ZTIWindowsUpdate.wsf` | `PSDWindowsUpdate.ps1` | Windows Update |
| `ZTISetVariable.wsf` | `PSDSetVariable.ps1` | Set TS variables |
| `ZTIValidate.wsf` | `PSDValidate.ps1` | System validation |

---

## What Stays the Same

When using PSD, the following MDT components and workflows remain **unchanged**:

- **MDT Deployment Workbench** — Used for managing deployment shares, importing content, and building boot images
- **Bootstrap.ini / CustomSettings.ini** — INI file format, priority logic, and rule processing are identical
- **Task sequence editor** — Visual task sequence editor in the Workbench
- **Operating System import** — Import Windows images via the Workbench as usual
- **Application management** — Import and manage applications via the Workbench
- **Driver import** (preparation only) — You still import drivers to the Workbench for driver package creation
- **MDT databases** — MDT database integration works normally
- **Selection profiles** — Content selection profiles work as in standard MDT

---

## What Changes

| Area | Change |
|---|---|
| Boot media | PSD boot media includes PowerShell modules and scripts; does not include VBScript files |
| Task sequences | PSD ships with new task sequence templates that reference PSD scripts |
| Drivers | Must be organized into WIM/ZIP archives per model |
| Deployment share SMB | Still created, but HTTPS (IIS) is the recommended transport |
| Existing MDT task sequences | Stop working in a PSD-extended share (VBScripts removed) |

---

## Should I Use PSD or Standard MDT?

Use **PSD** if:
- You need HTTPS-based deployments (cloud, internet, remote office)
- You want P2P/BranchCache bandwidth savings
- You are building a new deployment infrastructure from scratch
- You want a modern, PowerShell-only deployment pipeline

Use **Standard MDT** if:
- All your deployments are on a LAN with guaranteed SMB access
- You have heavily customized existing MDT task sequences you cannot migrate
- You rely on MDT features not yet implemented in PSD (Refresh, Replace, BIOS-to-UEFI)
