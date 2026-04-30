---
id: driver-packaging
title: Driver Packaging
sidebar_label: Driver Packaging
sidebar_position: 2
---

# Driver Packaging

PSD uses a fundamentally different approach to driver management compared to standard MDT. Rather than importing individual driver files into the Deployment Workbench, PSD uses **per-model driver archives** (WIM or ZIP format) for efficient download and injection.

---

## Why Archives?

| Standard MDT | PSD |
|---|---|
| Imports thousands of individual `.inf`, `.sys`, `.dll` files | Packages all drivers into a single WIM or ZIP |
| Each file downloaded individually over the network | Single large file downloaded; far more efficient over HTTPS |
| Works well with SMB; slow over HTTP | Optimized for BITS/HTTPS/BranchCache |

---

## Driver Package Structure

Place driver packages in the `DriverPackages\` folder within `PSDResources\`:

```
PSDResources\
└── DriverPackages\
    ├── Microsoft\
    │   └── Surface Pro 9\
    │       └── Drivers.wim
    ├── HP\
    │   └── HP ZBook 15 G8\
    │       └── Drivers.wim
    └── Dell\
        └── OptiPlex 7090\
            └── Drivers.wim
```

The folder structure should match `<Make>\<Model>\` where `Make` and `Model` are the values collected by `PSDGather.ps1` from WMI:  
`Win32_ComputerSystem.Manufacturer` and `Win32_ComputerSystem.Model`

---

## Creating Driver Archives from MDT

If you already have drivers imported into MDT's Deployment Workbench, you can export them to WIM format:

```powershell
# Import MDT module
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\Bin\MicrosoftDeploymentToolkit.psd1"
New-PSDrive -Name DS001 -PSProvider MDTProvider -Root "D:\MDT"

# Export all driver source files for a specific model to a WIM
$driverPath = "D:\MDT\Out-of-Box Drivers\HP\HP ZBook 15 G8"
$outputWim  = "D:\PSD\PSDResources\DriverPackages\HP\HP ZBook 15 G8\Drivers.wim"

New-Item -ItemType Directory -Path (Split-Path $outputWim) -Force | Out-Null

DISM /Capture-Dir:$driverPath /ImageFile:$outputWim /Name:"HP ZBook 15 G8 Drivers" /Compress:Fast
```

---

## Creating Driver Archives from Scratch

### From a Folder of Drivers

```powershell
$driverSourcePath = "C:\Drivers\Dell\OptiPlex 7090"
$outputWim = "D:\PSD\PSDResources\DriverPackages\Dell\OptiPlex 7090\Drivers.wim"

New-Item -ItemType Directory -Path (Split-Path $outputWim) -Force | Out-Null

DISM /Capture-Dir:$driverSourcePath /ImageFile:$outputWim /Name:"Dell OptiPlex 7090 Drivers" /Compress:Fast
```

### ZIP Format (Alternative)

PSD also supports ZIP archives:

```powershell
$driverSourcePath = "C:\Drivers\Dell\OptiPlex 7090"
$outputZip = "D:\PSD\PSDResources\DriverPackages\Dell\OptiPlex 7090\Drivers.zip"

Compress-Archive -Path "$driverSourcePath\*" -DestinationPath $outputZip
```

---

## Model Alias Mapping

Some hardware vendors report different model strings across BIOS versions, or you may want to map unusual model names to a folder name. PSD inherits MDT's `ModelAlias` feature in `CustomSettings.ini`:

```ini
[Settings]
Priority=Model, Default

[VMware7,1]
ModelAlias=VMware Virtual Platform

[VMware Virtual Platform]
TaskSequenceID=WIN11-VM
```

As of **v0.2.2.9**, all VMware models are automatically aliased to `"VMware"`.

---

## Verifying Driver Package Mapping

Use `DumpVars.ps1` after the gather phase to confirm `Make` and `Model` values:

```powershell
.\DumpVars.ps1 | Where-Object { $_ -match "Make|Model" }
```

Then verify a matching folder exists under `PSDResources\DriverPackages\<Make>\<Model>\`.

---

## Driver Injection

Drivers are injected into the **offline OS image** by `PSDApplyOS.ps1` using DISM:

```
DISM /Image:<OSPath> /Add-Driver /Driver:<CachedDriverPath> /Recurse
```

This happens after the OS image is applied to disk but before the first reboot — ensuring all drivers are present before Windows runs for the first time.
