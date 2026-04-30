---
id: bootstrap-ini
title: Bootstrap.ini
sidebar_label: Bootstrap.ini
sidebar_position: 1
---

# Bootstrap.ini

`Bootstrap.ini` is processed **first** during WinPE boot, before network connectivity is fully established. It provides the minimal configuration required for PSD to connect to the deployment share and begin gathering environment data.

The file is located at:
```
<DeploymentShare>\Control\Bootstrap.ini
```

---

## Minimal Example

```ini
[Settings]
Priority=Default

[Default]
DeployRoot=https://psd-server.contoso.com/PSD$
UserID=psd-build
UserPassword=P@ssw0rd!
UserDomain=CONTOSO
SkipBDDWelcome=YES
```

---

## Key Variables

### Connection Settings

| Variable | Description | Example |
|---|---|---|
| `DeployRoot` | URL or UNC path to the deployment share | `https://server/PSD$` or `\\server\PSD$` |
| `UserID` | Username for deployment share authentication | `psd-build` |
| `UserPassword` | Password for the build account | `P@ssw0rd!` |
| `UserDomain` | Domain for the build account | `CONTOSO` |

### Skip Settings

| Variable | Values | Description |
|---|---|---|
| `SkipBDDWelcome` | `YES` / `NO` | Skip the initial welcome screen |

### Debug Settings

| Variable | Values | Description |
|---|---|---|
| `PSDDebug` | `YES` / `NO` | Enable PSD debug mode — forces verbose logging and enables debug breakpoints |

---

## Debug Mode

To enable debug mode, add to `Bootstrap.ini`:

```ini
PSDDebug=YES
```

This forces PSD to run in verbose/debug mode across all scripts. The `-Debug` parameter can also be passed directly to `PSDStart.ps1` at the command line for interactive troubleshooting in WinPE.

---

## Priority-Based Processing

Like standard MDT, `Bootstrap.ini` supports priority-based processing for dynamic rule evaluation:

```ini
[Settings]
Priority=Default, MachineObjectOU

[Default]
DeployRoot=https://psd-server.contoso.com/PSD$
UserID=psd-build
UserPassword=P@ssw0rd!
UserDomain=CONTOSO

[MachineObjectOU]
Subsection=OU-%OSDComputerName%
```

---

## UNC vs HTTPS

| Transport | `DeployRoot` Format | Requirements |
|---|---|---|
| SMB (UNC) | `\\server\ShareName$` | SMB firewall access |
| HTTP | `http://server/VirtualDir` | IIS configured |
| HTTPS | `https://server/VirtualDir` | IIS with TLS certificate configured |

---

## Security Note

:::warning
`Bootstrap.ini` stores credentials **in plaintext**. Protect the deployment share and restrict read access to your build account only.
:::

See the [Security Guide](../advanced/security) for hardening recommendations.
