---
id: zero-touch
title: Zero-Touch Deployment
sidebar_label: Zero-Touch Deployment
sidebar_position: 4
---

# Zero-Touch Deployment

Zero-Touch deployment (ZTD) eliminates all user interaction during the OS deployment process. Devices boot, connect to the deployment share, and complete the full task sequence — including partitioning, OS application, driver injection, domain join, and application installation — without any technician input.

For the full guide, see the [official ZeroTouch Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/Powershell%20Deployment%20-%20ZeroTouch%20Guide.md).

---

## Prerequisites

- PSD installed with HTTPS transport configured (see [IIS Configuration](./iis-setup))
- All wizard prompts suppressible via `CustomSettings.ini`
- A task sequence ID that can be auto-selected based on hardware properties
- Domain join account credentials stored in `CustomSettings.ini`

---

## CustomSettings.ini for Zero-Touch

The following configuration fully automates a PSD deployment:

```ini
[Settings]
Priority=TaskSequenceID, Model, Default
Properties=

########################################
# Zero-Touch: Skip all wizard prompts  #
########################################
[Default]
OSInstall=Y

# Skip all wizard panes
SkipBDDWelcome=YES
SkipWizard=YES
SkipCapture=YES
SkipAdminPassword=YES
SkipProductKey=YES
SkipComputerBackup=YES
SkipBitLocker=YES
SkipComputerName=YES
SkipDomainMembership=YES
SkipUserData=YES
SkipLocaleSelection=YES
SkipTimeZone=YES
SkipApplications=YES
SkipSummary=YES
SkipFinalSummary=YES

# Locale and time
UILanguage=en-US
UserLocale=en-US
KeyboardLocale=0409:00000409
TimeZoneName=Eastern Standard Time

# Computer naming — uses serial number
OSDComputerName=%SerialNumber%

# Domain join
JoinDomain=CONTOSO
MachineObjectOU=OU=Workstations,OU=Computers,DC=CONTOSO,DC=COM
DomainAdmin=svc-domainjoin
DomainAdminDomain=CONTOSO
DomainAdminPassword=P@ssw0rd!

# Local admin password
AdminPassword=P@ssw0rd!

# Task sequence selection
TaskSequenceID=WIN11-ZTD

# Logging
SLShare=\\psd-server\DeployLogs$
```

---

## Auto-Selecting Task Sequences by Hardware

Use model-based sections to deploy different task sequences to different hardware:

```ini
[Settings]
Priority=Model, Default

[HP ZBook 15 G8]
TaskSequenceID=WIN11-LAPTOP

[Dell OptiPlex 7090]
TaskSequenceID=WIN11-DESKTOP

[VMware Virtual Platform]
TaskSequenceID=WIN11-VM

[Default]
TaskSequenceID=WIN11-GENERIC
```

---

## PXE Boot Configuration

For fully hands-free deployment, configure WDS to automatically boot target devices to the PSD WinPE image:

1. Import the PSD boot image (`PSDLiteTouch_x64.wim`) into WDS
2. Set the WDS response policy to **Respond to all client computers** (or use pre-staging + auto-approval)
3. Configure WDS to automatically select the PSD boot image without prompting

```powershell
# Disable F12 prompt for PXE boot (auto-boot after timeout)
Set-WdsBootImage -Architecture x64 `
    -FileName "boot\x64\PSDLiteTouch_x64.wim" `
    -NewDescription "PSD Zero-Touch Image" `
    -DisplayOrder 1
```

---

## Computer Naming Strategies

| Variable | Example Result | Description |
|---|---|---|
| `%SerialNumber%` | `5CG1234XYZ` | Hardware serial number |
| `%UUID%` | `4C4C4544-...` | System UUID |
| `%AssetTag%` | `ASSET001` | Asset tag (if set in BIOS) |
| `%MacAddress%` | `001A2B3C4D5E` | Primary NIC MAC address |

Custom naming via prefix:
```ini
OSDComputerName=WS-%SerialNumber%
```

---

## Monitoring Zero-Touch Deployments

Enable server-side logging to collect logs from all deployments:

```ini
SLShare=\\psd-server\DeployLogs$
SLShareDynamicLogging=\\psd-server\DeployLogs$
```

Monitor the `SLShare` folder for `BDD.log` and `PSD.log` files from each deployment.
