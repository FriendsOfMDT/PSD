---
id: user-exit-scripts
title: UserExitScripts
sidebar_label: UserExitScripts
sidebar_position: 4
---

# UserExitScripts

UserExitScripts allow you to inject custom PowerShell logic at defined hook points in the PSD deployment lifecycle **without modifying the core PSD scripts**. This is the recommended approach for customizing PSD behavior.

UserExitScripts were introduced in **PSD v0.2.3.1**.

---

## Location

Place UserExitScript files in:

```
<DeploymentShare>\PSDResources\UserExitScripts\
```

Sample scripts are included in this folder after installation.

---

## Lifecycle Hook Points

`PSDStartLoader.psm1` invokes `Invoke-PSDUserExitScript` at the following phases:

| Phase | Timing |
|---|---|
| `PreStart` | Before `PSDStart.ps1` begins connecting to the deployment share |
| `PostGather` | After `PSDGather.ps1` completes and TS variables are populated |
| `PreWizard` | Before the PSD Wizard is displayed (if enabled) |
| `PostWizard` | After the Wizard is dismissed |
| `PreTS` | Immediately before the main task sequence begins |
| `PostTS` | After the task sequence completes (final phase) |

---

## Script Naming Convention

Scripts are named using the phase they target:

```
<Phase>_<Description>.ps1
```

**Examples:**
```
PreStart_CheckNetwork.ps1
PostGather_SetComputerName.ps1
PreWizard_InjectCustomVars.ps1
PostTS_NotifyTeams.ps1
```

All scripts matching the phase name pattern in the `UserExitScripts\` folder are executed in alphabetical order.

---

## Example: Custom Computer Naming

Override the computer name based on a custom asset database lookup:

```powershell
# PostGather_SetComputerName.ps1

Import-Module PSDUtility

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Querying asset database for computer name"

$serial = $tsenv.Value("SerialNumber")
$apiUrl = "https://asset-db.contoso.com/api/computers/$serial"

try {
    $response = Invoke-RestMethod -Uri $apiUrl -UseDefaultCredentials
    $computerName = $response.ComputerName
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Setting OSDComputerName to $computerName"
    $tsenv.Value("OSDComputerName") = $computerName
} catch {
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Asset lookup failed, using serial: $serial" -LogLevel 2
    $tsenv.Value("OSDComputerName") = "WS-$serial"
}
```

---

## Example: Teams Notification

Send a Microsoft Teams webhook notification when a deployment completes:

```powershell
# PostTS_NotifyTeams.ps1

Import-Module PSDUtility

$computerName = $tsenv.Value("OSDComputerName")
$tsId         = $tsenv.Value("TaskSequenceID")
$webhookUrl   = "https://outlook.office.com/webhook/YOUR_WEBHOOK_URL"

$body = @{
    text = "✅ PSD Deployment Complete: **$computerName** | Task Sequence: $tsId"
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Teams notification sent"
} catch {
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Teams notification failed: $_" -LogLevel 2
}
```

---

## Accessing Task Sequence Variables

Inside UserExitScripts, use the `$tsenv` object (automatically available after `PSDUtility` is imported) to read and write task sequence variables:

```powershell
# Read a variable
$value = $tsenv.Value("VariableName")

# Write a variable
$tsenv.Value("VariableName") = "NewValue"
```

---

## Best Practices

- **Always import `PSDUtility`** and use `Write-PSDLog` for logging
- **Handle exceptions** with try/catch — a failing UserExitScript should not crash the deployment
- **Keep scripts focused** — one script per concern, named clearly
- **Test in WinPE** before deploying to production using `PSDHelper.ps1` for module loading
