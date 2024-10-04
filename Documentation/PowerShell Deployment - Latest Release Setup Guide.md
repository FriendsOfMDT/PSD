# Setting Up PSD 2.30

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Upgrade Process](#upgrade-process)
    - [Backup Existing Configuration](#backup-existing-configuration)
    - [Download PSD 2.30](#download-psd-230)
    - [Install PSD 2.30](#install-psd-230)
4. [Editing Configuration Files](#editing-configuration-files)
    - [CustomSettings.ini](#customsettingsini)
    - [Bootstrap.ini](#bootstrapini)
    - [PSDUpdateExit.ps1](#psdupdateexitps1)
5. [Final Steps](#final-steps)
6. [Troubleshooting](#troubleshooting)

## Introduction

This guide provides step-by-step instructions for setting up the new release of PSD 2.30, including the upgrade process and editing the necessary configuration files.

## Prerequisites

- Ensure you have administrative access to the system.

## Upgrade Process

### Backup Existing Configuration

1. Navigate to the directory containing your current PSD installation.
1. Go to the Control folder
1. Create a backup of the existing configuration files:
    - CustomSettings.ini
    - Bootstrap.ini

> NOTE: The _Install-PSD_ with **upgrade** switch will backup these files plus several others to the _Backup_ directory (eg. PSD_0001)

### Download PSD 2.30

1. Visit the official PSD github page: https://github.com/FriendsOfMDT/PSD
2. Download the latest release of PSD 2.30.
    - Click the green `[<> Code]` button, Select _Download Zip_

### Install PSD 2.30

1. Extract the downloaded files to your desired directory.
1. Open PowerShell as an Administrator and run the step provide here: [Installation Guide](PowerShell%20Deployment%20-%20Installation%20Guide.md)


## Review PSD Install

One of the common things skipped is reviewing the `Install-PSD.log` file. This is important as some files may not have ben overwritten.

Here are a few checks to be sure you have the latest release installed:

1. Check these files to ensure they have been updated:

   - Scripts\ZTIGather.xml
   - Tools\Modules\PSDGather\ZTIGather.xml
   - Tools\Modules\PSDWizardNew\PSDWizardNew.psm1

2. Check to make sure these folder exist

   - Scripts\PSDWizardNew\Themes\Classic
   - Scripts\PSDWizardNew\Themes\Dark

   > NOTE: you can delete the other folders unless you are using those themes.

3. Check to make sure these files exist:

   - PSDResources\Readiness\Computer_Readiness.ps1

   >NOTE this file contains basic functions and is required unless you disable the Readiness Check: _**SkipReadinessCheck=YES**_

## Editing Configuration Files

If this is a new installation, all the items are setup for you and ready to go. However, on an upgrade installation, several things must be done to support the new PSD release

### CustomSettings.ini

1. Ensure `Control\CustomSettings.ini` is backed up

2. Open `Control\CustomSettings.ini` in a text editor.

3. Overwrite `[Settings]` and `[Default]` sections with this one: [INIFiles/CustomSettings.ini](https://github.com/FriendsOfMDT/PSD/blob/master/INIFiles/CustomSettings.ini)

> **WHY?** There are several new items added and we want to make sure you get the best experience. Also if a PSD variable exists, it won't be processed

4. Update the necessary settings the related to your deployment share. Things like:
    - Priority
    - YOUR custom properties (not related to PSD)
    - Additional Sections

5. If no _Application001_ or _MandatoryApplications001_ exist, add a real or dummy one

 ```ini
 APPLICATIONS001={d7f2f50a-e85f-425e-a2f7-68392b1f31a6}
 ```
> **WHY?** This is known bug. Applications selected in UI won't install otherwise

6. Edit any skips if desired

7. Save and close the file.

### Bootstrap.ini

1. Ensure `Control\Bootstrap.ini` is backed up

2. Open `Control\Bootstrap.ini` in a text editor.

3. Overwrite `[Settings]` and `[Default]` sections with this one: [INIFiles/Bootstrap.ini](https://github.com/FriendsOfMDT/PSD/blob/master/INIFiles/Bootstrap.ini)

> **WHY?** There are several new items added and we want to make sure you get the best experience. Also if a PSD variable exists, it won't be processed

4. Ensure PSDDeployRoots reflects your deployment share url.

5. Edit any skips if desired

6. Save and close the file.

### PSDUpdateExit.ps1

If you have added content to this file, you must add it back.

## Final Steps

Update the Deployment share and select to build new ISO.

## Troubleshooting

If you encounter any issues, refer to the official PSD documentation or open an issue