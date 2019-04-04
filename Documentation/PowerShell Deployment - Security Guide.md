# Security Guide - PowerShell Deployment Extension Kit
April 2019

## Security Overview
SEcurity for PSD-enabled MDT solutions is essentially and effectively identical to a traditional MDT environment. Passwords are hidden and obfuscated from logs but may be transmitted in the clear over the wire.

## Accounts and Permissions
- PSD Installation - Installation of PSD requires administrative privledges and the exeution of PSD_Install.ps1 from an elevated permissions Powershell prompt

### PSD/MDT Shares and Content
Operation of PSD-enabled task sequences requries the following:
    - PSD Share (optionally hidden) cofigured in workbench
    - Account specified in BS/CS.ini
        - UserID, UserPassword, UserDomain 
    - Share Permissions (READ)
    - File Permissions (READ)

### Progress and Status Logs
Recording log and event information is done via logfiles
- Account specified in BS/CS.ini
    - UserID, UserPassword, UserDomain
 - SLSHARE value for log files
 - SLSHAREDynmaicLogging value for dynamic logs      
    - Share Permissions (WRITE)
    - File Permissions (WRITE)

### Active Directory
- Account specified in BS/CS.ini
    - JOINDOMAIN - set to target domain name
    - DOMAINADMIN - AD account with rights to create and delete AD computer objects
    - DOMAINADMINPASSWORD = AD account passowrd
    - DOMAINADMINDOMAN - blah


### Events and Monitoring

### IIS

### DaRT

## Firewall and Ports
MDT and PSD utilized the following ports:
- 80
- 443
- 135?
- 9800/9801 - Event Monitoring
