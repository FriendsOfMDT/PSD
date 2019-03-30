# 1. Operators Guide - PowerShell Deployment Extension Kit
April 2019



## 1.1. Introduction
PSD enabled deployments are very much like legacy MDT Lite Touch Deployments. The can be initiated via PXE and WDS or via Boot Media. The primary difference is that just about everything from MDT has been replaced with PowerShell scripts to accomplish the same functionality. 

Additionally, PSD deployments can be implemented from not only UNC paths (traditional Deployment Shares), but also from HTTP and HTTPS deployment shares. This opens up a new capability for bare metal wipe and load scenarios across the Internet! 

## 1.2. Installation
Installation is relatively straight forward. You can either install PSD and specify a NEW deployment repository and share -or- you can upgrade (and extend) an existing MDT deployment share and add-on PSD functionality. Installation is run by downloading the PSD solution from GitHub [here] http://somelink.com using the following syntax from and elevated PowerShell ISE prompt: 

    .\PSD_Install.ps1 -psdDeploymentFolder <folder> -psdDeploymentShare <sharename> (-Upgrade)

Refer to the PSD Installation Guide [here] <PSD Install guide link>
>PRO TIP: You may want to experiment with the PSD Kit outside of production envrionments initially. 

## 1.3. Configuration and Automation

### 1.3.1. New PSD Variables - Overview
The following new TS variables are provided in conjuction with PSD. Any new or additional Task Sequence variables **must** be instatiated and called via Bootstrap.ini or CustomSettings.ini !! Do NOT edit or modify ZTIGather.xml.

### 1.3.2. PSD Environmental Variables
The following new environmental variables are pre-configured and/or defined as part of PSD. See below in this document for details on new PSD variables.
- IsOnBattery
- IsVM
- IsSFF
- IsTablet
- PSDDeployRoots

### 1.3.3. PSD Debug Flow Control Variables
- DevCleanUp
- DevDebugLogging
- DevVerboseScreenLogging

## 1.4. Bootstrap and CustomSettings INI files
Bootstrap.ini and CustomSettings.ini function as before in MDT. Both can be used to automate OS deployments using PSD. PSD supports the following:
- Custom Properties (variables)
- Custom Priorities
- Single instance variables
- Array variables
- User Exit Scripts
- MDT Database integration (future)

## 1.5. PSDDeployRoots
A new TS variable PSDDeployRoots has been implemented so that designers and implementers can support *multiple* deployment roots. PSDDeployRoots takes a string of potential content repositories and feeds into PSD scripts for evaluation. At present, the list of deployment shares is processed in the order specified and the first successfully validated (and online) deployment share wins and will be used to provide content to the task sequence on the target device.

As an example, the following BootStrap.ini snippet is provided...

- [Settings]
- Priority= PDSVars, PSDLogs, Default
- Properties=IsOnBattery, PSDDeployRoots

- [Default]
- PSDDeployRoots=http://someserver.off/nothing, https://SecureServer.off/Nothing, http://foo.bar.xyz/psd, \\\SomeServer\SomeShare$

# 2. Your first PSD Task Sequence
Make sure your target device meets the following minimum hardware specifications:
- 1.5GB RAM or better 
    > NOTE: WinPE under PSD has been extended and requires additional memory
- Network adapter(s)
- At least 50GB hard drive (for New/BareMetal deployments)
- At least XXX MHz processor (for New/BareMetal deployments)

BLAH checklist
BLAH debug
BLAH wallpaper

## 2.1. PSD and 2Pint ACP
This section for how to install and configure PSD in conjunction with 2Pint softaware

### 2.1.1. Pint Overview
tba Andreas

### 2.1.2. Pre Requisites
- item 1
- item 2

### 2.1.3. Installing 2Pint software for PSD
as;dlfkjas;lkdjf
- item 1
- item 2

### 2.1.4. Configuring 2Pint software for PSD
- item 1
- item 2

### 2.1.5. Testing, Validating and Troubleshooting 2Pint software for PSD
- item 1
- item 2

# 3. Appendix - PSD Variables 
## 3.1. Environmental Variables
The following variables may be useful when automating or customizing PSD capabiltiies. 

| **Variable** | **Mandatory/Optional** | Description
|--------------|:------------:|-----------|
| **IsOnBattery** | Optional | Caclulated value during Gather. TRUE if target computer is a laptop and is running on AC. FALSE if desktop or laptop running on battery.
| **IsVM** | Optional | Caclulated value during Gather. TRUE if target computer is a virtual machine, otherwise FALSE.
| **IsSFF** | Optional | Caclulated value during Gather. TRUE if target computer eclosure is type 34, 35 or 36 (Small Form Factor)
| **IsTablet** | Optional | Caclulated value during Gather. TRUE if target computer eclosure is type 13, 33, 31, or 32 (Tablet)
| **PSDDeployRoots** | Optional | PSDDeployRoots is used to define multiple deployroots of either UNC, HTTP or HTTPS formats. Can *NOT* be called in conjuction wtih DeployRoot. See additonal notes [here] (https://foo.link)

## 3.2. Development and Debugging Variables
The following variables may be useful when customizing or developing PSD capabiltiies. 

| **Variable** | **Mandatory/Optional** | Description
|--------------|:------------:|-----------|
| **DevCleanUp** | Optional | Used to control cleanup up log files. When set to TRUE, removes all log files. When FALSE, log files are left in place.
| **DevDebugLogging** | Optional | blah blah blah
| **DevVerboseScreenLogging** | Optional | blah blah blah 

