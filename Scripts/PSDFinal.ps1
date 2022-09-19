<#
.SYNOPSIS
    Cleanup script.
.DESCRIPTION
    Cleanup script.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDFinal.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2020-06-16

          Version - 0.0.1 - () - Finalized functional version 1.
          TODO:

.Example
#>

Param(
    $Action,
    $ParentPID,
    $Debug
)

# Kill TS if running
Stop-Process -Id $ParentPID -Force

if($Debug -eq $true){
    Return
}

# Remove all Autologon entries
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoAdminLogon -Value 0
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultUserName -Value ""
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultDomainName -Value ""
Remove-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultPassword -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoLogonCount -Value 0
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutologonSID -Value ""

# Re-enabling UAC for built-in Administrator account
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name FilterAdministratorToken -Value "1"

# Reset AsyncRunOnce registry value with HideShell (Windows 10 and above)
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer' -Name AsyncRunOnce -Value "1"

# Clear the windows 10 upgrade registry key
Remove-Item -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Windows\Win10Upgrade' -Force -ErrorAction SilentlyContinue

# Remove the MININT and Drivers folder
$Folders = "MININT","Drivers"
Foreach($Folder in $Folders){
    Get-Volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\$Folder"} | % {
        $localPath = "$($_.DriveLetter):\$Folder"
        if(Test-Path -Path "$localPath"){
            Remove-Item "$localPath" -Recurse -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
}

# Remove the markerfile (TESTING)
$MarkerFile = "$env:SYSTEMDRIVE\marker.psd"
if(Test-Path -Path $MarkerFile){
    Remove-Item -Path $MarkerFile
}


Switch ($Action){
    'SHUTDOWN' {
        & Shutdown.exe /s /t 1 /f
    }
    'RESTART'{
        & Shutdown.exe /r /t 1 /f
    }
    'REBOOT'{
        & Shutdown.exe /r /t 1 /f
    }
    'LOGOFF' {
        & Logoff
    }
    Default {
    }
}
