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
