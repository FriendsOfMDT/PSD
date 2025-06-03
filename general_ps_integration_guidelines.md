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
