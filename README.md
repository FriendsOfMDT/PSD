# PowerShell Deployment (PSD)

## Overview

PowerShell Deployment (PSD) is a suite of scripts and tools designed to enhance and extend the capabilities of Microsoft Deployment Toolkit (MDT) by leveraging the power and flexibility of PowerShell for operating system deployment and configuration. It aims to provide a more modern, script-centric approach to many common deployment tasks, allowing for greater customization and automation.

This project is ideal for IT professionals and deployment engineers looking to:
*   Automate OS deployment beyond standard MDT capabilities.
*   Integrate custom PowerShell scripts seamlessly into their deployment process.
*   Utilize PowerShell-driven wizards and configuration gathering.
*   Maintain a high degree of control over each step of the task sequence.

## Key Features

*   **PowerShell-Driven Task Sequences:** Execute most deployment tasks using PowerShell scripts and modules.
*   **Customizable Gather Logic:** `PSDGather.ps1` provides extensive information gathering, easily extended with custom variables and rules.
*   **Interactive Wizards:** Modern WPF-based wizards (`PSDWizardNew`) for prestart interaction in WinPE.
*   **Modular Design:** Core functionalities are encapsulated in PowerShell modules for better organization and reusability.
*   **Extensible:** Easily add your own custom scripts and integrate them into the PSD framework.
*   **MDT Integration:** Designed to work within the Microsoft Deployment Toolkit environment, leveraging its structure for deployment shares, task sequences, and monitoring.

## Getting Started

To get started with PowerShell Deployment:

1.  **Prerequisites:** Ensure you have the necessary versions of Windows ADK (including WinPE Add-on) and Microsoft Deployment Toolkit (MDT) installed on your deployment server.
2.  **Installation:** For detailed instructions on setting up a PSD-enabled deployment share, please see the:
    *   **[Installation Guide](./Documentation/InstallationGuide.md)**
3.  **Task Sequence Creation:** Once PSD is installed and your deployment share is populated (OS, drivers, applications), refer to the following guide to create your deployment task sequence:
    *   **[Task Sequence Guide](./Documentation/PSD_TaskSequence_Guide.md)**

## Project Structure

A brief overview of the key directories in this project:

*   **`Install-PSD.ps1`**: The main installation script to set up or upgrade a PSD deployment share.
*   **`Scripts/`**: Contains the core PSD PowerShell scripts (`.ps1`) and modules (`.psm1`) that perform various deployment tasks.
*   **`Templates/`**: Includes PSD-specific Unattend.xml templates and other template files used by the MDT provider.
*   **`INIFiles/`**: Default `Bootstrap.ini` and `CustomSettings.ini` files used as a base for silent installations or as a reference.
*   **`PSDResources/`**: Contains resources like branding images, prestart executables, plugins, and other tools used during deployment.
*   **`Documentation/`**: Additional guides and documentation for using PSD.
*   **`Branding/`**: Source files for some of the branding elements.
*   **`Plugins/`**: Example plugins or extensions for PSD.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on how to contribute to this project. (Note: Create `CONTRIBUTING.md` if it doesn't exist and you want to define contribution guidelines).

## License

This project is licensed under the terms of the [LICENSE](./LICENSE) file. (Note: Ensure `LICENSE` file exists).
