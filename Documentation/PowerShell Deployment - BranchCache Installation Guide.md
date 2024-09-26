# BranchCache Installation Guide

## BranchCache Installation Overview

With the support of the free OSD Toolkit from 2Pint Software, you can enable BranchCache (P2P) for OS deployment. This is especially useful when deploying from servers in AWS or Azure, where you have to pay for data download, but you will also find P2P can speed up deployment on your local networks too.

> NOTE: For BranchCache to work, you must have setup your PSD deployment share for HTTP or HTTPS (recommended). See the "PowerShell Deployment - IIS Configuration Guide" for details.

## Enable BranchCache on your deployment server

To enable the BranchCache feature on Windows Server 2016 or Windows Server 2019, simply run the below command in an elevated PowerShell prompt:

Install-WindowsFeature BranchCache

## Enable BITS and BranchCache on your PSD Boot Image

For BranchCache to work during OS deployment, BITS and BranchCache components needs to be added to the PSD boot image.

1) Download the OSD Toolkit from 2Pint Software: https://2pintsoftware.com/products/osd-toolkit1/, and unpack to the PSDResources\Plugins\OSDToolkit folder in your PSD deployment share.
2) Import a Windows 10 operating system that is matching your boot image version. For example, if your deployment server is using Windows ADK 10 2004, import the install.wim from a Windows 10 2004 x64 ISO (Business Edition).
3) Update the CustomSettings.ini with the following:

```ini
BranchCacheEnabled=YES
SMSTSDownloadProgram=BITSACP.EXE
OSDToolkitImageName=Name (label) of imported operating system
```

4) In the PSD deployment share/scripts folder, in the PSDUpdateExit.ps1 script, make sure the lines in the "Added for the OSD Toolkit Plugin" are not commented out.
5) Update the PSD deployment share, and select the "completely regenerate the boot images" option.
6) Review the `Set-PSDBootImage2PintEnabled.log` file in _PSDResources\Plugins\OSDToolkit_ for errors.
7) If using PXE, add the updated LiteTouchPE_x64.wim to your PXE Server.

## Modify your Task Sequence

Finally, the task sequence have to be instructed to enable BITS and BranchCache, and to move the BranchCache cache to the full Windows installation in the end of the WinPE phase.

1) Edit your task sequence, and after the "Format and Partition Disk (UEFI)" action create a group named 2Pint Software.
1) In the 2Pint Software group, add a Run Command Line action with the following settings:
    - Name: Enable BranchCache to %_SMSTSMDataPath%
    - Command Line: BCEnabler.exe Enable %_SMSTSMDataPath%\BCCache 2 1337
1) After the "Configure" action create another group named 2Pint Software.
1) In the second 2Pint Software group, add a Run Command Line action with the following settings:
    - Name: Move BranchCache Cache
    - Command Line: BCEnabler.exe Move %OSVolume%: