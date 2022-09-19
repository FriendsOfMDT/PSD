# README - PowerShell Deployment Extension Kit
Jan 2022 (ver 0.2.2.7)

Welcome to PowerShell Deployment (PSD)

## Target audience
- Infrastructure Architects
- Solution Architects

The purpose of PowerShell Deployment for MDT is to create a new deployment solution that provides the same level of automation as MDT but built on a more modern framework - PowerShell. The major components and functionality are built on PowerShell alone, but still leverage the MDT Workbench and layout. The goal is to support deployment shares using PSD extensions as well as legacy MDT deployment shares.

Supported deployment scenarios include deployment from the following content repositories:

  -  IIS over HTTP(s) using WebClient (Native PS)
  -  IIS over HTTP(s) with BITS & BranchCache using 2Pint Software's OSD Toolkit
 
PSD is very much a work-in-progress solution, so stay tuned as we rapidly move forward on this.

## Related References
(intentionally blank)

## Test Scenarios
- Verify current supported version of Windows 10 (english)
- Verify supported version of Windows Server (english), including Core and UI based OS
- Verify the following Customsettings features

### SerialNumber
verify that you can deploy a computer, set the serial number in customsettings.ini to configure the computer, test multiple computers in the same settings file, check the sample file

### SLShare
Verify the SLShare works, you need to create a new web app, with BITS upload setting (someone also needs to create a script that creates it), check the sample file

### Logging
Check the logfiles, they should make sense, we need to get rid of all crap (that can be enabled in debug mode) but normal logging should be something that can be understood

### FinishAction
Verify finishaction, it should support reboot, restart, shutdown

### SkipWizard
Verify, it should work

### FinalSummary
Verify, it should work (both on and off, in server OS, both on and off)

### HideShell
Verify, it should work





