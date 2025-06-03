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
