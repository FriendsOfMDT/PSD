Welcome to PowerShell Deployment (PSD)

The purpose of this project is to create a new version of MDT that provides the same level of automation as MDT but built on a more modern framework. The major pieces are built on PowerShell alone, but still using the MDT Workbench and regular layout. The goal is to support deployment shares using PSD as well as regular MDT deployment shares.

Major Scenarios Supported, deploy from:

IIS over HTTP with BITS & BranchCache using 2Pint Software's Task Sequence ACP
IIS over HTTP with BITS & BranchCache using PowerShell (No BITS available in WinPE)
IIS over HTTP using WebClient (Native PS)
Deploy over UNC
Local Media

This is very much a work in progress solution, so stayed tune as we rapidly moves forward on this.

The solution file for Visual Studio requires PowerShell for Visual Studio (3rd party extension for Visual Studio 2015).

When using Visual Studio to edit the PowerShell scripts, configure the editor to use spaces instead of tabs for PowerShell.
