# Developers Guide - PowerShell Deployment Extension Kit
April 2019



# Coding add Development Standards
PowerShell vxxx is the standard for all PSD development.
There are three (3) critical files to the PSD execution environment.  These files along with the PSD-provided task sequences templates are coupled and sensitive to changes.
- PSDStart.ps1
- PSDPartition.ps1
- PSDApplyOS.ps1
>WARNING: Whatever you do, DO NOT EDIT or alter these files as you will destabilize your PSD experience and environment.

# Logging via Write-PSDLog
Logging in all PSD modules is and should be accomplished via a new **Write-PSDLog** function found in PSDUtility.psm1. Developers, coders and customizers should leverage this new function to capture output for logging and or debug purposes. The following syntax should be used or duplicated:

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): <<your message our output>>

This will output your message or text to the log file along with the calling script. Sample output looks like the following from the Get-PSDLocalDataPath function:

    <![LOG[Get-PSDLocalDataPath: Return the cached local data path if possible]LOG]!><time="20:31:39.462+000" date="03-26-2019" component="PSDUtility.psm1:27" context="" type="1" thread="" file="">

# Scripts, Modules and Libraries
The following PowerShell modules and scripts are provided with PSD:

## PSD Scripts
The following PowerShell scripts are included in PSD:
| Script               	| Description 	| Equivalent LTI script
|----------------------	|-------------	| ---------------|
| PSDApplications.ps1 	| Installs the apps specified by task sequence variables *Applications* and *MandatoryApplications*. Downloads applications to the PSD cache after validating platform and checking for existing or previous installation. Supports MSIExe.exe, .CMD and cscript installations. | ZTIApplications.wsf |
| PSDApplyOS.ps1       	| Sets PowerCFG to full power profiles. Applies the OS image using DISM. Modifies boot configurations | LTIApply.wsf |   
| PSDApplyWinPE.ps1     | Applies WinPE, supports reboot scenarios and disk operations  | n/a  |
| PSDConfigure.ps1     	| Customizes and configures the Unattend.xml file  | ZTIConfigure.wsf |
| PSDCustomPostWU.ps1  	| Incomplete. Installs customizations and custom actions POST Windows Update | n/a   |
| PSDCustomPreWU.ps1   	| Incomplete. Installs customizations and custom actions PRE Windows Update | n/a |
| PSDDisableBDEProtectors.ps1 | Disables BitLocker protection | ZTIDisableBDEProtectors.wsf |  
| PSDDrivers.ps1       	| Copies drivers to PSD cache on target systems and does offline install of those drivers | ZTIDrivers.wsf |
| PSDErrorInTS.ps1     	| (depricate) | n/a |
| PSDGather.ps1        	| Runs PSDGather from PSDGather.psm1 and gather environment and target device information and details. Updates information from Gather to the Task Sequence environment. INITIALIZATION -> VALIDATION -> STATECAPTURE -> PREINSTALL -> POSTINSTALL -> STATERESTORE  | LITGather.wsf
| PSDGroups.ps1         | (incomplete) Backup and restore local groups and memberships | ZTIGroups.wsf |
| PSDHelper.ps1        	| (development tool) Imports modules PSDUtility, PSDDeploymentShare, PSDGather. | n/a |
| PSDNextPhase.ps1     	| Manages the execution order of the Task Sequence engine (will be depricated) | ZTINextPhase.wsf |
| PSDNICConfig.ps1      | Configures NIC for IP, GW, SN (incomplete) | ZTINicConfig.wsf |
| PSDPartition.ps1     	| Partitions and configured disks. Disk partitioning details are hardcoded inside this script. Do NOT change. | ZTIDiskPart.wsf |
| PSDSetVariable.ps1   	| Sets OSD global variables for consumption within Task Sequence | ZTISetVariable.wsf | 
| PSDStart.ps1         	| Starts or continues a PSD-enabled task sequence.| LiteTouch.wsf |
| PSDTBA.ps1           	| Placeholder script for LTI scripts not yet converted | varies |
| PSDTemplate.ps1      	| Sample PowerShell template for PSD development | template |
| PSDUserState.ps1     	| (not yet implemented) | ZTIUserState.wsf | 
| PSDValidate.ps1      	| (not yet implemented) | ZTIValidate.wsf |
| PSDWindowsUpdate.ps1 	| (not yet implemented) | ZTIWindowsUpdate.wsf |

    
## PSD Modules
The following PowerShell script modules and function libraries are included in PSD:
| Module                	| Description 	|
|------------------------	|-------------	|
| PSDGather.psm1    	    | Module for gathering information about the OS and environment (mostly from WMI), and for processing rules (Bootstrap.ini, CustomSettings.ini).  All the resulting information is saved into task sequence variables	|
| PSDUtility.psm1         | General utility routines useful for all PSD scripts	|
| PSDWizard.psm1     	    | Module containing utilities for generating and processing the PSD Wizard |
| PSDDeploymentshare.psm1 | Connect to a deployment share and obtain content from it, using either HTTP(s) or SMB as needed |
| ZTIUtility.psm1 | Not really used, left over MDT relic |


## PSD Other Files
The following additional files are included in PSD:
| Module                	    | Description 	|
|------------------------	    |-------------	|
| PSDWizard.xaml   	          | Defines PSD Wizard content and UI, based on WPF |
| PSDWizard.xaml.initialize.ps1 | Script to initialize the wizard content in PSD	|


# PSD Script Mapping
The following table identifies the dependencies and interactions between the various PSD scripts and modules:

<table>
  <tr>
    <th>PowerShell Script</th>
    <th>Imports</th>
    <th>Functions</th>
  </tr>
  <tr>
    <td>PSDApplications.ps1</td>
    <td>PSDUtilityPSDDeploymentShare</td>
    <td>Install-PSDApplication</td>
  </tr>
  <tr>
    <td>PSDApplyOS.ps1</td>
    <td>Microsoft.BDD.TaskSequence.Module<br>DISM<br>PSDUtility<br>PSDDeploymentShare</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDConfigure.ps1</td>
    <td>Microsoft.BDD.TaskSequence.Module</td>
    <td>DISM</td>
  </tr>
  <tr>
    <td>PSDCustomPostWU.ps1</td>
    <td>Import-PSDUtility</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDCustomPreWU.ps1</td>
    <td>Import-PSDUtility</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDDrivers.ps1</td>
    <td>Import-PSDUtility</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDeploymentShare.ps1</td>
    <td>BitsTransfer</td>
    <td>Get-PSDConnection<br>Get-PSDProvider<br>Get-PSDAvailableDriveLetter<br>Get-PSDContent<br>Get-PSDContentUNC<br>Get-PSDContentWeb</td>
  </tr>
  <tr>
    <td>PSDErrorInTS.ps1</td>
    <td>Microsoft.BDD.TaskSequence.Module<br>DISM<br>PSDDeploymentShare<br>PSDUtility</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDFreshen.ps1</td>
    <td>PSDUtility<br>PSDGather</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDGather.psm1</td>
    <td>none</td>
    <td>Get-INIContent<br>Get-PSDLocalInfo<br>Get-PSDSettings<br>Invoke-PSDRule<br>Invoke-PSDRules</td>
  </tr>
  <tr>
    <td>PSDPartition.ps1</td>
    <td>PSDUtility</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDSetVariable.ps1</td>
    <td>PSDUtility</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDStart.ps1</td>
    <td>PSDUtility<br>PSDDeploymentShare<br>PSDGather<br>PSDWizard</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDTBA.ps1</td>
    <td>PSDUtility<br>PSDDeploymentShare</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDTemplate.ps1</td>
    <td>PSDUtility<br>PSDDeploymentShare</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDUserState.ps1</td>
    <td>PSDUtility</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDUtility.psm1</td>
    <td>Microsoft.BDD.TaskSequence Module</td>
    <td>Clear-PSDInformation<br>Copy-PSDFolder<br>Get-PSDDriverInfo<br>Get-PSDInputFromScreen<br>Get-PSDLocalDataPath<br>Get-PSDNtpTime<br>Initialize-PSDFolder<br>Invoke-PSDHelper<br>Invoke-PSDExe<br>Restore-PSDVariables<br>Save-PSDVariables<br>Show-PSDInfo<br>Set-PSDCommandWindowSize<br>Start-PSDLogging<br>Stop-PSDLogging<br>Test-PSDNetCon<br>Write-PSDEvent<br>Write-PSDLog</td>
   </tr>
  <tr>
    <td>PSDWizard.psm1</td>
    <td>none</td>
    <td>Get-PSDWizard<br>Save-PSDWizardResult<br>Set-PSDWizardDefault<br>Show-PSDWizard</td>
  </tr>
  <tr>
    <td>PSDWizard.xaml.initialize</td>
    <td>Validate-Wizard</td>
    <td>none</td>

  </tr>

</table>

# MDT Dependencies
The following MDT components and files are utilized, consumed, and or referenced by PSD:
- ZTIGather.xml
- ZTIConfigure.xml


