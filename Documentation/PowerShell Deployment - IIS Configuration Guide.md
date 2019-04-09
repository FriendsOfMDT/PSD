# IIS Configuration Guide - PowerShell Deployment Extension Kit
April 2019

## Introduction: 
In order to support OS deployments using PSD and content hosted on a web server(s), a substantial number of configuration items must be completed. This document highlights and outlines the settings and steps known to work with PSD.

> NOTE: Your security team and environment may require additional settings or lock down.

## High Level Overview and Checklist
Please review and or validate the following IIS/WEbDAV installation checklist:

* [ ] **Windows Server Version** - blah
* [ ] **Firewall** - blah
    - open port 80 for HTTP
    - open port 443 for HTTPS
    - open port XXXX 9080 for MDT Event Monitoring 
* [ ] **Install IIS** - blah
* [ ] **Install IIS Components** - blah
* [ ] **Install WebDAV** - blah
* [ ] **Application Pool** - blah
* [ ] **File Permissions** - Blah
* [ ] **MIME Types** - blah
* [ ] **Accounts** - blah
* [ ] **Certificates** - blah

## Detailed Configuration Steps

## Caveats
Not all MDT features for Lite Touch deployments are available for PSD over HTTP/S (yet). The following items have not yet been developed or finalized:
- something about Logs and Dynamic Logging (SLSHARE)
- something about MDT Database
- something about MDT Event Monitoring Service
- something about DaRT

## PSD IIS Installation Script
(in development)