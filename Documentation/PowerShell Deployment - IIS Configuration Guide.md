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
* [ ] **Certificates** - blah

## Detailed Script Execution Steps
### Install IIS
blah

### Install IIS Components
blah

### Install WebDAV
blah

### Install WebDAV Components
blah

### Configure IIS
blah

### Configure WebDAV
blah

### Firewall** - blah
    - open port 80 for HTTP
    - open port 443 for HTTPS
    - open port XXXX 9080 for MDT Event Monitoring 
### Application Pool
blah

### File Permissions
Blah

### MIME Types
blah

### Accounts
blah

### Certificates
blah

## Caveats
Not all MDT features for Lite Touch Installations are available for PSD over HTTP/S (yet). The following items have not yet been developed or finalized:
- SLShareDynamicLogging will not be available over HTTP/S
- MDT Database connectivity and functionality has not yet been implemented
- MDT Event Monitoring Service connectivity and functionality has not yet been implemented
- DaRT functionality and integration has not been implemented

## PSD IIS Installation Script
To simplify installation and configuration of IIS for PSD-enabled deployments, installers and implementers should run the PSD-Install-IIS.ps1 script. <<ADD A LINK>>

TODO: Add in instructions for running PSD-Install-IIS.ps1
TODO: test johan

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
- Customize wallpaper
- customize Bootstrap.ini
- Customize CustomSettings.ini
- (Optional) Edit your task sequence
- Add drivers
- Add applications
- etc and more

