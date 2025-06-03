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
