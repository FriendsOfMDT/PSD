---
id: debugging-logging
title: Debugging & Logging
sidebar_label: Debugging & Logging
sidebar_position: 1
---

# Debugging & Logging

PSD provides comprehensive logging using CMTrace-compatible log files and PowerShell transcript capture. This page covers how to enable debugging, interpret logs, and write custom log entries.

---

## Enabling Debug Mode

### Method 1: Bootstrap.ini (Persistent)

Add to `Bootstrap.ini` to enable debug mode for all deployments from that share:

```ini
[Default]
PSDDebug=YES
```

### Method 2: PSDStart.ps1 Command Line (Interactive)

Pass `-Debug` directly when invoking `PSDStart.ps1` from an interactive WinPE session:

```powershell
.\PSDStart.ps1 -Debug
```

This is the recommended approach for interactive troubleshooting in WinPE without changing the Bootstrap.ini.

---

## Log Files

### PSD.log

The primary PSD deployment log. Located in the PSD local cache folder during deployment:

```
X:\MININT\SMSOSD\OSDLOGS\PSD.log        # WinPE phase
C:\MININT\SMSOSD\OSDLOGS\PSD.log        # Full OS phase
```

### BDD.log

MDT base deployment log. Co-located with PSD.log.

### Transcript Logs

PowerShell transcript logs capture **everything** that appears in the PowerShell console — output, warnings, errors, verbose messages. These are more comprehensive than PSD.log and are the best source for troubleshooting.

```
X:\MININT\SMSOSD\OSDLOGS\PSD_Transcript_YYYYMMDD_HHMMSS.log
```

:::tip
Use the **CMTrace** tool (included with MDT at `C:\Program Files\Microsoft Deployment Toolkit\Tools\CMTrace.exe`) to view `.log` files with color-coded severity levels.
:::

---

## Log Format

PSD uses CMTrace-compatible log entries written by `Write-PSDLog`:

```
<![LOG[PSDApplyOS: Applying OS image to C:\]LOG]!><time="14:23:01.245+000" date="02-27-2026" component="PSDApplyOS.ps1:142" context="" type="1" thread="" file="">
```

| Field | Description |
|---|---|
| `LOG[...]LOG` | Log message text |
| `time` | Timestamp with milliseconds |
| `date` | Date (MM-DD-YYYY) |
| `component` | Calling script name and line number |
| `type` | Severity: `1`=Info, `2`=Warning, `3`=Error |

---

## Writing Log Entries

Use `Write-PSDLog` in all PSD scripts and custom extensions:

```powershell
Import-Module PSDUtility

# Info
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Starting driver injection"

# Warning
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Driver package not found, skipping" -LogLevel 2

# Error
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Failed to connect to deployment share" -LogLevel 3
```

---

## Server-Side Log Collection

Automatically upload logs to a central share at the end of deployment:

```ini
# CustomSettings.ini
SLShare=\\psd-server\DeployLogs$
```

Logs are uploaded by `PSDCopyLogs.ps1` as a task sequence step.

---

## Viewing Logs During Deployment

In WinPE with debug mode enabled, you can open a secondary PowerShell window to monitor the log in real time:

```powershell
# In a secondary WinPE PowerShell window
Get-Content X:\MININT\SMSOSD\OSDLOGS\PSD.log -Wait -Tail 50
```

---

## Dumping Task Sequence Variables

The `DumpVars.ps1` helper script enumerates all current task sequence variables:

```powershell
# Run in a WinPE PowerShell session
.\DumpVars.ps1
```

This is invaluable for verifying that `PSDGather.ps1` collected the expected hardware data or that your `CustomSettings.ini` rules evaluated correctly.

---

## Common Debugging Scenarios

### "Failed to connect to deployment share"
- Verify `DeployRoot` URL is reachable from WinPE
- Check TLS certificate validity and trust (for HTTPS)
- Verify build account credentials in `Bootstrap.ini`
- Test with: `Invoke-WebRequest -Uri $DeployRoot -Credential $cred`

### "Script not found" errors
- Verify PSD files were correctly deployed during installation
- Check that `Install-PSD.log` shows no errors
- Confirm `Scripts\` folder in the deployment share contains `PSDStart.ps1`

### Task sequence variable not set
- Run `DumpVars.ps1` to see all current TS variables
- Check `PSD.log` for gather section output
- Verify `CustomSettings.ini` rule priority and section names

### Application install failure
- Check application GUID is wrapped in `{ }` in `CustomSettings.ini`
- Verify application source files are present in the deployment share
- Check `ZTIApplication*` entries in `PSD.log`
