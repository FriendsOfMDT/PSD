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
