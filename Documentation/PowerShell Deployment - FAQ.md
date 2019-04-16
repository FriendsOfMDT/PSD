# Frequent Asked Questions - PowerShell Deployment Extension Kit
April 2019

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

Q: Does PSD work with 2Pint's ACP solution?
>A: TBD

Q: How does PSD work with 2Pint's ACP solution?
>A: lightweight description here. See [link](http://somedocument.com}

Q: Does PSD work with 1E's Nomad solution?
>A: PSD has not been tested in conjunction with 1E's Nomad product (yet)

Q: Does PSD work with Deployment Optimization?
>A: TBD

Q: Does PSD work with Branch Cache?
>A: TBD

Q: Does PSD work with Peer Cache?
>A: TBD

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
    <td>PSDUtility.psm1<br>PSDGather.psm1<br>PSDWizard.psm1<br><span style="font-weight:400;font-style:normal;text-decoration:none">PSDDeploymentShare.psm1</span><br>ZTIGather.xml<br><span style="font-weight:400;font-style:normal;text-decoration:none">Interop.TSCore.dll</span><br><span style="font-weight:400;font-style:normal;text-decoration:none">Microsoft.BDD.TaskSequenceModule.dll</span><br><span style="font-weight:400;font-style:normal;text-decoration:none">Microsoft.BDD.TaskSequenceModule.psd</span><br></td>
    <td>PSDStart.ps1<br>PSDHelper.ps1<br></td>
  </tr>
</table>

Q: What scripts or files can be safely deleted from my PSD Deployment Share?
>A: This is still being refined and defined. For now: 
- Do NOT delete any PSD*.ps1 or PSD*.psm1 files. 
- Do NOT delete ZTIGather.xml or ZTIConfigure.xml
- If installing applications as part of the task sequence, do not delete ZTIUtility.vbs as it is called during the deployment
- If desired, many of the legacy MDT .wsf scripts and Wizard files can be removed manually from the PSD Deployment Share scripts folder to thin out the environment. 

## Documented Platforms and Scenarios
Q: What operating systems and components has PSD been tested and or evaluated against?
>A: The following tables identifies tested and validated components, scenarios as well as testing and development status: 
<style type="text/css">
.tg  {border-collapse:collapse;border-spacing:0;}
.tg td{font-family:Arial, sans-serif;font-size:14px;padding:10px 5px;border-style:solid;border-width:1px;overflow:hidden;word-break:normal;border-color:black;}
.tg th{font-family:Arial, sans-serif;font-size:14px;font-weight:normal;padding:10px 5px;border-style:solid;border-width:1px;overflow:hidden;word-break:normal;border-color:black;}
.tg .tg-fymr{font-weight:bold;border-color:inherit;text-align:left;vertical-align:top}
.tg .tg-xldj{border-color:inherit;text-align:left}
.tg .tg-0pky{border-color:inherit;text-align:left;vertical-align:top}
</style>
<table class="tg">
  <tr>
    <th class="tg-fymr">Component</th>
    <th class="tg-fymr">Version</th>
    <th class="tg-fymr">Notes</th>
  </tr>
  <tr>
    <td class="tg-xldj">MDT</td>
    <td class="tg-0pky">8456</td>
    <td class="tg-0pky"></td>
  </tr>
  <tr>
    <td class="tg-0pky">ADK</td>
    <td class="tg-0pky">1809</td>
    <td class="tg-0pky"></td>
  </tr>
  <tr>
    <td class="tg-0pky">WinPe addon</td>
    <td class="tg-0pky">1809</td>
    <td class="tg-0pky"></td>
  </tr>
  <tr>
    <td class="tg-0pky">Target client OS</td>
    <td class="tg-0pky">Windows 10 ENT x64 EN 1809<br>Windows 10 ENT x64 EN 1709</td>
    <td class="tg-0pky">MSDN media tested</td>
  </tr>
  <tr>
    <td class="tg-0pky">BareMetal via UNC</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">Tested and working</td>
  </tr>
  <tr>
    <td class="tg-0pky">BareMetal via HTTP</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">Tested and working</td>
  </tr>
  <tr>
    <td class="tg-0pky">BareMetal via HTTPS</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet tested</td>
  </tr>
  <tr>
    <td class="tg-0pky">IIS</td>
    <td class="tg-0pky"></td>
    <td class="tg-0pky"></td>
  </tr>
  <tr>
    <td class="tg-0pky">WebDAV</td>
    <td class="tg-0pky"></td>
    <td class="tg-0pky"></td>
  </tr>
  <tr>
    <td class="tg-0pky">PXE</td>
    <td class="tg-0pky"></td>
    <td class="tg-0pky"></td>
  </tr>
  <tr>
    <td class="tg-0pky">Host Server OS</td>
    <td class="tg-0pky">Windows Server 2016 ENT </td>
    <td class="tg-0pky"></td>
  </tr>
    <tr>
    <td class="tg-0pky">Virtual Machines</td>
    <td class="tg-0pky">Microsoft Hyper-V </td>
    <td class="tg-0pky">Client deployments tested against Hyper-V.<br>MDT/PSD tested hosted on Hyper-V</td>
  </tr>
    <tr>
    <td class="tg-0pky">Refresh via UNC</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
    <tr>
    <td class="tg-0pky">Refresh via HTTP</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
    <tr>
    <td class="tg-0pky">Refresh via HTTPS</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
  <tr>
    <td class="tg-0pky">Replace via UNC</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
    <tr>
    <td class="tg-0pky">Replace via HTTP</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
    <tr>
    <td class="tg-0pky">Replace via HTTPS</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
  <tr>
    <td class="tg-0pky">BIOS-to-UEFI via UNC</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
    <tr>
    <td class="tg-0pky">BIOS-to-UEFI  via HTTP</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
    <tr>
    <td class="tg-0pky">BIOS-to-UEFI via HTTPS</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
        <tr>
    <td class="tg-0pky">Generic, non-OSD TS via UNC</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
    <tr>
    <td class="tg-0pky">Generic, non-OSD TS via HTTP</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
    <tr>
    <td class="tg-0pky">Generic, non-OSD TS via HTTPS</td>
    <td class="tg-0pky">n/a</td>
    <td class="tg-0pky">not yet implemented</td>
  </tr>
</table>

## Installation Observations

- The PSD installer will create the -psDeploymentShare name *exactly* as specified. The PSD installer does **not** handle or change the hidden share ($) character in any form or fashion.

- The PSD installer does **not** automatically mount a new PSD-created deployment share repository. Users will need to mount newly created PSD deployment shares manually.

- The PSD installer does **not** automatically copy over any existing MDT artifacts and components to a new PSD-created deployment share repositories. Users will need to manually copy over, re-import or instantiate applications, drivers, etc. manually.

## Operational Observations
Please review the PSD Installation Guide for additional detailed post-installation configuration recommendations.

- Applications specified in task sequences or in BOOTSTRAP/CUSTOMSETTINGS **MUST** have { } brackets around their GUID
- New TS variables **must** be declared explicitly in BOOTSTRAP/CUSTOMSETTINGS



