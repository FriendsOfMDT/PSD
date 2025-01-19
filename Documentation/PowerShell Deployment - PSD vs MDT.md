# PSD vs MDT

While PSD is an extension of MDT, it enhances it capabilities, however it does also "break" items. We find this list should answer most of the issue opened. While we are working to bring most of MDT functionality into PSD, some of them may not be needed or required. 


## Support Matrix

Feature | PSD | MDT | On Roadmap |Comment
--|--|--|--|--
Windows 11 OSD | x | | |
Server 2019+ OSD | x | | |
Http(s) deployments | x | | |
UNC Deployments | | x | no | While this may still work, the goal of PSD is move away from UNC deployments and go to more modern approach
WinPE deployments | x | x | |
Desktop deployments |  | x | yes |
Capture Deployments | | x | no |
Pause Deployments | | x | yes | This is similar to LTISuspend
Profile Selection |  | | yes | This is where profiles types can be used during wizard for pre-selection
Litetouch OSD | x | x | |
ZeroTouch OSD | x | x | |Follow _Powershell Deployment - ZeroTouch Guide.md_ guide
Linked Deployment Shares | | x | no | http deployment should help reduces this need
Database Support | | x | |
MDT Logging (SLShare) | x | x 
Debugging |x| | |
Deployment Workbench | x |x| | There is discussion of developing a new deployment workbench
UDI Designer | | x | maybe |
Wizard Themes | x | || Currently there isa light and dark theme. 
Wizard Custom Pages | x | x || PSD wizard uses XAML while MDT uses UDI Designer. UDI Designer is limited while XAML allows ANY type of customizations
Multiple Language support | | | yes | Current language is en-US; working to get others
Organizational Branding | x | | | Use branding image during PSDWizard
Use State Migration | | x |no |
UserExit Scripts | | x | yes|
Precheck Readiness | x | | | New in PSD 2.30
Prestart Menu (disk wipe, static IP, etc) | x | | | New in PSD 2.30
BranchCache | x | x | |
Custom Properties | x | x | 
DriverGroups | |x | yes | Drivergroup001 are not being developed on or working, please use _New-MDTDriverPackage.ps1_ to create "driver packages"
Packages | | x | no |
Domain Join | x | x| | This must still be done via LAN; Offline Domain Join (ODJ) support is not there yet
Event Monitoring | x | x| | There is some limitations with this
WinPE Dart Support | x | | | 
Workbench Dart Remote Control |  | x | | https://github.com/FriendsOfMDT/PSD/issues/83
Offline Media | | x | yes | Offline media is on the TODO list
Application Bundles | | x | yes | 
Applications Deployments Only  | | x | yes | This is part of the Desktop deployments development
Autopilot Support | | | yes |
Azure Image Builder support | | | maybe | some discussion around this.
Reverse Proxy | | | maybe | 
802.1x support | | | maybe |
PowerShell 7 or higher support | | | unknown | Since the native PowerShell in Windows and WinPE is 5.1, that is the one being used. Some testing has been done in PowerShell 7. 


> NOTE: even though some of these items are on the roadmap, there are no estimated release dates as to when they will be available. 
