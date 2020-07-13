# Introduction to PowerShell Deployment (PSD)

## PSD Background
The PSD solution is an extension for MDT which adds support for installation via HTTP/HTTPS, enabling cloud imaging and P2P scenarios. 

## PSD Workflow Changes
When using a standard MDT deployment share, MDT is using VBScripts on the client side to launch the task sequence, as well as to carry out the various task sequence actions. Standard MDT is also using UNC (SMB) for all network-based deployments. 

When extended with PSD, the VBScripts are replaced with PowerShell Scripts, meaning the launch of the task sequence as well as the actions are carried out by PowerShell scripts. The connection to deployment share is now done by creating a PSDrive. The task sequences have also been heavily simplified compared to standard MDT task sequences. 

> FUN FACT: The standard MDT task sequecnes has their very origin in the OSD Feature Pack for SMS 2003. We thought it was time to modernize them a bit :)

## The Team

The team behind PSD is:

* Mikael Nystrom (@mikael_nystrom)
* Johan Arwidmark (@jarwidmark)
* Michael Niehaus (@mniehaus)
* Steve Campbell (@SoupAtWork)
* Jordan Benzing (@JordanTheItGuy)
* Andreas Hammarskjold (@AndHammarskjold)


