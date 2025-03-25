# Frequent Asked Questions - PowerShell Deployment Extension Kit

This document highlights and captures some of the known issues and limitations of PSD (as of the published date above).

## Frequently Asked Questions

Q: Does the installer copy over my existing MDT Deployment Share content (e.g. applications, drivers, task sequences, etc) to a new PSD share?
>A: No, users and administrators will need to copy/export any existing components to *new* PSD shares using in-built content management features of MDT. MDT Shares which have been PSD upgraded will continue to have access to any existing object and artifacts.

Q: Can the installer (PSD_Install.ps1) be executed remotely?
>A: No, PSD_Install.ps1 must be run locally with administrative rights on the target/intended MDT installation.

Q: Does the installer copy over my existing BootStrap.ini or CustomSettings.ini files to the target PSD repositories?
>A: No, if you've created a new PSD-enabled deployment share, users and administrators will need to manually copy or reproduce any existing Bootstrap and CustomSettings files to new repositories.

Q: What are the client/target hardware requirements for baremetal PSD deployments?
>A: PSD requires roughly the same hardware as is required for Windows 10 and MDT deployments:
- At least 1.5GB RAM (WinPE has been extended and requires additional memory)
- At least one (1) network adapter(s)
- At least one (1) 50GB hard drive (for New/BareMetal deployments)
- At least one (1) XXX MHz processor (for New/BareMetal deployments)

Q: Are system clocks synchronized?
>A: Yes, PSDStart.ps1 will attempt to synchronize the time are deployment target computers. Deployment Roots servers and or the HTTP/S target servers will be NTP synchronized.

Q: Does PSD work with 2Pint's OSD Toolkit?
>A: Yes: See the BranchCache installation guide

Q: Why does the PowerShell window appear to flash and then change size?
>A: The default window is resized by PSDStart by design. You should observe it to change from full screen to roughly one third the screen early in the boot/start process. This is again by design.

Q: What is "Transcript Logging"?
>A: Logs (for example PSD.LOG, and BDD.log) are what we explicitly write, Transcript logs captures everything that happens on the screen. PSD Transcript logs are much better suited and useful for troubleshooting, but may be visually "sub-optimal".

Q: What do I see frequent references to "Stopping Transcript Logging"?
>A: (TBA MiNy)

Q: Do I still need to 'add' PowerShell support to my WinPE images?
>A: No, the PSD installation and scripting takes care of it for you. As a matter of fact, unticking the box on the WinPE Features tab will not affect PSD at all.

Q: Will PSD work on my xxx version of MDT or ADK?
>A: We've only developed and tested against the versions and platforms listed below. If you have success on additional versions and platforms, please be sure and let us know!

Q: Do I need to add PowerShell to my boot media images?

A: **NO**, PSD and MDT automatically handle this for you. By default LiteTouchPE.XML automatically injects PowerShell into Boot Media (despite what may or may not be configured in the MDT WinPE tab)

Q: Which MDT components are copied or injected into the PSD Boot Media?
>A: As defined by **LiteTouchPE.XML**, the following files are injected into MDT and PSD boot media by default:

- winpe-dismcmdlets
- winpe-enhancedstorage
- winpe-fmapi
- winpe-hta
- winpe-netfx
- **winpe-powershell**
- winpe-scripting
- winpe-securebootcmdlets
- winpe-securestartup
- winpe-storagewmi
- winpe-wmi

Q: What files and or components are copied or injected into the PSD-enabled Boot Media?
>A: As defined by **LiteTouchPE.XML**, the following files are injected into MDT and PSD boot media by default:

<table>
  <tr>
    <th>COMPONENTS</th>
    <th>TOOLS</th>
    <th>CONFIG</th>
  </tr>
  <tr>
    <td>winpe-hta<br>winpe-scripting<br>winpe-wmi<br>winpe-securestartup<br>winpe-fmapi<br>winpe-netfx<br>winpe-powershell<br>winpe-dismcmdlets<br>winpe-storagewmi<br>winpe-enhancedstorage<br>winpe-securebootcmdlets</td>
    <td rowspan="3">BDDRUN.exe<br>WinRERUN.exe<br>CcmCore.dll<br>CcmUtilLib.dll<br>Smsboot.exe<br>SmsCore.dll<br>TsCore.dll<br>TSEnv.exe<br>TsManager.exe<br>TsmBootstrap.exe<br>TsMessaging.dll<br>TsmBootstrap.exe<br>TsProgressUI.exe<br>TSResNlc.dll<br>CommonUtils.dll<br>ccmgencert.dll<br>msvcp120.dll<br>msvcr120.dll<br>00000409\tsres.dll<br>Microsoft.BDD.Utility.dll</td>
    <td>Bootstrap.ini<br>Unattend.xml<br>winpeshl.ini<br></td>
  </tr>
  <tr>
    <td>MODULES<br></td>
    <td>SCRIPTS</td>
  </tr>
  <tr>
    <td>PSDUtility.psm1<br>PSDGather.psm1<br>PSDWizard.psm1<br><br>PSDWizardNew.psm1<br><span style="font-weight:400;font-style:normal;text-decoration:none">PSDDeploymentShare.psm1</span><br>ZTIGather.xml<br><span style="font-weight:400;font-style:normal;text-decoration:none">Interop.TSCore.dll</span><br><span style="font-weight:400;font-style:normal;text-decoration:none">Microsoft.BDD.TaskSequenceModule.dll</span><br><span style="font-weight:400;font-style:normal;text-decoration:none">Microsoft.BDD.TaskSequenceModule.psd</span><br></td>
    <td>PSDStart.ps1<br>PSDHelper.ps1<br></td>
  </tr>
</table>

Q: What scripts or files can be safely deleted from my PSD Deployment Share?
>A: This is still being refined and defined. For now:
- Do NOT delete any PSD*.ps1 or PSD*.psm1 files.
- Do NOT delete ZTIGather.xml or ZTIConfigure.xml
- If installing applications as part of the task sequence, do not delete ZTIUtility.vbs as it **might** be called during the deployment.
- If desired, many of the legacy MDT .wsf scripts and Wizard files can be removed manually from the PSD Deployment Share scripts folder to thin out the environment.

## Documented Platforms and Scenarios
Q: What operating systems and components has PSD been tested and or evaluated against?
>A: The following tables identifies tested and validated components, scenarios as well as testing and development status:
<table>
  <tr>
    <th>Component</th>
    <th>Version</th>
    <th>Notes</th>
  </tr>
  <tr>
    <td>MDT</td>
    <td>6.3.8456.1000 - (8456)</td>
    <td></td>
  </tr>
  <tr>
    <td>ADK</td>
    <td>10.1.16299 - (1709)<br>10.1.17763.1 - (1809)</td>
    <td></td>
  </tr>
  <tr>
    <td>MDT WinPE addon</td>
    <td>10.1.17763.1 - (1809)</td>
    <td></td>
  </tr>
  <tr>
    <td>Target client OS</td>
    <td>Windows 10 ENT x64 EN 1809<br>
    Windows 10 ENT x64 EN 1709</td>
    <td>MSDN media tested</td>
  </tr>
    <tr>
    <td>IIS</td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>WebDAV</td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>PXE</td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>BareMetal via UNC</td>
    <td>n/a</td>
    <td>Tested and working</td>
  </tr>
  <tr>
    <td>BareMetal via HTTP</td>
    <td>n/a</td>
    <td>Tested and working</td>
  </tr>
  <tr>
    <td>BareMetal via HTTPS</td>
    <td>n/a</td>
    <td>not yet tested</td>
  </tr>

  <tr>
    <td>Host Server OS</td>
    <td>Windows Server 2016 ENT </td>
    <td></td>
  </tr>
  <tr>
    <td>Virtual Machines</td>
    <td>Microsoft Hyper-V </td>
    <td>Client deployments tested against Hyper-V.<br>MDT/PSD tested hosted on Hyper-V</td>
  </tr>
  <tr>
    <td>Refresh via UNC</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>Refresh via HTTP</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>Refresh via HTTPS</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>Replace via UNC</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>Replace via HTTP</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>Replace via HTTPS</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>BIOS-to-UEFI via UNC</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>BIOS-to-UEFI&nbsp;&nbsp;via HTTP</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>BIOS-to-UEFI via HTTPS</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>Generic, non-OSD TS via UNC</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>Generic, non-OSD TS via HTTP</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
  <tr>
    <td>Generic, non-OSD TS via HTTPS</td>
    <td>n/a</td>
    <td>not yet implemented</td>
  </tr>
</table>

## Installation Observations

- The PSD installer will create the -psDeploymentShare name *exactly* as specified. The PSD installer does **NOT** handle or change the hidden share ($) character in any form or fashion.

- The PSD installer **should** automatically mount a new PSD-created deployment share repository. Users may need to refresh the workbench or manually mount newly created PSD deployment shares.

- The PSD installer does **NOT** automatically copy over any existing MDT artifacts and components to a new PSD-created deployment share repositories. Users will need to manually copy over, re-import or instantiate applications, drivers, etc.

## Operational Observations

Please review the  [PSD Installation Guide](https://github.com/soupman98/PSD/blob/master/Documentation/PowerShell%20Deployment%20-%20Installation%20Guide.md) for additional detailed post-installation configuration recommendations.

- Applications specified in task sequences BootStrap.ini or CustomSettings.ini **MUST** have { } brackets around their GUID
- New TS variables **must** be declared explicitly in BootStrap.ini or CustomSettings.ini
- You many notice that during the Post OS install phases of the PSD Task Sequence (OOBE) that the screen briefly flashes a window and the PowerShell window appears to refresh. This is expected when a script is executed.