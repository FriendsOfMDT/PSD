<#
.SYNOPSIS
    Modifies settings when deploying OS
.DESCRIPTION
    Modifies settings when deploying OS
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDCustomization.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2022-09-18

          Version - 0.1.0 - () - Finalized functional version 1.

.Example
#>
param (
    $Config
)

# Load core modules
Import-Module PSDUtility

if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
    $VerbosePreference = "Continue"
}
Write-Verbose "Verbose is on"

# Set scriptversion for logging
$ScriptVersion = "0.1.0"


# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true)
{
    $verbosePreference = "Continue"
}

switch ($Config)
{
    'Custom' {
        [string]$SerialNumber = (Get-CimInstance -ClassName win32_bios).Serialnumber
        $CleanSerialNumber =  $SerialNumber.Replace("/","").Replace("\","").Replace("|","").Replace("-","").Replace(" ","")
        $CutOfNumber = 10
        $checklength = $CleanSerialNumber.Length
        If($checklength -lt $CutOfNumber ){
            $numberx = $checklength
        }
        Else{
            $numberx = $CutOfNumber
        }
        $sn5 = $CleanSerialNumber.Substring($CleanSerialNumber.Length - $numberx )

        $tsenv:OSDComputerName = "PC-$($sn5)"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSDComputerName is now = $tsenv:OSDComputerName"

        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
        Save-PSDVariables

    }
    Default {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Attempting to hide DOadmin account from login screen."
        try {
            $RegPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"
            # Ensure the parent path exists
            if (-not (Test-Path $RegPath)) {
                New-Item -Path $RegPath -Force | Out-Null
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Created registry path $RegPath."
            }
            New-ItemProperty -Path $RegPath -Name "DOadmin" -Value 0 -PropertyType DWord -Force -ErrorAction Stop
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Successfully set registry key to hide DOadmin account."
        }
        catch {
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Error setting registry key to hide DOadmin account. Error: $($_.Exception.Message)" -LogLevel 3
        }
    }
}




