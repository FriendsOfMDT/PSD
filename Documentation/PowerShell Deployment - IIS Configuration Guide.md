# IIS Configuration Guide - PowerShell Deployment Extension Kit
April 2019

## Introduction: 
In order to support OS deployments using PSD and content hosted on a web server(s), a substantial number of configuration items must be completed. This document highlights and outlines the settings and steps known to work with PSD.

> NOTE: Your security team and environment may require additional settings or lock down.

## High Level Overview and Checklist
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

## Detailed Configuration Steps
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