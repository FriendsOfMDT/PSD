---
id: restps
title: RestPS Integration
sidebar_label: RestPS Integration
sidebar_position: 5
---

# RestPS Integration with PSD

[RestPS](https://github.com/jpsider/RestPS) is a PowerShell-based lightweight REST API server that can be integrated with PSD to enable dynamic, server-side rule processing and custom API endpoints during deployment.

For the full official guide, see the [RestPS Guide with PSD](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20RestPS%20Guide%20with%20PSD.md).

---

## Use Cases

RestPS + PSD enables scenarios such as:

- **Dynamic computer naming** — Query a CMDB or inventory system for the correct computer name based on MAC address or serial number
- **Deployment validation** — Check if a device is authorized to be deployed before proceeding
- **Real-time progress reporting** — Push deployment status to a dashboard or ticketing system
- **Variables-as-a-service** — Serve `CustomSettings.ini`-equivalent variables dynamically from a REST API instead of static INI files

---

## Architecture

```
WinPE Client
    │  HTTPS
    ▼
RestPS Server (PowerShell REST API)
    │  Queries
    ▼
CMDB / Asset Database / Custom Logic
    │  Returns
    ▼
JSON Response → PSD injects into TS variables
```

---

## Setting Up RestPS

### Install RestPS

```powershell
Install-Module -Name RestPS -Scope CurrentUser
```

### Define an Endpoint

Create an endpoint script that handles computer name lookups:

```powershell
# Get-ComputerName.ps1 — RestPS endpoint

param ($Body)

$data = $Body | ConvertFrom-Json
$serial = $data.SerialNumber

# Query your CMDB or database
$computerName = Invoke-SqlQuery -Query "SELECT ComputerName FROM Assets WHERE Serial = '$serial'"

if ($computerName) {
    return @{ ComputerName = $computerName } | ConvertTo-Json
} else {
    return @{ ComputerName = "WS-$serial" } | ConvertTo-Json
}
```

### Start the RestPS Server

```powershell
Start-RestPSListener -Port 8080 -RoutesFilePath ".\routes.json"
```

---

## Calling RestPS from PSD

Use a **UserExitScript** to call the RestPS endpoint during the `PostGather` phase:

```powershell
# PostGather_QueryRestPS.ps1

Import-Module PSDUtility

$serial     = $tsenv.Value("SerialNumber")
$restPsUrl  = "https://psd-server.contoso.com:8080/api/computername"

$body = @{ SerialNumber = $serial } | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $restPsUrl -Method Post `
        -Body $body -ContentType "application/json" -UseBasicParsing

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Got computer name: $($response.ComputerName)"
    $tsenv.Value("OSDComputerName") = $response.ComputerName
} catch {
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): RestPS query failed: $_" -LogLevel 2
}
```

---

## Security Considerations

- Run RestPS behind HTTPS using the same IIS/certificate infrastructure as your PSD share
- Authenticate API requests using Windows Authentication or token-based auth
- Validate all inputs server-side — the serial number or MAC address sent from WinPE should be treated as untrusted input
