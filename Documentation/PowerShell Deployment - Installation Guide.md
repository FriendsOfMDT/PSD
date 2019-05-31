# Installation Guide - PowerShell Deployment Extension Kit
April 2019

## PSD Installation Checklist
Please review, validate and/or obtain the following installation checklist items:

* [ ] **ADK** - Download and install Microsoft ADK on a computer to be used to host the MDT Workbench. Ensure Microsoft ADK is installed and operational

* [ ] **MDT** -  Download and install Microsoft MDT on a computer to be used to host the MDT Workbench. Ensure Microsoft MDT is installed and operational

* [ ] **Source Media (OS)** - Obtain source media for Windows OS

* [ ] **Source Media (Applications)** - Obtain source media for any applications to be installed as part of task sequences

* [ ] **Source Media (Drivers)** - Obtain source media for OEM hardware drivers

* [ ] **Source Media (Language Packs)** - Obtain source media for Windows OS Language Packs

* [ ] **WDS** - [optional] Ensure Windows Deployment Services is installed and available if implementing WinPE based initiation

* [ ] **Wallpaper** - [optional] Obtain any necessary custom backgrounds and wallpapers

* [ ] **SQL** - [optional] - SQL installed for MDT database functionality 

* [ ] **Accounts** - You'll need account(s) with sufficient rights for the following:
    - Accessing PSD/MDT Share(s)
    - Accessing log folder location(s)
    - Joining computers to Active Directory

# Installing PSD
PSD installation requires the following:
- Existing installation of MDT Workbench and ADK
- Administrative rights on the MDT Workbench computer
- Downloaded or local copy of the PSD solution and it's installer

1) If open, close the MDT Workbench.
1) Download or clone the PSD content from the [PSD GitHub Home](https://github.com/FriendsOfMDT/PSD)
1) Open an elevated PowerShell command prompt, run one of the following commands
    - For **NEW** installations of PSD run:
        - ./PSD_Install.ps1 -psDeploymentFolder \<your folder path> -psDeploymentShare \<your share name>
    - To **UPGRADE** an existing MDT/PSD installation run: 
        - ./PSD_Install.ps1 -psDeploymentFolder \<your folder path> -psDeploymentShare \<your share name> **-upgrade**
1) Review the command window and PSD installation log (future) for errors
1) You should see PSD folders ./SCRIPTS and ./TOOLS in your MDT Workbench
    >PRO TIP: You may need to refresh or open and close your Workbench for the PSD deployment share to appear.

## PSD Configuration Checklist
The following actions should be completed as part of PSD installation:

* [ ] **Install PSD** - Install PSD on a machine with ADK and MDT already installed. Install PSD either as a NEW deployment share or as an UPGRADE to an existing MDT deployment share. Detailed PSD installation instructions can be found in the [PSD Installation Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20Installation%20Guide.md).

* [ ] **Open PSD share in MDT** - Following installation of PSD, navigate to and open the newly created PSD deployment share in the MDT Workbench

* [ ] **Import Operating Systems** - Within MDT Workbench, on the newly created PSD Deployment share, import/create/copy any desired Operating Systems. Follow MDT-provided instructions and techniques. 
    >PRO TIP: You can copy Operating Systems from other MDT deployment shares.

* [ ] **Create Applications** - Within MDT Workbench, on the newly created PSD Deployment share, import/create/copy any desired Applications. Follow MDT-provided instructions and techniques. Make note of application's unique GUIDs for use automating application installation with CustomSettings.ini.
    >PRO TIP: You can copy **Applications** from other MDT deployment shares.

* [ ] **Import/Add Drivers** - Within MDT Workbench, on the newly created PSD Deployment share, import/create/copy any desired DRIVERS. Follow MDT-provided instructions and techniques. Make note of their unique package IDs for use automating drivers installation using CustomSettings.ini.
    >PRO TIP: You can copy **Drivers** from other MDT deployment shares.

* [ ] **Import/Add Language Packs** - Within MDT Workbench, on the newly created PSD Deployment share, import any desired LANGUAGE PACKS. Follow MDT-provided instructions and techniques. Make note of their unique GUIDs for use automating language packs installation using CustomSettings.ini.
    >PRO TIP: You can copy **Language** entries from other MDT deployment shares.

* [ ] **Check deployment share Permissions** - By default, the PSD installer creates an MDT folder structure for PSD. PSD-specific files , scripts and templates are added and a new SMB share is created if specified. Ensure that the necessary domain and/or local computer user accounts have access to the PSD share. 

    >PRO TIP: Only grant the *minimum necessary rights* to write logs in the PSD share. Only **READ** rights are required for the 
    PSD/MDT share.

* [ ] **Enable MDT/PSD Logging** - By default, the PSD installer pre-creates folders for LOGS and DYNAMIC LOGS in the root of the PSD deployment share along with configuring an SMB share if specified. (You may wish to point PSD logs somewhere else.) Ensure that the necessary domain and/or local computer user accounts have read and write access to the **LOGS** folders. 

    >PRO TIP: Only grant the *minimum necessary permissions and access* to write logs in your location

* [ ] **Update Windows PE settings** - Update the MDT WinPE configuration panels including the following settings:
    - WinPE custom wallpaper (see notes below)
    - WinPE Extra Directory (configured by default)
    - ISO File name and generation
    - WIM file name and generation
        >PRO TIP: Be sure to configure *BOTH* x86 and x64 WinPE settings.

* [ ] **Enable MDT monitoring** - Enable MDT Event Monitoring and specify the MDT server name and ports to be used. ![Event Monitoring configuration](images/Config/PSDConfig-Event.png "Event Monitoring")
    >PRO TIP: Azure hosted VMs FQDNs will likely not work when configuring MDT Event Monitoring. Just use the internal network name in the MDT configuration panel and be sure to specify the internet-facing Azure VM name in BootStrap and CustomSettings files. 

* [ ] **Update CustomSettings.ini** - Edit and customize *CustomSettings.ini* to perform the necessary and desired automation and configuration of your OSD deployments. These should be settings to affect the installed OS typically. Be sure to configure new PSD properties and variables. See XXX for more details.
    >PRO TIP: If using the new PSDDeployRoots property, remove *all* reference to DeployRoots from CustomSettings.ini. All other MDT techniques and settings still apply.

* [ ] **Update BootStrap.ini** - Edit and customize *BootStrap.ini* for your any necessary and desired  configuration of your OSD deployments. These should be settings to affect the OSD environment typically. Be sure to configure new PSD properties and variables. See XXX for more details.
    >PRO TIP: If using the new PSDDeployRoots property, remove *all* reference to DeployRoots from BootStrap.ini. All other MDT techniques and settings still apply.

* [ ] **Review and adjust PSD Variables** - blah

* [ ] **Update Background Wallpaper** - By default, a new PSD themed background wallpaper (PSDBackground.bmp) is provided. It can be found at Samples folder of the MDT installation. Adjust the MDT WinPE Customization tab to reflect this new .bmp (or use your own).
    >PRO TIP: Custom wallpapers should be 800x600 resolution!

* [ ] **Configure Extra Files** - Create and populate an ExtraFiles folder that contains anything you want to add to WinPE. Things like *cmtrace.exe, wallpapers, etc.
    >PRO TIP: Create the same folder structure as where you want the files to land (e.g. \Windows\System32\)

    >PRO TIP WARNING: If using WinPE v1809, you **MUST** source and stage **BCP47Langs.dll** and **BCP47mrm.dll**, otherwise the PSD deployment wizard and final WinForms will crash.

* [ ] **Include Custom Branding files** - Populate the appropriate PSD Resource folder with branding files. These include PSD_Progress01.png, branding.txt and blah. Copy these to <deployment share\Resources\Branding>. PSD Scripts will inject the branding files and text to the appropriate location(s).

* [ ] **Include Certificates for HTTPS** - Populate the appropriate PSD Resource folder a certificate named **PSDRoot.cer** that will be used to authenticate target clients to download PSD/MDT content via HTTPS (443) and for secure transfer and access to the MDT Event Monitoring Service on 9800/9801. Copy the cert to <deployment share\Resources\Certs> and PSD Scripts will inject the cert to the appropriate locations.

* [ ] **Include Custom Autopilot JSON file** - Populate the appropriate PSD Resource folder with your JSON file for AutoPilot Deployments. Copy a json file named PSD_AutopilotConfig.json to <deployment share\Resources\AutoPilot>. PSD Scripts will inject the JSON file and to the appropriate location.

* [ ] **Configure WinPE Drivers and Patches** - Using MDT Selection Profiles, customize your WinPE settings to utilize an appropriate set of MDT objects. Be sure to consider Applications, Drivers, Packages, and Task Sequences.
    >PRO TIP: You may want to create a new or custom Selection Profile unique to your new PSD-enabled PE environment.

* [ ] **Generate new Boot Media** - Using MDT Workbench techniques, generate *new* boot media. By default the installer, will configure NEW PSD deployment shares to be PSD_LTI_x64.iso and PSD_LTI_x86.iso. Rename these if necessary.
    >PRO TIP: PSD increases the size of boot media due to additional components. This may affect your ability to deploy on low-spec equipment.

* [ ] **Content Caching and Network Traffic Shaping** - Integrate, configure and test any necessary or required software and solutions that shape network traffic or cache content. This may include:
- Peer Caching
- Branch Cache
- Delivery Optimization
- 2Pint software
- 1E Nomad
- Hardware-based content caching solutions (F5)
    >PRO TIP: When setting up and testing PSD for the first time, stick to the basics and eliminate caching and traffic shaping until you're comfortable with PSD functionality.

* [ ] **Review Network, Firewall and Active Directory** - If you're deploying Windows 10 for the first time, be sure to review the following:
- Active Directory Group Policies (specifically for Windows 10 settings)
- Network Firewall settings
- Windows 10 firewall settings
- PXE availability
- Windows Deployment Services (WDS)
    >PRO TIP: Create a new Organizational Unit (OU) for both PSD testing and on-going Windows 10 administration

    >PRO TIP: Be on the lookout for multiple (or rogue) PXE servers on  network segments

    >PRO TIP: You'll need to enable TCP ports 80, 443, 9800 and 9801 for most scenarios.

* [ ] **Configure IIS for PSD over HTTP/S** - Install and configure IIS and WebDAV). See the [IIS Configuration Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20IIS%20Configuration%20Guide.md) for details.
    - [ ] Install IIS
    - [ ] Install and configure WebDAV
    - [ ] Test your HTTP/S PSD functionality
    >PRO TIP: The PSD IIS installation script expects to find a clean environment without IIS or WebDAV installed.

* [ ] **Create PSD Task Sequence** - You **MUST** create a new PSD task sequence from the PSD Templates within the MDT workbench. PSD will fail otherwise. Do not attempt to clone/copy/import or otherwise work around this step. Some task sequence steps are required for PSD functionality. Do not delete any of the PSD task sequence steps - you may disable steps in the PSD Template task sequences if you choose.

    >PRO TIP: If you upgrade PSD version at a later date, **expect** to have to recreate your task sequences from the new PSD templates and to update any associated boot media.

# Troubleshooting
The following links are provided to assist in troubleshooting.
- [MDT Event Service troubleshooting](https://blogs.technet.microsoft.com/mniehaus/2012/05/10/troubleshooting-mdt-2012-monitoring/)