# Developers Guide - PowerShell Deployment Extension Kit
April 2019

PowerShell vxxx is the standard for all PSD development.

## Table of Contents 

<!-- TOC -->autoauto- [Developers Guide - PowerShell Deployment Extension Kit](#developers-guide---powershell-deployment-extension-kit)auto    - [Table of Contents](#table-of-contents)auto- [Coding Standards](#coding-standards)auto- [Logging via Write-TSxLog](#logging-via-write-tsxlog)auto- [Scripts, Modules and Libraries](#scripts-modules-and-libraries)auto    - [PSD Scripts](#psd-scripts)auto    - [PSD Modules](#psd-modules)auto    - [Other](#other)auto- [PSD Script Mapping](#psd-script-mapping)auto- [MDT Dependencies](#mdt-dependencies)autoauto<!-- /TOC -->

# Coding Standards

# Logging via Write-TSxLog
Logging in all PSD modules is and should be accomplished via a new **Write-TSxLog** function found in PSDUtility.psm1. Developers, coders and customizers should leverage this new function to capture output for logging and or debug purposes. The following syntax should be used or duplicated:

    Write-TSxLog -Message "$($MyInvocation.MyCommand.Name): <<your message our output>>

This will output your message or text to the logfile along with the calling script. Sample output looks like the following from the Get-PSDLocalDataPath function:

    <![LOG[Get-PSDLocalDataPath: Return the cached local data path if possible]LOG]!><time="20:31:39.462+000" date="03-26-2019" component="PSDUtility.psm1:27" context="" type="1" thread="" file="">

# Scripts, Modules and Libraries
The following PowerShell modules and scripts are provided with PSD:

## PSD Scripts
| Script               	| Description 	| Equivalent LTI script
|----------------------	|-------------	| ---------------|
| PSDAppliacations.ps1 	| Installs the apps specified by task sequence variables *Applications* and *MandatoryApplications*. Downloads applicatoins to the PSD cache after validating platform and checking for existing or previous installation. Supports MSIExe.exe, .CMD and cscript installations.           	|
| PSDApplyOS.ps1       	| Sets POwerCFG to full power profiles. Applies the OS image and injects drivers using DISM. Modifies boot configurations          	|
| PSDConifgure.ps1     	| Customizes and configures Unattend.xml file.        |
| PSDCustomPostWU.ps1  	| Incomplete. Installs customizations POST Windows Update           	|
| PSDCustomPreWU.ps1   	| Incomplete. Installs customizations PRE Windows Update            	|
| PSDDrivers.ps1       	| Copies drivers to PSD Cacahe on target systems.             	|
| PSDErrorInTS.ps1     	| Incomplete             	|
| PSDGather.ps1        	| Runs PSDGather from PSDGather.psm1 and gather environment and target device information and details             	| LITGather.wsf
| PSDHelper.ps1        	| Incomplete. Imports modules PSDUtility, PSDDeploymentShare, PSDGather. blah foo            	|
| PSDNextPhase.ps1     	| Manages the execution order of the Task Sequence engine |            	|
| PSDFreshen.ps1       	| Updates information from Gather to the Task Sequence environment. INITIALIZATION -> VALIDATION -> STATECAPTURE -> PREINSTALL -> POSTINSTALL -> STATERESTORE            	|
| PSDPartition.ps1     	| Partitions and configured disks. Disk partitioning details are hardcoded inside this script. Do NOT change.              	|
| PSDSetVariable.ps1   	| MiNy?             	|
| PSDStart.ps1         	| Starts or continues a PSD-enabled task sequence.            	| LITWizard.wsf
| PSDTBA.ps1           	| Placeholder script for LTI scripts not yet convertied | varies
| PSDTemplate.ps1      	| Sample PowerShell template for PSD development            	| template |
| PSDUserState.ps1     	| not yet impelmented            	|
| PSDValidate.ps1      	|             	|
| PSDWindowsUpdate.ps1 	|             	|
|        

## PSD Modules
| Module                	| Description 	|
|------------------------	|-------------	|
| PSDGather.psm1    	    | blah        	|
| PSDUtility.psm1         |             	|
| PSDWizard.psm1     	    |             	|
| PSDDeploymentshare.psm1 |             	|
| ZTIUtility.psm1   	    |             	|


## Other
| Module                	    | Description 	|
|------------------------	    |-------------	|
| PSDWizard.xaml   	            | blah        	|
| PSDWizard.xaml.initialize.ps1 |             	|


# PSD Script Mapping
The following table identifies the dependencies and interactions between the various PSD scripts and modules:

<style type="text/css">
.tg  {border-collapse:collapse;border-spacing:0;}
.tg td{font-family:Arial, sans-serif;font-size:14px;padding:10px 5px;border-style:solid;border-width:1px;overflow:hidden;word-break:normal;border-color:black;}
.tg th{font-family:Arial, sans-serif;font-size:14px;font-weight:normal;padding:10px 5px;border-style:solid;border-width:1px;overflow:hidden;word-break:normal;border-color:black;}
.tg .tg-fymr{font-weight:bold;border-color:inherit;text-align:left;vertical-align:top}
.tg .tg-0pky{border-color:inherit;text-align:left;vertical-align:top}
</style>
<table class="tg">
  <tr>
    <th class="tg-fymr">PowerShell Script</th>
    <th class="tg-fymr">Imports</th>
    <th class="tg-fymr">Functions</th>
    <th class="tg-fymr">Starts</th>
    <th class="tg-fymr">Export</th>
  </tr>
  <tr>
    <td class="tg-0pky">PSDApplications.ps1</td>
    <td class="tg-0pky">PSDUtility<br>PSDDeploymentShare</td>
    <td class="tg-0pky">Install-PSDApplication</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDApplyOS.ps1</td>
    <td class="tg-0pky">Microsoft.BDD.TaskSqeunce Module<br>DISM<br>PSDUtility<br>PSDDeploymentShare</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDConfigure.ps1</td>
    <td class="tg-0pky">Microsoft.BDD.TaskSqeunce Module<br>DISM<br>PSDUtility<br>PSDDeploymentShare</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDCustomPostWU.ps1</td>
    <td class="tg-0pky">Import-PSDUtility</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDCustomPreWU.ps1</td>
    <td class="tg-0pky">Import-PSDUtility</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDDrivers.ps1</td>
    <td class="tg-0pky">Import-PSDUtility</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDeploymentShare.ps1</td>
    <td class="tg-0pky">BitsTransfer</td>
    <td class="tg-0pky">Get-PSDConnection<br>Get-PSDProvider<br>Get-PSDAvailableDriveLetter<br>Get-PSDContent<br>Get-PSDContentUNC<br>Get-PSDContentWeb</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">Get-PSDConnection<br>Get-PSDContent</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDErrorInTS.ps1</td>
    <td class="tg-0pky">Microsoft.BDD.TaskSqeunce Module<br>DISM<br>PSDUtility<br>PSDDeploymentShare</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDFreshen.ps1</td>
    <td class="tg-0pky">PSDUtility<br>PSDGAther</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDGather.psm1</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">Get-PSDLocalInfo<br>Invoke-PSDRules<br>Invoke-PSDRule<br>Get-PSDSettings<br>Get-INIContent</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDPartition.ps1</td>
    <td class="tg-0pky">PSDUtility</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDSetVariable.ps1</td>
    <td class="tg-0pky">PSDUtility</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDStart.ps1</td>
    <td class="tg-0pky">PSDUtility<br>PSDDeploymentShare<br>PSDGather<br>PSDWizard</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">Get-PSDLogging<br>Start-PSDLogging</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDTBA.ps1</td>
    <td class="tg-0pky">PSDUtility<br>PSDDeploymentShare</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDTemplate.ps1</td>
    <td class="tg-0pky">PSDUtility<br>PSDDeploymentShare</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDUserState.ps1</td>
    <td class="tg-0pky">PSDUtility<br></td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDUtility.psm1</td>
    <td class="tg-0pky">Microsoft.BDD.TaskSqeunce Module</td>
    <td class="tg-0pky">Get-PSDLocalDataPath<br>Initialize PSDFolder<br>Start-PSDLogging<br>Clear-PSDInformation<br>Copy-PSDFolder<br>Set-FailTaskSequence<br>Stop-PSDLogging<br>Write-TSxLog<br>Invoke-TSxUnZip<br>Invoke-TSxZtip<br>Get-TSxDriverInfo<br>Restore-PSDVariables</td>
    <td class="tg-0pky">Start-PSDLogging</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDWizard.psm1</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">Get-PSDWizard<br>Save-PSDWizardResult<br>Set-PSDWizardDefault<br>Show-PSDWizard</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">Show-PSDWizard</td>
  </tr>
  <tr>
    <td class="tg-0pky">PSDWizard.xaml.initialize</td>
    <td class="tg-0pky">Validate-Wizard</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">TSxUtility.psm1</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
  <tr>
    <td class="tg-0pky">ZTIUtilty.psm1</td>
    <td class="tg-0pky">Microsoft.BDD.TaskSqeunce Module</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
    <td class="tg-0pky">none</td>
  </tr>
</table>

# MDT Dependencies
The following MDT components and files are utilized, consumed, and or referenced by PSD:
- ZTIGather.xml
- ZTIConfigure.xml
- xxx.bdd.xxx
- xxx.bbb.xxx



