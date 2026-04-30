---
id: scenarios
title: Deployment Scenarios
sidebar_label: Deployment Scenarios
sidebar_position: 1
---

# Deployment Scenarios

PSD supports multiple deployment transport methods and use cases. This page summarizes what is currently supported.

---

## Transport Methods

| Transport | DeployRoot Format | Requirements |
|---|---|---|
| **SMB (UNC)** | `\\server\ShareName$` | Direct network SMB access; traditional MDT requirement |
| **HTTP** | `http://server/VirtualDir` | IIS configured without TLS |
| **HTTPS** | `https://server/VirtualDir` | IIS with a valid TLS certificate (recommended) |
| **HTTPS + BITS/BranchCache** | `https://server/VirtualDir` | IIS + 2Pint OSD Toolkit plugin |

---

## Deployment Types

### New / Bare-Metal

Deploy Windows to a device with no existing OS (or wipe and reload).

| Transport | Status |
|---|---|
| UNC (SMB) | ✅ Supported |
| HTTP | ✅ Supported |
| HTTPS | ✅ Supported |

**Recommended task sequence steps:**
1. Validate (`PSDValidate.ps1`)
2. Gather (`PSDGather.ps1`)
3. Partition (`PSDPartition.ps1`)
4. Apply OS (`PSDApplyOS.ps1`)
5. Configure (`PSDConfigure.ps1`)
6. Drivers (`PSDDrivers.ps1`)
7. Windows Update (`PSDWindowsUpdate.ps1`)
8. Applications (`PSDApplications.ps1`)
9. Tattoo (`PSDTattoo.ps1`)
10. Final (`PSDFinal.ps1`)

---

### Zero-Touch Deployment

Fully automated deployments with no user interaction. Achieved by setting all `Skip*` variables to `YES` in `CustomSettings.ini`.

See the [Zero-Touch Guide](./zero-touch) for detailed configuration.

---

### BranchCache / Peer-to-Peer

For environments where multiple clients deploy simultaneously across a shared network segment (e.g., a branch office), BranchCache enables clients to retrieve content from peers rather than the central server.

See the [BranchCache Guide](./branchwcache) for setup instructions.

---

### Refresh (In-Place Upgrade)

:::info Coming Soon
Refresh (in-place upgrade) deployments are **not yet implemented** in PSD. This is a planned feature.
:::

---

### Replace

:::info Coming Soon
Replace deployments (capture user data → deploy new OS → restore user data) are **not yet implemented**.
:::

---

### BIOS-to-UEFI

:::info Coming Soon
Automated BIOS-to-UEFI conversion as part of the deployment task sequence is **not yet implemented**.
:::

---

## Choosing Your Transport

```
Are you deploying across the internet or without VPN?
  ├── YES → Use HTTPS
  └── NO  → Are you concerned about WAN bandwidth?
              ├── YES → Use HTTPS + BranchCache (2Pint OSD Toolkit)
              └── NO  → UNC or HTTPS both work
```

**General recommendation:** Always use **HTTPS** — it works in all network scenarios including direct, internet-based, and VPN-based deployments, and it is the most secure.

---

## Supported Operating Systems for Deployment

### Client OS

| OS | Editions | Architecture |
|---|---|---|
| Windows 10 1909 | Pro, Education, Enterprise | x64 |
| Windows 10 2004 / 20H2 / 21H1 / 21H2 / 22H2 | Pro, Education, Enterprise | x64 |
| Windows 11 21H2 / 22H2 | Pro, Education, Enterprise | x64 |

### Server OS

| OS | Editions |
|---|---|
| Windows Server 2016 | Standard, Datacenter |
| Windows Server 2019 | Standard, Datacenter |
| Windows Server 2022 | Standard, Datacenter |

:::note
x86 support is disabled by default in PSD. The installer sets `SupportX86=False` on the deployment share.
:::
