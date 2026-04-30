---
id: customsettings-ini
title: CustomSettings.ini
sidebar_label: CustomSettings.ini
sidebar_position: 2
---

# CustomSettings.ini

`CustomSettings.ini` is processed **after** `Bootstrap.ini` and after basic network connectivity is established. It is the primary file for configuring deployment behavior, automating user prompts, and setting task sequence variables.

The file is located at:
```
<DeploymentShare>\Control\CustomSettings.ini
```

---

## Minimal Example

```ini
[Settings]
Priority=Default
Properties=MyCustomVar

[Default]
OSInstall=Y
SkipCapture=YES
SkipAdminPassword=YES
SkipProductKey=YES
SkipComputerBackup=YES
SkipBitLocker=YES
SkipBDDWelcome=YES
```

---

## Skip Variables

Set these to `YES` to suppress the corresponding Wizard pane (fully automate deployments):

| Variable | Description |
|---|---|
| `SkipBDDWelcome` | Skip the initial welcome screen |
| `SkipCapture` | Skip the capture options pane |
| `SkipAdminPassword` | Skip local admin password prompt |
| `SkipProductKey` | Skip Windows product key entry |
| `SkipComputerBackup` | Skip backup pane |
| `SkipBitLocker` | Skip BitLocker configuration pane |
| `SkipComputerName` | Skip computer name prompt |
| `SkipDomainMembership` | Skip domain/workgroup join pane |
| `SkipUserData` | Skip user data migration pane |
| `SkipLocaleSelection` | Skip locale/language selection |
| `SkipTimeZone` | Skip time zone pane |
| `SkipApplications` | Skip application selection pane |
| `SkipSummary` | Skip pre-deployment summary screen |
| `SkipFinalSummary` | Skip post-deployment summary screen |
| `SkipWizard` | Skip the entire PSD Wizard |

---

## Common Variables

### Computer Identity

```ini
OSDComputerName=%SerialNumber%
```

| Variable | Description |
|---|---|
| `OSDComputerName` | Sets the target computer name. Supports MDT substitution variables like `%SerialNumber%`, `%UUID%`, `%AssetTag%`. |
| `JoinDomain` | Domain to join |
| `JoinWorkgroup` | Workgroup to join (mutually exclusive with `JoinDomain`) |
| `MachineObjectOU` | Fully-qualified OU path for the computer account |
| `DomainAdmin` | Domain join account username |
| `DomainAdminDomain` | Domain for the join account |
| `DomainAdminPassword` | Password for the domain join account |

### Operating System

```ini
OSInstall=Y
TaskSequenceID=WIN11-001
```

| Variable | Description |
|---|---|
| `OSInstall` | Must be `Y` to proceed with OS installation |
| `TaskSequenceID` | ID of the task sequence to run automatically |

### Locale and Time

```ini
UILanguage=en-US
UserLocale=en-US
KeyboardLocale=en-US
TimeZoneName=Eastern Standard Time
```

### Applications

```ini
Applications001={GUID-of-application-1}
Applications002={GUID-of-application-2}
MandatoryApplications001={GUID-of-mandatory-app}
```

:::warning
Application GUIDs **must** be wrapped in curly braces `{ }`.
:::

### User Accounts

```ini
AdminPassword=P@ssw0rd!
```

---

## Declaring Custom Variables

Any custom task sequence variables must be explicitly declared in the `Properties` line:

```ini
[Settings]
Priority=Default
Properties=MyCustomVar, AnotherVar, DeviceRole
```

Custom variables can then be set in any section:

```ini
[Default]
DeviceRole=Workstation
```

---

## Dynamic Sections (Priority-Based Rules)

`CustomSettings.ini` supports MDT's priority processing for dynamic configuration:

```ini
[Settings]
Priority=TaskSequenceID, Default

[WIN11-LAPTOP]
OSDComputerName=LT-%SerialNumber%
SkipComputerName=YES

[WIN11-DESKTOP]
OSDComputerName=DT-%SerialNumber%
SkipComputerName=YES

[Default]
OSInstall=Y
SkipCapture=YES
```

---

## Server-Side Logging

To enable log upload to a central share at the end of deployment:

```ini
SLShare=\\server\DeploymentLogs$
SLShareDynamicLogging=\\server\DeploymentLogs$
```

---

## Full Automated Deployment Example

```ini
[Settings]
Priority=Default
Properties=

[Default]
OSInstall=Y
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

OSDComputerName=%SerialNumber%
JoinDomain=CONTOSO
MachineObjectOU=OU=Workstations,OU=Computers,DC=CONTOSO,DC=COM
DomainAdmin=svc-domainjoin
DomainAdminDomain=CONTOSO
DomainAdminPassword=P@ssw0rd!

UILanguage=en-US
UserLocale=en-US
KeyboardLocale=en-US
TimeZoneName=Eastern Standard Time
AdminPassword=P@ssw0rd!
```
