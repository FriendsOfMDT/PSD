# Operators Guide - PowerShell Deployment Extension Kit
April 2019

## Introduction
PSD enabled deployments are very much like legacy MDT Lite Touch Deployments. The can be initiated via PXE and WDS or via Boot Media. The primary difference is that just about everything from MDT has been replaced with PowerShell scripts to accomplish the same functionality. 

Additionally, PSD deployments can be implemented from not only UNC paths (traditional Deployment Shares), but also from HTTP and HTTPS deployment shares. This opens up a new capability for bare metal wipe and load scenarios across the Internet! 

## Installation
Installation is relatively straight forward. You can either install PSD and specify a NEW deployment repository and share -or- you can upgrade (and extend) an existing MDT deployment share and add-on PSD functionality. Installation is completed by downloading the PSD solution from [GitHub.com/FriendsOfMDT](https://github.com/FriendsOfMDT/PSD) and running the PSD_Install.ps1 script using the following syntax from an elevated PowerShell ISE prompt: 

    .\PSD_Install.ps1 -psdDeploymentFolder <folder> -psdDeploymentShare <sharename> (-Upgrade)

Refer to the  [PSD Installation Guide](https://github.com/FriendsOfMDT/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20Installation%20Guide.md) for detailed installation instructions.
>PRO TIP: You may want to experiment with the PSD Kit outside of production environments initially. 

## Configuration and Automation

### New PSD Variables - Overview
The following new TS variables are provided in conjunction with PSD. Any new or additional Task Sequence variables **must** be instantiated and called via Bootstrap.ini or CustomSettings.ini !! Do NOT edit or modify ZTIGather.xml (ever).

### PSD Environmental Variables
The following new environmental variables are pre-configured and/or defined as part of PSD. See below in this document for details on new PSD variables.
- IsOnBattery
- IsVM
- IsSFF
- IsTablet
- PSDDeployRoots
- AutoPilot

### PSD Debug Flow Control Variables
- DevCleanUp
- DevDebugLogging
- DevVerboseScreenLogging

## Bootstrap and CustomSettings INI files
Bootstrap.ini and CustomSettings.ini function as before in MDT. Both can be used to automate OS deployments using PSD. PSD supports the following:
- Custom Properties (variables)
- Custom Priorities
- Single instance variables
- Array variables
- User Exit Scripts
- MDT Database integration (future)

## PSDDeployRoots
A new TS variable (PSDDeployRoots) has been implemented so that designers and implementers can support *multiple* deployment roots. PSDDeployRoots takes a string of potential content repositories and feeds into PSD scripts for evaluation. At present, the list of deployment shares is processed in the order specified and the first successfully validated (and online) deployment share wins and will be used to provide content to the task sequence on the target device.

As an example, the following BootStrap.ini snippet is provided...

    - [Settings]
    - Priority = PDSVars, PSDLogs, Default
    - Properties = IsOnBattery, PSDDeployRoots

    - [Default]
    - PSDDeployRoots=http://someserver.off/nothing, https://SecureServer.off/Nothing, http://foo.bar.xyz/psd, \\SomeServer\SomeShare$

# Your First PSD Task Sequence
Make sure your target device meets the following minimum hardware specifications:
- 1.5GB RAM or better 
    > NOTE: WinPE has been extended under PSD and requires additional memory
- At least one (1) active network adapter(s)
- At least one (1) 50GB hard drive (for New/BareMetal deployments)
- At least XXX MHz processor (for New/BareMetal deployments)

- BLAH checklist
- BLAH debug
- BLAH wallpaper

# Troubleshooting PSD
Troubleshooting PSD is very similar to a traditional MDT environment. Except, nearly everything occurs via connectivity to a PSDrive and within a BDD/MDT Task Sequence.
 
## Simple PSD Testing and Development Environment
Some PSD functionality can be tested and developed using a technique similar to that for LTI deployments. It's a bit more complicated than it was for legacy MDT though.....

1. Create a new empty VM with sufficient and appropriate network, RAM and disk settings
1. Create a new Task Sequence using the **PSD RnD template**
1. Create a new Boot ISO and mount it in your new VM
1. Boot your VM using the new PSD Boot media
1. The VM should start and launch a PowerShell window
1. At this point, you should have a TS environment, access to TS variables. You can import modules, create PSDrives, and run many of the scripts and modules provided by PSD. The default script normally run first is PSDStart.ps1. You may need to map shares, and copy files locally. Have fun!

# PSD and 2Pint ACP
This section for how to install and configure PSD in conjunction with 2Pint software. [in progress]

### Pint Overview
[In Progress]

### Pre Requisites
- item 1
- item 2

### Installing 2Pint software for PSD
[In Progress]
- item 1
- item 2

### Configuring 2Pint software for PSD
- item 1
- item 2

### Testing, Validating and Troubleshooting 2Pint software for PSD
- item 1
- item 2

# Appendix - PSD Variables 
## Environmental Variables
The following variables may be useful when automating or customizing PSD capabilities. 

| **Variable** | **Mandatory/Optional** | Description |
|--------------|:------------:|-----------|
| **IsOnBattery** | Optional | Calculated value during PSDGather. TRUE if target computer is a laptop and is running on AC. FALSE if desktop or laptop running on battery.
| **IsVM** | Optional | Calculated value during PSDGather. TRUE if target computer is a virtual machine, otherwise FALSE.
| **IsSFF** | Optional | Calculated value during PSDGather. TRUE if target computer enclosure is type 34, 35 or 36 (Small Form Factor)
| **IsTablet** | Optional | Calculated value during Gather. TRUE if target computer enclosure is type 13, 33, 31, or 32 (Tablet)
| **PSDDeployRoots** | Optional | PSDDeployRoots is used to define multiple deployroots of either UNC, HTTP or HTTPS formats. Can *NOT* be called in conjunction with DeployRoot. See additional [notes](https://foo.link)
| **AutoPilot** | Optional | Used to define how a target computer will be built using Autopilot. JSON is used if the target computer will only have the JSON file processed while SYSPREP is defined if the system should be prepared by running sysprep.exe and then completing an Autopilot deployment.

## Development and Debugging Variables
The following variables may be useful when customizing or developing PSD capabilities. 

| **Variable** | **Mandatory/Optional** | Description
|--------------|:------------:|-----------|
| **DevCleanUp** | Optional | Used to the control cleanup up log files. When set to TRUE, the task sequence engine removes all log files. When FALSE, log files are left in place (C:\MININT)
| **DevDebugLogging** | Optional | [In Progress]
| **DevVerboseScreenLogging** | Optional | [In Progress]
 

