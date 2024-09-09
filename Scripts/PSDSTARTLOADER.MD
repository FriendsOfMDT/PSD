# Change log for PSDStartLoader

## 1.1.1 - June 19, 2024

- Fixed font size for asset information; no longer cuts off hyper-v serial number
- Fixed progress text; auto sizes and wraps text if needed

## 1.1.0 - March 4, 2024

- (PC) - Beta to full release
- (PC) - Added Cmtrace logger check

## 1.0.8b - June 15,2022

- (PC) - Added TS progress sync capabiltiies; still in preview. 
- (PC) - Added logo and org name control; still in preview. 
- (PC) - Exposed calls to all UI's in module; provides external use case

## 1.0.7b - June 13,2022

- (PC) - Changed Debug button to Prestart menu; added prestart launch button to support value of SkipBDDWelcome 
- (PC) - Added cmdlet Invoke-PSDStartPrestartButton to show button
- (PC) - Fixed UI from locking; Removed runspace from prestart menu button actions and removed wait command
- (PC) - Added shadows to menu buttons; shows depth and clarifies screens
- (PC) - Fixed Countdown formatting; Position in centered and allow different calls

## 1.0.6b - May 31,2022

- (PC) - Added Cmtrace button and function to find it location; open PSD log if found
- (PC) - Added F9 to control loader UI; press ones will make it normal, press again to make it full screen again. 
- (PC) - Changed all cmdlets to have a prefix noun of PSDStartLoader; follows module standards and eliminates conflict 
- (PC) - changed all UI cmdlets to store data in respective has table; can be retrieved for debugging
- (PC) - Added basic logging to loader; open and close logging

## 1.0.5b - May 22,2022

- (PC) - Separated menu from Loader; provides asynchronous control over menu and allows loader to continue
- (PC) - Added UI for diskmgr, diskclean, and network settings; all running in separate runspace
- (PC) - Updated PSDGather to support Loader; Provides the capability to grab systeminfo when TSenv isn't loaded yet. 
- (PC) - Changed all functions prefix to reflect module name (PSDStart); ensures no clobber with other modules
- (PC) - Added Device detail check as loader is launched; speed up process and simulates bginfo
- (PC) - Fixed Disk check in PE; single disk as are now an array

## 1.0.4b - Apr 29, 2022

- (PC) - Reorder progress bar updates to reflect actual runs. 
- (PC) - Changed all popup windows to use hashtables instead variables

## 1.0.4b - Apr 23, 2022

- (PC) - Added functionality to DartPE and Open Powershell buttons

## 1.0.3b - Apr 20, 2022

- (PC) - Added all logic from PSDstart.ps1; replacing Write-PSDBootInfo with Powershell UI
- (PC) - Added Debug regular check with script.
- (PC) - Removed Prestart check during load; not needed with new UI  
-
## 1.0.2b - Apr 21, 2022

- Converted Script into module simplified cmdlets to reflect new changes

## 1.0.1b - Mar 2, 2022

- Major revamp. Build runspace in a cmdlet. Allows control from a command on the fly. 

## 1.0.0b - Feb 21, 2022

- Initial build