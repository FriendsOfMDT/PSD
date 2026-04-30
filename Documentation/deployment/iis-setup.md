---
id: iis-setup
title: IIS Configuration
sidebar_label: IIS Configuration
sidebar_position: 2
---

# IIS Configuration for HTTPS Deployments

PSD requires IIS to deliver deployment content over HTTP or HTTPS. This page provides an overview of the IIS configuration required. For the complete step-by-step guide, see the [official IIS Configuration Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20IIS%20Configuration%20Guide.md).

---

## Overview

IIS is installed on the same server as your MDT/PSD deployment share. You configure a virtual directory that maps to the deployment share folder, then secure it with a TLS certificate for HTTPS.

```
Client (WinPE)
    │
    │  HTTPS request
    ▼
IIS (port 443)
    │
    │  Maps virtual directory → UNC/local path
    ▼
PSD Deployment Share (D:\PSD\)
```

---

## Step 1: Install IIS and Required Roles

Run in an elevated PowerShell prompt:

```powershell
Install-WindowsFeature -Name Web-Server, Web-Mgmt-Tools, Web-Basic-Auth,
    Web-Windows-Auth, Web-Digest-Auth, Web-Client-Auth, Web-Cert-Auth,
    Web-IP-Security, Web-Url-Auth, Web-WebSockets, Web-AppInit,
    Web-Asp-Net, Web-Asp-Net45, Web-Static-Content, Web-Default-Doc,
    Web-Dir-Browsing, Web-Http-Errors, Web-Http-Redirect,
    Web-DAV-Publishing, Web-Http-Logging, Web-Log-Libraries,
    Web-Http-Tracing, Web-Security, Web-Filtering, Web-Performance,
    Web-Mgmt-Console, Web-Scripting-Tools -IncludeManagementTools
```

---

## Step 2: Create the Virtual Directory

Create a virtual directory in IIS that points to your PSD deployment share:

```powershell
$deployShare = "D:\PSD"
$virtualDirName = "PSD"

New-WebVirtualDirectory -Site "Default Web Site" `
    -Name $virtualDirName `
    -PhysicalPath $deployShare
```

---

## Step 3: Configure Authentication

Enable **Windows Authentication** and disable Anonymous Authentication for the virtual directory:

```powershell
Set-WebConfigurationProperty -Filter "system.webServer/security/authentication/windowsAuthentication" `
    -Name enabled -Value $true `
    -PSPath "IIS:\Sites\Default Web Site\$virtualDirName"

Set-WebConfigurationProperty -Filter "system.webServer/security/authentication/anonymousAuthentication" `
    -Name enabled -Value $false `
    -PSPath "IIS:\Sites\Default Web Site\$virtualDirName"
```

---

## Step 4: Configure MIME Types

WinPE needs to download files with extensions that IIS doesn't serve by default. Add the required MIME types:

```powershell
$mimeTypes = @(
    @{ Extension = '.wim';  MimeType = 'application/octet-stream' }
    @{ Extension = '.iso';  MimeType = 'application/octet-stream' }
    @{ Extension = '.ps1';  MimeType = 'application/octet-stream' }
    @{ Extension = '.psm1'; MimeType = 'application/octet-stream' }
    @{ Extension = '.psd1'; MimeType = 'application/octet-stream' }
    @{ Extension = '.xml';  MimeType = 'text/xml' }
    @{ Extension = '.ini';  MimeType = 'text/plain' }
    @{ Extension = '.json'; MimeType = 'application/json' }
)

foreach ($mime in $mimeTypes) {
    Add-WebConfigurationProperty -Filter "system.webServer/staticContent" `
        -PSPath "IIS:\Sites\Default Web Site\$virtualDirName" `
        -Name "." `
        -Value @{ fileExtension = $mime.Extension; mimeType = $mime.MimeType }
}
```

---

## Step 5: Bind a TLS Certificate (HTTPS)

1. Obtain a valid TLS certificate for your server. Options:
   - **Internal PKI** — Issue from your organization's CA
   - **Let's Encrypt** — For internet-facing servers
   - **Self-signed** — For lab/testing only (clients need to trust the cert)

2. Import the certificate to the **Local Machine\Personal** certificate store.

3. Bind the certificate to IIS port 443:

```powershell
# Get the certificate thumbprint
$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*psd-server*" }

# Add HTTPS binding
New-WebBinding -Name "Default Web Site" -Protocol https -Port 443 -IPAddress "*"

# Assign the certificate
$binding = Get-WebBinding -Name "Default Web Site" -Protocol https
$binding.AddSslCertificate($cert.Thumbprint, "my")
```

---

## Step 6: Configure NTFS Permissions

Grant the build account read access to the deployment share folder:

```powershell
$acl = Get-Acl $deployShare
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "CONTOSO\psd-build", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl $deployShare $acl
```

---

## Step 7: Update Bootstrap.ini

Update your `Bootstrap.ini` to point to the HTTPS URL:

```ini
[Default]
DeployRoot=https://psd-server.contoso.com/PSD
UserID=psd-build
UserPassword=P@ssw0rd!
UserDomain=CONTOSO
```

---

## Step 8: Inject TLS Certificate into Boot Media

If using a certificate from an internal CA or a self-signed certificate, the WinPE boot image must trust it. Inject your CA certificate into the boot image:

1. Place the CA cert (`.cer`) in `PSDResources\Certificates\`
2. The PSD prestart scripts will automatically import it into the WinPE certificate store during boot

---

## Verification

Test the HTTPS connection from a browser or PowerShell before deploying:

```powershell
$uri = "https://psd-server.contoso.com/PSD/Control/Bootstrap.ini"
Invoke-WebRequest -Uri $uri -Credential (Get-Credential) -UseBasicParsing
```

A 200 OK response confirms IIS is correctly serving PSD content over HTTPS.

---

## Next Steps

- *(Optional)* Configure [BranchCache](./branchwcache) for P2P deployment support
- Test a bare-metal deployment using your HTTPS-configured environment
