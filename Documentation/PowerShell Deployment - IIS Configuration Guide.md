# IIS Configuration Guide - PowerShell Deployment Extension Kit
April 2019

## Introduction: 
In order to support OS deployments using PSD and content hosted on a web server(s), a substantial number of configuration items must be completed. This document highlights and outlines the settings and steps known to work with PSD.

> NOTE: Your security team and environment may require additional settings or lock down.

## High Level Script Overview and Checklist
Please review and or validate the following IIS/WEbDAV installation checklist:

* [ ] **Windows Server Version** - blah
* [ ] **Install IIS** - blah
* [ ] **Install IIS Components** - blah
* [ ] **Install WebDAV** - blah
* [ ] **Install WebDAV Components** - blah
* [ ] **Configure IIS** - blah
* [ ] **Configure WebDAV** - blah
* [ ] **Firewall Ports** - blah
* [ ] **Application Pool** - blah
* [ ] **File Permissions** - Blah
* [ ] **MIME Types** - blah
* [ ] **Accounts** - blah
* [ ] **Certificates** - you'll need at least a self-signed Web Hosting cert for the PSD IIS server for client authentication 

## Detailed Script Execution Steps
### Install IIS
- blah

### Install IIS Components
- blah

### Install WebDAV
- blah

### Install WebDAV Components
- blah

### Configure IIS
- blah

### Configure WebDAV
- blah

### Firewall** - blah
    - open port 80 for HTTP
    - open port 443 for HTTPS
    - open TCP port 9800 and 9801 for MDT Event Monitoring 
### Application Pool
- blah

### File Permissions
- Blah

### MIME Types
 - blah

### Accounts
- blah

### Certificates
- blah

## Caveats
Not all MDT features for Lite Touch Installations are available for PSD over HTTP/S (yet). The following items have not yet been developed or finalized:
- SLShareDynamicLogging will not be available over HTTP/S
- MDT Database connectivity and functionality has not yet been implemented
- DaRT functionality and integration has not been implemented, attempted or tested

## PSD IIS Installation Script
To simplify installation and configuration of IIS for PSD-enabled deployments, installers and implementers should run the PSD-Install-IIS.ps1 script. <<ADD A LINK>>

TODO: Add in instructions for running PSD-Install-IIS.ps1

#Configure PSD for HTTP/S operation
## HTTPS configuration checklist
In order to connect to a PSD Deployment Share via HTTPS, certificate based authentication is required. Administrators will need to generate a self-signed cert from the IIS server hosting the PSD Deployment Share, bind that cert to the IIS server, inject the cert into Windows PE and finally import and apply the cert into the new target computer. While a self signed cert may satisfy authentication and access concerns for most organizations, others may want to leverage certs from a commercial or private cert solution. Only a self-signed approach is supported by default. 

By default, a self signed cert (named PSDRoot.cer) must be generated and used within PSDStart.ps1 to enable HTTPS PSD connectivity. 

* [ ] **Modify firewall rules to enable HTTPS in environment** - enable HTTPS traffic at all necessary infrastructure
* [ ] **Create self-signed cert  (PSDRoot.cer)** - using Windows IIS Manager
* [ ] **Bind self-signed cert to IIS site** - using Windows IIS Manager
* [ ] **Verify PSDRoot cert exits in cert store**  - using Windows Certificate Manager
* [ ] **Export PSDRoot cert** - using Windows Certificate Manager
* [ ] **Copy PSDRoot cert to PSD Deployment Share**
* [ ] **Copy certutil.exe to PSD Deployment Share**
* [ ] **Regenerate PSD boot media** - using MDT Workbench
* [ ] **Manually run certutil command during PSDStart.ps1** or modify PSDStart.ps1 to autorun
* [ ] **Adjust post-OSD deployment steps to clean up and or remove PSD certificate** (Optional)

## HTTPS configuration step-by-step
<table>
  <tr>
    <th>Task</th>
    <th>Instructions</th>
  </tr>
  <tr>
    <td>Create PSD self-signed certificate</td>
    <td>Open IIS Manager<br>Navigate to the PSD server<br>Navigate to Default Web Site (or appropriate<br>Click on **Certificates**<br>(image)</td>
  </tr>
  <tr>
    <td>Bind certificate to IIS</td>
    <td>Navigate to the PSD server<br>Navigate to Default Web Site (or appropriate<br>Click on **Bindings**<br></td>
  </tr>
  <tr>
    <td>Copy PSDRoot.cer and certutil.exe to PSD Deployment Share</td>
    <td>Windows 10 ENT x64 EN 1809<br>
    Windows 10 ENT x64 EN 1709</td>
  </tr>
  <tr>
    <td>Regenerate PSD boot media</td>
    <td>Windows 7 ENT x64 SP1<br></td>
  </tr>
  <tr>
    <td>Target client OS</td>
    <td>Windows 7 ENT x32 SP1<br>Windows 8.x </td>
  </tr>
  </table>

# Hydration
The New-PSDHydration.ps1 script will completely build out a basic Windows Server in about 20m. The hydration script calls the PSD Installer script (Install-PSD.ps1) and the PSD Installation script (New-PSDWebInstance.ps1) as part of it's activities.

## Hydration Prerequisites Checklist
* [ ] **Windows Server 2019** - basic Windows 2019 Server **without** IIS or WebDAV pre-installed or configured. This server should be as vanilla as possible.
* [ ] **Download PSD** - download and store the PSD content including Documentation, Installers, Scripts and Tools.
* [ ] **Download ADK** - download and store the appropriate ADK installer for your environment. You can optionally also run the ADK in advance and download the actual ADK content in advance.
* [ ] **Download ADK for PE** - download and store the appropriate ADK for PE installer for your environment. You can optionally also run the ADK PE Installer in advance and download the actual ADK content in advance.
* [ ] **Download MDT** - download and store the appropriate MDT installer for your environment. 
* [ ] **Download Windows 10** - download and store an appropriate Windows 10 ISO for your environment. 
    >PRO TIP: You may want to avoid **Evaluation** media 
* [ ] **Network Access Account** - (pre)create a domain or local account that can be used to access the deployment share.
    >PRO TIP: Make sure this account has the least privileges needed. At a minimum, read/execute/list for the deployment share. This account doesn't need JoinDomain or Logon rights. 
* [ ] **Create Deployment Share Location** - The Hydration script expects a target share folder to already be created.
* [ ] **Run the PSD Hydration script** - The Hydration script will run mostly silent by default, but will require some info and iteration by a user. The Hydration script generates a log in the same directory it was run from.
    >PRO TIP: Run the PSD hydration script from an Elevated PowerShell prompt with the -verbose flag for maximum visibility.

## Post Hydration Tasks
You'll still need to do some things after hydration is finished.
- Configure Firewall ports
- Configure certificates 
- Customize wallpaper(s)
- Customize Bootstrap.ini
- Customize CustomSettings.ini
- (Optional) Edit your task sequence
- Add hardware drivers
- Add applications
- etc and more

