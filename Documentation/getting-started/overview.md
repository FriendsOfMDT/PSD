---
id: overview
title: Overview
sidebar_label: Overview
sidebar_position: 1
---

# PSD Overview

PowerShell Deployment (PSD) is an extension to Microsoft Deployment Toolkit (MDT) that modernizes the Windows OS deployment pipeline. It preserves the familiar MDT Deployment Workbench workflow while replacing the underlying automation engine with PowerShell and adding support for HTTP/HTTPS-based content delivery.

---

## Why PSD?

Standard MDT has served the enterprise deployment community for many years, but it carries significant legacy:

- Automation relies on **VBScript** (`.wsf`/`.vbs`), which is no longer maintained.
- Content delivery is **SMB-only**, requiring line-of-sight network connections.
- Task sequences are complex and difficult to modify.
- No native support for cloud, remote, or P2P deployment scenarios.

PSD addresses all of these limitations.

---

## Key Capabilities

### PowerShell-Native Automation
Every stage of the task sequence — from boot to final cleanup — is executed by PowerShell scripts and modules. This makes the solution easier to debug, extend, and maintain.

### HTTP/HTTPS Transport
PSD exposes the deployment share over IIS, allowing clients to pull content over standard web protocols. This removes the SMB firewall requirement and enables:

- Internet-based deployments
- Cloud-hosted deployment shares
- Deployments across untrusted networks

### BranchCache / Peer-to-Peer
When used with [2Pint Software's OSD Toolkit](https://2pintsoftware.com/), PSD enables BITS-based peer-to-peer caching. Clients in the same subnet share downloaded content, dramatically reducing WAN bandwidth for large-scale rollouts.

### Simplified Task Sequences
PSD ships with streamlined task sequence templates that are easier to read, modify, and troubleshoot compared to standard MDT sequences.

### Modern Wizard UI
The PSD Wizard (`PSDWizardNew`) features an updated interface with dedicated panes for:
- Language and locale selection
- Domain/workgroup join
- Intune enrollment (0.2.3.0+)
- Device role assignment (0.2.3.0+)
- User-defined custom panes (via XAML themes)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      MDT Deployment Server                       │
│                                                                  │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │  MDT Workbench       │    │  PSD Deployment Share           │ │
│  │  (Management UI)     │    │  ├─ Scripts/   (PS scripts)     │ │
│  │                      │◄───│  ├─ Templates/ (TS templates)   │ │
│  │                      │    │  ├─ Control/   (ini files)      │ │
│  └─────────────────────┘    │  └─ PSDResources/               │ │
│                              └──────────────┬──────────────────┘ │
│                                             │                    │
│                                    ┌────────▼────────┐          │
│                                    │   IIS (HTTPS)   │          │
│                                    └────────┬────────┘          │
└─────────────────────────────────────────────┼───────────────────┘
                                              │ HTTPS / SMB
                              ┌───────────────▼───────────────┐
                              │         Target Device          │
                              │                                │
                              │  WinPE → PSDStart.ps1          │
                              │       → Task Sequence          │
                              │       → Windows Install        │
                              └───────────────────────────────┘
```

---

## PSD vs. Standard MDT

See the full comparison in the [PSD vs MDT](../reference/psd-vs-mdt) reference page.

---

## Repository Structure

```
PSD/
├── Branding/          # Background images and BGInfo config
├── Documentation/     # Official guides (Markdown)
├── INIFiles/          # Starter Bootstrap.ini and CustomSettings.ini
├── Plugins/           # Optional plugin integrations (OSD Toolkit)
├── PSDResources/      # Runtime resources (prestart, readiness, certs, scripts)
├── Scripts/           # All PSD PowerShell scripts and modules
├── Templates/         # MDT task sequence and deployment share templates
├── Tools/             # Supporting utilities and MDT modules
└── Install-PSD.ps1    # Main installer
```
