# Toolkit Reference

In this document you find generic developer info for further customizing PSD, as well as a reference to the scripts used in the solution.

## Enable Debugging

By adding PSDDebug=YES to Bootstrap.ini you force PSD to run in debug mode. The old method of specifying the -Debug parameter to the PSDStart.ps1 command line still works, and is useful when doing interactive troubleshooting in WinPE or Windows.

## Logging via Write-PSDLog

Logging in all PSD modules and scripts is, and should be accomplished via a new **Write-PSDLog** function found in PSDUtility.psm1. For PSD development you should leverage this new function to capture output for logging and or debug purposes. The following syntax should be used or duplicated:

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): <<your message or output>>

This will output your message or text to the log file along with the calling script. Sample output looks like the following from the Get-PSDLocalDataPath function:

    <![LOG[Get-PSDLocalDataPath: Return the cached local data path if possible]LOG]!><time="20:31:39.462+000" date="03-26-2019" component="PSDUtility.psm1:27" context="" type="1" thread="" file="">

## Scripts, Modules and Libraries

The following PowerShell modules and scripts are provided with PSD:

## Main PSD Scripts

| Script               	| Description 	| Equivalent LTI script
|----------------------	|-------------	| ---------------|
| PSDApplications.ps1 	| Installs the apps specified by task sequence variables *Applications* and *MandatoryApplications*. Downloads applications to the PSD cache after validating platform and checking for existing or previous installation. Supports msiexec.exe, .CMD and cscript installations. | ZTIApplications.wsf
| PSDApplyOS.ps1       	| Sets PowerCFG to full power profiles. Applies the OS image and injects drivers using DISM. Modifies boot configurations. | LTIApply.wsf
| PSDConfigure.ps1     	| Customizes and configures the Unattend.xml file.        | ZTIConfigure.wsf
| PSDDrivers.ps1       	| Copies drivers to PSD cache on target systems. | ZTIDrivers.wsf|
| PSDGather.ps1        	| Runs PSDGather from PSDGather.psm1 and gathers environment and target device information and details | ZTIGather.wsf
| PSDPartition.ps1     	| Partitions and configured disks. Disk partitioning details are hardcoded inside this script. Do NOT change. | ZTIDiskpart.wsf   |
| PSDSetVariable.ps1   	| Script to set variables | ZTISetVariable.wsf |
| PSDStart.ps1         	| Starts or continues a PSD-enabled task sequence.| LiteTouch.wsf |
| PSDTBA.ps1           	| Placeholder script for scripts not yet converted | Varies |
| PSDTemplate.ps1      	| Sample PowerShell template for PSD development | template | N/A
| PSDValidate.ps1      	| Checks for system requirements            	| ZTIValidate.wsf |
| PSDWindowsUpdate.ps1 	| Script that runs Windows Update            	| ZTIWindowsUpdate.wsf         |

## PSD Modules

| Module                	| Description 	|
|------------------------	|-------------	|
| PSDGather.psm1    	    | Module for gathering information about the OS and environment (mostly from WMI), and for processing rules (Bootstrap.ini and CustomSettings.ini). All the resulting information is saved into task sequence variables.        	|
| PSDUtility.psm1         | General utility routines for all PSD scripts.        	| PSDWizard.psm1     	    | Module for the PSD Wizard        	|
| PSDDeploymentshare.psm1 | Module for connecting to a deployment share and obtain content from it, using either HTTP/HTTPS or SMB.        	|
| PSDWizardNew.psm1 | Module for new PSD Wizard

## PSD Wizard Files

| Script                	    | Description 	| Replacement |
|------------------------	    |-------------	| ----------- |
| PSDWizard.xaml   	            | Template for the old PSD Wizard        	| Various XML files
| PSDWizard.xaml.initialize.ps1 | Script to initialize the wizard content in PSD         	| Wizard.hta


## PSD Helper scripts for test and development

| Module                	    | Description 	|
|------------------------	    |-------------	|
| DumpVars.ps1 | Enumerates all task sequence variables         	|
| PSDHelper.ps1 | Imports main PSD modules for testing         	|

## MDT Dependencies

The following MDT components and files are utilized, consumed, and or referenced by PSD:
- ZTIGather.xml
- ZTIConfigure.xml