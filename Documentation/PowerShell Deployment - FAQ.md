# FQ - PowerShell Deployment Extension Kit
April 2018

This document artifact highlights and documents some of the known issues and limitation of PSD as of the published date above. 

## Frequently Asked Questions
Q: Does the installer copy over my existing MDT Deployment Share content?

A: No, users and administrators will need to copy/export any existing components to PSD-enabled using in-built content management features of MDT.

Q: Does the installer copy over my existing BootStrap.ini or CustomSettings.ini files to the target PSD repositories?

A: No, if you've created a new PSD-enabled deployment share, users and administrators will need to manually copy or reproduce any existing Bootstrap and CustomSettings files to new repositories.

Q: What has PSD been tested against? What are the supported (tested) components?

A: The following components and versions were tested or used in development of PSD for MDT:
- MDT - version 8456
- WinPE Add - 
- ADK - version XXX
- Windows 10 - 1809 Enterprise
- BareMetal via UNC
- BareMetal via HTTP
- IIS 
- WebDAV
- PXE - Windows Server 2016, Windows Server 2019

## Installation Observations

- The PSD installer will create the -psDeploymentShare name *exactly* as specified. The PSD installer does **not** handle or change the hidden share $ character in any form or fashion.

- The PSD installer does **not** automatically mount a new PSD-created deployment share respository. Users will need to mount newly created PSD deployment shares manually.

- The PSD installer does **not** automatically copy over any existing MDT artifacts and components to a new PSD-created deployment share respositories. Users will need to manually copy over, re-import or instatiate applications, drivers, etc. manually.

## Opeational Observations
Please review the PSD Installation Guide for additional detailed post-installation configuration recomendations.

- Applications specified in the TS or in BS/CS.ini **MUST** have { } brackets around their GUID



