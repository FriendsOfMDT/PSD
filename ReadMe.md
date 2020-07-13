# README - PowerShell Deployment Extension Kit
June 2020 (ver 0.2.0.1)

Welcome to PowerShell Deployment (PSD)

## Target audience
- Infrastructure Architects
- Solution Architects

The purpose of PowerShell Deployment for MDT is to create a new deployment solution that provides the same level of automation as MDT but built on a more modern framework - PowerShell. The major components and functionality are built on PowerShell alone, but still leverage the MDT Workbench and layout. The goal is to support deployment shares using PSD extensions as well as legacy MDT deployment shares.

Supported deployment scenarios include deployment from the following content repositories:

  -  IIS over HTTP with BITS & BranchCache using 2Pint Software's Task Sequence ACP
  -  IIS over HTTP with BITS & BranchCache using PowerShell (No BITS available in WinPE)
  -  IIS over HTTP using WebClient (Native PS)
  -  UNC (\\server\share)

PSD is very much a work-in-progress solution, so stay tuned as we rapidly move forward on this.

## Related References
(intentionally blank)