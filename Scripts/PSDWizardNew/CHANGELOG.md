# Change log for PSDWizardNew

# 2.3.6 - Dec 29, 2024

- Fixed issue with trimming off serial (https://github.com/FriendsOfMDT/PSD/issues/196)
- Added native MACADDRESS and ASSETTAG support in computername (https://github.com/FriendsOfMDT/PSD/issues/167)


## 2.3.3 - May 1, 2024

- (PC) Fixed null TSenv properties; cause PSDWizard to not load
- (PC) Removed unused themes: Modern, Tabular and Refresh
- (PC) Updates PSD Wizard guide
- (PC) Optimized keydown handlers and add debug console option

## 2.3.2 - April 27, 2024

- (PC) Added Dark theme
- (PC) Updated PSDWizard Documentation
- (PC) Fixed OS language selection; support multilanguage

## 2.3.1 - April 19, 2024

- (PC) Added additional pages to classic theme: roles, intunegroup, target disk
- (PC) Added additional PSDDebug logging for selection
- (PC) Added Slashscreen loader to show wizard starting

## 2.3.0 - April 6, 2024

- (PC) Added custom pane control by external scripts. Allows dynamic pages
- (PC) Cleaned up theme fonts and readiness fonts. 
- (PC) Renamed PSDWizard.Initialize.ps1 to PSDWizard.Helper.ps1
- (PC) Add PSDWizardCollapseTSList to collapse large TS list (https://github.com/FriendsOfMDT/PSD/issues/127)
- (PC) Fixed change log version check n PSDWizard

## 2.2.9 - Feb 24, 2024

- (PC) Fixed issue with workgroup and domain join value conflict (https://github.com/FriendsOfMDT/PSD/issues/117)
- (PC) Fixed issue with language not showing up in ui (https://github.com/FriendsOfMDT/PSD/issues/123)
- (PC) Fixed issue with Domain Join OU not working; used wrong variable DomainJoinOU instead of MachineObjectOU
- (PC) Added DomainOUs1 list option (https://github.com/FriendsOfMDT/PSD/issues/135)
- (PC) Moved all PSDWizard functions from PSDWizard.Initialize.ps1 to module
- (PC) Added troubleshooting function in PSDWizard.Initialize.ps1

## 2.2.8 - Jan 21, 2024

- (PC) Fixed miss-spelled Where-Object-Object. (Thanks @Tenster)
- (PC) Expanded all alias to cmdlets (eg % --> Foreach-Object)
- (PC) Fixed pre-selected Task sequence
- (PC) Moved PSDWizard functions from Initializer script to PSDWizardNew module.

## 2.2.7 - Aug 27, 2023

- (PC) - Changed test functions to reflect module for PSDWizard; ensure no conflict
- (PC) - Added more PSD debug logging; fixed cmdlet entry.
- (PC) - Updated PSDWizard details page
- (PC) - Resolved majority of PSScriptAnalyzer checks
- (PC) - Fixed App list when only one item exists; declared app list as an array; if array not defined, single item has 0 count
- (PC) - Fixed issue where apps that have not been accessed or set to enabled or not hidden won't show in UI without using * to search for them
- (PC) - Fixed issue if one app exists the UI does not list it. THis is because a single item in an array is considered count 0. Fixed this by defining array first and adding the single app to list
- (PC) - Fixed Computer name while processing variable %; it always appended %% to non-variable based computer names.

## 2.2.6 - Aug 20, 2023

- Changed Application count from -GT 1 -GE 1, to show applications when the count is 1

## 2.2.5 - Oct 8, 2022

- (PC) - Added more descriptive Welcome page response when conditions are checked
- (PC) - Added TS folder check to error appropriately when selected
- (PC) - Added F5 refresh help context.

## 2.2.4 - Oct 7, 2022

- (PC) - Fixed default locale output if not set in CustomSettings.ini
- (PC) - Optimized PSDWizard by moving handlers out of page selection; fixed issue with dual WPF selectionChange events
- (PC) - Fixed Serial number variable for ComputerName; supports RAND, SERIAL, SERIALNUMBER
- (PC) - Changed debug logs for element change to be more clear
- (PC) - Fixed Definition xml condition query for PSDWizard; change from _or_ to _and_; fixes PSDWizard toggle
- (PC) - Add more synopsis to PSDWizard functions; removing majority of test code.

## 2.2.3 - Sept 30, 2022

- (PC) - Removed beta from version; released to public
- (PC) - Added character check during xml conversion
- (PC) - Fix logo not showing when using web URL
- (PC) - Filter language based on TS selected
- (PC) - Check TS for valid OS; added invalid message to wizard

## 2.2.2b - Apr 20, 2022

- (PC) - Updated computer name validation to accept 1 character instead of minimum of 5
- (PC) - Hid features still in testing: OSDAddAdmin, Profile Selection, App bundle selection
- (PC) - Updated keyboard locale to check for culture value as well as keyboard layout; ensure all locale are defaulted to English if not found
- (PC) - Removed Time zone from UI export; not needed after Windows XP
- (PC) - Fixed theme control from CS.ini

## 2.2.1b - Mar 03, 2022

- (PC) - Fixed Tabular template; missing grid tag
- (PC) - Change Set-PSDWizardComputerName to Get-PSDWizardComputerName;it get the proper computer name using variables
- (PC) - Optimized the PSWDWizard engine; fixed computer name process and made only validate name when pan is open

## 2.2.0b - Mar 02, 2022

- (PC) - Revamped wizard xml structure to support themes; now includes language and theme definition file
- (PC) - Cleaned up PSDWizardNew module's log output; more consistent during debugging
- (PC) - Added more debugging logs and outputs
- (PC) - Added Modern theme; can be selected in CustomerSettings.ini now
- (PC) - Fixed script path for initializer; using older path that does not exist.
- (PC) - Changed Tabular theme to classic; add new Tabular theme and refresh theme
- (PC) - Fixed paths for language and index xml; path is now using copied location instead of deployroot; breaks http deployments
- (PC) - Fixed locale conversion to culture and keyboard layout; variables need to be global for it to work in PE
- (PC) - Added keyboard button event for F5 to refresh Task sequences and applications; tab also has event added

## 2.1.9b - Feb 21, 2022

- (PC) - Updates to UI; colored icons to make the page more recognizable; removed start buttons for static IP and cmd.

## 2.1.8b - Feb 20, 2022

- (PC) - Optimized PSDWizard load time; preload variables instead of loping through all variables for comparison
- (PC) - Added ability to launch PS from start wizard; same as debug window
- (PC) - Added ability to parse TS value with %deployroot% and %scriptroot%; Updates value with actual paths.
- (PC) - Added logo control using CustomSettings.ini; add PSDLogoImg and a valid path to display in Wizard
- (PC) - Added try/catch and checks for null values; Fixed errors and null values with verbose output;

## 2.1.7b - Feb 18, 2022

- (PC) - Further removed un-needed cmdlets from initializer; simplified the locale query in wizard module
- (PC) - Fixed summary page output; changed to only show TS variables set by wizard
- (PC) - Added debug console button when in debug mode; hides textbox when not
- (PC) - Added version label to UI; changed Title parameter to Version in Invoke-PSDWizard cmdlet
- (PC) - Generalize definition for them control; can be changed by either CustomSettings.ini or parameter

## 2.1.6b - Feb 17, 2022

- (PC) - Built index and Language XML as external data; changes initializer to use those
- (PC) - Fixed summary page output; filter only needed variables
- (PC) - Removed unused functions from initialize script

## 2.1.5b - Feb 10, 2022

- (PC) - Replaced Definition file parameter with language parameter for Show-PSDWizard; enforce naming standard while support future languages
- (PC) - Added -AsSynJob to call in PSDstart; if PE is running set this option to false; provides better UI experience
- (PC) - Added summary page to Wizard and function to output TS variables
- (PC) - Cleaned UI; aligned lines and buttons and removed window frame with drag ability

## 2.1.4b - Feb 4, 2022

- (PC) - Changed all Functions to \<Verb\>-PSDWizard\<Noun\>
- (PC) - Changed module name to PSDWizardNew; removed conflict with original PSDWizard

## 2.1.3b - Feb 14, 2021

- (PC) Fixed Search for Task sequence and applications; added auto search during typing
- (PC) Added Domain Join Section; fixed valid checks for each field
- (PC) Moved events to case select; speed up UI slightly while providing less errors when tabs as not loaded; organized events
- (PC) Added live update event handlers for text fields.

## 2.1.2b - Jan 12, 2021

- (PC) Added hashtables for locale info; provided quicker UI load.
- (PC) Added Get/Set-UIElements functions to debug issues with UI.
- (PC) Fixed UI issues with invalid TS selection unable to continue if navigate back

## 2.1.1b - Jan 11, 2021

- (PC) Cleaned up logging and added script source; moved all variables in messages to format tag
- (PC) Fixed computername detection; added Autopilot like variables (eg. %RAND:4%, %4:SERIAL% and %SERIAL:4%)

## 2.1.0b - Dec 27, 2020

- (PC) Fixed Locale check and update; using function convert TS to Object and back
- (PC) Removed TSVariable parameter; uses Get-TSValue Function for each check
- (PC) Add title parameter to Invoke-PSDWizard; dynamically updates version based on CHANGELOG.MD

## 2.0.9b - Dec 09, 2020

- (PC) Fixed Working path for XAML

## 2.0.8b - Dec 08, 2020

- (PC) Convert PSDWizard.psq to module
- (PC) Build function for entire module

## 2.0.7b - Dec 07, 2020

- (PC) Added Admin credential page; added functionality to check password
- (PC) Added TaskSequence tree Objects to check if item has been selected; enabls next if selected
- (PC) disable navigation via tabs. only use back and next buttons

## 2.0.6b - Dec 06, 2020

- (PC) Changed get culture function to use getcultures .net command; speed up collection by 20sec
- (PC) Moved all style settings to resources directory; allows for easier theme and styling management

## 2.0.5b - Dec 05, 2020

- (PC) Renamed PSDWizard_Tabular.ps1 to PDSWizard.ps1
- (PC) Added locale selection for keyboard, user and timezone

## 2.0.4b - Nov 29, 2020

- (PC) Added check for welcome canvas in xaml generator function - does not add welcome wizard if SkipWizard=YES

## 2.0.3b - Nov 28, 2020

- (PC) Added Tabcontrol event to control button configurations at each screen
- (PC) Added search function for Taskseqeunce page
- (PC) Fixed TSEnv to process deploymentshare customsettings.ini
- (PC) Added Lists function with search function. Populates applications
- (PC) Added Dropdown list function. Populates timezone
- (PC) Add SkipWizard to Set-PSDWizardXAML code using condition function

## 2.0.2b - Nov 27, 2020

- (PC) Added systeminfo page
- (PC) Built handler for task sequence tree viewer - displays full tree view for all folders and files
- (PC) Moved all PSD functions to PSDWizardInitialize.ps1

## 2.0.1b - Nov 22, 2020

- (PC) Built handler condition function - Parses definition XSL format and determine if a page should be displayed.
- (PC) Built welcome wizard as canvas in front of menu.

## 2.0.0b - Nov 22, 2020

- (PC) built XAML generate functions - dynamically builds XAML based on definition file and existing pages
