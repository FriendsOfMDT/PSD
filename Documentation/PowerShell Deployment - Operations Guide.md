# Operations Guide

## Introduction
PSD enabled deployments works the same as standard MDT Lite Touch Deployments. They can be initiated via PXE, or via Boot Media (ISO/USB). Here follows a list of common operations actions for the PSD solution

* **Import Operating Systems** - Within MDT Deployment workbench, on the newly created PSD Deployment share, import/create/copy any desired Operating Systems. Follow MDT-provided instructions and techniques. 
    >PRO TIP: You can copy Operating Systems from other MDT deployment shares.

* [ ] **Create PSD Task Sequence** - You **MUST** create a new Task Sequence from the PSD Templates within the workbench. PSD will fail otherwise. Do not attempt to clone/copy/import or otherwise work around this step. Some steps are required for PSD functionality. Do not delete any of the PSD task sequence steps - you may disable steps in the PSD Template task sequences if you choose.

    >PRO TIP: If you upgrade PSD version at a later date, **expect** to recreate your task sequences from the new PSD templates.

* **Create Applications** - Within MDT Deployment workbench, on the newly created PSD Deployment share, import/create/copy any desired Applications. Follow MDT-provided instructions and techniques. Make note of application's unique GUIDs for use automating application installation with CustomSettings.ini.
    >PRO TIP: You can copy Applications from other MDT deployment shares.

* **Import/Add Drivers** - Within MDT Deployment workbench, on the newly created PSD Deployment share, import/create/copy any desired drivers. After adding new drivers to MDT using the "total control method" (OS/Make/Model, or OS/Model, etc. ), you need to run the New-PSDDriverPackage.ps1 to generate the ZIP or WIM archives. One ZIP or WIM archive is created for each OS and Model.
    >PRO TIP: You can copy Drivers from other MDT deployment shares, and PSD also supports that you add any existing WIM or ZIP driver packages to the platform.

Sample syntax: 
.\New-MDTDriverPackage.ps1 -psDeploymentFolder E:\PSDProduction -CompressionType WIM

.\New-MDTDriverPackage.ps1 -psDeploymentFolder E:\PSDProduction -CompressionType ZIP

* **Check Deployment Share Permissions** - By default, the PSD installer creates an MDT folder structure for PSD. PSD-specific files , scripts and templates are added and a new SMB share is created if specified. Ensure that the necessary domain and/or local computer user accounts have access to the PSD Share. 

    >PRO TIP: Only grant the *minimum necessary rights* to write logs in the PSD share. Only **READ** rights are required for the 
    PSD/MDT share.

* **Update Windows PE settings** - Update the MDT WinPE configurations panels including the following settings:
- WinPE Custom Wallpaper (see notes below)
- WinPE Extra Directory (configured by default)
- ISO File name and generation
- WIM file name and generation
  
* **Enable MDT monitoring** - Enable MDT Event Monitoring and specify the MDT server name and ports to be used. 

* **Update CustomSettings.ini** - Edit and Customize CUSTOMSETTINGS.INI to perform the necessary and desired automation and configuration of your OSD deployments. These should be settings to affect the installed OS typically. Be sure to configure new PSD properties and variables. See XXX for more details.

* **Update BootStrap.ini** - Edit and customize BOOTSTRAP.INI for your any necessary and desired  configuration of your OSD deployments. These should be settings to affect the OSD environment typically. Be sure to configure new PSD properties and variables. 
    >PRO TIP: If using the new PSDDeployRoots property, remove *all* reference to DeployRoot from BootStrap.ini. 

* **Update Background wallpaper** - By default, a new PSD themed background wallpaper (PSDBackground.bmp) is provided. It can be found at Samples folder of the MDT installation. Adjust the MDT WinPE Customizations tab to reflect this new bmp (or use your own).
    
* **Configure Extra Files** - Create and populate an ExtraFiles folder that contains anything you want to add to WinPE or images. Things like CMTRACE.EXE, wallpapers, etc.
    >PRO TIP: Create the same folder structure as where you want the files to land (e.g. \Windows\System32)

* **Configure WinPE Drivers** - Using MDT Selection Profiles, customize your WinPE settings to utilize an appropriate set of MDT objects. Be sure to consider Applications, Drivers, Packages, and Task Sequences.

* **Generate new Boot Media** - Using MDT Deployment workbench techniques, generate new boot media. By default the installer, will configure NEW PSD deployment shares to be PSDLiteTouch_x64.iso and PSDLiteTouch_x86.iso. Rename these if necessary.
    
* **Content Caching and Peer to Peer support** - Please see the BranchCache Installation Guide for information on how to enable P2P support.




