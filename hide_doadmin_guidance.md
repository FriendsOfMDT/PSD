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
