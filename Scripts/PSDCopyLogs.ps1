<#
.SYNOPSIS
    Copy log files.
.DESCRIPTION
    Copy log files.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDCopyLogs.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2020-06-16

          Version - 0.0.1 - () - Finalized functional version 1.
          TODO:

.Example
#>

[CmdletBinding()]
param(
)

# Set scriptversion for logging
$ScriptVersion = "0.0.1"

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true)
{
    $verbosePreference = "Continue"
}
$Folders = "C:\Minint\SMSOSD\OSDLOGS","C:\Windows\Temp\DeploymentLogs","C:\_SMSTaskSequence\Logs"


if($tsenv:SLShare -eq $null -or $tsenv:SLShare -eq ""){
    Exit 0
}
if ($tsenv:SLShare -ilike "http*"){
    foreach($Folder in $Folders){
        If((Test-Path -Path $Folder) -eq $true){
            $FolderName = ($Folder | Split-Path -Leaf)
            switch ($FolderName){
                'OSDLOGS' {$LogName = "OSDLOGS"}
                'DeploymentLogs' {$LogName = "DeploymentLogs"}
                'Logs' { $LogName = "SMSTSlog"}
                Default {}
            }
            $SecurePassword = $tsenv:LogUserPassword | ConvertTo-SecureString -AsPlainText -Force
            $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList "$tsenv:LogUserDomain\$tsenv:LogUserID", $SecurePassword
            $SourceFolderToZIP = "$Folder"
            $SourceFile = "$env:TEMP\$FolderName.zip"
            Compress-Archive -Path $SourceFolderToZIP -DestinationPath $SourceFile -Verbose -Force
            Start-BitsTransfer -Authentication Ntlm -Source $SourceFile -Destination $("$tsenv:SLshare/$env:COMPUTERNAME-" + "$LogName" + ".zip") -TransferType Upload -Verbose -Credential $Credentials
        }
    }
}
if ($tsenv:SLShare -like "\\*"){
    Return
}





