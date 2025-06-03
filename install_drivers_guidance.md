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
