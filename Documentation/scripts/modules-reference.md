---
id: modules-reference
title: Modules Reference
sidebar_label: Modules Reference
sidebar_position: 2
---

# PSD PowerShell Modules Reference

PSD modules (`.psm1`) are loaded into the deployment environment and provide shared functions used across all PSD scripts. They reside in `Scripts\` and are deployed to `Tools\Modules\` within the deployment share.

---

## PSDUtility.psm1

The **core utility module** that must be imported by every PSD script. Provides shared logging, path management, and common helper functions.

### Key Functions

#### Write-PSDLog

The standard logging function for all PSD scripts and custom extensions.

```powershell
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Your message here"
Write-PSDLog -Message "An error occurred" -LogLevel 3
```

| Parameter | Type | Description |
|---|---|---|
| `-Message` | String | The message to log |
| `-LogLevel` | Int (1-3) | `1` = Info (verbose), `2` = Warning, `3` = Error (written to `$Error`) |

**Log output format (CMTrace-compatible):**
```
<![LOG[PSDApplyOS: Applying OS image]LOG]!><time="14:23:01.245+000" date="02-27-2026" component="PSDApplyOS.ps1:142" context="" type="1" thread="" file="">
```

#### Get-PSDLocalDataPath

Returns the local cache path used by PSD during deployment. Uses a cached path if one was set in a previous step.

```powershell
$localPath = Get-PSDLocalDataPath
```

#### Set-PSDDefaultLogPath

Initializes the log file path at script startup. Called automatically at the beginning of each PSD script.

```powershell
Set-PSDDefaultLogPath
```

#### Get-PSDContent

Downloads content from the deployment share (via SMB, HTTP, or HTTPS) to the local PSD cache.

```powershell
Get-PSDContent -Source "Deploy\Scripts\PSDApplyOS.ps1" -Destination $localPath
```

#### Invoke-PSDHelper

Runs a command with logging and error handling.

#### Start-PSDSequence / Resume-PSDSequence

Manages task sequence state — starting a new sequence or resuming from the last checkpoint after a restart.

#### Set-PSDCommandLine

Sets the command to run at the next boot (via `winpeshl.ini` or `SetupComplete.cmd`) to resume the task sequence.

---

## PSDGather.psm1

Provides all hardware and environment data collection functions. Reads `ZTIGather.xml` to determine which WMI queries and rules to evaluate.

### Key Functions

#### Invoke-PSDRules

Processes a given INI file (Bootstrap.ini or CustomSettings.ini) and evaluates priority sections. Results are applied to task sequence variables.

```powershell
Invoke-PSDRules -FilePath "$deployRoot\Control\Bootstrap.ini" -MappingFile $mappingFile
```

#### Get-PSDGatherFacts

Gathers hardware facts from WMI/CIM and stores them as task sequence variables. Collects:
- `Make`, `Model`, `SerialNumber`, `UUID`, `AssetTag`
- `Memory`, `ProcessorSpeed`
- `IsVM`, `IsLaptop`, `IsDesktop`
- `IPAddress`, `MACAddress`, `DefaultGateway`, `DNSServers`
- `IsUEFI`, `SecureBootEnabled`
- `OSDisk`, `FreeDiskSpace`

---

## PSDDeploymentShare.psm1

Abstracts all deployment share connectivity. PSD scripts never connect to the share directly — they always go through this module, which handles the transport transparently.

### Key Functions

#### Get-PSDConnection

Establishes a connection to the deployment share using the transport defined in `DeployRoot`:

- **SMB** — Creates a mapped network drive
- **HTTP/HTTPS** — Creates a custom PSDrive backed by WebClient

```powershell
Get-PSDConnection -deployRoot $deployRoot -username $user -password $pass
```

#### Get-PSDProvider

Returns the deployment share provider type (`SMB` or `HTTP`) for a given path.

#### Copy-PSDFile

Downloads or copies a file from the deployment share using the appropriate transport.

---

## PSDWizardNew.psm1

Drives the new PSD Wizard UI. Loads XAML pane definitions from `Scripts\PSDWizardNew\`, handles user input, and writes selections back to task sequence variables.

### Key Functions

#### Show-PSDWizard

Displays the wizard based on enabled panes and current `Skip*` variable values.

```powershell
Show-PSDWizard -ResourcePath "$deployRoot\Scripts\PSDWizardNew" -Theme "Classic"
```

#### Get-PSDWizardPages

Returns the list of active wizard panes based on `Skip*` variable state.

---

## PSDStartLoader.psm1

Handles the initial loading and environment bootstrapping sequence for `PSDStart.ps1`. Supports the **UserExitScripts** framework introduced in v0.2.3.1.

### Key Functions

#### Invoke-PSDUserExitScript

Discovers and executes scripts from `PSDResources\UserExitScripts\` at defined hook points in the deployment lifecycle.

```powershell
Invoke-PSDUserExitScript -Phase "PreStart"
Invoke-PSDUserExitScript -Phase "PostGather"
```

---

## ZTIUtility.psm1

Retained MDT utility module providing compatibility functions required for application installation (`PSDApplications.ps1`) and other MDT-derived operations.

:::note
Do not delete `ZTIUtility.vbs` from your deployment share if you are installing applications via task sequence — it may be called by legacy application install scripts.
:::

---

## MDT Provider Modules

The following MDT provider DLLs are copied to `Tools\Modules\Microsoft.BDD.PSSnapIn\` during installation and are required for PSD to interact with MDT:

| File | Description |
|---|---|
| `Microsoft.BDD.PSSnapIn.dll` | MDT PowerShell snap-in |
| `Microsoft.BDD.Core.dll` | MDT core library |
| `Microsoft.BDD.ConfigManager.dll` | MDT configuration manager |
| `Interop.TSCore.dll` | Task sequence interop library |
| `Microsoft.BDD.TaskSequenceModule.dll` | Task sequence module |

---

## Developing Custom Modules

When adding custom PSD scripts, always follow the established pattern:

```powershell
# At the top of every custom script
Import-Module PSDUtility

# Use Write-PSDLog for all logging
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Starting custom step"

# Use Get-PSDLocalDataPath for cache paths
$cachePath = Get-PSDLocalDataPath

# End with a log entry
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Completed successfully"
```

See [Debugging & Logging](../advanced/debugging-logging) for more details.
