# Developers Guide - PowerShell Deployment Extension Kit
April 2019

PowerShell vxxx is the standard for all PSD development.

## Table of Contents 

<!-- TOC -->autoauto- [Developers Guide - PowerShell Deployment Extension Kit](#developers-guide---powershell-deployment-extension-kit)auto    - [Table of Contents](#table-of-contents)auto- [Coding Standards](#coding-standards)auto- [Logging via Write-PSDLog](#logging-via-write-psdlog)auto- [Scripts, Modules and Libraries](#scripts-modules-and-libraries)auto    - [PSD Scripts](#psd-scripts)auto    - [PSD Modules](#psd-modules)auto    - [PSD Other Files](#psd-other-files)auto- [PSD Script Mapping](#psd-script-mapping)auto- [MDT Dependencies](#mdt-dependencies)autoauto<!-- /TOC -->

# Coding Standards

# Logging via Write-PSDLog
Logging in all PSD modules is and should be accomplished via a new **Write-PSDLog** function found in PSDUtility.psm1. Developers, coders and customizers should leverage this new function to capture output for logging and or debug purposes. The following syntax should be used or duplicated:

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): <<your message our output>>

This will output your message or text to the log file along with the calling script. Sample output looks like the following from the Get-PSDLocalDataPath function:

    <![LOG[Get-PSDLocalDataPath: Return the cached local data path if possible]LOG]!><time="20:31:39.462+000" date="03-26-2019" component="PSDUtility.psm1:27" context="" type="1" thread="" file="">

# Scripts, Modules and Libraries
The following PowerShell modules and scripts are provided with PSD:

## PSD Scripts
| Script               	| Description 	| Equivalent LTI script
|----------------------	|-------------	| ---------------|
| PSDApplications.ps1 	| Installs the apps specified by task sequence variables *Applications* and *MandatoryApplications*. Downloads applications to the PSD cache after validating platform and checking for existing or previous installation. Supports MSIExe.exe, .CMD and cscript installations. |
| PSDApplyOS.ps1       	| Sets PowerCFG to full power profiles. Applies the OS image and injects drivers using DISM. Modifies boot configurations |
| PSDApplyWinPE.ps1     | blah |   |
| PSDConfigure.ps1     	| Customizes and configures Unattend.xml file.        |
| PSDCustomPostWU.ps1  	| Incomplete. Installs customizations POST Windows Update |
| PSDCustomPreWU.ps1   	| Incomplete. Installs customizations PRE Windows Update | |
| PSDDisableBDEProtectors.ps1 | blah | ZTIDisableBDEProtectors.wsf |  
| PSDDrivers.ps1       	| Copies drivers to PSD cache on target systems. | |
| PSDErrorInTS.ps1     	| Incomplete | |
| PSDFreshen.ps1       	| Updates information from Gather to the Task Sequence environment. INITIALIZATION -> VALIDATION -> STATECAPTURE -> PREINSTALL -> POSTINSTALL -> STATERESTORE |  |
| PSDGather.ps1        	| Runs PSDGather from PSDGather.psm1 and gather environment and target device information and details | LITGather.wsf
| PSDGroups.ps1         | blah | ZTIGroups.wsf |
| PSDHelper.ps1        	| Incomplete. Imports modules PSDUtility, PSDDeploymentShare, PSDGather. blah foo |
| PSDNextPhase.ps1     	| Manages the execution order of the Task Sequence engine | |
| PSDNICConfig.ps1      | blah | ZTINicConfig.wsf |
| PSDPartition.ps1     	| Partitions and configured disks. Disk partitioning details are hardcoded inside this script. Do NOT change. |   |
| PSDSetVariable.ps1   	| MiNy? |  |  |
| PSDStart.ps1         	| Starts or continues a PSD-enabled task sequence.| LTIWizard.wsf |
| PSDTBA.ps1           	| Placeholder script for LTI scripts not yet converted | varies |
| PSDTemplate.ps1      	| Sample PowerShell template for PSD development | template |
| PSDUserState.ps1     	| not yet implemented |  ZTIUserState.wsf| 
| PSDValidate.ps1      	| blah            	| ZTIValidate.wsf |
| PSDWindowsUpdate.ps1 	| blah            	|          |


      

## PSD Modules
| Module                	| Description 	|
|------------------------	|-------------	|
| PSDGather.psm1    	    | blah        	|
| PSDUtility.psm1         | blah        	|
| PSDWizard.psm1     	    | blah        	|
| PSDDeploymentshare.psm1 | blah        	|
| ZTIUtility.psm1   	    | blah        	|


## PSD Other Files
| Module                	    | Description 	|
|------------------------	    |-------------	|
| PSDWizard.xaml   	            | blah        	|
| PSDWizard.xaml.initialize.ps1 | blah         	|


# PSD Script Mapping
The following table identifies the dependencies and interactions between the various PSD scripts and modules:

<table>
  <tr>
    <th>PowerShell Script</th>
    <th>Imports</th>
    <th>Functions</th>
    <th>Starts</th>
    <th>Export</th>
  </tr>
  <tr>
    <td>PSDApplications.ps1</td>
    <td>PSDUtilityPSDDeploymentShare</td>
    <td>Install-PSDApplication</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDApplyOS.ps1</td>
    <td>Microsoft.BDD.TaskSequence.Module<br>DISM<br>PSDUtility<br>PSDDeploymentShare</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDConfigure.ps1</td>
    <td>Microsoft.BDD.TaskSequence.Module</td>
    <td>DISM</td>
    <td>PSDUtility</td>
    <td>PSDDeploymentShare</td>
  </tr>
  <tr>
    <td>PSDCustomPostWU.ps1</td>
    <td>Import-PSDUtility</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDCustomPreWU.ps1</td>
    <td>Import-PSDUtility</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDDrivers.ps1</td>
    <td>Import-PSDUtility</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDeploymentShare.ps1</td>
    <td>BitsTransfer</td>
    <td>Get-PSDConnection<br>Get-PSDProvider<br>Get-PSDAvailableDriveLetter<br>Get-PSDContent<br>Get-PSDContentUNC<br>Get-PSDContentWeb</td>
    <td>none</td>
    <td>Get-PSDConnection<br>Get-PSDContent</td>
  </tr>
  <tr>
    <td>PSDErrorInTS.ps1</td>
    <td>Microsoft.BDD.TaskSequence.Module<br>DISM<br>PSDDeploymentShare<br>PSDUtility</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDFreshen.ps1</td>
    <td>PSDUtility<br>PSDGather</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDGather.psm1</td>
    <td>none</td>
    <td>Get-INIContent<br>Get-PSDLocalInfo<br>Get-PSDSettings<br>Invoke-PSDRule<br>Invoke-PSDRules</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDPartition.ps1</td>
    <td>PSDUtility</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDSetVariable.ps1</td>
    <td>PSDUtility</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDStart.ps1</td>
    <td>PSDUtility<br>PSDDeploymentShare<br>PSDGather<br>PSDWizard</td>
    <td>none</td>
    <td>Get-PSDLogging<br>Start-PSDLogging</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDTBA.ps1</td>
    <td>PSDUtility<br>PSDDeploymentShare</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDTemplate.ps1</td>
    <td>PSDUtility<br>PSDDeploymentShare</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDUserState.ps1</td>
    <td>PSDUtility</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDUtility.psm1</td>
    <td>Microsoft.BDD.TaskSequence Module</td>
    <td>Clear-PSDInformation<br>Copy-PSDFolder<br>Get-PSDDriverInfo<br>Get-PSDInputFromScreen<br>Get-PSDLocalDataPath<br>Get-PSDNtpTime<br>Initialize-PSDFolder<br>Invoke-PSDHelper<br>Invoke-PSDExe<br>Restore-PSDVariables<br>Save-PSDVariables<br>Show-PSDInfo<br>Set-PSDCommandWindowSize<br>Start-PSDLogging<br>Stop-PSDLogging<br>Test-PSDNetCon<br>Write-PSDEvent<br>Write-PSDLog</td>
    <td>Start-PSDLogging</td>
    <td>none</td>
  </tr>
  <tr>
    <td>PSDWizard.psm1</td>
    <td>none</td>
    <td>Get-PSDWizard<br>Save-PSDWizardResult<br>Set-PSDWizardDefault<br>Show-PSDWizard</td>
    <td>none</td>
    <td>Show-PSDWizard</td>
  </tr>
  <tr>
    <td>PSDWizard.xaml.initialize</td>
    <td>Validate-Wizard</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>TSxUtility.psm1</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
  <tr>
    <td>ZTIUtility.psm1</td>
    <td>Microsoft.BDD.TaskSequence.Module</td>
    <td>none</td>
    <td>none</td>
    <td>none</td>
  </tr>
</table>

# MDT Dependencies
The following MDT components and files are utilized, consumed, and or referenced by PSD:
- ZTIGather.xml
- ZTIConfigure.xml


