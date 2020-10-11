# PSD Installation Guide

## PSD Installation Overview
The PSD installation script is used to either create a new, or extend an existing MDT deployment share. It is also possible to use the Hydration script on a new server to setup a PSD lab environment. For the Hydration scenario, check out the Hydration Kit Installation document.

> WARNING: We strongly recommend that you create a new deployment share for PSD, and copy an existing resources (applications, driversr, images) to it. Once a de ployment share is extended with MDT, standard MDT task sequences will no longer work!

## PSD Installer Supported Configurations
The PSD installer has been tested on the following:

Server operating systems

       Windows Server 2016
       Windows Server 2019

Windows ADK 10 

        Windows ADK 10 1903
        Windows ADK 10 2004

Microsoft Deployment Kit (MDT)

        MDT 8456

## PSD Supported Deployments
The following operating systems have been tested for deployment via PSD:

Server operating systems

       Windows Server 2016
       Windows Server 2019

Client Operating Systems
        
        Windows 10 1903 Pro or Enterprise x64 (English)
        Windows 10 1909 Pro or Enterprise x64 (English)
        Windows 10 2004 Pro or Enterprise x64 (English)

## PSD Installation Checklist
Please review, validate and/or obtain following installation checklist items:

* **Windows ADK 10** - Download and install Microsoft Windows ADK 10 on a computer to be used to host the MDT Deployment workbench. Ensure Microsoft ADK is installed and operational

* **MDT** -  Download and install Microsoft MDT on a computer to be used to host the MDT Deployment workbench. Ensure Microsoft MDT is installed and operational

* **Source Media (OS)** - Obtain source media for Windows OS

* **Source Media (Applications)** - Obtain source media for any applications to be installed as part of task sequences

* **Source Media (Drivers)** - Obtain source media for OEM hardware drivers

* **WDS** - [optional] Ensure Windows Deployment Services is installed and available if implementing PXE-based deployments.

* **Accounts** - You'll need account(s) with sufficient rights for the following:
    - Build Account for accessing PSD/MDT Share(s)
    - Join Domain Account for joining computers to Active Directory (currently requires line of sight to domain controller)

# Installing PSD
PSD installation requires the following:
- Existing installation of MDT and Windows ADK 10
- Administrative rights on the MDT Server
- Downloaded the PSD solution

> WARNING: Again, we strongly recommend that you create a new deployment share for PSD, and copy an existing resources (applications, driversr, images) to it. Once a de ployment share is extended with MDT, standard MDT task sequences will no longer work!

> NOTE: Existing MDT scripts are moved to a backup folder in the deployment share specified.

1) If open, close the MDT Deployment Workbench.
1) Download or clone the PSD content from the [PSD GitHub Home](https://github.com/FriendsOfMDT/PSD)
1) Open an elevated Powershell command prompt, run one of the following commands
    - For **NEW** installations of PSD run:
        - .\Install-PSD.ps1 -psDeploymentFolder \<your folder path> -psDeploymentShare \<your share name>
    - To **UPGRADE** an existing MDT/PSD installation run: 
        - .\Install-PSD.ps1 -psDeploymentFolder \<your folder path> -psDeploymentShare \<your share name> **-upgrade**
1) Review the PSD Installation log for errors

# Next steps
The default setup configures the PSD deployment share for deployment via SMB. To enable HTTP or HTTPS (recommended) deployments, follow the steps in the "PowerShell Deployment - IIS Configuration Guide"

To enable BranchCache (P2P) support, first complete the steps in the "PowerShell Deployment - IIS Configuration Guide", and then the steps in the "PowerShell Deployment - BranchCache Installation Guide".
