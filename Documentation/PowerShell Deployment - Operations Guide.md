# Operations Guide

This guid is for standard operational guide when using PSD. For the latest updates refer to the [PowerShell Deployment - Latest Release Setup Guide.md](./PowerShell%20Deployment%20-%20Latest%20Release%20Setup%20Guide.md)

## Introduction

PSD enabled deployments works the same as standard MDT Lite Touch Deployments. They can be initiated via PXE, or via Boot Media (ISO/USB). Here follows a list of common operations actions for the PSD solution

### Import Operating Systems

Within MDT Deployment workbench, on the newly created PSD Deployment share, import/create/copy any desired Operating Systems. Follow MDT-provided instructions and techniques.

>PRO TIP: You can copy Operating Systems from other MDT deployment shares within the Deployment Workbench.

### Create PSD Task Sequence

You **MUST** create a new Task Sequence from the PSD Templates within the workbench. PSD will fail otherwise. Do not attempt to clone/copy/import or otherwise work around this step. Some steps are required for PSD functionality. Do not delete any of the PSD task sequence steps - you may disable steps in the PSD Template task sequences if you choose.

>PRO TIP: If you upgrade PSD version at a later date, **expect** to recreate your task sequences from the new PSD templates.


### Create Applications

Within MDT Deployment workbench, on the newly created PSD Deployment share, import/create/copy any desired Applications. Follow MDT-provided instructions and techniques. Make note of application's unique GUIDs for use automating application installation with CustomSettings.ini.

>PRO TIP: You can copy Applications from other MDT deployment shares within the Deployment Workbench.

>BUG: Be sure to add a dummy app to `customsettings.ini`. THere is a glitch if you want to use application selection in the new PSDWizard

### Import/Add Drivers

Within MDT Deployment workbench, on the newly created PSD Deployment share, import/create/copy any desired drivers. After adding new drivers to MDT using the "total control method" (OS/Make/Model, or OS/Model, etc. ), you need to run the New-PSDDriverPackage.ps1 to generate the ZIP or WIM archives. One ZIP or WIM archive is created for each OS and Model.

>PRO TIP: You can copy drivers from other MDT deployment shares. PSD also supports adding existing WIM or ZIP driver packages to the platform for seamless integration.

Sample syntax:
```powershell
.\New-MDTDriverPackage.ps1 -psDeploymentFolder "E:\PSDProduction" -CompressionType WIM

.\New-MDTDriverPackage.ps1 -psDeploymentFolder "E:\PSDProduction" -CompressionType ZIP
```

### Check Deployment Share Permissions

By default, the PSD installer creates an MDT folder structure for PSD. PSD-specific files , scripts and templates are added and a new SMB share is created if specified. Ensure that the necessary domain and/or local computer user accounts have access to the PSD Share.

>PRO TIP: Only grant the *minimum necessary rights* to write logs in the PSD share. Only **READ** rights are required for the PSD/MDT share.

### Update Windows PE settings

Update the MDT WinPE configurations panels including the following settings:

- WinPE Custom Wallpaper (see notes below)
- WinPE Extra Directory (configured by default)
- ISO File name and generation
- WIM file name and generation

### Enable MDT monitoring

Enable MDT Event Monitoring and specify the MDT server name and ports to be used.

### Update CustomSettings.ini

Edit and Customize `customsettings.ini` to perform the necessary and desired automation and configuration of your OSD deployments. These should be settings to affect the installed OS typically. Be sure to configure new PSD properties and variables.

> PRO TIP: Recommend using the latest `customsettings.ini` provided in repo. This requires that your sections and settings will have to be migrated and tested as well

### Update BootStrap.ini

Edit and customize `bootstrap.ini` for your any necessary and desired configuration of your OSD deployments. These should be settings to affect the OSD environment typically. Be sure to configure new PSD properties and variables.

> PRO TIP: Recommend using the latest `bootstrap.ini` provided in repo. If using the new PSDDeployRoots property, remove *all* reference to DeployRoot from BootStrap.ini.

### Update Background wallpaper

By default, a new PSD themed background wallpaper (PSDBackground.bmp) is provided. It can be found at Samples folder of the MDT installation. Adjust the MDT WinPE Customizations tab to reflect this new bmp (or use your own).

### Configure Extra Files

Create and populate an ExtraFiles folder that contains anything you want to add to WinPE or images. Things like CMTRACE.EXE, wallpapers, etc.

>PRO TIP: Create the same folder structure as where you want the files to land (e.g. \Windows\System32)

### Readiness

PSD now runs a default script _Computer_Readiness.ps1_ from PSDResources\Readiness folder. Edit this file with new functions or create a new readiness script. Be sure to update the property in CustomSetting.ini. If Deployment Readiness page is enabled, a valid file path **must** be used.

### Certificates

Be sure to export the full chain of certificates to PSDResources\Certificates folder. This is required for HTTPS PSD shares

### Configure WinPE Drivers

Using MDT Selection Profiles, customize your WinPE settings to utilize an appropriate set of MDT objects. Be sure to consider Applications, Drivers, Packages, and Task Sequences.

### Generate new Boot Media

Using MDT Deployment workbench techniques, generate new boot media. By default the installer, will configure NEW PSD deployment shares to be PSDLiteTouch_x64.iso and PSDLiteTouch_x86.iso. Rename these if necessary.

### Content Caching and Peer to Peer support

Please see the BranchCache Installation Guide for information on how to enable P2P support.
# Appendix: PowerShell Script Integration and Guidance

This section provides detailed guidance on integrating and using various PowerShell scripts within your PSD environment and task sequences.


# General PowerShell Script Integration in PSD Task Sequences

PowerShell is integral to PowerShell Deployment (PSD), extending MDT's capabilities. Here's how to integrate your custom or provided PowerShell scripts into a PSD task sequence:

## Adding a PowerShell Script Step

1.  **Open Task Sequence Editor:** In the MDT Deployment Workbench, edit your PSD task sequence.
2.  **Add "Run PowerShell Script" Step:**
    *   Navigate to the desired point in the task sequence where the script should run.
    *   Click "Add", then go to "General" and select "Run PowerShell Script".
3.  **Configure the Step:**
    *   **Name:** Give the step a descriptive name (e.g., "Install Custom Application - MyCoolApp" or "Set Desktop Wallpaper").
    *   **PowerShell script:** Specify the name of the script you want to run.
        *   If the script is part of your MDT Scripts folder (e.g., `%SCRIPTROOT%`), you can just use its name (e.g., `MyScript.ps1`).
        *   If the script is in a subfolder within `%SCRIPTROOT%`, use a relative path (e.g., `CustomScripts\MyScript.ps1`).
        *   If the script is part of a Package, you might specify the path relative to the package source.
    *   **Parameters:** This is a crucial field.
        *   Enter any parameters your script accepts, similar to how you'd run it from a PowerShell console.
        *   **Example:** If your script `MyScript.ps1` takes a `-FilePath` parameter and a `-Mode` parameter, you would enter: `-FilePath "C:\Some\Path\File.txt" -Mode "Test"`
        *   **Using Task Sequence Variables:** You can make your scripts dynamic by using task sequence variables as parameter values. Task sequence variables are referenced with `%VariableName%`.
            *   **Example:** `-SourcePath "%DEPLOYROOT%\ExtraFiles" -ComputerName "%OSDComputerName%"`
            *   Ensure the variable exists and is populated before this step in the task sequence.
    *   **Start in:** If your script expects to be run from a specific working directory, you can specify it here. Often left blank.
    *   **PowerShell execution policy:** It's generally recommended to set this to `Bypass` to avoid issues with restricted execution policies on the client. MDT/PSD often handles this by default when invoking PowerShell.
    *   **Success codes:** Default is `0 3010`. `3010` indicates a reboot is required. Adjust if your script uses different success codes.

## Script Content Best Practices

*   **Error Handling:** Use `try-catch` blocks in your scripts to gracefully handle errors. Use `Write-Error` for terminating errors.
*   **Logging:**
    *   Use `Write-Host` for general information (visible in logs if script output is captured).
    *   Use `Write-Warning` for non-critical issues.
    *   Use `Write-Verbose` for detailed debugging messages (enable with `$VerbosePreference = "Continue"` or by running the script with `-Verbose`).
    *   For PSD-specific logging that integrates with MDT/PSD logging mechanisms (like `PSDUtility` module's `Write-PSDLog`), ensure the necessary modules are available or loaded by your script.
*   **Administrator Privileges:** Most task sequence steps run in the System context, which has administrator privileges. However, it's good practice for scripts that require elevation to include a check, especially if they might be run standalone.
    ```powershell
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Administrator privileges are required. Aborting."
        exit 1 # Or handle appropriately
    }
    ```
*   **Parameters:** Clearly define parameters in your script using `param()` blocks. Provide default values if applicable.
*   **Exit Codes:** Ensure your script exits with appropriate codes. `0` for success, `3010` for success with a required reboot. Other non-zero codes typically indicate failure.
*   **Accessing Task Sequence Variables within Script:** Besides passing them as parameters, scripts can directly access task sequence variables using the `Microsoft.SMS.TSEnvironment` COM object:
    ```powershell
    $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
    $myVar = $tsenv.Value("MyCustomVariable")
    $tsenv.Value("OutputVariable") = "MyScriptOutput" # To set a variable
    ```
    This is very common in MDT/PSD scripts.

## Example: Running `Set-DesktopWallpaper.ps1`

1.  **Script:** `Set-DesktopWallpaper.ps1` (ensure it's in your `%SCRIPTROOT%` or a package).
2.  **Task Sequence Step ("Run PowerShell Script"):**
    *   **Name:** Set Corporate Wallpaper
    *   **PowerShell script:** `Set-DesktopWallpaper.ps1`
    *   **Parameters:** `-WallpaperPath "%DEPLOYROOT%\Branding\CorporateWallpaper.jpg"`
        *   This assumes `CorporateWallpaper.jpg` is in a `Branding` subfolder of your deployment share.
    *   **PowerShell execution policy:** `Bypass`

By following these guidelines, you can effectively integrate PowerShell scripts into your PSD task sequences for customized and automated deployments.


## Script Guidance: `Copy-DOTempFolder.ps1`

**Purpose:** This script is designed to copy a folder from a source location (typically the deployment share or another network location) to a specified local path on the target machine during a task sequence.

**Key Features:**

*   **Parameterized:** Accepts source and destination paths as parameters.
*   **Administrator Check:** Includes a check for administrator privileges (though task sequences usually run as System).
*   **Source Path Validation:** Checks if the source path exists and is accessible.
*   **Error Handling:** Uses `try-catch` for the copy operation.

**Task Sequence Integration:**

1.  **Add "Run PowerShell Script" Step:** Add a new "Run PowerShell Script" step to your task sequence.
2.  **Configure the Step:**
    *   **Name:** e.g., "Copy DO-Temp Utilities"
    *   **PowerShell script:** `Copy-DOTempFolder.ps1`
        *   Ensure this script is accessible, e.g., in your `%SCRIPTROOT%` or a custom script package.
    *   **Parameters:**
        *   You **must** provide the `-SourcePath` and ideally the `-DestinationPath` parameters.
        *   **`-SourcePath` (Mandatory):** The UNC path to the folder you want to copy.
            *   Example using `%DEPLOYROOT%`: `-SourcePath "%DEPLOYROOT%\Applications\MyTool\Files"`
            *   Example using a direct UNC path: `-SourcePath "\\MyFileServer\Share\MyTool\Files"`
        *   **`-DestinationPath` (Recommended):** The local path on the target machine where the folder should be copied. If not specified, it defaults to `C:\DO-Temp` as per the script's internal default, but it's better to be explicit.
            *   Example: `-DestinationPath "C:\ProgramData\MyToolFiles"`
            *   Example: `-DestinationPath "%SystemDrive%\Temp\MyToolFiles"`
    *   **Combined Example Parameters:**
        ```powershell
        -SourcePath "%DEPLOYROOT%\ExtraTools\SpecialConfig" -DestinationPath "C:\Windows\Temp\SpecialConfig"
        ```
    *   **PowerShell execution policy:** Set to `Bypass`.

**Usage Considerations:**

*   **Permissions:** The context under which the task sequence runs (usually SYSTEM) needs read access to the `SourcePath` and write access to the parent of the `DestinationPath`.
*   **Path Variables:** Using task sequence variables like `%DEPLOYROOT%` for `SourcePath` is highly recommended to keep paths relative to your deployment environment.
*   **Error Logging:** Errors will be logged by the script to the standard error stream, which is captured in the task sequence logs (SMSTS.log).

**When to Use:**

*   Copying utility scripts, tools, or configuration files that are needed locally on the target machine during the deployment process.
*   Staging files for an application that will be installed in a later step.
*   Copying custom branding elements or other assets.


## Script Guidance: `Enable-TipbandVisibility.ps1`

**Purpose:** This script modifies a registry value (`TaskbarGlomLevel`) for the current user to change how taskbar buttons are grouped or combined. It sets `TaskbarGlomLevel` to `1`, which typically corresponds to "Combine when taskbar is full."

**Key Features:**

*   **Registry Modification:** Directly changes an HKCU (Current User) registry value.
*   **Path Creation:** Attempts to create the necessary registry keys if they don't exist.
*   **Administrator Check:** Includes a warning if not run as administrator, though for HKCU changes for the *current user*, it might sometimes work without full admin rights. However, in a task sequence context (running as SYSTEM), modifications to a specific user's profile registry (HKCU) need special handling.

**Task Sequence Integration:**

1.  **Add "Run PowerShell Script" Step:** Add a new "Run PowerShell Script" step.
2.  **Configure the Step:**
    *   **Name:** e.g., "Configure Taskbar Grouping"
    *   **PowerShell script:** `Enable-TipbandVisibility.ps1`
        *   Ensure this script is accessible (e.g., in `%SCRIPTROOT%`).
    *   **Parameters:** This script does not take any parameters.
    *   **PowerShell execution policy:** Set to `Bypass`.

**Usage Considerations:**

*   **HKCU Context:** This script modifies `HKCU`. When a task sequence runs, it typically executes as the SYSTEM account. The SYSTEM account's HKCU is not the same as the end-user's HKCU.
    *   **For Default User Profile:** To have this setting apply to all *new* users logging into the machine, the script would need to be modified to load the Default User's registry hive (`C:\Users\Default\NTUSER.DAT`) and make the changes there. The current script does not do this. (See `Set-DesktopWallpaper.ps1` for an example of loading a hive).
    *   **For a Specific Existing User:** If you need to apply this to an existing user who is *not* the user running the task sequence (which is rare during OS deployment), more complex solutions involving running the script in that user's context would be needed.
    *   **During "State Restore" or "Configuration" phase:** If this script runs late in the task sequence *after* a user has logged in (less common for this type of setting, but possible in some scenarios), it might apply to that logged-in user. However, it's generally applied *before* first user logon.
*   **Applying to Default User (Modification Required):**
    If the goal is for all new users to get this setting, `Enable-TipbandVisibility.ps1` would need to be adapted similar to how `Set-DesktopWallpaper.ps1` loads the default user hive:
    ```powershell
    # (Conceptual modification - not the full script)
    $defaultUserHive = "C:\Users\Default\NTUSER.DAT"
    $tempHiveName = "TempDefaultUser"
    reg load "HKLM\$tempHiveName" $defaultUserHive
    $registryPath = "HKLM\$tempHiveName\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    # ... then Set-ItemProperty to $registryPath ...
    reg unload "HKLM\$tempHiveName"
    ```
*   **Effectiveness:** Registry changes related to UI often require `explorer.exe` to be restarted or a user logoff/logon to take effect. This is mentioned in the script's output.

**When to Use:**

*   To customize the default taskbar behavior for users on newly deployed machines.
*   **Important:** If the intent is for this to be a default setting for all new users, the script **must be modified** to alter the Default User registry hive. As-is, if run by SYSTEM, it will modify SYSTEM's HKCU, which has no visible effect on end-users.

**Recommendation:**

For applying this setting to all new users, it's recommended to:
1.  Modify `Enable-TipbandVisibility.ps1` to load and modify the Default User registry hive.
2.  Run the modified script during the "State Restore" or "Configuration" phases of the task sequence, before the first user logon.


## Script Guidance: `Hide-DOAdmin.ps1`

**Purpose:** This script hides a specified user account from the Windows Welcome/Login screen. It achieves this by creating a registry value under `HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList`.

**Key Features:**

*   **Parameterized Username:** Accepts the username to hide as a parameter (`-UserNameToHide`), defaulting to "DOAdmin".
*   **Registry Modification (HKLM):** Modifies HKLM, which is system-wide.
*   **Administrator Check:** Correctly requires and checks for administrator privileges, which is standard in task sequences.
*   **Path Creation:** Creates the necessary `SpecialAccounts` and `UserList` registry keys if they don't exist.

**Task Sequence Integration:**

1.  **Add "Run PowerShell Script" Step:** Add a new "Run PowerShell Script" step to your task sequence.
2.  **Configure the Step:**
    *   **Name:** e.g., "Hide Local Administrator Account" or "Hide DOAdmin Account"
    *   **PowerShell script:** `Hide-DOAdmin.ps1`
        *   Ensure this script is accessible (e.g., in `%SCRIPTROOT%`).
    *   **Parameters:**
        *   **`-UserNameToHide` (Optional):** Specify the exact username of the account you want to hide.
            *   If you want to hide the default "DOAdmin" account, you don't need to specify this parameter, as it defaults to "DOAdmin".
            *   To hide a different account, for example, "LocalAdmin": `-UserNameToHide "LocalAdmin"`
            *   To hide the built-in Administrator account (though be cautious with this): `-UserNameToHide "Administrator"`
        *   You can use a task sequence variable if the username is dynamic: `-UserNameToHide "%AdminAccountName%"` (ensure `%AdminAccountName%` is set).
    *   **Example Parameters (hiding 'LocalAdmin'):**
        ```powershell
        -UserNameToHide "LocalAdmin"
        ```
    *   **Example Parameters (hiding default 'DOAdmin'):**
        (No parameters needed, or explicitly `-UserNameToHide "DOAdmin"`)
    *   **PowerShell execution policy:** Set to `Bypass`.

**Usage Considerations:**

*   **Account Existence:** The script doesn't check if the user account actually exists. It simply creates the registry entry to hide it. Hiding a non-existent account has no effect.
*   **Reversibility:** To unhide the account, you would need to delete the registry value created by this script (e.g., `Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" -Name "UserNameToHide"`) or set its value to `1`.
*   **Security Note:** Hiding an account from the login screen is a form of security through obscurity. The account still exists and can be accessed if known. Ensure proper password policies and account management practices are also in place.
*   **Built-in Administrator:** Be careful when hiding the default built-in Administrator account, especially if it's the only local administrator. Ensure you have other means of administrative access if needed.

**When to Use:**

*   To hide local administrative accounts (like a temporary admin account used during deployment, e.g., "DOAdmin") from the login screen for a cleaner user experience or to discourage direct login with these accounts.
*   Commonly used towards the end of a task sequence, after all configurations requiring the admin account are complete.

**Recommendation:**

This script is generally safe and effective for its stated purpose.
*   Run it late in the task sequence, typically in the "State Restore" or "System Preparation" phases.
*   If you use a custom local administrator account name, ensure you pass it using the `-UserNameToHide` parameter.


## Script Guidance: Application Installation Scripts

This section covers the various scripts related to application installation found in the repository: `Install-App1.ps1`, `Install-App2.ps1`, `Install-Applications.ps1`, and `Scripts/PSDApplications.ps1`.

### 1. `Install-App1.ps1` and `Install-App2.ps1`

*   **Purpose:** These scripts are **placeholders** intended to contain the actual installation logic for individual applications (e.g., "App1" and "App2").
*   **Current State:** As provided, they only contain a comment `# Placeholder for AppX installation script`. They do nothing functional.
*   **Action Required:** To use these, you must edit them and add the PowerShell commands necessary to silently install your specific applications. This usually involves:
    *   Copying installer files (if not already on the machine or accessible via UNC path).
    *   Running the installer with silent switches (e.g., `setup.exe /S /v/qn`, `msiexec /i "installer.msi" /qn`).
    *   Checking exit codes for success (often `0` or `3010` for reboot required).
    *   Adding logging or error handling.

**Example (Conceptual content for `Install-App1.ps1` to install 7-Zip):**
```powershell
# Install-App1.ps1 - Example for installing 7-Zip

$installerSource = "%DEPLOYROOT%\Applications\7-Zip\7z1900-x64.msi" # Assuming MSI is here
$logFile = "C:\Windows\Temp\7-Zip_Install.log"

Write-Host "Attempting to install 7-Zip..."
try {
    if (-not (Test-Path $installerSource)) {
        Write-Error "7-Zip installer not found at $installerSource"
        exit 1
    }

    Start-Process msiexec.exe -ArgumentList "/i `"$installerSource`" /qn /L*v `"$logFile`"" -Wait -PassThru -ErrorAction Stop

    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) {
        Write-Host "7-Zip installation successful (Exit Code: $LASTEXITCODE)."
        if ($LASTEXITCODE -eq 3010) {
            Write-Host "A reboot is required to complete 7-Zip installation."
            # Consider setting task sequence reboot variable if PSD framework doesn't handle it based on exit code
            # $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
            # $tsenv.Value('SMSTSRebootRequested') = 'true'
        }
    } else {
        Write-Error "7-Zip installation failed (Exit Code: $LASTEXITCODE). Check log: $logFile"
    }
}
catch {
    Write-Error "Error during 7-Zip installation: $($_.Exception.Message)"
    exit 1
}
```

### 2. `Install-Applications.ps1`

*   **Purpose:** This script acts as a simple orchestrator to run a series of other application installation scripts (like the modified `Install-App1.ps1`, `Install-App2.ps1`).
*   **How it Works:** It iterates through an array `$applicationInstallScripts` which contains the paths to the individual scripts to be executed.
*   **Task Sequence Integration:**
    1.  **Populate Individual Scripts:** First, ensure `Install-App1.ps1`, `Install-App2.ps1`, etc., are updated with actual installation logic.
    2.  **Add "Run PowerShell Script" Step:**
        *   **Name:** e.g., "Install Standard Applications"
        *   **PowerShell script:** `Install-Applications.ps1`
        *   **Parameters:** This script doesn't take parameters itself, but it calls other scripts that might (though the current placeholders don't).
        *   **PowerShell execution policy:** `Bypass`.
    3.  **Script Location:** `Install-Applications.ps1` expects the scripts it calls (e.g., `.\Install-App1.ps1`) to be in the same directory as itself. If you place `Install-Applications.ps1` in `%SCRIPTROOT%`, then `Install-App1.ps1` should also be in `%SCRIPTROOT%`.

*   **When to Use:**
    *   Suitable for simpler scenarios where you have a fixed list of applications to install and prefer to manage them via individual script files called by this central script.
    *   If you are not using MDT/PSD's built-in Application objects or need a more direct scripting approach.

### 3. `Scripts/PSDApplications.ps1`

*   **Purpose:** This is a more advanced and **recommended** script for handling application installations when working within the PSD/MDT framework, especially if you are defining Applications in the Deployment Workbench.
*   **Key Features:**
    *   Integrates with PSD/MDT task sequence variables (e.g., `ApplicationGUID`, `MandatoryApplications`, `Applications`).
    *   Uses `PSDUtility` and `PSDDeploymentShare` modules.
    *   Can process dependencies defined in MDT Application objects.
    *   Checks if an application is already installed (based on `tsenvlist:InstalledApplications`).
    *   Can handle applications defined in the MDT Deployment Workbench.
*   **Task Sequence Integration:**
    *   This script is typically used as part of a standard PSD task sequence. MDT often has a built-in "Install Application" or "Install Multiple Applications" step type that might use logic similar to this or call this script.
    *   **Single Application Install:** If a task sequence step is configured to install a single application by its GUID, this script detects and uses the `tsenv:ApplicationGUID` variable.
    *   **Multiple Applications (Dynamic Lists):** It processes applications listed in `tsenvlist:MandatoryApplications` and `tsenvlist:Applications`. These variables are usually populated by earlier steps in the task sequence (like "Gather" or UI choices from the PSD Wizard).
    *   **To use it directly (if not already part of your base PSD task sequence):**
        1.  **Add "Run PowerShell Script" Step:**
            *   **Name:** e.g., "Process Application Installations (PSDApplications)"
            *   **PowerShell script:** `Scripts\PSDApplications.ps1` (note the subfolder)
            *   **Parameters:** Generally, no direct parameters are needed as it relies on task sequence variables.
            *   **PowerShell execution policy:** `Bypass`.
        2.  **Ensure PSD Modules:** This script depends on PSD modules (`PSDUtility`, `PSDDeploymentShare`). These are usually available if the script runs within a full PSD environment (e.g., from a PSD boot image and when appropriate `Gather` steps have run).

*   **When to Use:**
    *   **Highly Recommended** when you are defining Application objects in the MDT Deployment Workbench and want to install them based on task sequence logic (e.g., selections made in the PSD Wizard, or a predefined list for a specific role).
    *   When you need dependency management as defined in your MDT Application objects.

**Summary of Recommendations:**

*   **For robust, MDT-integrated application deployment:**
    *   Define your applications in the MDT Deployment Workbench.
    *   Rely on `Scripts/PSDApplications.ps1` (or built-in PSD task sequence steps that utilize similar logic) to install these applications. This script is designed to work with the `Applications` and `MandatoryApplications` task sequence variables typically populated by the PSD wizard or `CustomSettings.ini`.
*   **For simpler, scripted application suites outside of MDT Application objects:**
    *   Modify `Install-App1.ps1`, `Install-App2.ps1`, etc., with your custom installation logic.
    *   Use `Install-Applications.ps1` to run these scripts in sequence.
    *   Call `Install-Applications.ps1` from a "Run PowerShell Script" step in your task sequence.
*   **Avoid mixing both approaches for the same set of applications to prevent confusion.**


## Script Guidance: `Install-Drivers.ps1`

**Purpose:** This script installs drivers using `.inf` files found within a specified source directory and its subdirectories. It uses `pnputil.exe` to add and install the drivers.

**Key Features:**

*   **Parameterized Source Path:** Accepts a `-DriverSourcePath` parameter to define where the drivers are located. Defaults to `.\Drivers` if not specified.
*   **Recursive Search:** Searches for `.inf` files in the source path and all its subfolders.
*   **Administrator Check:** Requires and checks for administrator privileges.
*   **Uses `pnputil.exe`:** Leverages the standard Windows utility for driver staging and installation.

**Task Sequence Integration:**

1.  **Add "Run PowerShell Script" Step:** Add a new "Run PowerShell Script" step to your task sequence, typically in the "Preinstall" or "State Restore" phase, after the OS is applied but before driver injection steps if any, or as a supplementary driver installation method.
2.  **Configure the Step:**
    *   **Name:** e.g., "Install Custom Drivers" or "Install Drivers for Model XYZ"
    *   **PowerShell script:** `Install-Drivers.ps1`
        *   Ensure this script is accessible (e.g., in `%SCRIPTROOT%`).
    *   **Parameters:**
        *   **`-DriverSourcePath` (Recommended):** Specify the path to the directory containing your driver files (organized in folders, each with its `.inf` files).
            *   **Using MDT/PSD Variables (Common):**
                *   `%OSDDriverPath%`: This variable is often set by MDT's "Inject Drivers" step if you are using MDT's driver management by model. If you have a step that determines the correct driver path based on model and sets `OSDDriverPath`, you could potentially use it here: `-DriverSourcePath "%OSDDriverPath%"`
                *   `%DeployRoot%\Out-of-Box Drivers\MyCustomDrivers`: You can point to a specific folder within your deployment share's driver structure: `-DriverSourcePath "%DEPLOYROOT%\Out-of-Box Drivers\MyCustomDrivers"`
            *   **Using a Local Path (If drivers are copied locally first):**
                *   If you've copied drivers to the local machine in a previous step (e.g., using `Copy-DOTempFolder.ps1`): `-DriverSourcePath "C:\Windows\Temp\MyModelDrivers"`
            *   **Default:** If no path is specified, it looks for a `Drivers` subfolder in the script's current working directory. This is less reliable in task sequences unless the working directory is explicitly set and drivers are present there. It's better to be explicit.
    *   **Example Parameters (using a folder in DeployRoot):**
        ```powershell
        -DriverSourcePath "%DEPLOYROOT%\Out-of-Box Drivers\SpecialSoundCard"
        ```
    *   **PowerShell execution policy:** Set to `Bypass`.

**Usage Considerations:**

*   **Driver Structure:** Organize your drivers in a structured way within the `DriverSourcePath`. For example, `DriverSourcePath\Audio\Realtek\*.inf`, `DriverSourcePath\Video\Nvidia\*.inf`. The script will search recursively.
*   **Driver Quality:** Ensure the drivers are correct for the hardware and operating system being deployed. This script simply attempts to install what it finds.
*   **MDT Driver Management:** This script can be an alternative or supplement to MDT's built-in "Inject Drivers" functionality.
    *   You might use MDT's "Inject Drivers" for most drivers sorted by model.
    *   You could use `Install-Drivers.ps1` for specific drivers that need special handling, are not easily integrated into the MDT driver store, or for drivers that are not strictly Plug and Play.
*   **Timing:** Run this script after the OS is installed and before applications that might depend on specific hardware drivers.
*   **Exit Codes:** `pnputil.exe` exit codes are checked. `0` and `3010` (reboot required) are considered success. Other codes will be reported as errors.
*   **Logging:** The script outputs information about which drivers it's attempting to install and the results from `pnputil.exe`. This will be in the SMSTS.log.

**When to Use:**

*   To install drivers from a specified folder structure, especially for drivers not included in the standard OS image or managed through MDT's PnP driver injection.
*   For out-of-box drivers that you want to control explicitly via a script.
*   As a targeted driver installation step for particular hardware models if you manage drivers this way.

**Recommendation:**

*   Always specify the `-DriverSourcePath` parameter for clarity and reliability in a task sequence.
*   Leverage task sequence variables (like `%DEPLOYROOT%` or model-specific paths you might set with custom logic) to point to the correct driver sources.
*   Test thoroughly with your target hardware.


## Script Clarification: `Install-PSD.ps1`

**Purpose:**

The `Install-PSD.ps1` script is a **setup and management utility for the PowerShell Deployment (PSD) environment itself.** It is **NOT** intended to be run as part of a standard client OS deployment task sequence (i.e., when you are deploying Windows to a new or existing computer).

**Key Functions of `Install-PSD.ps1`:**

*   **New PSD Deployment Share Creation:** It initializes a new PSD deployment share, sets up the necessary folder structure, and configures default settings.
*   **PSD Upgrade:** It can upgrade an existing PSD deployment share to a newer version of the PSD toolkit.
*   **Dependency Checks:** It checks for required components like the correct version of the Windows ADK (Assessment and Deployment Kit) and MDT (Microsoft Deployment Toolkit).
*   **File Copying:** It copies PSD-specific scripts, modules, templates, and resources into the deployment share.
*   **MDT Integration:** It interacts with the MDT provider and configures PSD-specific settings within the MDT environment.

**Why it's NOT for Client Task Sequences:**

*   **Modifies Deployment Share:** Its primary role is to build and maintain the deployment share on your MDT server, not to configure a client PC being deployed.
*   **Server-Side Logic:** Contains logic specific to setting up the PSD framework, which is irrelevant to a client OS installation.
*   **Interactive/Setup Parameters:** It takes parameters like `-psDeploymentFolder` and `-psDeploymentShare` which define where the PSD environment is built on the server.

**When to Use `Install-PSD.ps1`:**

*   When you are **first setting up a new PowerShell Deployment environment** on your MDT server.
*   When you are **upgrading an existing PSD environment** to a newer version of the toolkit.
*   It should be run manually by an administrator on the MDT server itself.

**In Summary:**

Think of `Install-PSD.ps1` as the installer *for* PSD, not a tool *used by* PSD to deploy operating systems. The scripts that PSD uses to deploy operating systems are those found within the `Scripts`, `PSDResources`, etc., folders *after* `Install-PSD.ps1` has successfully set up the environment.


## Script Guidance: `Run-TaskSequence.ps1`

**Purpose:** This script is designed as an orchestrator to execute a predefined sequence of other PowerShell scripts. It iterates through a list of script names and runs them one by one.

**Key Features:**

*   **Sequential Execution:** Runs scripts in the order they are listed in its internal `$scriptsToExecute` array.
*   **Administrator Check:** Includes a check for administrator privileges.
*   **Basic Logging:** Outputs information about which script it's starting and any errors encountered to the console (which will be captured by SMSTS.log).
*   **Error Handling:** Includes a `try-catch` block for each script execution to report errors but continue with the sequence.

**Scripts Called by `Run-TaskSequence.ps1` (Default Order):**

1.  `Hide-DOAdmin.ps1`
2.  `Install-Applications.ps1` (which in turn calls `Install-App1.ps1`, `Install-App2.ps1`)
3.  `Enable-TipbandVisibility.ps1`
4.  `Set-ChromeAsDefault.ps1`
5.  `Set-DesktopWallpaper.ps1` **(Important: See parameter issue below)**
6.  `Install-Drivers.ps1`
7.  `Copy-DOTempFolder.ps1`

**Task Sequence Integration:**

While this script *can* be run from a task sequence, it has some limitations compared to calling individual scripts as separate task sequence steps:

1.  **Using `Run-TaskSequence.ps1` directly:**
    *   **Add "Run PowerShell Script" Step:**
        *   **Name:** e.g., "Execute Custom Script Sequence"
        *   **PowerShell script:** `Run-TaskSequence.ps1`
        *   **Parameters:** This script itself does not take parameters.
        *   **PowerShell execution policy:** `Bypass`.
    *   **Script Locations:** `Run-TaskSequence.ps1` expects all the scripts it calls to be in the same directory as itself.

**Usage Considerations & Recommendations:**

*   **Parameterization Issue:**
    *   The most significant issue with using `Run-TaskSequence.ps1` as-is is that `Set-DesktopWallpaper.ps1` (which it calls) has a **mandatory `-WallpaperPath` parameter**.
    *   `Run-TaskSequence.ps1` does **not** provide this parameter to `Set-DesktopWallpaper.ps1`.
    *   Therefore, when `Run-TaskSequence.ps1` tries to execute `Set-DesktopWallpaper.ps1`, the wallpaper script will fail because its mandatory parameter is missing. This failure will be logged by `Run-TaskSequence.ps1`.
    *   The script itself contains warnings about this specific issue.

*   **Flexibility and Control:**
    *   Calling individual scripts as separate steps in your PSD task sequence offers much better flexibility and control.
    *   **Parameter Passing:** You can easily pass specific parameters (including task sequence variables) to each script when they are separate steps.
    *   **Conditional Execution:** Task sequence steps can have conditions, allowing you to run certain scripts only when needed.
    *   **Error Handling:** The task sequence engine has robust error handling for each step. While `Run-TaskSequence.ps1` tries to catch errors, a failure in one of its sub-scripts might be handled differently than a direct task sequence step failure.
    *   **Logging and Visibility:** Each script called as a separate step will have its execution clearly demarcated in the SMSTS.log, making troubleshooting easier.

*   **When `Run-TaskSequence.ps1` *might* be useful (with modifications):**
    *   If you have a very fixed sequence of scripts that *do not require external parameters* or if you modify `Run-TaskSequence.ps1` to internally define or fetch those parameters.
    *   For very simple, self-contained sequences.

**Recommendation:**

**It is generally recommended to call the individual scripts (`Hide-DOAdmin.ps1`, `Install-Applications.ps1`, `Set-DesktopWallpaper.ps1` etc.) as separate "Run PowerShell Script" steps within your main PSD task sequence rather than using `Run-TaskSequence.ps1`.**

This approach provides:
*   Proper parameter passing for each script (e.g., providing `-WallpaperPath` to `Set-DesktopWallpaper.ps1`).
*   Better error control and visibility within the task sequence.
*   More granular control over the sequence flow.

If you choose to use `Run-TaskSequence.ps1`, you **must** modify it or the scripts it calls (especially `Set-DesktopWallpaper.ps1`) to handle parameter requirements correctly. For example, you could hardcode the wallpaper path within `Run-TaskSequence.ps1` and pass it when it calls `Set-DesktopWallpaper.ps1`, but this reduces flexibility.


## Script Guidance: `Set-ChromeAsDefault.ps1`

**Purpose:** This script attempts to set Google Chrome as the default web browser for HTTP and HTTPS protocols by modifying registry settings under `HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations`.

**Key Features:**

*   **Checks for Chrome Installation:** Verifies if Chrome is installed by checking common registry paths for `chrome.exe`.
*   **Modifies HKCU:** Targets the current user's registry hive.
*   **ProgID Setting:** Sets the `ProgId` for HTTP and HTTPS to `ChromeHTML`.
*   **Administrator Check:** Includes a warning if not run as administrator.

**Task Sequence Integration:**

1.  **Add "Run PowerShell Script" Step:** Add a new "Run PowerShell Script" step.
2.  **Configure the Step:**
    *   **Name:** e.g., "Set Chrome as Default Browser"
    *   **PowerShell script:** `Set-ChromeAsDefault.ps1`
        *   Ensure this script is accessible (e.g., in `%SCRIPTROOT%`).
    *   **Parameters:** This script does not take any parameters.
    *   **PowerShell execution policy:** Set to `Bypass`.

**Important Caveats and Considerations:**

*   **Windows Default App Restrictions:**
    *   Modern versions of Windows (Windows 10 and later) have significantly restricted the ability of applications to programmatically change default application associations, especially for web browsers. This is to protect users from malicious software hijacking their defaults.
    *   While this script attempts the registry modifications that used to work, **it is not guaranteed to be effective on all versions or configurations of Windows 10/11.**
    *   Windows often relies on a hash value stored alongside the `ProgId` in the `UserChoice` registry key. This hash is generated based on the user's explicit choice through the Windows UI. Simply setting the `ProgId` programmatically without a valid hash may be ignored by the OS, or the OS might prompt the user to confirm the choice upon first use.
*   **HKCU Context:**
    *   Similar to `Enable-TipbandVisibility.ps1`, this script modifies `HKCU`. If run by the SYSTEM account during a task sequence, it modifies SYSTEM's HKCU, which will not affect end-users.
    *   **For Default User Profile:** To have this setting potentially influence new users, the script would need to be modified to load the Default User's registry hive (`C:\Users\Default\NTUSER.DAT`) and make changes there. The current script **does not** do this. Even then, the hash issue mentioned above remains a significant hurdle.
    *   **Official Method (XML):** The Microsoft-supported way to configure default application associations for new users is by creating an XML file (using `Dism /Online /Export-DefaultAppAssociations:"C:\AppAssoc.xml"`) that defines the associations, and then applying it to the default user profile or the image (using `Dism /Online /Import-DefaultAppAssociations:"C:\AppAssoc.xml"`). This is typically done during image creation or can be applied to the Default User profile. This script does not use this XML method.
*   **Chrome Installation Prerequisite:** The script checks if Chrome is installed. Ensure Chrome is installed *before* this script runs in the task sequence.

**When to Use (and Expected Outcome):**

*   You can include this script in a task sequence if you want to *attempt* to set Chrome as the default browser.
*   **Be aware that it may not work reliably on modern Windows versions.** Users might still be prompted to choose their default browser, or Edge might remain the default.
*   If applying to the Default User profile (after modifying the script to load the hive), it *might* influence the initial default for new users, but the hash validation by Windows is still a factor.

**Recommendation:**

1.  **Temper Expectations:** Understand that this method is unreliable for setting the default browser in modern Windows.
2.  **Consider Official XML Method:** For a more robust and supported solution, especially for setting defaults for all new users, investigate using the `Export-DefaultApplicationAssociation` and `Import-DefaultApplicationAssociation` DISM commands to apply an XML file. This is typically done when customizing your base Windows image.
3.  **User Education:** It might be more practical to provide instructions to users on how to set their default browser manually if the programmatic methods are not consistently effective.
4.  **If used, run after Chrome is installed.** If attempting to apply to the Default User profile, the script needs modification as discussed.

Given the OS-level restrictions, relying solely on this script to set the default browser is likely to lead to inconsistent results.


## Script Guidance: `Set-DesktopWallpaper.ps1`

**Purpose:** This script sets the desktop wallpaper for the current user and, importantly, attempts to set it for the **Default User profile**. This means new users logging into the machine for the first time should see the specified wallpaper.

**Key Features:**

*   **Mandatory `WallpaperPath` Parameter:** Requires the full path to the wallpaper image file.
*   **Optional Styling Parameters:** Accepts `-WallpaperStyle` and `-TileWallpaper` for customization.
*   **Default User Profile Modification:** Includes logic to load the Default User's registry hive (`NTUSER.DAT`) and apply the wallpaper settings there. This is crucial for ensuring all new users get the wallpaper.
*   **Administrator Check:** Requires and checks for administrator privileges, which are necessary for modifying the Default User hive.
*   **Refreshes Desktop:** Attempts to refresh desktop settings for the current user to apply the change immediately (if applicable).

**Task Sequence Integration:**

1.  **Add "Run PowerShell Script" Step:** Add a new "Run PowerShell Script" step to your task sequence. This should typically be run in the "State Restore" or "Configuration" phase, after the OS is installed and before user creation or first login.
2.  **Configure the Step:**
    *   **Name:** e.g., "Set Corporate Desktop Wallpaper"
    *   **PowerShell script:** `Set-DesktopWallpaper.ps1`
        *   Ensure this script is accessible (e.g., in `%SCRIPTROOT%`).
    *   **Parameters:**
        *   **`-WallpaperPath` (MANDATORY):** You **must** provide the full path to your wallpaper image file.
            *   **Example using `%DEPLOYROOT%`:** This is the most common and recommended way if your wallpaper is stored in your deployment share.
                ```powershell
                -WallpaperPath "%DEPLOYROOT%\Branding\MyCompanyWallpaper.jpg"
                ```
                (This assumes you have `MyCompanyWallpaper.jpg` in a `Branding` subfolder of your deployment share, e.g., `DeploymentShare\Branding\MyCompanyWallpaper.jpg`)
            *   **Example using a local path (if copied earlier):**
                ```powershell
                -WallpaperPath "C:\Windows\Web\Wallpaper\MyCustomWallpaper.png"
                ```
        *   **`-WallpaperStyle` (Optional):** Defines how the wallpaper is displayed. Defaults to '2' (Stretch).
            *   '0' (Center), '1' (Tile - see TileWallpaper), '2' (Stretch), '6' (Fit), '10' (Fill)
            *   Example: `-WallpaperStyle "10"` for Fill.
        *   **`-TileWallpaper` (Optional):** Defines if the wallpaper should be tiled. Defaults to '0' (No). Set to '1' if using `WallpaperStyle '1'`.
            *   Example: `-WallpaperStyle "1" -TileWallpaper "1"`
    *   **Full Example Parameters:**
        ```powershell
        -WallpaperPath "%DEPLOYROOT%\Branding\CompanyWallpaper.jpg" -WallpaperStyle "10"
        ```
    *   **PowerShell execution policy:** Set to `Bypass`.

**Usage Considerations:**

*   **Image File Accessibility:** The path provided to `-WallpaperPath` must be accessible by the SYSTEM account during the task sequence. Using `%DEPLOYROOT%` (which resolves to the deployment share path) is generally reliable.
*   **Image Format:** Use common image formats like JPG or PNG.
*   **Default User Profile:** The script's ability to modify the Default User profile is key to its effectiveness for new users. Ensure the task sequence runs with sufficient privileges (which it normally does).
*   **Timing:** Run this script after the operating system is installed and configured, but before any user accounts are created or log in for the first time, to ensure new users get the wallpaper.

**When to Use:**

*   To enforce a standard corporate or organizational desktop wallpaper for all users on newly deployed machines.
*   This is a common customization step in OS deployment.

**Recommendation:**

*   This script is well-suited for its purpose.
*   **Always provide the `-WallpaperPath` parameter.**
*   Store your standard wallpaper in your deployment share (e.g., in a `Branding` or `Wallpapers` subfolder) and use the `%DEPLOYROOT%` variable to reference it for maximum portability of your task sequence.
*   Test to ensure the wallpaper applies correctly for new users logging in post-deployment.


## Script Guidance: `Invoke-PSDScript.ps1`

**Purpose:** This script serves as a wrapper to demonstrate best practices for calling other PowerShell scripts. It showcases:
- Parameter passing to a target script.
- Basic logging to a file and the console.
- Error handling for the execution of the target script.

**Key Features:**
- Accepts `-TargetScriptPath` and `-TargetScriptParameters` (a hashtable) to dynamically call scripts.
- Logs its actions to `C:\Windows\Temp\InvokePSDScript.log` by default.
- Includes example logic for handling default parameters for `Set-DesktopWallpaper.ps1` if its mandatory `WallpaperPath` is not provided.

**How it's Used in This Repository:**
- The `Run-TaskSequence.ps1` script has been modified to use `Invoke-PSDScript.ps1` to call each of its target scripts. This makes `Run-TaskSequence.ps1` a more robust local orchestrator, though direct task sequence steps are still generally preferred for PSD deployments.

**Task Sequence Integration (If used directly):**
While `Invoke-PSDScript.ps1` can be called directly from a task sequence step, its main purpose here is illustrative. If you were to call it directly:
1.  **Add Run PowerShell Script Step:**
    *   **Name:** e.g., Invoke Set Wallpaper Script
    *   **PowerShell script:** `Invoke-PSDScript.ps1`
    *   **Parameters:**
        ```powershell
        -TargetScriptPath .Set-DesktopWallpaper.ps1 -TargetScriptParameters @{ WallpaperPath = %DEPLOYROOT%BrandingMyWallpaper.jpg; WallpaperStyle = 10 }
        ```
    *   **PowerShell execution policy:** `Bypass`.

This script primarily serves as an educational tool within this repository to demonstrate script invocation patterns.
