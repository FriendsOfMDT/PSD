# Security Guide - PowerShell Deployment Extension Kit
April 2019

## Security Overview
Security for PSD-enabled MDT solutions is essentially and effectively identical to a traditional MDT environment. Passwords are hidden and obfuscated from logs but may be transmitted in the clear over the wire.

## Accounts and Permissions
- PSD Installation - Installation of PSD requires administrative privileges and the execution of PSD_Install.ps1 from an elevated Powershell prompt.

### PSD/MDT Shares and Content
Operation of PSD-enabled task sequences requires the following:
    - PSD Share (optionally hidden) configured in workbench
    - Account specified in BS/CS.ini
        - UserID, UserPassword, UserDomain 
    - Share Permissions (READ)
    - File Permissions (READ)

### Progress and Status Logs
Recording log and event information is done via log files
- Account specified in BS/CS.ini
    - UserID, UserPassword, UserDomain
 - SLSHARE value for log files
 - SLSHAREDynamicLogging value for dynamic logs      
    - Share Permissions (WRITE)
    - File Permissions (WRITE)

### Active Directory
- Account specified in BS/CS.ini
    - JOINDOMAIN - Set to target domain name
    - DOMAINADMIN - AD account with rights to create and delete AD computer objects
    - DOMAINADMINPASSWORD = AD account password
    - DOMAINADMINDOMAN - blah


### Events and Monitoring

### IIS

### DaRT
TODO: document DaRT limitations, and security considerations (TEST)

## Firewall and Ports
MDT and PSD utilized the following ports:
- 80
- 443
- 135?
- 9800/9801 - Event Monitoring
