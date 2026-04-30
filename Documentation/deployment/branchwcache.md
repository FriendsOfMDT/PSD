---
id: branchwcache
title: BranchCache / P2P
sidebar_label: BranchCache / P2P
sidebar_position: 3
---

# BranchCache and Peer-to-Peer Deployments

PSD supports **BranchCache-based peer-to-peer (P2P) content delivery** through integration with [2Pint Software's OSD Toolkit](https://2pintsoftware.com/). This enables clients deploying on the same network segment to share downloaded content, dramatically reducing WAN and server bandwidth consumption during large-scale rollouts.

---

## How It Works

```
First client in a subnet:
  Downloads OS/drivers from PSD Server (HTTPS + BITS)
  → Content is cached locally (BranchCache)

Subsequent clients in the same subnet:
  BranchCache detects peers with cached content
  → Downloads from peers instead of server
  → Only downloads missing/changed chunks from server
```

---

## Requirements

| Component | Details |
|---|---|
| [2Pint Software OSD Toolkit](https://2pintsoftware.com/) | Commercial plugin providing BITS/BranchCache integration |
| PSD with HTTPS configured | See [IIS Configuration](./iis-setup) |
| Windows BranchCache feature | Enabled on deployment server and IIS |
| WinPE BranchCache support | Provided by OSD Toolkit WinPE injection |

---

## Setup Overview

Full step-by-step instructions are in the official [BranchCache Installation Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20BranchCache%20Installation%20Guide.md).

### High-Level Steps

1. **Complete IIS HTTPS setup** — BranchCache requires content served over HTTPS with BITS enabled.

2. **Install OSD Toolkit** on the deployment server.

3. **Enable BranchCache on IIS** — Allow BITS transfers for the PSD virtual directory.

4. **Copy OSD Toolkit WinPE components** to the `Plugins\OSDToolkit\` folder in your deployment share.

5. **Configure `CustomSettings.ini`** to enable the OSD Toolkit plugin:
   ```ini
   PSDPlugin=OSDToolkit
   ```

6. **Rebuild boot images** in the MDT Deployment Workbench — the OSD Toolkit components will be injected into WinPE.

7. **Enable Distributed Cache mode** on the IIS server:
   ```powershell
   Enable-BCDistributed
   ```

---

## BranchCache Requirements on Target Clients

BranchCache operates in WinPE, so clients must:
- Boot from a PSD-capable WinPE image with OSD Toolkit injected
- Have network connectivity to at least one subnet peer or the PSD server

---

## Bandwidth Considerations

BranchCache is most effective when:
- Multiple clients (~5 or more) deploy concurrently in the same subnet
- OS images and driver packages are large (1+ GB)
- WAN links to the central deployment server are constrained (< 100 Mbps)

For single-device or high-speed LAN deployments, standard HTTPS without BranchCache is simpler and equally performant.

---

## Troubleshooting

Check BITS transfer status in WinPE:
```powershell
Get-BitsTransfer | Format-List
```

Check BranchCache statistics:
```powershell
Get-BCStatus
Get-BCDataCache
```
