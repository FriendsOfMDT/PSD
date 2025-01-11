# README - PowerShell Deployment Extension Kit

Sep 2024 (ver 0.2.3.0)
- Updated Deployemnt wizard with new panes for Intune and device role
- Improved task sequence templates
- Updated installer
- Customized ZTIGather.xml
- Updated Prestart menu

Feb 2024 (ver 0.2.2.9)
- Changed ModelAlis for WMware, all VMware models are no defined as "VMware"

Sep 2022 (ver 0.2.2.8)

- New Wizard (enabled via PSDWizard and PSDWizardTheme variables)
- Better disk handling
- Extended logging
- Performance improvements
- Code cleanup
- Support for driver packages in WIM format
- Server Side logging support via BITS upload (enabled via SLShare variable)
- Many late nights and days has resulted in a much better solution

Welcome to PowerShell Deployment (PSD)

## Target audience

- Infrastructure Architects
- Solution Architects
- Modern Device Engineers

The purpose of PowerShell Deployment for MDT is to create a new deployment solution that provides the same level of automation as MDT but built on a more modern framework - PowerShell. The major components and functionality are built on PowerShell alone, but still leverage the MDT Workbench and layout. The goal is to support deployment shares using PSD extensions as well as legacy MDT deployment shares.

Supported deployment scenarios include deployment from the following content repositories:

- IIS over HTTPS using WebClient (Native PS)
- IIS over HTTPS with BITS & BranchCache using 2Pint Software's OSD Toolkit
 
PSD is very much a work-in-progress solution, so stay tuned as we rapidly move forward on this.

## Documentation

Follow these guides to help setup your environment (follow these in order)

1. [Introduction](./Documentation/PowerShell%20Deployment%20-%20Installation%20Guide.md)
1. [Pre-Installation (Beginners)](./Documentation/Powershell%20Deployment%20-%20Beginners%20Guide.md)
1. [PSD Installation](./Documentation/PowerShell%20Deployment%20-%20Installation%20Guide.md)
1. [Post-Installation (IIS Setup)](./Documentation/PowerShell%20Deployment%20-%20IIS%20Configuration%20Guide.md)
1. [Operational](./Documentation/PowerShell%20Deployment%20-%20Operations%20Guide.md)

Here are some additional documents for advanced setup

- [Recent Upgrades](./Documentation/PowerShell%20Deployment%20-%20Latest%20Release%20Setup%20Guide.md)
- [Security](./Documentation/PowerShell%20Deployment%20-%20Security%20Guide.md)
- [BranchCache](./Documentation/PowerShell%20Deployment%20-%20BranchCache%20Installation%20Guide.md)
- [Hydration Kit](./Documentation/PowerShell%20Deployment%20-%20Hydration%20Kit%20Installation%20Guide.md)
- [PSD Wizard](./Documentation/PowerShell%20Deployment%20-%20PSD%20Wizard%20Guide.md)
- [RestPS with PSD](./Documentation/PowerShell%20Deployment%20-%20RestPS%20Guide%20with%20PSD.md)
- [ZeroTouch Deployment](./Documentation/Powershell%20Deployment%20-%20ZeroTouch%20Guide.md)

If you need help understanding PSD or have questions, please refer to these documents first

- [Toolkit Reference](./Documentation/PowerShell%20Deployment%20-%20Toolkit%20Reference.md)
- [Support Matrix (MDT & PSD)](./Documentation/PowerShell%20Deployment%20-%20PSD%20vs%20MDT.md)
- [FAQs](./Documentation/PowerShell%20Deployment%20-%20FAQ.md)


## Credits and love
For this major PSD release we had an amazing support from the following people, dedicating hundreds of hours to the project:
 - Elias Markelis, https://github.com/emarkelis
 - George Simos, https://github.com/GeoSimos
 - Dick Tracy, https://github.com/powershellcrack

## Development of PSD
This repository currently acts as a download repository. If you are interested of participating in the development of PSD the active repository is private and you need an invitation. Please contact 
johan@2pintsoftware.com or Mikael.nystrom@truesec.se