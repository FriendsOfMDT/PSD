# README - PowerShell Deployment Extension Kit
Feb 2024 (ver 0.2.2.9)
- Changed ModelAlis for WMware, all VMware models are no defined as "VMware"

Sept 2022 (ver 0.2.2.8)

- New Wizard (enabled via PSDWizard and PSDWizardTheme variables)
- Better disk handling
- Extended logging
- Performance improvments
- Code cleanup
- Support for driver packages in WIM format
- Server Side logging support via BITS upload (enabled via SLShare variable)
- Many late nights and days has resulted in a much better solution

Welcome to PowerShell Deployment (PSD)

## Target audience
- Infrastructure Architects
- Solution Architects

The purpose of PowerShell Deployment for MDT is to create a new deployment solution that provides the same level of automation as MDT but built on a more modern framework - PowerShell. The major components and functionality are built on PowerShell alone, but still leverage the MDT Workbench and layout. The goal is to support deployment shares using PSD extensions as well as legacy MDT deployment shares.

Supported deployment scenarios include deployment from the following content repositories:

  -  IIS over HTTPS using WebClient (Native PS)
  -  IIS over HTTPS with BITS & BranchCache using 2Pint Software's OSD Toolkit
 
PSD is very much a work-in-progress solution, so stay tuned as we rapidly move forward on this.

## Credits and love
For this major PSD release we had an amazing support from the following people, dedicating hundreds of hours to the project:
 - Elias Markelis, https://github.com/emarkelis
 - George Simos, https://github.com/GeoSimos
 - Dick Tracy, https://github.com/powershellcrack

## Development of PSD
This repository currently acts as a download repository. If you are interested of participating in the development of PSD the active repository is private and you need an invitation. Please contact 
johan@2pintsoftware.com or Mikael.nystrom@truesec.se