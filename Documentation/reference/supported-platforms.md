---
id: supported-platforms
title: Supported Platforms
sidebar_label: Supported Platforms
sidebar_position: 1
---

# Supported Platforms

This page lists the tested and validated configurations for PSD as of the current release.

---

## MDT Server

### Operating System

| OS | Support |
|---|---|
| Windows Server 2016 (Standard / Datacenter) | ✅ |
| Windows Server 2019 (Standard / Datacenter) | ✅ |
| Windows Server 2022 (Standard / Datacenter) | ✅ |

### Required Software

| Component | Version | Notes |
|---|---|---|
| MDT | 8456 (6.3.8456.1000) | With KB4564442 HotFix |
| Windows ADK 10 | Build ≥ 17763 (1809) | 2004 or later recommended |
| WinPE Add-on for ADK | Matching ADK version | Required |

---

## Target Devices — Client OS

| Operating System | Editions | Architecture | Status |
|---|---|---|---|
| Windows 10 1909 | Pro, Education, Enterprise | x64 | ✅ |
| Windows 10 2004 | Pro, Education, Enterprise | x64 | ✅ |
| Windows 10 20H2 | Pro, Education, Enterprise | x64 | ✅ |
| Windows 10 21H1 | Pro, Education, Enterprise | x64 | ✅ |
| Windows 10 21H2 | Pro, Education, Enterprise | x64 | ✅ |
| Windows 10 22H2 | Pro, Education, Enterprise | x64 | ✅ |
| Windows 11 21H2 | Pro, Education, Enterprise | x64 | ✅ |
| Windows 11 22H2 | Pro, Education, Enterprise | x64 | ✅ |

:::note
All tested OS editions are English language MSDN/Evaluation or Volume License media.  
x86 is **not supported** — PSD disables x86 deployments by default.
:::

---

## Target Devices — Server OS

| Operating System | Editions | Status |
|---|---|---|
| Windows Server 2016 | Standard, Datacenter (English) | ✅ |
| Windows Server 2019 | Standard, Datacenter (English) | ✅ |
| Windows Server 2022 | Standard, Datacenter (English) | ✅ |

---

## Virtualization

| Hypervisor | Status | Notes |
|---|---|---|
| Microsoft Hyper-V | ✅ Tested | Both client deployments and MDT/PSD server hosting |
| VMware (any model) | ✅ Tested | All VMware models aliased to `"VMware"` since v0.2.2.9 |
| Other | ⚠️ Untested | May work; report results to the community |

---

## Deployment Scenarios Status

| Scenario | Transport | Status |
|---|---|---|
| Bare-Metal | UNC | ✅ |
| Bare-Metal | HTTP | ✅ |
| Bare-Metal | HTTPS | ✅ |
| Bare-Metal | HTTPS + BranchCache | ✅ (requires 2Pint OSD Toolkit) |
| Zero-Touch | Any | ✅ |
| Refresh (In-Place Upgrade) | Any | ❌ Not yet implemented |
| Replace | Any | ❌ Not yet implemented |
| BIOS-to-UEFI | Any | ❌ Not yet implemented |

---

## Target Hardware Requirements

| Resource | Minimum |
|---|---|
| RAM | 1.5 GB |
| Network Adapters | 1 |
| Hard Drive | 50 GB |
| Architecture | x64 |
| Firmware | BIOS or UEFI |

---

## WinPE Components Injected

The following optional WinPE components are automatically included in PSD boot images via `LiteTouchPE.XML`:

| Component |
|---|
| `winpe-dismcmdlets` |
| `winpe-enhancedstorage` |
| `winpe-fmapi` |
| `winpe-hta` |
| `winpe-netfx` |
| `winpe-powershell` |
| `winpe-scripting` |
| `winpe-securebootcmdlets` |
| `winpe-securestartup` |
| `winpe-storagewmi` |
| `winpe-wmi` |

:::tip
You do **not** need to manually configure WinPE features in the MDT Workbench. PSD handles this automatically — unchecking/checking boxes in the WinPE features tab has no effect on PSD boot media.
:::
