
# Beginners Guide for ADK and MDT

Welcome to the beginner's guide for installing ADK (Assessment and Deployment Kit) and MDT (Microsoft Deployment Toolkit). It's completely okay to be new to this – you're in the right place! By following this guide, you'll be well on your way to becoming a top-notch OS deployment technician.

## Prerequisites

- A server running Windows Server OS.
- Administrative privileges on the server.
- Internet connection for downloading the necessary files.

## Step 1: Download and Install Windows ADK

1. **Download Windows ADK:**
   - Go to the Microsoft ADK download page here: [Download and install the Windows ADK](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)
   - Download the installer for the latest version of Windows ADK
   > HINT: Look for a link like: _Download the Windows ADK \<version\> (\<Date\>)_

2. **Run the ADK Installer:**
   - Launch the downloaded `adksetup.exe`.
   - Choose the installation path and click **Next**.
   - Select the features you need. Best options for MDT are:
     - **Deployment Tools**
     - Imaging and Configuratiuon Designer (ICD)
     - Configuration Designer
     - **User State Migration Tool (USMT)**
   - Click **Install** and wait for the installation to complete.

## Step 2: Download and Install WinPE Add-on

1. **Download WinPE Add-on:**
   - Go to the WinPE Add-on download page here: [Download and install the Windows ADK](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)
   - Download the WinPE add-on installer.
   > HINT: Look for a link like: _Download the Windows PE add-on for the Windows ADK \<version\> (\<Date\>)_

2. **Run the WinPE Add-on Installer:**
   - Launch the downloaded `adkwinpesetup.exe`.
   - Choose the installation path and click **Next**.
   - Click **Install** and wait for the installation to complete.

## Step 3: Install Microsoft Deployment Toolkit (MDT)

1. **Download MDT:**
   - Go to the MDT download page here: [Microsoft Deployment Toolkit (MDT)](https://www.microsoft.com/en-us/download/details.aspx?id=54259)
   - Download the MDT installer.

2. **Run the MDT Installer:**
   - Launch the downloaded `MDT_x64.msi`.
   - Follow the on-screen instructions to complete the installation.

## Step 4: Configure MDT

**DO NOT** launch the Deployment Workbench. This will be done when the PSD portion is done; it build your deploymentshare for you.

>NOTE: While MDT can work with Windows 11 with some modifications, it is no longer supported by Microsoft, nor are x86 deployments. However, integrating PSD modifies MDT to continue deployment of Windows 11 images.

To ensure things run smoother:

- Run command as an administrator on the MDT server:

```cmd
Mkdir "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\x86\WinPE_OCs"
```
- Download the necessary drivers need to support your models
- Download a Operating System ISO. These can be pull from MSDN or from the official link: [Download Windows 11 Disk Image (ISO) for x64 devices](https://www.microsoft.com/en-us/software-download/windows11?ISO&msockid=1a583ca89d6d67bd32e8289a9c446670)
- Download Applications needed.
>NOTE: Application setup is not provided with this documentation, however there are several guides online to show how it done.

## Links

- https://www.deploymentresearch.com/building-a-windows-11-24h2-reference-image-using-microsoft-deployment-toolkit-mdt/

## Conclusion

You have now installed Windows ADK, the WinPE add-on, and the Microsoft Deployment Toolkit on your server. You can now use MDT to deploy Windows operating systems across your network.

For instructions on how to setup PSD, refer to the [PSD Installation Guide](./PowerShell%20Deployment%20-%20Installation%20Guide.md)
