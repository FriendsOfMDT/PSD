---
id: prerequisites
title: Prerequisites
sidebar_label: Prerequisites
sidebar_position: 2
---

# Prerequisites

Before installing PSD, ensure all the following requirements are met on the server that will host the MDT/PSD deployment share.

---

## Server Operating System

PSD has been tested and is supported on:

| OS | Support |
|---|---|
| Windows Server 2016 | ✅ Supported |
| Windows Server 2019 | ✅ Supported |
| Windows Server 2022 | ✅ Supported |

---

## Required Software

Install these components in the following order on your deployment server:

### 1. Windows Assessment and Deployment Kit (ADK)

The Windows ADK provides the tools required to build WinPE boot images.

| ADK Version | Build | Support |
|---|---|---|
| Windows ADK 10 2004 | 19041 | ✅ |
| Windows ADK for Windows 11 22H2 | 22621 | ✅ |

**Downloads:**
- [Latest ADK](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)
- [Older ADK versions](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install#other-adk-downloads)

:::caution
Minimum supported ADK build: **17763** (Windows 10 1809 / ADK 1809).  
The installer will abort if a lower version is detected.
:::

### 2. WinPE Add-on for ADK

The WinPE Add-on is a separate download from the ADK that provides the Windows PE environment files required to build boot images.

- Download the WinPE Add-on that **matches your ADK version** from the same page as the ADK.

### 3. Microsoft Deployment Toolkit (MDT)

| MDT Version | Notes |
|---|---|
| MDT 8456 (6.3.8456.1000) | Required. Apply the HotFix below. |

**Downloads:**
- [MicrosoftDeploymentToolkit_x64.msi](https://www.microsoft.com/en-us/download/details.aspx?id=54259)
- [MDT 8456 HotFix (KB4564442)](https://support.microsoft.com/en-us/topic/windows-10-deployments-fail-with-microsoft-deployment-toolkit-on-computers-with-bios-type-firmware-70557b0b-6be3-81d2-556f-b313e29e2cb7) — Required for Windows 10 deployments on BIOS-based hardware

---

## Required Accounts

| Account | Required Permissions | Purpose |
|---|---|---|
| **Installation Account** | Local Administrator on the MDT Server | Run `Install-PSD.ps1` |
| **Build Account** | Read access to the deployment share | Authenticate from WinPE clients during deployment |
| **Domain Join Account** | Permission to join computers to Active Directory | Join deployed systems to the domain |

:::note
Domain join currently requires line-of-sight to a Domain Controller from the deployment target.
:::

---

## Source Media

Gather the following before running task sequences:

- **OS Source Media** — Windows 10/11 or Server ISO files
- **Application Source Media** — Installers for applications deployed via task sequence
- **Driver Source Media** — OEM hardware drivers for target systems

For PSD, drivers should be organized by model and prepared as **WIM or ZIP archives**. See [Driver Packaging](../advanced/driver-packaging).

---

## Optional: Windows Deployment Services (WDS)

WDS is only required if you plan to perform **PXE-based network boots**. It is not required for deployments via ISO or pre-staged USB media.

---

## Optional: IIS

IIS is required for HTTP/HTTPS-based deployments. While the PSD installer does not configure IIS for you, it is strongly recommended for all production environments.

See the [IIS Configuration Guide](../deployment/iis-setup) after completing the installation.

---

## Client Hardware Requirements

Target devices being deployed must meet these minimums:

| Resource | Minimum |
|---|---|
| RAM | **1.5 GB** (WinPE with PSD requires more memory than standard MDT) |
| Network Adapters | 1 |
| Hard Drive | 50 GB (for new/bare-metal deployments) |
| Architecture | x64 (x86 support is disabled by default) |

---

## Checklist Summary

Before proceeding to installation, confirm:

- [ ] Windows Server 2016/2019/2022 installed
- [ ] Windows ADK (build ≥ 17763) installed
- [ ] WinPE Add-on for ADK installed
- [ ] MDT 8456 installed and patched with KB4564442
- [ ] Installation account has local admin rights
- [ ] Build account and domain join account created
- [ ] OS source media obtained
- [ ] Application and driver media gathered (optional but recommended)
