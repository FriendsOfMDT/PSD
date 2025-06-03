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
