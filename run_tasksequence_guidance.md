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
