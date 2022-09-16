<#
.SYNOPSIS
    Start or continue a PSD task sequence. 
.DESCRIPTION
    Start or continue a PSD task sequence.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDStart.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2019-06-02

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.9.1 - Added check for network access when doing network deployment
          Version - 0.9.2 - Check that needed files are in WinPE for XAML files to show correctly
                            Logic for detection if running in WinPE
                            Check for unsupported variables
          Version - 0.9.2 - Added logic when removing tscore.dll and TSprogressUI to avoid errors in log files
          Version - 0.9.3 - ZTINextPhase.wsf is now replaced with PSDNextPhase.ps1
                            ZTIApplications.wsf is now replaced with PSDApplications.ps1
          Version - 0.9.4 - Added partial support for HTTPS
          version - 0.9.5 - Added detection if we can find certificate in certain folders, of so they will be imported as Root Cert's
                            $($env:SYSTEMDRIVE)\Deploy\Certificates
                            $($env:SYSTEMDRIVE)\MININT\Certificates
          version - 0.9.6 - Added https condition for NTP, and set time
          version - 0.9.7 - Debugging, logging, Write to screen has changed... alot...
          TODO:

.Example
#>

param (
    [switch] $start,
    [switch] $Debug
)

function Write-PSDBootInfo{
    Param(
        $Message,
        $SleepSec = "NA"
    )

    # Check for BGInfo
    if(!(Test-Path -Path "$env:SystemRoot\system32\bginfo.exe")){
        Return
    }

    # Check for BGinfo file
    if(!(Test-Path -Path "$env:SystemRoot\system32\psd.bgi")){
        Return
    }

    # Update background
    $Result = New-Item -Path HKLM:\SOFTWARE\PSD -ItemType Directory -Force
    $Result = New-ItemProperty -Path HKLM:\SOFTWARE\PSD -Name PSDBootInfo -PropertyType MultiString -Value $Message -Force
    & bginfo.exe "$env:SystemRoot\system32\psd.bgi" /timer:0 /NOLICPROMPT /SILENT
    
    if($SleepSec -ne "NA"){
        Start-Sleep -Seconds $SleepSec
    }
}

# Set the module path based on the current script path
$deployRoot = Split-Path -Path "$PSScriptRoot"
$env:PSModulePath = $env:PSModulePath + ";$deployRoot\Tools\Modules"

# Check for debug settings

$Global:PSDDebug = $false
if(Test-Path -Path "C:\MININT\PSDDebug.txt"){
    $DeBug = $true
    $Global:PSDDebug = $True
}

if($Global:PSDDebug -eq $false){
    if($DeBug -eq $true){
        $Result = Read-Host -Prompt "Press y and Enter to continue in debug mode, any other key to exit from debug..."
        if($Result -eq "y"){
            $DeBug = $True
        }else{
            $DeBug = $False
        }
    }
}

if($DeBug -eq $true){
    $Global:PSDDebug = $True
    $verbosePreference = "Continue"
}

if($PSDDeBug -eq $true){
    Write-Verbose "PSDDeBug is now $PSDDeBug"
    Write-Verbose "verbosePreference is now $verbosePreference"
    Write-Verbose $env:PSModulePath
}

# Make sure we run at full power
Write-PSDBootInfo -Message "Setting Power plan to High performance" -SleepSec 1
& powercfg.exe /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Load core modules
Write-PSDBootInfo -SleepSec 1 -Message "Loading core PowerShell modules"
Import-Module PSDUtility -Force -Verbose:$False
Import-Module Storage -Force -Verbose:$False

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Beginning initial process in PSDStart.ps1"

if($PSDDeBug -eq $true){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Imported Module: PSDUtility,Storage "
}

# Check if we booted from WinPE
$Global:BootfromWinPE = $false
if ($env:SYSTEMDRIVE -eq "X:"){
    $Global:BootfromWinPE = $true
}
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): BootfromWinPE is now $BootfromWinPE"

# Write Debug status to logfile
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PSDDeBug is now $PSDDeBug"

# Install PSDRoot certificate if exist in WinPE
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Looking for certificates..."

$Certificates = @()

$CertificateLocations = "$($env:SYSTEMDRIVE)\Deploy\Certificates","$($env:SYSTEMDRIVE)\MININT\Certificates"
foreach($CertificateLocation in $CertificateLocations){
    if((Test-Path -Path $CertificateLocation) -eq $true){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Looking for certificates in $CertificateLocation"
        $Certificates += Get-ChildItem -Path "$CertificateLocation" -Filter *.cer
    }
}

foreach($Certificate in $Certificates){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Found $($Certificate.FullName), trying to add as root certificate"
    # Write-PSDBootInfo -SleepSec 1 -Message "Installing PSDRoot certificate"
    $Return = Import-PSDCertificate -Path $Certificate.FullName -CertStoreScope "LocalMachine" -CertStoreName "Root"
    If($Return -eq "0"){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Succesfully imported $($Certificate.FullName)"
    }
    else{
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Failed to import $($Certificate.FullName)"
    }
}

# Set Command Window size
# Reason for 99 is that 99 seems to use the screen in the best possible way, 100 is just one pixel to much
if($Global:PSDDebug -ne $True){
    Set-PSDCommandWindowsSize -Width 99 -Height 15
}

if($BootfromWinPE -eq $true){
    # Windows ADK v1809 could be missing certain files, we need to check for that.
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Check if we are running Windows ADK 10 v1809"
    if($(Get-WmiObject Win32_OperatingSystem).BuildNumber -eq "17763"){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Check for BCP47Langs.dll and BCP47mrm.dll, needed for WPF"
        if(-not(Test-Path -Path X:\Windows\System32\BCP47Langs.dll) -or -not(Test-Path -Path X:\Windows\System32\BCP47mrm.dll)){
            Start-Process PowerShell -ArgumentList {
                "Write-warning -Message 'We are missing the BCP47Langs.dll and BCP47mrm.dll files required for WinPE 1809.';Write-warning -Message 'Please check the PSD documentation on how to add those files.';Write-warning -Message 'Critical error, deployment can not continue..';Pause"
            } -Wait
            exit 1
        }
    }

    # We need more than 1.5 GB (Testing for at least 1499MB of RAM)
    Write-PSDBootInfo -SleepSec 2 -Message "Checking that we have at least 1.5 GB of RAM"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Check for minimum amount of memory in WinPE to run PSD"
    if ((Get-WmiObject -Class Win32_computersystem).TotalPhysicalMemory -le 1499MB){
        Show-PSDInfo -Message "Not enough memory to run PSD, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        Start-Process PowerShell -Wait
        exit 1
    }

    # All tests succeded, log that info
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Completed WinPE prerequisite checks"
}

# Load more modules
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load more modules"
Import-Module PSDDeploymentShare -ErrorAction Stop -Force -Verbose:$False
Import-Module PSDGather -ErrorAction Stop -Force -Verbose:$False
Import-Module PSDWizard -ErrorAction Stop -Force -Verbose:$False

#Set-PSDDebugPause -Prompt 182

#Check if tsenv: works
try{
    Get-ChildItem -Path "TSEnv:"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Able to read from TSEnv"
}
catch{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to read from TSEnv"
    #Break
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $deployRoot"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"

# If running from RunOnce, create a startup folder item and then exit
if ($start){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating a link to re-run $PSCommandPath from the all users Startup folder"

    # Create a shortcut to run this script
    $allUsersStartup = [Environment]::GetFolderPath('CommonStartup')
    $linkPath = "$allUsersStartup\PSDStartup.lnk"
    $wshShell = New-Object -comObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($linkPath)
    $shortcut.TargetPath = "powershell.exe"
    
    if($PSDDebug -eq $True){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Command set to:PowerShell.exe -Noprofile -Executionpolicy Bypass -File $PSCommandPath -Debug"
        $shortcut.Arguments = "-Noprofile -Executionpolicy Bypass -File $PSCommandPath -Debug"
    }
    else{
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Command set to:PowerShell.exe -Noprofile -Executionpolicy Bypass -Windowstyle Hidden -File $PSCommandPath"
        $shortcut.Arguments = "-Noprofile -Executionpolicy Bypass -Windowstyle Hidden -File $PSCommandPath"
    }
    $shortcut.Save()
    exit 0
}

# Gather local info to make sure key variables are set (e.g. Architecture)
Write-PSDBootInfo -SleepSec 1 -Message "Running local gather"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run Get-PSDLocalInfo"
Get-PSDLocalInfo
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $deployRoot"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking if there is an in-progress task sequence"

# Check for an in-progress task sequence
Write-PSDBootInfo -SleepSec 1 -Message "Check for an in-progress task sequence"
$tsInProgress = $false
Get-Volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\_SMSTaskSequence\TSEnv.dat"} | % {

    # Found it, save the location
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): In-progress task sequence found at $($_.DriveLetter):\_SMSTaskSequence"
    $tsInProgress = $true
    $tsDrive = $_.DriveLetter

    #Set-PSDDebugPause -Prompt 240

    # Restore the task sequence variables
    $variablesPath = Restore-PSDVariables
    try{
        foreach($i in (Get-ChildItem -Path TSEnv:)){
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property $($i.Name) is $($i.Value)"
        }
    }
    catch{
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to restore variables from $variablesPath."
        Show-PSDInfo -Message "Unable to restore variables from $variablesPath." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        Start-Process PowerShell -Wait
        Exit 1
    }

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Restored variables from $variablesPath."

    # Reconnect to the deployment share
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reconnecting to the deployment share at $($tsenv:DeployRoot)."
    if ($tsenv:UserDomain -ne ""){
        Get-PSDConnection -deployRoot $tsenv:DeployRoot -username "$($tsenv:UserDomain)\$($tsenv:UserID)" -password $tsenv:UserPassword
    }
    else{
        Get-PSDConnection -deployRoot $tsenv:DeployRoot -username $tsenv:UserID -password $tsenv:UserPassword
    }
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): If a task sequence is in progress, resume it. Otherwise, start a new one"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $deployRoot"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"

# If a task sequence is in progress, resume it.  Otherwise, start a new one
[Environment]::CurrentDirectory = "$($env:WINDIR)\System32"
if ($tsInProgress){
    # Find the task sequence engine
    if (Test-Path -Path "X:\Deploy\Tools\$($tsenv:Architecture)\tsmbootstrap.exe"){
        $tsEngine = "X:\Deploy\Tools\$($tsenv:Architecture)"
    }
    else{
        $tsEngine = Get-PSDContent "Tools\$($tsenv:Architecture)"
    }
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Task sequence engine located at $tsEngine."

    # Get full scripts location
    $scripts = Get-PSDContent -Content "Scripts"
    $env:ScriptRoot = $scripts

    # Set the PSModulePath
    $modules = Get-PSDContent -Content "Tools\Modules"
    $env:PSModulePath = $env:PSModulePath + ";$modules"

    # Resume task sequence
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $deployRoot"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"
    Stop-PSDLogging
    Write-PSDBootInfo -SleepSec 1 -Message "Resuming existing task sequence"
    $result = Start-Process -FilePath "$tsEngine\TSMBootstrap.exe" -ArgumentList "/env:SAContinue" -Wait -Passthru
}
else{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No task sequence is in progress."

    # Process bootstrap
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing Bootstrap.ini"
    if ($env:SYSTEMDRIVE -eq "X:"){
        $mappingFile = "X:\Deploy\Tools\Modules\PSDGather\ZTIGather.xml"
        Invoke-PSDRules -FilePath "X:\Deploy\Scripts\Bootstrap.ini" -MappingFile $mappingFile
    }
    else{
        $mappingFile = "$deployRoot\Scripts\ZTIGather.xml"
        Invoke-PSDRules -FilePath "$deployRoot\Control\Bootstrap.ini" -MappingFile $mappingFile
    }

    # Determine the Deployroot
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Determine the Deployroot"

    # Check if we are deploying from media
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Check if we are deploying from media"

    Get-Volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\Deploy\Scripts\Media.tag"} | % {
        # Found it, save the location
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Found Media Tag $($_.DriveLetter):Deploy\Scripts\Media.tag"
        $tsDrive = $_.DriveLetter
	    $tsenv:DeployRoot = $tsDrive + ":\Deploy"
	    $tsenv:ResourceRoot = $tsDrive + ":\Deploy"
	    $tsenv:DeploymentMethod = "MEDIA"

        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): DeploymentMethod is $tsenv:DeploymentMethod, this solution does not currently support deploying from media, sorry, aborting"
        Show-PSDInfo -Message "No deployroot set, this solution does not currently support deploying from media, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        Start-Process PowerShell -Wait
        Break
    }

    #Set-PSDDebugPause -Prompt 337


    switch ($tsenv:DeploymentMethod){
        'MEDIA'{
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): DeploymentMethod is $tsenv:DeploymentMethod, this solution does not currently support deploying from media, sorry, aborting"
            Show-PSDInfo -Message "No deployroot set, this solution does not currently support deploying from media, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
            Start-Process PowerShell -Wait
            Break
        }
        Default{
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): We are deploying from Network, checking IP's,"
            
            # Check Network
            Write-PSDBootInfo -SleepSec 1 -Message "Checking for a valid network configuration"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Invoking DHCP refresh..."    
            $Null = Invoke-PSDexe -Executable ipconfig.exe -Arguments "/renew"

            $NICIPOK = $False

            $ipList = @()
            $ipListv4 = @()
            $macList = @()
            $gwList = @()
            Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1" | % {
                $_.IPAddress | % {$ipList += $_ }
                $_.MacAddress | % {$macList += $_ }
                if ($_.DefaultIPGateway) {
                $_.DefaultIPGateway | % {$gwList += $_ }
                }
            }
            $ipListv4 = $ipList | Where-Object Length -EQ 15
            
            foreach($IPv4 in $ipListv4){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Found IP address $IPv4"
            }

            if (((Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1").Index).count -ge 1){
                $NICIPOK = $True
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): We have at least one network adapter with a IP address, we should be able to continue"
            }
            

            if($NICIPOK -ne $True){
                $Message = "Sorry, it seems that you don't have a valid IP, aborting..."
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $Message"
                Show-PSDInfo -Message "$Message" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
                Start-Process PowerShell -Wait
                break
            }

            # Log if we are running APIPA as warning
            # Log IP, Networkadapter name, if exist GW and DNS
            # Return Network as deployment method, with Yes we have network
        }
    }

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Looking for PSDeployRoots in the usual places..."

    #Set-PSDDebugPause -Prompt 398

    if($tsenv:PSDDeployRoots -ne ""){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PSDeployRoots definition found!"
        $items = $tsenv:PSDDeployRoots.Split(",")
        foreach($item in $items){
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Testing PSDDeployRoots value: $item"
            if ($item -ilike "https://*"){
                $ServerName = $item.Replace("https://","") | Split-Path
                $Result = Test-PSDNetCon -Hostname $ServerName -Protocol HTTPS
                if(($Result) -ne $true){
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to access PSDDeployRoots value $item using HTTP"
                }
                else{
                    $tsenv:DeployRoot = $item
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $tsenv:DeployRoot"
                    Break
                }
            }
            if ($item -ilike "http://*"){
                $ServerName = $item.Replace("http://","") | Split-Path
                $Result = Test-PSDNetCon -Hostname $ServerName -Protocol HTTP
                if(($Result) -ne $true){
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to access PSDDeployRoots value $item using HTTPS"
                }
                else{
                    $tsenv:DeployRoot = $item
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $tsenv:DeployRoot"
                    Break
                }
            }
            if ($item -like "\\*"){
                $ServerName = $item.Split("\\")[2]
                $Result = Test-PSDNetCon -Hostname $ServerName -Protocol SMB
                if(($Result) -ne $true){
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to access $item using SMB"
                }
                else{
                    $tsenv:DeployRoot = $item
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $tsenv:DeployRoot"
                    Break
                }
            }
        }
    }
    else{
        $deployRoot = $tsenv:DeployRoot
    }

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Validating network access to $tsenv:DeployRoot"
    Write-PSDBootInfo -SleepSec 2 -Message "Validating network access to $tsenv:DeployRoot"

    #Set-PSDDebugPause -Prompt 451

    if(!($tsenv:DeployRoot -notlike $null -or "")){
        $Message = "Since we are deploying from network, we should be able to access the deploymentshare, but we can't, please check your network."
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $Message"
        Show-PSDInfo -Message "$Message" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        Start-Process PowerShell -Wait
        Break
    } 
    
    if($NICIPOK -eq $False){
        if ($deployRoot -notlike $null -or ""){
            $Message = "Since we are deploying from network, we should have network access but we don't, check networking"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $Message"
            Show-PSDInfo -Message "$Message" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
            Start-Process PowerShell -Wait
            Break
        }
    }

    # Validate network route to $deployRoot
    if ($deployRoot -notlike $null -or ""){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): New deploy root is $deployRoot."
        if ($deployRoot -ilike "https://*"){
            $ServerName = $deployRoot.Replace("https://","") | Split-Path
            $Result = Test-PSDNetCon -Hostname $ServerName -Protocol HTTPS
            if(($Result) -ne $true){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to access $ServerName"
                Show-PSDInfo -Message "Unable to access $ServerName, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
                Start-Process PowerShell -Wait
                Break
            }
        }

        if ($deployRoot -ilike "http://*"){
            $ServerName = $deployRoot.Replace("http://","") | Split-Path
            $Result = Test-PSDNetCon -Hostname $ServerName -Protocol HTTP
            if(($Result) -ne $true){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to access $ServerName"
                Show-PSDInfo -Message "Unable to access $ServerName, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
                Start-Process PowerShell -Wait
                Break
            }
        }

        if ($deployRoot -like "\\*"){
            $ServerName = $deployRoot.Split("\\")[2]
            $Result = Test-PSDNetCon -Hostname $ServerName -Protocol SMB -ErrorAction SilentlyContinue
            if(($Result) -ne $true){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to access $ServerName"
                Show-PSDInfo -Message "Unable to access $ServerName, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
                Start-Process PowerShell -Wait
                Break
            }
        }
    }
    else{
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is empty, this solution does not currently support deploying from media, sorry, aborting"
        Show-PSDInfo -Message "No deployroot set, this solution does not currently support deploying from media, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        Start-Process PowerShell -Wait
        Break
    }

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): New deploy root is $deployRoot."
    Get-PSDConnection -DeployRoot $tsenv:DeployRoot -Username "$tsenv:UserDomain\$tsenv:UserID" -Password $tsenv:UserPassword

    #Set-PSDDebugPause -Prompt 518

    # Set time on client
    $Time = Get-Date
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Current time on computer is: $Time"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Set time on client"
    If($tsenv:DeploymentMethod -ne "MEDIA"){
        if ($deployRoot -like "\\*"){
            net time \\$ServerName /set /y
        }
        if ($deployRoot -ilike "https://*"){
            $NTPTime = Get-PSDNtpTime
            if($NTPTime -ne $null){
                Set-Date -Date $NTPTime.NtpTime
            }
            else{
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Failed to set time/date" -LogLevel 2
            }
            
        }
        if ($deployRoot -ilike "http://*"){
            $NTPTime = Get-PSDNtpTime -Server Gunk.gunk.gunk
            if($NTPTime -ne $null){
                Set-Date -Date $NTPTime.NtpTime
            }
            else{
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Failed to set time/date" -LogLevel 2
            }
        }
    }

    $Time = Get-Date
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): New time on computer is: $Time"

    # Process CustomSettings.ini
    $control = Get-PSDContent -Content "Control"

    #verify access to "$control\CustomSettings.ini" 
    if((Test-path -Path "$control\CustomSettings.ini") -ne $true){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to access $control\CustomSettings.ini"
        Show-PSDInfo -Message "Unable to access $control\CustomSettings.ini, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        Start-Process PowerShell -Wait
        Break    
    }
    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing CustomSettings.ini"
    Invoke-PSDRules -FilePath "$control\CustomSettings.ini" -MappingFile $mappingFile

    if($tsenv:EventService -notlike $null -or ""){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Eventlogging is enabled"
    }
    else{
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Eventlogging is not enabled"
    }

    # Get full scripts location
    $scripts = Get-PSDContent -Content "Scripts"
    $env:ScriptRoot = $scripts

    # Set the PSModulePath
    $modules = Get-PSDContent -Content "Tools\Modules"
    $env:PSModulePath = $env:PSModulePath + ";$modules"

    #Set-PSDDebugPause -Prompt "Process wizard"

    # Process wizard
    Write-PSDBootInfo -SleepSec 1 -Message "Loading the PSD Deployment Wizard"
    # $tsenv:TaskSequenceID = ""
    if ($tsenv:SkipWizard -ine "YES"){
        $result = Show-PSDWizard "$scripts\PSDWizard.xaml"
        if ($result.DialogResult -eq $false){
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Cancelling, aborting..."
            Show-PSDInfo -Message "Cancelling, aborting..." -Severity Information -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
            Stop-PSDLogging
            Clear-PSDInformation
            Start-Process PowerShell -Wait
            Exit 0
        }
    }

    If ($tsenv:TaskSequenceID -eq ""){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No TaskSequence selected, aborting..."
        Show-PSDInfo -Message "No TaskSequence selected, aborting..." -Severity Information -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        Stop-PSDLogging
        Clear-PSDInformation
        Start-Process PowerShell -Wait
        Exit 0
    }

    if ($tsenv:OSDComputerName -eq "") {
        $tsenv:OSDComputerName = $env:COMPUTERNAME
    }

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Find the task sequence engine"

    # Find the task sequence engine
    if (Test-Path -Path "X:\Deploy\Tools\$($tsenv:Architecture)\tsmbootstrap.exe"){
        $tsEngine = "X:\Deploy\Tools\$($tsenv:Architecture)"
    }
    else{
        $tsEngine = Get-PSDContent "Tools\$($tsenv:Architecture)"
    }
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Task sequence engine located at $tsEngine."

    # Transfer $PSDDeBug to TSEnv: for TS to understand
    If($PSDDeBug -eq $true){
        $tsenv:PSDDebug = "YES"
    }

    # Start task sequence
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): --------------------"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Start the task sequence"

    # Saving Variables
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Saving Variables"
    $variablesPath = Save-PSDVariables
    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy Variables"
    Copy-Item -Path $variablesPath -Destination $tsEngine -Force
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copied $variablesPath to $tsEngine"
    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy ts.xml"
    Copy-Item -Path "$control\$($tsenv:TaskSequenceID)\ts.xml" -Destination $tsEngine -Force
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copied $control\$($tsenv:TaskSequenceID)\ts.xml to $tsEngine"

    #Update TS.XML before using it, changing workbench specific .WSF scripts to PowerShell to avoid issues
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Update ts.xml before using it, changing workbench specific .WSF scripts to PowerShell to avoid issues"

    $TSxml = "$tsEngine\ts.xml"
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIDrivers.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDDrivers.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIGather.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDGather.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIValidate.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDValidate.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIBIOSCheck.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIDiskpart.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDPartition.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIUserState.wsf" /capture','PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1" /capture') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIBackup.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTISetVariable.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDSetVariable.ps1"') | Set-Content -Path $TSxml
    # (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTINextPhase.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDNextPhase.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\LTIApply.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDApplyOS.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIWinRE.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIPatches.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIApplications.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDApplications.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIWindowsUpdate.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDWindowsUpdate.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIBde.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIBDE.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIGroups.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Saving a copy of the updated TS.xml"
    Copy-Item -Path $tsEngine\ts.xml -Destination "$(Get-PSDLocalDataPath)\"

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $deployRoot"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"
    Write-PSDEvent -MessageID 41016 -severity 4 -Message "PSD beginning deployment"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Done in PSDStart for now, handing over to Task Sequence by running $tsEngine\TSMBootstrap.exe /env:SAStart"
    Write-PSDBootInfo -SleepSec 0 -Message "Running Task Sequence"
    Stop-PSDLogging
    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Looking for $tsEngine\TSMBootstrap.exe"
    if((Test-Path -Path "$tsEngine\TSMBootstrap.exe") -ne $true){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to access $tsEngine\TSMBootstrap.exe" -Loglevel 3
        Show-PSDInfo -Message "Unable to access $tsEngine\TSMBootstrap.exe" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
    }
    $result = Start-Process -FilePath "$tsEngine\TSMBootstrap.exe" -ArgumentList "/env:SAStart" -Wait -Passthru
}

# If we are in WinPE and we have deployed an operating system, we should write logfiles to the new drive
if($BootfromWinPE -eq $True){
    # Assuming that the first Volume having mspaint.exe is the correct OS volume
    $Drives = Get-PSDrive | Where-Object {$_.Provider -like "*filesystem*"}
    Foreach ($Drive in $Drives){
        # TODO: Need to find a better file for detection of running OS
        If (Test-Path -Path "$($Drive.Name):\Windows\System32\mspaint.exe"){
            Start-PSDLogging -Logpath "$($Drive.Name):\MININT\SMSOSD\OSDLOGS"

            Break
        }
    }
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): logPath is now $logPath"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Task Sequence is done, PSDStart.ps1 is now in charge.."

# Make sure variables.dat is in the current local directory
if (Test-Path -Path "$(Get-PSDLocalDataPath)\Variables.dat"){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Variables.dat found in the correct location, $(Get-PSDLocalDataPath)\Variables.dat, no need to copy."
}
else{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying Variables.dat to the current location, $(Get-PSDLocalDataPath)\Variables.dat."
    Copy-Item $variablesPath "$(Get-PSDLocalDataPath)\"
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $deployRoot"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"

# Process the exit code from the task sequence
# Start-PSDLogging
#if($result.ExitCode -eq $null){$result.ExitCode = 0}
#Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Return code from TSMBootstrap.exe is $($result.ExitCode)"

Switch ($result.ExitCode){
    0 {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): SUCCESS!"
        Write-PSDEvent -MessageID 41015 -severity 4 -Message "PSD deployment completed successfully."
        
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reset HKLM:\Software\Microsoft\Deployment 4"
        Get-ItemProperty "HKLM:\Software\Microsoft\Deployment 4" | Remove-Item -Force -Recurse

        $Executable = "regsvr32.exe"
        $Arguments = "/u /s $tools\tscore.dll"
        if((Test-Path -Path "$tools\tscore.dll") -eq $true){
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run: $Executable $Arguments"
            $return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Exitcode: $return"
        }

        $Executable = "$Tools\TSProgressUI.exe"
        $Arguments = "/Unregister"
        if((Test-Path -Path "$Tools\TSProgressUI.exe") -eq $true){
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run: $Executable $Arguments"
            $return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Exitcode: $return"
        }

        # TODO Reboot for finishaction
        # Read-Host -Prompt "Check for FinishAction and cleanup leftovers"
        Write-Verbose "tsenv:FinishAction is $tsenv:FinishAction"
        
        if($tsenv:FinishAction -eq "Reboot" -or $tsenv:FinishAction -eq "Restart"){
            $Global:RebootAfterTS = $True
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Will reboot for finishaction"
        }

        # Set-PSDDebugPause -Prompt "Before PSDFinal.ps1"
       
        Stop-PSDLogging

        Copy-Item -Path $env:SystemDrive\MININT\Cache\Scripts\PSDFinal.ps1 -Destination $env:TEMP
        Clear-PSDInformation
                
        #Checking for FinalSummary
        if(!($tsenv:SkipFinalSummary -eq "YES")){
            Show-PSDInfo -Message "OSD SUCCESS!" -Severity Information -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        }

        if($tsenv:PSDPause -eq "YES"){
            Read-Host -Prompt "Exit 0"
        }

        # Read-Host -Prompt "Check for finish action and cleanup leftovers"
        # Check for finish action and cleanup leftovers
        
        if($RebootAfterTS -eq $True){
            Start-Process powershell -ArgumentList "$env:TEMP\PSDFinal.ps1 -Restart $true -ParentPID $PID" -WindowStyle Hidden -Wait
        }
        else{
            Start-Process powershell -ArgumentList "$env:TEMP\PSDFinal.ps1 -Restart $false -ParentPID $PID" -WindowStyle Hidden -Wait
        }

        # Done
        Exit 0
        
    }
    -2147021886 {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): REBOOT!"
        $variablesPath = Restore-PSDVariables

        try{
            foreach($i in (Get-ChildItem -Path TSEnv:)){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property $($i.Name) is $($i.Value)"
            }
        }
        catch{
        }


        if ($env:SYSTEMDRIVE -eq "X:"){
            # We are running in WinPE and need to reboot, if we have a hard disk, then we need files to continute the TS after reboot, copy files...
            # Exit with a zero return code and let Windows PE reboot

            # Assuming that the first Volume having mspaint.exe is the correct OS volume
            $Drives = Get-PSDrive | Where-Object {$_.Provider -like "*filesystem*"}
            Foreach ($Drive in $Drives){
                # TODO: Need to find a better file for detection of running OS
                If (Test-Path -Path "$($Drive.Name):\Windows\System32\mspaint.exe"){
                    #Copy files needed for full OS

                    Write-PSDLog -Message "Copy-Item $scripts\PSDStart.ps1 $($Drive.Name):\MININT\Scripts"
                    Initialize-PSDFolder "$($Drive.Name):\MININT\Scripts"
                    Copy-Item "$scripts\PSDStart.ps1" "$($Drive.Name):\MININT\Scripts"

                    try{
                        $drvcache = "$($Drive.Name):\MININT\Cache"
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy-Item X:\Deploy\Tools -Destination $drvcache"
                        $cres = Copy-Item -Path "X:\Deploy\Tools" -Destination "$drvcache" -Recurse -Force -Verbose -PassThru
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $cres"
                        
                        #simulate download to x:\MININT\Cache\Tools
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy-Item X:\Deploy\Tools -Destination X:\MININT\Cache\Tools"
                        $cres = Copy-Item -Path "X:\Deploy\Tools" -Destination "X:\MININT\Cache" -Recurse -Force -Verbose -PassThru
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $cres"

                        #Copies from x:\MININT\Cache to target drive
                        $Modules = Get-PSDContent "Tools\Modules"
                        Write-PSDLog -Message "Copy-PSDFolder $Modules $($Drive.Name):\MININT\Tools\Modules"
                        Copy-PSDFolder "$Modules" "$($Drive.Name):\MININT\Tools\Modules"
                        
                        #Copies from x:\MININT\Cache\Tools\<arc> to target drive
                        $Tools = Get-PSDContent "Tools\$($tsenv:Architecture)"
                        Write-PSDLog -Message "Copy-PSDFolder $Tools $($Drive.Name):\MININT\Tools\$($tsenv:Architecture)"
                        Copy-PSDFolder "$Tools" "$($Drive.Name):\MININT\Tools\$($tsenv:Architecture)"

                    }
                    catch{
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy failed"
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $_"
                    }

                    Write-PSDLog -Message "Copy-PSDFolder $Certificates $($Drive.Name):\MININT\Certificates"
                    $Certificates = Get-PSDContent "PSDResources\Certificates"
                    Copy-PSDFolder "$Certificates" "$($Drive.Name):\MININT\Certificates"

                    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy items from X:\Deploy\Tools to $($tsenv:OSVolume):\MININT\Cache\Tools"
                    # Copy-PSDFolder -Source X:\Deploy\Tools -Destination "$($tsenv:OSVolume):\MININT\Cache\Tools"
                    # Get-ChildItem -Path "$($tsenv:OSVolume):\MININT\Cache\Tools" -Filter ts.xml -Recurse | Remove-Item -Force
                    # Get-ChildItem -Path "$($tsenv:OSVolume):\MININT\Cache\Tools" -Filter variables.dat -Recurse | Remove-Item -Force

                    if($PSDDeBug -eq $true){
                        New-Item -Path "$($Drive.Name):\MININT\PSDDebug.txt" -ItemType File -Force
                    }

                    #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): We are now on line 775 and we are doing a break on line 776..."
                    #Break
                }
            }

            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Exit with a zero return code and let Windows PE reboot"
            Stop-PSDLogging

            if($tsenv:PSDPause -eq "YES"){
                Read-Host -Prompt "Exit -2147021886 (WinPE)"
            }

            exit 0
        }
        else{
            # In full OS, need to initiate a reboot
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): In full OS, need to initiate a reboot"

            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Saving Variables"
            $variablesPath = Save-PSDVariables

            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Finding out where the tools folder is..."
            $Tools = Get-PSDContent -Content "Tools\$($tsenv:Architecture)"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Tools is now $Tools"
            
            $Executable = "regsvr32.exe"
            $Arguments = "/u /s $tools\tscore.dll"
            if((Test-Path -Path "$tools\tscore.dll") -eq $true){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run: $Executable $Arguments"
                $return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Exitcode: $return"
            }
            if($return -ne 0){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to unload $tools\tscore.dll" -Loglevel 2
            }

            $Executable = "$Tools\TSProgressUI.exe"
            $Arguments = "/Unregister"
            if((Test-Path -Path "$Tools\TSProgressUI.exe") -eq $true){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run: $Executable $Arguments"
                $return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Exitcode: $return"
            }
            if($return -ne 0){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to unload $Tools\TSProgressUI.exe" -Loglevel 2
            }

            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Restart, see you on the other side... (Shutdown.exe /r /t 30 /f)"
            
            if($tsenv:PSDPause -eq "YES"){
                Read-Host -Prompt "Exit -2147021886 (Windows)"
            }
            
            #Restart-Computer -Force
            Shutdown.exe /r /t 30 /f

            Stop-PSDLogging
            exit 0
        }
    }
    default {
        # Exit with a non-zero return code
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Task sequence failed, rc = $($result.ExitCode)"

        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reset HKLM:\Software\Microsoft\Deployment 4"
        Get-ItemProperty "HKLM:\Software\Microsoft\Deployment 4"  -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse

        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reset HKLM:\Software\Microsoft\SMS"
        Get-ItemProperty "HKLM:\Software\Microsoft\SMS" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse

        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Findig out where the tools folder is..."
        $Tools = Get-PSDContent -Content "Tools\$($tsenv:Architecture)"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Tools is now $Tools"

        $Executable = "regsvr32.exe"
        $Arguments = "/u /s $tools\tscore.dll"
        if((Test-Path -Path "$tools\tscore.dll") -eq $true){
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run: $Executable $Arguments"
            $return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Exitcode: $return"
        }

        $Executable = "$Tools\TSProgressUI.exe"
        $Arguments = "/Unregister"
        if((Test-Path -Path "$Tools\TSProgressUI.exe") -eq $true){
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run: $Executable $Arguments"
            $return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Exitcode: $return"
        }

        Clear-PSDInformation
        Stop-PSDLogging

        #Invoke-PSDInfoGather
        Write-PSDEvent -MessageID 41014 -severity 1 -Message "PSD deployment failed, Return Code is $($result.ExitCode)"
        Show-PSDInfo -Message "Task sequence failed, Return Code is $($result.ExitCode)" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot

        exit $result.ExitCode
    }
}
