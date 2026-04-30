---
id: psd-wizard
title: PSD Wizard
sidebar_label: PSD Wizard
sidebar_position: 3
---

# PSD Wizard

The PSD Wizard provides a graphical interface during deployment for collecting deployment-specific information from the technician or end-user. PSD ships with a modernized wizard (`PSDWizardNew`) that replaces the legacy MDT wizard interface.

---

## Enabling the Wizard

Add the following variables to `CustomSettings.ini`:

```ini
PSDWizard=YES
PSDWizardTheme=Classic
```

To skip the wizard entirely for zero-touch deployments:

```ini
SkipWizard=YES
```

---

## Wizard Panes

The PSD Wizard includes the following built-in panes:

| Pane | Description | Skip Variable |
|---|---|---|
| **Welcome** | Initial welcome screen | `SkipBDDWelcome=YES` |
| **Computer Name** | Set the target computer name | `SkipComputerName=YES` |
| **Domain / Workgroup** | Join a domain or workgroup | `SkipDomainMembership=YES` |
| **Language / Locale** | Language, locale, keyboard, time zone | `SkipLocaleSelection=YES` |
| **Time Zone** | Time zone selection | `SkipTimeZone=YES` |
| **Applications** | Optional application selection | `SkipApplications=YES` |
| **Admin Password** | Set local administrator password | `SkipAdminPassword=YES` |
| **BitLocker** | BitLocker encryption settings | `SkipBitLocker=YES` |
| **Summary** | Pre-deployment review | `SkipSummary=YES` |
| **Device Role** | Select the device role/purpose *(v0.2.3.0+)* | — |
| **Intune Enrollment** | Configure Intune enrollment settings *(v0.2.3.0+)* | — |

---

## PSDWizardNew vs Legacy PSDWizard

| Feature | Legacy `PSDWizard` | New `PSDWizardNew` |
|---|---|---|
| Engine | `PSDWizard.psm1` | `PSDWizardNew.psm1` |
| XAML template | `PSDWizard.xaml` | `Scripts\PSDWizardNew\` |
| Themes supported | No | Yes |
| Intune pane | No | Yes *(v0.2.3.0+)* |
| Device Role pane | No | Yes *(v0.2.3.0+)* |
| Recommended | No | **Yes** |

:::note
The legacy wizard was removed from `PSDStart.ps1` in version **0.2.3.1**. Use `PSDWizardNew` for all new deployments.
:::

---

## Themes

Themes allow you to customize the wizard appearance using XAML files. Theme files are stored in `Scripts\PSDWizardNew\`.

```ini
PSDWizardTheme=Classic
```

Refer to the [PSD Wizard Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20PSD%20Wizard%20Guide.md) for instructions on creating and applying custom themes.

---

## Pre-Populating Wizard Fields

You can pre-populate wizard fields using `CustomSettings.ini` variables while still showing the wizard for review:

```ini
[Default]
OSDComputerName=%SerialNumber%
JoinDomain=CONTOSO
SkipComputerName=NO
SkipDomainMembership=NO
```

This shows the wizard with pre-filled values that the technician can confirm or override.
