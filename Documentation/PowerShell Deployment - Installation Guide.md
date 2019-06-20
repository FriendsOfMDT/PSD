# Installation Guide - PowerShell Deployment Extension Kit
April 2019

## PSD Installation Materials Checklist
In order to install PSD you'll need to obtain the following installation media and checklist items:

* [ ] **ADK** - Download and install Microsoft ADK on a computer to be used to host the MDT Workbench. Ensure Microsoft ADK is installed and operational

* [ ] **MDT** -  Download and install Microsoft MDT on a computer to be used to host the MDT Workbench. Ensure Microsoft MDT is installed and operational

* [ ] **Source Media (OS)** - Obtain source media for Windows client (or server) OS you intend to deploy

* [ ] **Source Media (Language Packs)** - Obtain source media for Windows OS Language Packs

* [ ] **Source Media (Applications)** - Obtain source media for any applications to be installed as part of task sequences

* [ ] **Source Media (Drivers)** - Obtain source media and drivers for OEM hardware and peripherals

* [ ] **Wallpaper** - [optional] Obtain any necessary custom backgrounds and wallpapers

* [ ] **WDS** - [optional] Ensure Windows Deployment Services is installed and available (if implementing WDS-based initiation)

* [ ] **SQL** - [optional] - SQL installed for MDT database functionality and integration

* [ ] **Accounts** - You'll need account(s) with sufficient rights for the following actions and activities:
    - Installing SQL
    - Installing IIS and WebDAV
    - Installation of MDT and PSD
    - Accessing PSD/MDT Share(s)
    - Accessing log folder location(s)
    - Domain joining computers to Active Directory

# PSD Installation Options
PSD can be installed and configured either manually or via PSD installation and hydration scripts. Both approaches are covered in this document:
- **Manual** - useful when you have an existing server with MDT already installed, you want more explicit control over the installation of PSD or you're updating to a new version of MDT or PSD. 
    >NOTE: Manual installation should be used for **production** environments when there are multiple installation and configuration considerations
- **Hydration** - Primarily intended to quickly setup and test PSD in a non-production environment. Useful if you have a bare server and want to minimize the number of configurations required
    >NOTE: Hydration of PSD is should only be used for **test** environments. There are no considerations for customization in this release!

# PSD Hydration
The PSD solution provides three scripts to automate and simplify the installation and configuration of PSD:

1) **New-PSDHydration** - used to automate the installation and configuration of PSD. Calls Install-PSD.ps1 and New-PSDWebInstance.ps1
1) **Install-PSD.ps1** - used to install PSD on top of an MDT installation
1) **New-PSDWebInstance.ps1** - used to install and configure IIS and WebDAV on a fresh server

## PSD Hydration Step-by-Step
>NOTE: This version of hydration only supports installation to C: as default for all components and options.

The PSD hydration script (New-PSDHydration.ps1) should only be used in test or evaluation environments. It calls two other scripts from the PSD solution payload as part of it's execution: Install-PSD.ps1 and New-PSDWebInstance.ps1.  It will install and configure the following components to default locations on C: drive:

- Install ADK
- Install ADK PE extensions (if required)
- Install MDT
- Install PSD
- Install PSD templates and samples
- Import and instantiate an OS from ISO (future will support WIM too)
- Create an initial PSD task sequence 
- Create PSD boot media
- Enable MDT Monitoring
- Update and customize WinPE
- Install and configure IIS
- Install and configure WebDAV

>NOTE: On decent hardware, PSD Hydration will require approximately 20-25 minutes after completing the wizards.

## PSD Hydration Environment
To install PSD using the included hydration scripts, you'll need to provide a fresh, bare Windows Server with nothing but patches and network connectivity. Normal hardware requirements for MDT should be satisfied (e.g. CPU, RAM, Disk, network). The server can be either workplace or domain joined. As with any server, the network IP address(es) should be static and not DHCP due to the use of IIS.
>PRO TIP: You'll want to have at least 20-30G of free space on the C: drive to hold all the downloads, installers, and the resulting MDT/PSD installation. 

## PSD Hydration high-level instructions
1) Logon to the target PSD server with administrative rights
1) Download the entire PSD source content from the [PSD GitHub](https://github.com/FriendsOfMDT/PSD) repository locally to the target server
1) The hydration script will prompt for the files above as it executes. Download or have access to the necessary source files:
    - MDT - [Download MDT](https://www.microsoft.com/en-us/download/details.aspx?id=54259)
    - ADK - [Download ADK](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install)
    - ADK for WinPE - [Download ADKPE](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install)
    - PSD Install script (Install-PSD.ps1) - [Download PSD](https://github.com/friedsofmdt/PSD)
    - Windows 10 OS ISO - [MSDN](https://msdn.microsoft.com) or [Volume License Servicing Center (VLSC)](https://www.microsoft.com/licensing/servicecenter/default.aspx)

    >NOTE: You can either download just the ADKSetup.exe or go ahead and run the installation of ADKSetup.exe before hand (-layout).
1) Open an **elevated** PowerShell prompt
    >PRO TIP: **Avoid using PowerShell ISE**, there's some bugginess with it when used in conjunction with the PSD Hydration and Installation scripts.
1) Navigate to the PSD Hydration script location in "Tools" folder and execute ./New-Hydration.ps1
    >PRO TIP: Add the -verbose command for maximum output visibility
1) Respond to the PSD Hydration script prompts for inputs and locations of installation files 
![PSD Hydration Wizard](images/Config/PSDHydration-Wizard.png "PSD Hydration Wizard")
    >PRO TIP: Make sure the target folder for PSD is **EMPTY** -or- alternatively ensure you use the -upgrade parameter
1) New-PSDHydration.ps1 will complete
1) Reboot and run New-PSDHydration.ps1 -verbose again to complete IIS installation
1) Review the New-PSDHydration output log file 
1) You'll need to still need to populate PSD with your OS files, applications and drivers along with creating task sequences and generating boot media
    - Refer to the PSD Configuration Checklist below for detailed configuration guidance
    - If you used a "Business Editions" ISO, you may want to delete any N or EDU Operating Systems from the workbench
    - Only ENT and PRO task sequences will be created from a "Business Editions" ISO

# Manually Installing PSD
PSD, IIS, WebDAV and other components can also be installed manually if substantial customization is required or you're installing into an existing environment. Manual PSD installation requires the following:
- Administrative rights on the MDT Workbench computer 
- Existing installation of MDT Workbench and ADK
- Downloaded or local copy of the PSD solution and it's installers

1) Install ADK (make note of the version)
1) Install ADK for PE (if needed) (make note of version)
1) Install MDT (make note of version)
1) Download or clone the PSD content from the [PSD GitHub Home](https://github.com/FriendsOfMDT/PSD)
1) Open an elevated PowerShell command prompt, run one of the following commands:
    - For **NEW** installations of PSD run:
        - ./PSD_Install.ps1 -psDeploymentFolder \<your folder path> -psDeploymentShare \<your share name>
    - To **UPGRADE** an existing MDT/PSD installation run: 
        - ./PSD_Install.ps1 -psDeploymentFolder \<your folder path>  **-upgrade**
1) Review the command window and PSD installation log (future) for errors
1) You should see PSD folders ./SCRIPTS and ./TOOLS in your MDT Workbench
    >PRO TIP: You may need to refresh or open and close your Workbench for the PSD deployment share to appear.

# PSD Configuration Checklist
The following actions should be completed as part of PSD configuration regardless of installation technique.

* [ ] **Install PSD** - Install PSD on a machine with ADK and MDT already installed. Install PSD either as a NEW deployment share or as an UPGRADE to an existing MDT deployment share. Detailed PSD installation instructions can be found in the [PSD Installation Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20Installation%20Guide.md).

* [ ] **Setup PSD in MDT** - Following installation of PSD, navigate to and open the newly created PSD deployment share in the MDT Workbench

* [ ] **Import Operating Systems** - Within MDT Workbench, on the newly created PSD Deployment share, import/create/copy any desired Operating Systems. Follow MDT-provided instructions and techniques. 
    >PRO TIP: You can copy Operating Systems from other MDT deployment shares.

* [ ] **Create Applications** - Within MDT Workbench, on the newly created PSD Deployment share, import/create/copy any desired Applications. Follow MDT-provided instructions and techniques. Make note of application's unique GUIDs for use automating application installation with CustomSettings.ini.
    >PRO TIP: You can copy **Applications** from other MDT deployment shares.

* [ ] **Import/Add Drivers** - Within MDT Workbench, on the newly created PSD Deployment share, import/create/copy any desired DRIVERS. Follow MDT-provided instructions and techniques. Make note of their unique package IDs for use automating drivers installation using CustomSettings.ini.
    >PRO TIP: You can copy **Drivers** from other MDT deployment shares.

* [ ] **Import/Add Language Packs** - Within MDT Workbench, on the newly created PSD Deployment share, import any desired LANGUAGE PACKS. Follow MDT-provided instructions and techniques. Make note of their unique GUIDs for use automating language packs installation using CustomSettings.ini.
    >PRO TIP: You can copy **Language** entries from other MDT deployment shares.

* [ ] **Check deployment share Permissions** - By default, the PSD installer creates an MDT folder structure for PSD. PSD-specific files, scripts and templates are added and a new SMB share is created if specified. Ensure that the necessary domain and/or local computer user accounts have access to the PSD share. 

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