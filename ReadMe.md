# PowerShell Deployment Extension Kit
April 2019

Welcome to PowerShell Deployment (PSD)

## Target audience
- Infrastructure Architects
- Solution Architects

The purpose of PowerShell Deployment for MDT is to create a new deployment solution that provides the same level of automation as MDT but built on a more modern framework - PowerShell. The major components and functionality are built on PowerShell alone, but still leverage the MDT Workbench and layout. The goal is to support deployment shares using PSD extensions as well as legacy MDT deployment shares.

Supported deployment scenarios include deployment from the following content repositories:

  -  IIS over HTTP with BITS & BranchCache using 2Pint Software's Task Sequence ACP
  -  IIS over HTTP with BITS & BranchCache using PowerShell (No BITS available in WinPE)
  -  IIS over HTTP using WebClient (Native PS)
  -  UNC (\\server\share)
  -  Local Media

PSD is very much a work-in-progress solution, so stay tuned as we rapidly move forward on this.

## Visual Studio Notes
The solution file for Visual Studio requires PowerShell for Visual Studio (3rd party extension for Visual Studio 2015).

When using Visual Studio to edit the PowerShell scripts, configure the editor to use spaces instead of tabs for PowerShell.

## Related References