# IIS Configuration Guide - PowerShell Deployment Extension Kit
April 2019

## Introduction: 
In order to support OS deployments using PSD and content hosted on a web server(s), a substantial number of configuration items must be completed. This document highlights and outlines the settings and steps known to work with PSD.

> NOTE: Your security team and environment may require additional settings or lock down.

## High Level Script Overview and Checklist
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

* [ ] **Configure IIS**

The PSD Extension for MDT requires some configuration changes to IIS in order to function. Most of these changes have to do with configuring IIS to work properly with WebDav. If you use the installation script these will be automatically configured for you. Detailed steps regarding its configuration are incldued in the Detailed Configuration Steps section.

     * Create New Virtual Directory
     * Enable Directory Browsing
     * Disable Anonymous Authentication
     * Enable Windows Authentication
     * Create and add new MIME type 
     
* [ ] **Configure WebDAV**

The PSD Extension for MDT Requires some configuration changes to WebDAV in order to function. Most of the changes have to do with rules and properties that allow specific types of data. If you use the installation script these will be automatically configured for you. Detailed steps regarding its configuration are incldued in the Detailed Configuration Steps section. 

     * Enable WebDAV
     * Create new WebDav Authoring Rule
     * Modify WebDAV Settings
         * Allow File Extension Filtering
         * Allow Hidden Segment Filtering
         * Allow Verb Filtering
     * Modify Default MIME type

* [ ] **Firewall Ports** - blah

* [ ] **Application Pool** - blah

* [ ] **File Permissions** - Blah

* [ ] **MIME Types**

The PSD Extension for MDT Requires some configuration changes to MIME types in order to function. The current known required change is to add an additional MIME type. Details on the mime type changes can be found in the Detailed Configuration Steps section. 


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

