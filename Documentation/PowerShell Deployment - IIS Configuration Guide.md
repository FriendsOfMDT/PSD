# IIS Configuration Guide

## Introduction: 
In order to support OS deployments using PSD when content is hosted on a web server, a series of configuration items must be completed. This document highlights and outlines the settings and steps known to work with PSD.

> NOTE: Your security team and environment may require additional settings or lock down.

## Operating System Requirements for imaging via HTTP/HTTPS
We have tested the IIS Setup for PSD on the following server operating systems

       Windows Server 2016
       Windows Server 2019

## Install IIS and configure WebDAV
To install IIS and configure WebDAV for OSD you need to run two scripts, one for setup, and one for configuration, with a reboot in between.

To run the IIS Setup, run the first script (New-PSDWebInstance.ps1) without any parameters, and after completion, reboot the server. The New-PSDWebInstance.ps1 script is found in the Tools folder of PSD.

> NOTE: The IIS Setup script does currently NOT support a server that already has IIS installed, it has to be run on a clean Windows Server installation.

Then, to run the configuration, you run the second script (Set-PSDWebInstance.ps1), specifying your deployment folder, and the name of the virtual directory to create. The Set-PSDWebInstance.ps1 script is also located in the Tools folder of PSD. Sample syntax:

.\Set-PSDWebInstance.ps1 -psDeploymentFolder E:\PSDProduction -psVirtualDirectory PSDProduction 

## HTTPS and Certificates
To support imaging via HTTPS you need to install a proper web server certificate, and make sure the Root CA is added to WinPE. If you export the Root CA to the PSDResources\Certificates folder, PSD will automatically add it to WinPE when updating the deployment share.

For lab purposes, we also provide a script (New-PSDSelfSignedCert.ps1) that creates a self-signed certificate and exports it to the PSDResources\Certificates folder. You need to specify the deployment folder, the DNS Name of the cert, the validity period, and a friendly name. Sample syntax:

.\New-PSDSelfSignedCert.ps1 -psDeploymentFolder E:\PSDProduction -DNSName mdt01.corp.viamonstra.com -ValidityPeriod 2 -FriendlyName PSDProduction

## Firewall Ports
In addition to the IIS setup and configuration the following firewall ports needs to open: 

    * Port 80 for HTTP (not recommended)
    * Port 443 for HTTPS
    * Port 9080 for MDT Event Monitoring if enabled (disabled by default)

* ## IIS Setup Reference 
In this section you find a list of all components being added by the setup script as well as info on what the configuration script does.

* **IIS Components**

The following IIS components are required to ensure that PSD functions as expected for imaging via HTTP/HTTPS. This components are all available in the web server role.

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

* **WebDAV**

The PSD extension for MDT requires the WebDAV Redirector to be installed. This is a feature and not a role in Server Manager. This feature does require a reboot.

*  WebDAV Redirector

* **Configure IIS**

 For IIS, PSD requires some configuration changes in order to function. Most of these changes have to do with configuring IIS to work properly with WebDav. If you use the configuration script these will be automatically configured for you, but shorthand, the following needs to be done:

     * Create New Virtual Directory
     * Enable Directory Browsing
     * Disable Anonymous Authentication
     * Enable Windows Authentication
     * Create and add new MIME type 
     
* **Configure WebDAV**

Finally, PSD requires some configuration changes to WebDAV, and again, if you use the configuration script these will be automatically configured for you. Shorthand, the following needs to be done:

     * Enable WebDAV
     * Create new WebDav Authoring Rule
     * Modify WebDAV Settings
         * Allow File Extension Filtering
         * Allow Hidden Segment Filtering
         * Allow Verb Filtering
     * Modify Default MIME type

