# Change log for PSDWizard

## 2.1.0b - Dec 27, 2020

- Fixed Locale check and update; using function convert TS to Object and back
- Removed TSVariable parameter; uses Get-TSValue Function for each check
- Add title parameter to Invoke-PSDWizard; dynamically updates version based on CHANGELOG.MD

## 2.0.9b - Dec 09, 2020

- Fixed Working path for XAML

## 2.0.8b -  - Dec 08, 2020

- Convert PSDWizard.psq to module
- Build function for entire module

## 2.0.7b - Dec 07, 2020

- Added Admin credential page; added functionality to check password
- Added TaskSequecne tree Objects to check if item has been selected; enabls next if selected
- disable navigation via tabs. only use back and next buttons

## 2.0.6b - Dec 06, 2020

- Changed get culture function to use getcultures .net command; speed up collection by 20sec
- Moved all style settings to resources directory; allows for easier theme and styling management

## 2.0.5b - Dec 05, 2020

- Renamed PSDWizard_Tabular.ps1 to PDSWizard.ps1
- Added locale selection for keyboard, user and timezone

## 2.0.4b - Nov 29, 2020

- Added check for welcome canvas in xaml generator function - does not add welcome wizard if SkipWizard=YES

## 2.0.3b - Nov 28, 2020

- Added Tabcontrol event to control button configurations at each screen
- Added search function for Taskseqeunce page
- Fixed TSEnv to process deploymentshare customsettings.ini
- Added Lists function with search function. Populates applications
- Added Dropdown list function. Populates timezone
- Add SkipWizard to Set-PSDWizardXAML code using condition function

## 2.0.2b - Nov 27, 2020

- Added systeminfo page
- Built handler for task sequence tree viewer - displays full tree view for all folders and files
- Moved all PSD functions to PSDWizardInitialize.ps1

## 2.0.1b - Nov 22, 2020

- Built handler condition function - Parses definition XSL format and determine if a page should be displayed.
- Built welcome wizard as canvas in front of menu.

## 2.0.0b - Nov 22, 2020

- built xaml generate functions - dynamically builds xaml based on definition file and existing pages