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
