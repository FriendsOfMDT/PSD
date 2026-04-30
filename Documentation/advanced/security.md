---
id: security
title: Security Guide
sidebar_label: Security
sidebar_position: 3
---

# Security Guide

This page covers security hardening recommendations for PSD deployments. For the full official guide, see the [Security Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20Security%20Guide.md).

---

## Threat Model

A PSD deployment infrastructure is sensitive because it handles:
- **Credentials** stored in `Bootstrap.ini` and `CustomSettings.ini`
- **OS images** and software that are applied to production systems
- **Domain join accounts** with Active Directory write permissions
- **Network communication** over HTTP/HTTPS between WinPE clients and the server

---

## Credential Security

### Bootstrap.ini Credentials

`Bootstrap.ini` stores the build account password **in plaintext**. Mitigate this with:

**1. Principle of Least Privilege**

The build account should have **read-only** access to the deployment share only. It should not be a domain admin, local admin on target devices, or have any other permissions.

**2. Restrict Share Access**

Limit who can read `Bootstrap.ini` at the file system level:

```powershell
# Remove broad permissions
icacls "D:\PSD\Control\Bootstrap.ini" /inheritance:d
icacls "D:\PSD\Control\Bootstrap.ini" /remove "Users"
icacls "D:\PSD\Control\Bootstrap.ini" /grant "CONTOSO\psd-build:(R)"
icacls "D:\PSD\Control\Bootstrap.ini" /grant "Administrators:(F)"
```

**3. Use a Dedicated Service Account**

Create a dedicated, non-interactive service account for `psd-build`. Rotate the password regularly. Monitor for any interactive logons using this account.

---

## HTTPS / TLS

Always use **HTTPS** (not HTTP) for production deployments. HTTP transmits all content — including credentials in INI files — in cleartext.

### Certificate Recommendations

| Scenario | Certificate Type |
|---|---|
| Lab / dev | Self-signed (add to WinPE trust store) |
| Internal deployments | Internal CA certificate |
| Internet-facing | Public CA or Let's Encrypt |

### Certificate Validity

Ensure your TLS certificate:
- Has the correct Subject Alternative Name (SAN) for your server FQDN
- Is not expired
- Has a trust chain that WinPE can validate

### Injecting CA Certificates into Boot Media

Place your CA certificate (`.cer`) in `PSDResources\Certificates\`. It will be automatically imported into the WinPE certificate store during prestart.

---

## Deployment Share Permissions

### File System (NTFS)

| Principal | Permissions | Notes |
|---|---|---|
| `Administrators` | Full Control | Server admins |
| `SYSTEM` | Full Control | Local system |
| `Users` / build account | Read & Execute | Deployment clients |

The PSD installer sets these permissions automatically. Verify with:

```powershell
Get-Acl "D:\PSD" | Format-List
```

### SMB Share

| Principal | Permissions |
|---|---|
| `EVERYONE` | Change |
| `CREATOR OWNER` | Not granted (revoked by installer) |

NTFS permissions are the effective security boundary — the SMB share grants broad Change access, but NTFS restricts what can actually be read/modified.

---

## IIS Authentication

Use **Windows Authentication** on the IIS virtual directory. Do not use Anonymous Authentication in production — it would allow anyone with network access to read deployment content.

```powershell
# Verify Windows Auth is enabled
Get-WebConfigurationProperty -Filter "system.webServer/security/authentication/windowsAuthentication" `
    -Name enabled -PSPath "IIS:\Sites\Default Web Site\PSD"
# Should return: True
```

---

## Domain Join Account

The domain join account (`DomainAdmin` in `CustomSettings.ini`) needs only the right to **join computers to the domain** in a specific OU.

Delegate the minimum required permissions:

```powershell
# Delegate "Create Computer Objects" and "Delete Computer Objects" on the target OU
# Do NOT use a Domain Admin account for this purpose
```

---

## WinPE Security

- WinPE runs as `NT AUTHORITY\SYSTEM` with no password. Anyone with physical access to a machine that can boot from your PXE server has significant power.
- Restrict WDS to respond only to **pre-staged devices** (known MAC addresses) in production.
- Use **BitLocker pre-provisioning** in the task sequence for sensitive environments.

---

## Audit Logging

Enable server-side logging to maintain a record of all deployments:

```ini
SLShare=\\psd-server\DeployLogs$
```

Ensure the `SLShare` folder has write access for the build account and read access only for administrators.

Review logs regularly for:
- Unexpected task sequence executions
- Failed domain join attempts
- Unusual computer names or hardware
