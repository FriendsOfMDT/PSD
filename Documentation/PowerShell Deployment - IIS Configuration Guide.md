# IIS Configuration Guide - PowerShell Deployment Extension Kit
April 2019

## Introduction: 
In order to support OS deployments using PSD and content hosted on a web server(s), a substantial number of configuration items must be completed. This document highlights and outlines the settings and steps known to work with PSD.

> NOTE: Your security team and environment may require additional settings or lock down.

## High Level Script Overview and Checklist
Please review and/or validate the following IIS/WebDAV installation checklist:

* [ ] **Windows Server Version**

       Windows Server 2012R2 - Not Supported - May Work
       Windows Server 2016 - Supported - And Verified
       Windows Server 2019 - Supported - And Verified

* [ ] **Install IIS**

Currently the IIS installation and configurartion script does NOT support a server that already has IIS or a server you have manually installed IIS on. The script we have provided will handle the installation of IIS for you. 


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
     * IIS Management Compatibility 
     * IIS 6 Management Compatibility
          * IIS 6 Metabase Compatibility

* [ ] **Install WebDAV**

The PSD extension for MDT requires the WebDAV Redirector to be installed. This is a feature, not a role in Server Manager. This feature does require a reboot.

*  WebDAV Redirector

* [ ] **Configure IIS**

The PSD Extension for MDT requires some configuration changes to IIS in order to function. Most of these changes have to do with configuring IIS to work properly with WebDav. If you use the installation script, these will be automatically configured for you. Detailed steps regarding its configuration are included in the Detailed Configuration Steps section.

     * Create new Virtual Directory
     * Enable Directory Browsing
     * Disable Anonymous Authentication
     * Enable Windows Authentication
     * Create and add new MIME type 
     
* [ ] **Configure WebDAV**

The PSD Extension for MDT requires some configuration changes to WebDAV in order to function. Most of the changes have to do with rules and properties that allow specific types of data. If you use the installation script these will be automatically configured for you. Detailed steps regarding its configuration are included in the Detailed Configuration Steps section. 

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

* [ ] **MIME Types** - The PSD Extension for MDT requires some configuration changes to MIME types in order to function. The current known required change is to add an additional MIME type. Details on the mime type changes can be found in the Detailed Configuration Steps section. 

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
Not all MDT features for Lite Touch Installation (LTI) are available for PSD over HTTP/S (yet). The following items have not yet been developed or finalized:
- SLShareDynamicLogging will **NOT** be available over HTTP/S
- MDT Database connectivity and functionality has not yet been implemented
- DaRT functionality and integration has not been implemented, attempted or tested

## PSD IIS Installation Script
To simplify installation and configuration of IIS for PSD-enabled deployments, installers and implementers should run the PSD-Install-IIS.ps1 script. <<ADD A LINK>>

TODO: Add in instructions for running PSD-Install-IIS.ps1

#Configure PSD for HTTP/S operation
## HTTPS configuration checklist
In order to connect to a PSD deployment share via HTTPS, certificate based authentication is required. Administrators will need to generate a self-signed cert from the IIS server hosting the PSD deployment share, bind that cert to the IIS server, inject the cert into Windows PE and finally import and apply the cert into the new target computer. While a self signed cert may satisfy authentication and access concerns for most organizations, others may want to leverage certs from a commercial or private cert solution. Only a self-signed approach is supported by default. 

By default, a self signed cert (named PSDRoot.cer) must be generated and used within PSDStart.ps1 to enable HTTPS PSD connectivity. 

* [ ] **Modify firewall rules to enable HTTPS in environment** - enable HTTPS traffic at all necessary infrastructure
* [ ] **Create self-signed cert  (PSDRoot.cer)** - using Windows IIS Manager
* [ ] **Bind self-signed cert to IIS site** - using Windows IIS Manager
* [ ] **Verify PSDRoot cert exits in cert store**  - using Windows Certificate Manager
* [ ] **Export PSDRoot cert** - using Windows Certificate Manager
* [ ] **Copy PSDRoot cert to PSD deployment share**
* [ ] **Copy certutil.exe to PSD deployment share**
* [ ] **Regenerate PSD boot media** - using MDT Workbench
* [ ] **Manually run certutil command during PSDStart.ps1** or modify PSDStart.ps1 to autorun
* [ ] **Adjust post-OSD deployment steps to clean up and/or remove PSD certificate** (Optional)

## HTTPS configuration step-by-step
<table>
  <tr>
    <th>Task</th>
    <th>Instructions</th>
  </tr>
  <tr>
    <td>Create PSD self-signed certificate</td>
    <td>- Open IIS Manager<br>- Navigate to the PSD server<br>- Navigate to Default Web Site (or appropriate)<br>- Click on **Certificates**<br>(image)</td>
  </tr>
  <tr>
    <td>Bind certificate to IIS</td>
    <td>- Navigate to the PSD server<br>- Navigate to Default Web Site (or appropriate)<br>- Click on **Bindings**<br></td>
  </tr>
  <tr>
    <td>Copy cert files and tools to MDT/PSD</td>
    <td>Copy certutil.exe to PSD deployment share<br>
   Copy PSDRoot.cer to PSD deployment share</td>
  </tr>
  <tr>
    <td>Regenerate PSD boot media</td>
    <td>- Select PSD Deployment share in MDT Workbench<br>- Update deployment share and completely generate new boot media</td>
  </tr>
  <tr>
    <td>Task Sequence(s)</td>
    <td>- blah </td>
  </tr>
  </table>

# PSD Hydration
The **New-PSDHydration.ps1** script will completely build out a basic Windows Server in about 20 minutes. The PSD Hydration script calls the PSD installer script (Install-PSD.ps1) and the PSD installation script (New-PSDWebInstance.ps1) as part of it's activities.

## Hydration Prerequisites Checklist
* [ ] **Windows Server 2019** - Basic Windows 2019 Server **without** IIS or WebDAV pre-installed or configured. This server should be as vanilla as possible.
* [ ] **Download PSD** - Download and store the PSD content including Documentation, Installers, Scripts and Tools.
* [ ] **Download ADK** - Download and store the appropriate ADK installer for your environment. You can optionally also run the ADK in advance and download the actual ADK content in advance.
* [ ] **Download ADK for PE** - Download and store the appropriate ADK for PE installer for your environment. You can optionally also run the ADK PE Installer in advance and download the actual ADK content in advance.
* [ ] **Download MDT** - Download and store the appropriate MDT installer for your environment. 
* [ ] **Download Windows 10** - Download and store an appropriate Windows 10 ISO for your environment. 
    >PRO TIP: You may want to avoid the use of **Evaluation** media as it's not been thoroughly tested. 
* [ ] **Network Access Account** - (pre)create a domain or local account that can be used to access the PSD deployment share.
    >PRO TIP: Make sure this account has the least privileges needed. At a minimum, read/execute/list for the deployment share. This account does not require JoinDomain or Logon rights. 
* [ ] **Create deployment share Location** - The Hydration script expects a target share folder to already have been created.
* [ ] **Run the PSD Hydration script** - The PSD hydration script will run mostly silent by default, but will require some info and input to complete. The PSD Hydration script generates a log in the same directory it was run from.
    >PRO TIP: Run the PSD hydration script from an elevated PowerShell prompt with the **-verbose** option for maximum visibility.

## Post Hydration Tasks
You'll still need to do some things after PSD hydration is finished:
- Configure Firewall ports
- Configure certificates 
- Customize wallpaper(s)
- Customize Bootstrap.ini
- Customize CustomSettings.ini
- (Optional) Edit your task sequence
- Add your hardware drivers
- Add your applications
- etc (and more)

