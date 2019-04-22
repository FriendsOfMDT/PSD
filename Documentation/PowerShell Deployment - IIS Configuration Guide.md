# IIS Configuration Guide - PowerShell Deployment Extension Kit
April 2019

## Introduction: 
In order to support OS deployments using PSD and content hosted on a web server(s), a substantial number of configuration items must be completed. This document highlights and outlines the settings and steps known to work with PSD.

> NOTE: Your security team and environment may require additional settings or lock down.

## High Level Overview and Checklist
Please review and or validate the following IIS/WEbDAV installation checklist:

* [ ] **Windows Server Version**

       Windows Server 2012R2 - Not Supported - May Work
       Windows Server 2016 - Supported - And Verified
       Windows Server 2019 - Supported - And Verified

* [ ] **Install IIS**

Currently the IIS installation and configure script does NOT support a server that already has IIS or a server you have manually installed IIS on. The Script we have provided will handle the instalation of IIS for you. 


* [ ] **Install IIS Components**

The following IIS components are required to ensure that PSD functions as expected and can all be found under "Web Server (IIS)" in Server Manager. 

* Common HTTP Features

     * Default Document
     * Directory Browsing
     * HTTP Errors
     * Static Content
     * HTTP Redirection
     * WebDav Publishing

* Health and Diagnostics

     * HTTP Logging
     * Custom Logging
     * Logging Tools
     * Request Monitor
     * Tracing
     
* Performance

     * Static Content Compression

* Security 

     * Request Filtering
     * Basic Authentication
     * Digest Authentication
     * URL Authorization
     * Windows Authentication
     
* Management Tools
     * IIS Management Compatability 
     * IIS 6 Management Compatibility
          * IIS 6 Metabase Compatability

* [ ] **Install WebDAV**

The PSD extension for MDT requires the WebDAV Redirector to be installed. This is a feature and not a role in Server Manager. This feature does require a reboot.

*  WebDAV Redirector

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
TODO: test johan
