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
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2022-09-19

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
          version - 0.9.8 - Added support for Windows Core Server
          version - 0.9.9 - Fixed for SMSTSlogging, plus lots of minor stuff
          version - 0.1.0 - Minor change, removing Write-PSDLog entries
          version - 0.1.1 - (PC) Fixed PSDStartLoader and added beta support PSDWizardRS

          TODO:

.Example
#>

param (
    [switch] $start,
    [switch] $Debug
)

$DeploymentToolkitVersion = "2.2.8"
# OSDProgress=Native
# OSDProgress=Modern

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
    $Null = New-Item -Path HKLM:\SOFTWARE\PSD -ItemType Directory -Force
    $Null = New-ItemProperty -Path HKLM:\SOFTWARE\PSD -Name PSDBootInfo -PropertyType MultiString -Value $Message -Force
    & bginfo.exe "$env:SystemRoot\system32\psd.bgi" /timer:0 /NOLICPROMPT /SILENT
    
    if($SleepSec -ne "NA"){
        Start-Sleep -Seconds $SleepSec
    }
}
Function Wait-PSDPrompt{
    Param(
        $prompt,
        $secondsToWait
    )
    Write-Host -NoNewline $prompt
    $secondsCounter = 0
    $subCounter = 0
    While ( (!$host.ui.rawui.KeyAvailable) -and ($count -lt $secondsToWait) ){
        Start-Sleep -Milliseconds 10
        $subCounter = $subCounter + 10
        if($subCounter -eq 1000)
        {
            $secondsCounter++
            $subCounter = 0
            Write-Host -NoNewline "."
        }       
        If ($secondsCounter -eq $secondsToWait) { 
            Write-Host "`r`n"
            return $false;
        }
    }
    Write-Host "`r`n"
    return $true;
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
        $Result = Wait-PSDPrompt -prompt "Press Enter to continue in debug mode, or wait 5 seconds" -secondsToWait 5
        if($Result -eq $True){
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
    Write-Verbose "PowerShell variable PSDDeBug is now = $PSDDeBug"
    Write-Verbose "PowerShell variable verbosePreference is now = $verbosePreference"
    Write-Verbose $env:PSModulePath
    Set-PSDDebugPause -Prompt "PSDebug is active"
}

# Load core modules
Write-PSDBootInfo -SleepSec 1 -Message "Loading core PowerShell modules"
Import-Module PSDUtility -Force -Verbose:$False
Import-Module Storage -Global -Force -Verbose:$False

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PSDVersion $DeploymentToolkitVersion"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Entering initial block..."
Write-PSDDebugLog -Message "$($MyInvocation.MyCommand.Name): Entering initial block...[Debug logging is Enabled]"

# Make sure we run at full power
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Setting power to High performance"
& powercfg.exe /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Check if we booted from WinPE
$Global:BootfromWinPE = $false
if ($env:SYSTEMDRIVE -eq "X:"){
    $Global:BootfromWinPE = $true
}
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable BootfromWinPE is now = $BootfromWinPE"

# Install PSDRoot certificate if exist in WinPE
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Entering certificate block..."
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
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Entering WinPE block..."

    # We need more than 1.5 GB (Testing for at least 1499MB of RAM)
    Write-PSDBootInfo -SleepSec 2 -Message "Checking that we have at least 1.5 GB of RAM"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking that we have at least 1.5 GB of RAM"
    if ((Get-CimInstance -ClassName Win32_computersystem).TotalPhysicalMemory -le 1499MB){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Not enough memory to run PSD, aborting..."
        Show-PSDInfo -Message "Not enough memory to run PSD, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        Start-Process PowerShell -Wait
        exit 1
    }

    # Create SMSTS.ini (TESTING)
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating SMSTS.INI for WinPE"
    function New-PSDSMSTSinifile {
        param(
            $path
        )
        Set-Content -Value "[Logging]" -Path $path -Encoding Ascii
        Add-Content -Value "LOGMAXSIZE=10000000" -Path $path -Encoding Ascii
        Add-Content -Value "LOGMAXHISTORY=1" -Path $path -Encoding Ascii
    }
    New-PSDSMSTSinifile -path X:\Windows\SMSTS.ini
}

# Load more modules
Import-Module PSDDeploymentShare -ErrorAction Stop -Force -Verbose:$False
Import-Module PSDGather -ErrorAction Stop -Force -Verbose:$False

# Gather local info to make sure key variables are set (e.g. Architecture)
Write-PSDBootInfo -SleepSec 1 -Message "Running local gather"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running local gather"
Get-PSDLocalInfo
Set-PSDDebugPause -Prompt "After Get-PSDLocalInfo"

# Check for an in-progress task sequence
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking if there is an in-progress task sequence"
Write-PSDBootInfo -SleepSec 1 -Message "Checking if there is an in-progress task sequence"
$tsInProgress = $false
Get-Volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\_SMSTaskSequence\TSEnv.dat"} | % {

    # Found it, save the location
    if($PSDDeBug -eq $true){Set-PSDDebugPause -Prompt "Existing task sequence found"}
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): In-progress task sequence found at $($_.DriveLetter):\_SMSTaskSequence"
    $tsInProgress = $true
    $tsDrive = $_.DriveLetter

    # Restore the task sequence variables
    $variablesPath = Restore-PSDVariables
    try{
        foreach($i in (Get-ChildItem -Path TSEnv:)){
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property $($i.Name) is now = $($i.Value)"
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

    # Updating SMSTSlogpath
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Setting SMSTSlog path in registry to $($tsDrive + ":\MININT")" 
    $Null = New-Item -Path HKLM:\SOFTWARE\Microsoft\CCM -Force
    $Null = New-Item -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging -Force
    $Null = New-Item -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence  -Force

    $Result = Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence -Name LogDirectory $($tsDrive + ":\MININT") -Force -PassThru
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): - HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence LogDirectory is $($Result.LogDirectory)" 

    $Result = Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence -Name LogEnabled -Type DWord 1 -Force -PassThru
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): - HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence LogEnabled is $($Result.LogEnabled)" 

    $Result = Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence -Name LogLevel -Type DWord 0 -Force -PassThru
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): - HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence LogLevel is $($Result.LogLevel)" 

    $Result = Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence -Name LogMaxHistory -Type DWord 1 -Force -PassThru
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): - HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence LogMaxHistory is $($Result.LogMaxHistory)" 

    $Result = Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence -Name LogMaxSize -Type DWord 10000000 -Force -PassThru
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): - HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence LogMaxSize is $($Result.LogMaxSize)" 
}

# If running from RunOnce, create a startup folder item and then exit
if ($start){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running with the /start switch, need to determine how to re-run PSDStart.ps1 after reboot"
        
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running Get-PSDLocalInfo to determine what we are"
        Get-PSDLocalInfo

        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property HideShell is now = $($tsenv:HideShell)"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property IsServerCoreOS is now = $($tsenv:IsServerCoreOS)"

        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property PSDDirtyOS is now = false"
        $tsenv:PSDDirtyOS = $false

    If(!($tsenv:HideShell -eq "YES" -or $tsenv:IsServerCoreOS -eq "True")){
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
    else{
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Setting RunOnceKey, since we are in ServerCore or Hideshell"

        $RunOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Setting RunOnceKey"
        if($PSDDebug -eq $True){
            $Arguments = "-Noprofile -Executionpolicy Bypass -File $PSCommandPath -Debug -Start"
        }
        else{
            $Arguments = "-Noprofile -Executionpolicy Bypass -Windowstyle Hidden -File $PSCommandPath -Start"
        }
        Set-ItemProperty -Path $RunOnceKey -Name "NextRun" ("C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe $Arguments")
        $Command = (Get-ItemProperty -Path $RunOnceKey -Name "NextRun").NextRun
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $RunOnceKey is now = $Command"
    }
}

# If a task sequence is in progress, resume it.  Otherwise, start a new one
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Looking for a task sequence, if we find one, we will run that"
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
    Write-PSDBootInfo -SleepSec 1 -Message "Resuming existing task sequence"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Done in PSDStart for now, handing over to Task Sequence by running $tsEngine\TSMBootstrap.exe /env:SAContinue"
    Stop-PSDLogging
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

    # Check for WelcomeWizard
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Check if we should run PSDPrestart"
    if($tsenv:SkipBDDWelcome -ne "YES"){
        if($BootfromWinPE -eq $true){
            if((Test-Path -Path X:\Deploy\Scripts\PSDPrestart.ps1) -eq $true){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): We should run PSDPrestart"
                if(($tsenv:PSDPrestartMode -eq $null) -or ($tsenv:PSDPrestartMode -eq "") -or ($tsenv:PSDPrestartMode -eq "Native")){
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PSDPrestart is in Mode: Native"
                    $Mode = "Native"
                }
                else{
                    $Mode = $tsenv:PSDPrestartMode
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PSDPrestart is in Mode: $tsenv:PSDPrestartMode"
                    
                    #check for position variable if set
                    #only supports: VerticalLeft, VerticalRight, HorizontalTop, HorizontalBottom
                    If($tsenv:PSDPrestartPosition){
                        $Position = $tsenv:PSDPrestartPosition
                    }
                    else{
                        $Position = "VerticalRight"
                    }
                }

                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to start X:\Deploy\Scripts\PSDPrestart.ps1 -Mode $Mode"

                switch ($Mode)
                {
                    'FullScreen' {
                        Import-Module PSDStartLoader.psm1 -Global -Force -Verbose:$False
                        ##* BEGIN LOADER
                        $PSDStartLoader = New-PSDStartLoader -LogoImgPath "$deployRoot\scripts\powershell.png" -MenuPosition $Position -FullScreen

                        #wait for UI to loaded on screen
                        Do{
                            Start-Sleep -Milliseconds 300
                        }
                        Until($PSDStartLoader.isLoaded)

                        #start the progress bar scrolling
                        Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Gathering device details..." -Indeterminate

                        $DeviceInfo = Get-PSDLocalInfo -Passthru
                        $primaryinterface = Get-PSDStartLoaderInterfaceDetails

                        Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Populating device details..." -PercentComplete 10
                        #Update UI with device details
                        Set-PSDStartLoaderElement -Runspace $PSDStartLoader -ElementName txtManufacturer -Value $DeviceInfo.Manufacturer
                        Set-PSDStartLoaderElement -Runspace $PSDStartLoader -ElementName txtModel -Value $DeviceInfo.Model
                        Set-PSDStartLoaderElement -Runspace $PSDStartLoader -ElementName txtSerialNumber -Value $DeviceInfo.SerialNumber
                        Set-PSDStartLoaderElement -Runspace $PSDStartLoader -ElementName txtAssetTag -Value $DeviceInfo.assettag

                        Set-PSDStartLoaderElement -Runspace $PSDStartLoader -ElementName txtMac -Value $primaryinterface.MacAddress
                        Set-PSDStartLoaderElement -Runspace $PSDStartLoader -ElementName txtIP -Value $primaryinterface.IPAddress
                        Set-PSDStartLoaderElement -Runspace $PSDStartLoader -ElementName txtSubnet -Value $primaryinterface.SubnetMask
                        Set-PSDStartLoaderElement -Runspace $PSDStartLoader -ElementName txtGateway -Value $primaryinterface.GatewayAddresses
                        Set-PSDStartLoaderElement -Runspace $PSDStartLoader -ElementName txtDHCP -Value $primaryinterface.DhcpServer

                        #update image
                        If($tsenv:PSDLoaderLogo){
                            If(Test-Path $tsenv:PSDLoaderLogo){
                                Set-PSDStartLoaderProperty -Runspace $PSDStartLoader -PropertyName LogoImg -Value $tsenv:PSDLoaderLogo
                            }
                        }
                        #update org
                        If($tsenv:PSDOrgName){
                            Set-PSDStartLoaderProperty -Runspace $PSDStartLoader -PropertyName OrgName -Value $tsenv:PSDOrgName
                        }
                        
                        Update-PSDStartLoaderProgressBar -Status "Providing option to open Prestart menu" -Runspace $PSDStartLoader -PercentComplete 20
                        # $PSDStartLoader = Invoke-PSDStartPrestartButton -Runspace $PSDStartLoader -HideCountdown 10 -wait
                        # $PSDPreStartLoader = New-PSDStartLoaderPrestartMenu -Position $Position -OnTop
                        $PSDPreStartMenu = Invoke-PSDStartPrestartButton -Runspace $PSDStartLoader -HideCountdown 10 -Wait
                        # $PSDPreStartLoader = New-PSDStartLoaderPrestartMenu -Position $Position -OnTop

                        # Hide all non functioning buttons
                        #'btnWipeDisk','btnOpenDisk','btnAddStaticIP' | Set-PSDStartLoaderElement -Runspace $PSDStartLoader -Property Visibility -Value Hidden
                        Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Continuing" -PercentComplete 30
                    }
                    'PrestartMenu' {
                        #load the PSDStartLoader module
                        Import-Module PSDStartLoader.psm1 -Global -Force -Verbose:$False

                        #only initialize the prestart menu (not the loader)
                        $PSDStartLoader = New-PSDStartLoaderPrestartMenu -Position $Position -OnTop

                        # Hide all non functioning buttons
                        #'btnWipeDisk','btnOpenDisk','btnAddStaticIP' | Set-PSDStartLoaderElement -Runspace $PSDStartLoader -Property Visibility -Value Hidden
                    }
                    Default {
                        PowerShell.exe -noprofile -file X:\Deploy\Scripts\PSDPrestart.ps1 -Mode $Mode
                    }
                }
            }
            else{
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): We should run PSDPrestart.ps1, but it could not be found, skipping"
            }
        }
    }
    else{
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): We should not run PSDPrestart.ps1, skipping"
    }

    # Set-PSDDebugPause -Prompt "Before checking for media deployment"

    # Check if we are deploying from media
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Check if we are deploying from media"

    Get-Volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):Deploy\Scripts\Media.tag"} | % {
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

    # Determine the deployment method
    switch ($tsenv:DeploymentMethod){
        'MEDIA'{
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): DeploymentMethod is $tsenv:DeploymentMethod, this solution does not currently support deploying from media, sorry, aborting"
            Show-PSDInfo -Message "No deployroot set, this solution does not currently support deploying from media, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
            Start-Process PowerShell -Wait
            Break
        }
        Default{
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): We are deploying from Network, checking IP's,"
            
            # Check Network
            Write-PSDBootInfo -SleepSec 1 -Message "Checking for a valid network configuration"
            if($tsenv:PSDPrestartMode -eq "FullScreen"){
                Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Checking for a valid network configuration..." -PercentComplete 40
            }
            
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Invoking DHCP refresh..."    
            $Null = Invoke-PSDexe -Executable ipconfig.exe -Arguments "/renew"

            $NICIPOK = $False

            $ipList = @()
            $ipListv4 = @()
            $macList = @()
            $gwList = @()
            Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1" | % {
                $_.IPAddress | % {$ipList += $_ }
                $_.MacAddress | % {$macList += $_ }
                if ($_.DefaultIPGateway) {
                $_.DefaultIPGateway | % {$gwList += $_ }
                }
            }
            $ipListv4 = $ipList | Where-Object { $_.Length -EQ 15 }
            
            foreach($IPv4 in $ipListv4){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Found IP address $IPv4"
            }

            if (((Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1").Index).count -ge 1){
                $NICIPOK = $True
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): We have at least one network adapter with an IP address, continuing..."
            }
            

            if($NICIPOK -ne $True){
                $Message = "Sorry, it seems that you don't have a valid IP, aborting..."
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $Message"
                Show-PSDInfo -Message "$Message" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
                Start-Process PowerShell -Wait
                break
            }

            # TBA
            # Log if we are running APIPA as warning
            # Log IP, Networkadapter name, if exist GW and DNS
            # Return Network as deployment method, with Yes we have network
        }
    }

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Looking for PSDeployRoots in the usual places..."
    if($tsenv:PSDPrestartMode -eq "FullScreen"){Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Looking for PSDeployRoots in the usual places..." -PercentComplete 50}
    if($tsenv:PSDDeployRoots -ne ""){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property PSDeployRoots exists."
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
                    Break
                }
            }
        }
    }
    else{
        $deployRoot = $tsenv:DeployRoot
    }

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Validating network access to $tsenv:DeployRoot"
    Write-PSDBootInfo -SleepSec 2 -Message "Validating network access to $tsenv:DeployRoot"
    if($tsenv:PSDPrestartMode -eq "FullScreen"){Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Validating network access to $tsenv:DeployRoot" -PercentComplete 60}

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
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is empty, this solution does not currently support deploying from media, aborting"
        Show-PSDInfo -Message "No deployroot set, this solution does not currently support deploying from media, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        Start-Process PowerShell -Wait
        Break
    }

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): New deploy root is $deployRoot."
    if($tsenv:PSDPrestartMode -eq "FullScreen"){Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "New deploy root is $deployRoot." -PercentComplete 70}
    Get-PSDConnection -DeployRoot $tsenv:DeployRoot -Username "$tsenv:UserDomain\$tsenv:UserID" -Password $tsenv:UserPassword

    # Set time on client
    $Time = Get-Date
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Current time on computer is: $Time"
    if($tsenv:PSDPrestartMode -eq "FullScreen"){Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Current time on computer is: $Time" -PercentComplete 80}
    If($tsenv:DeploymentMethod -ne "MEDIA"){
        if ($deployRoot -like "\\*"){
            $Null = & net time \\$ServerName /set /y
        }
        if ($deployRoot -ilike "https://*"){
            $NTPTime = Get-PSDNtpTime -Server time.windows.com
            if($null -ne $NTPTime){
                Set-Date -Date $NTPTime.NtpTime
            }
            else{
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Failed to set time/date" -LogLevel 2
            }
            
        }
        if ($deployRoot -ilike "http://*"){
            $NTPTime = Get-PSDNtpTime -Server time.windows.com
            if($null -ne $NTPTime){
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
    if($tsenv:PSDPrestartMode -eq "FullScreen"){Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Processing CustomSettings.ini" -PercentComplete 90}
    Invoke-PSDRules -FilePath "$control\CustomSettings.ini" -MappingFile $mappingFile

    # Get full scripts location
    $scripts = Get-PSDContent -Content "Scripts"
    $env:ScriptRoot = $scripts

    # Set the PSModulePath
    $modules = Get-PSDContent -Content "Tools\Modules"
    $env:PSModulePath = $env:PSModulePath + ";$modules"

    # Process wizard
    # Check if we should run the native wizard or not
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Determine which PSDWizard to use"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property PSDWizard is now = $tsenv:PSDWizard"
    if(($tsenv:PSDWizard -eq $null) -or ($tsenv:PSDWizard -eq "") -or ($tsenv:PSDWizard -eq "Native")){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running the command Import-Module PSDWizard -ErrorAction Stop -Force -Verbose:`$False"
        Import-Module PSDWizard -ErrorAction Stop -Force -Verbose:$False

        Write-PSDBootInfo -SleepSec 1 -Message "Loading the PSD Deployment Wizard"
        if($tsenv:PSDPrestartMode -eq "FullScreen"){Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Loading the PSD Deployment Wizard" -PercentComplete 100}
        # $tsenv:TaskSequenceID = ""
        if ($tsenv:SkipWizard -ine "YES"){
        
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property PSDDirty is now = true"
            $tsenv:PSDDirty = $true
        
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

        # Translate PSDRole to TSENV:Role001
        switch ($tsenv:PSDROLE){
            'Configuration 001' {$tsenv:ROLE001 = "Config001"}
            'Configuration 002' {$tsenv:ROLE001 = "Config002"}
            'Configuration 003' {$tsenv:ROLE001 = "Config003"}
            'Configuration 004' {$tsenv:ROLE001 = "Config004"}
            'Configuration 005' {$tsenv:ROLE001 = "Config005"}
            'Configuration 006' {$tsenv:ROLE001 = "Config006"}
            'Configuration 007' {$tsenv:ROLE001 = "Config007"}
            'Configuration 008' {$tsenv:ROLE001 = "Config008"}
            'Configuration 009' {$tsenv:ROLE001 = "Config009"}
            Default {}
        }

        # Translate PSDTIMEZONENAME to TSENV:TimeZoneName
        switch ($tsenv:PSDTIMEZONENAME){
            '(UTC) Casablanca' {$tsenv:TimeZoneName = "Morocco Standard Time"}
            '(UTC) Coordinated Universal Time' {$tsenv:TimeZoneName = "Coordinated Universal Time"}
            '(UTC) Dublin, Edinburgh, Lisbon, London' {$tsenv:TimeZoneName = "GMT Standard Time"}
            '(UTC) Monrovia, Reykjavik' {$tsenv:TimeZoneName = "Greenwich Standard Time"}
            '(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna' {$tsenv:TimeZoneName = "W. Europe Standard Time"}
            '(UTC+01:00) Belgrade, Bratislava, Budapest, Ljubljana, Prague' {$tsenv:TimeZoneName = "Central Europe Standard Time"}
            '(UTC+01:00) Brussels, Copenhagen, Madrid, Paris' {$tsenv:TimeZoneName = "Romance Standard Time"}
            '(UTC+01:00) Sarajevo, Skopje, Warsaw, Zagreb' {$tsenv:TimeZoneName = "Central European Standard Time"}
            '(UTC+01:00) West Central Africa' {$tsenv:TimeZoneName = "W. Central Africa Standard Time"}
            '(UTC+01:00) Windhoek' {$tsenv:TimeZoneName = "Namibia Standard Time"}
            '(UTC+02:00) Amman' {$tsenv:TimeZoneName = "Jordan Standard Time"}
            '(UTC+02:00) Athens, Bucharest' {$tsenv:TimeZoneName = "GTB Standard Time"}
            '(UTC+02:00) Beirut' {$tsenv:TimeZoneName = "Middle East Standard Time"}
            '(UTC+02:00) Cairo' {$tsenv:TimeZoneName = "Egypt Standard Time"}
            '(UTC+02:00) Damascus' {$tsenv:TimeZoneName = "Syria Standard Time"}
            '(UTC+02:00) E. Europe' {$tsenv:TimeZoneName = "E. Europe Standard Time"}
            '(UTC+02:00) Harare, Pretoria' {$tsenv:TimeZoneName = "South Africa Standard Time"}
            '(UTC+02:00) Helsinki, Kyiv, Riga, Sofia, Tallinn, Vilnius' {$tsenv:TimeZoneName = "FLE Standard Time"}
            '(UTC+02:00) Istanbul' {$tsenv:TimeZoneName = "Turkey Standard Time"}
            '(UTC+02:00) Jerusalem' {$tsenv:TimeZoneName = "Jerusalem Standard Time"}
            '(UTC+02:00) Kaliningrad (RTZ 1)' {$tsenv:TimeZoneName = "Russia TZ 1 Standard Time"}
            '(UTC+02:00) Tripoli' {$tsenv:TimeZoneName = "Libya Standard Time"}
            '(UTC+03:00) Baghdad' {$tsenv:TimeZoneName = "Arabic Standard Time"}
            '(UTC+03:00) Kuwait, Riyadh' {$tsenv:TimeZoneName = "Arab Standard Time"}
            '(UTC+03:00) Minsk' {$tsenv:TimeZoneName = "Belarus Standard Time"}
            '(UTC+03:00) Moscow, St. Petersburg, Volgograd (RTZ 2)' {$tsenv:TimeZoneName = "Russia TZ 2 Standard Time"}
            '(UTC+03:00) Nairobi' {$tsenv:TimeZoneName = "E. Africa Standard Time"}
            '(UTC+03:30) Tehran' {$tsenv:TimeZoneName = "Iran Standard Time"}
            '(UTC+04:00) Abu Dhabi, Muscat' {$tsenv:TimeZoneName = "Arabian Standard Time"}
            '(UTC+04:00) Baku' {$tsenv:TimeZoneName = "Azerbaijan Standard Time"}
            '(UTC+04:00) Izhevsk, Samara (RTZ 3)' {$tsenv:TimeZoneName = "Russia TZ 3 Standard Time"}
            '(UTC+04:00) Port Louis' {$tsenv:TimeZoneName = "Mauritius Standard Time"}
            '(UTC+04:00) Tbilisi' {$tsenv:TimeZoneName = "Georgian Standard Time"}
            '(UTC+04:00) Yerevan' {$tsenv:TimeZoneName = "Caucasus Standard Time"}
            '(UTC+04:30) Kabul' {$tsenv:TimeZoneName = "Afghanistan Standard Time"}
            '(UTC+05:00) Ashgabat, Tashkent' {$tsenv:TimeZoneName = "West Asia Standard Time"}
            '(UTC+05:00) Ekaterinburg (RTZ 4)' {$tsenv:TimeZoneName = "Russia TZ 4 Standard Time"}
            '(UTC+05:00) Islamabad, Karachi' {$tsenv:TimeZoneName = "Pakistan Standard Time"}
            '(UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi' {$tsenv:TimeZoneName = "India Standard Time"}
            '(UTC+05:30) Sri Jayawardenepura' {$tsenv:TimeZoneName = "Sri Lanka Standard Time"}
            '(UTC+05:45) Kathmandu' {$tsenv:TimeZoneName = "Nepal Standard Time"}
            '(UTC+06:00) Astana' {$tsenv:TimeZoneName = "Central Asia Standard Time"}
            '(UTC+06:00) Dhaka' {$tsenv:TimeZoneName = "Bangladesh Standard Time"}
            '(UTC+06:00) Novosibirsk (RTZ 5)' {$tsenv:TimeZoneName = "Russia TZ 5 Standard Time"}
            '(UTC+06:30) Yangon (Rangoon)' {$tsenv:TimeZoneName = "Myanmar Standard Time"}
            '(UTC+07:00) Bangkok, Hanoi, Jakarta' {$tsenv:TimeZoneName = "SE Asia Standard Time"}
            '(UTC+07:00) Krasnoyarsk (RTZ 6)' {$tsenv:TimeZoneName = "Russia TZ 6 Standard Time"}
            '(UTC+08:00) Beijing, Chongqing, Hong Kong, Urumqi' {$tsenv:TimeZoneName = "China Standard Time"}
            '(UTC+08:00) Irkutsk (RTZ 7)' {$tsenv:TimeZoneName = "Russia TZ 7 Standard Time"}
            '(UTC+08:00) Kuala Lumpur, Singapore' {$tsenv:TimeZoneName = "Malay Peninsula Standard Time"}
            '(UTC+08:00) Perth' {$tsenv:TimeZoneName = "W. Australia Standard Time"}
            '(UTC+08:00) Taipei' {$tsenv:TimeZoneName = "Taipei Standard Time"}
            '(UTC+08:00) Ulaanbaatar' {$tsenv:TimeZoneName = "Ulaanbaatar Standard Time"}
            '(UTC+09:00) Osaka, Sapporo, Tokyo' {$tsenv:TimeZoneName = "Tokyo Standard Time"}
            '(UTC+09:00) Seoul' {$tsenv:TimeZoneName = "Korea Standard Time"}
            '(UTC+09:00) Yakutsk (RTZ 8)' {$tsenv:TimeZoneName = "Russia TZ 8 Standard Time"}
            '(UTC+09:30) Adelaide' {$tsenv:TimeZoneName = "Cen. Australia Standard Time"}
            '(UTC+09:30) Darwin' {$tsenv:TimeZoneName = "AUS Central Standard Time"}
            '(UTC+10:00) Brisbane' {$tsenv:TimeZoneName = "E. Australia Standard Time"}
            '(UTC+10:00) Canberra, Melbourne, Sydney' {$tsenv:TimeZoneName = "AUS Eastern Standard Time"}
            '(UTC+10:00) Guam, Port Moresby' {$tsenv:TimeZoneName = "West Pacific Standard Time"}
            '(UTC+10:00) Hobart' {$tsenv:TimeZoneName = "Tasmania Standard Time"}
            '(UTC+10:00) Magadan' {$tsenv:TimeZoneName = "Magadan Standard Time"}
            '(UTC+10:00) Vladivostok, Magadan (RTZ 9)' {$tsenv:TimeZoneName = "Russia TZ 9 Standard Time"}
            '(UTC+11:00) Chokurdakh (RTZ 10)' {$tsenv:TimeZoneName = "Russia TZ 10 Standard Time"}
            '(UTC+11:00) Solomon Is., New Caledonia' {$tsenv:TimeZoneName = "Central Pacific Standard Time"}
            '(UTC+12:00) Anadyr, Petropavlovsk-Kamchatsky (RTZ 11)' {$tsenv:TimeZoneName = "Russia TZ 11 Standard Time"}
            '(UTC+12:00) Auckland, Wellington' {$tsenv:TimeZoneName = "New Zealand Standard Time"}
            '(UTC+12:00) Coordinated Universal Time+12' {$tsenv:TimeZoneName = "UTC+12"}
            '(UTC+12:00) Fiji' {$tsenv:TimeZoneName = "Fiji Standard Time"}
            '(UTC+12:00) Petropavlovsk-Kamchatsky - Old' {$tsenv:TimeZoneName = "Kamchatka Standard Time"}
            '(UTC+13:00) Nuku alofa' {$tsenv:TimeZoneName = "Tonga Standard Time"}
            '(UTC+13:00) Samoa' {$tsenv:TimeZoneName = "Samoa Standard Time"}
            '(UTC+14:00) Kiritimati Island' {$tsenv:TimeZoneName = "Line Islands Standard Time"}
            '(UTC-12:00) International Date Line West' {$tsenv:TimeZoneName = "Dateline Standard Time"}
            '(UTC-11:00) Coordinated Universal Time-11' {$tsenv:TimeZoneName = "UTC-11"}
            '(UTC-10:00) Hawaii' {$tsenv:TimeZoneName = "Hawaiian Standard Time"}
            '(UTC-09:00) Alaska' {$tsenv:TimeZoneName = "Alaskan Standard Time"}
            '(UTC-08:00) Baja California' {$tsenv:TimeZoneName = "Pacific Standard Time (Mexico)"}
            '(UTC-08:00) Pacific Time (US + Canada)' {$tsenv:TimeZoneName = "Pacific Standard Time"}
            '(UTC-07:00) Arizona' {$tsenv:TimeZoneName = "US Mountain Standard Time"}
            '(UTC-07:00) Chihuahua, La Paz, Mazatlan' {$tsenv:TimeZoneName = "Mountain Standard Time (Mexico)"}
            '(UTC-07:00) Mountain Time (US + Canada)' {$tsenv:TimeZoneName = "Mountain Standard Time"}
            '(UTC-06:00) Central America' {$tsenv:TimeZoneName = "Central America Standard Time"}
            '(UTC-06:00) Central Time (US + Canada)' {$tsenv:TimeZoneName = "Central Standard Time"}
            '(UTC-06:00) Guadalajara, Mexico City, Monterrey' {$tsenv:TimeZoneName = "Central Standard Time (Mexico)"}
            '(UTC-06:00) Saskatchewan' {$tsenv:TimeZoneName = "Canada Central Standard Time"}
            '(UTC-05:00) Bogota, Lima, Quito, Rio Branco' {$tsenv:TimeZoneName = "SA Pacific Standard Time"}
            '(UTC-05:00) Chetumal' {$tsenv:TimeZoneName = "Eastern Standard Time (Mexico)"}
            '(UTC-05:00) Eastern Time (US + Canada)' {$tsenv:TimeZoneName = "Eastern Standard Time"}
            '(UTC-05:00) Indiana (East)' {$tsenv:TimeZoneName = "US Eastern Standard Time"}
            '(UTC-04:30) Caracas' {$tsenv:TimeZoneName = "Venezuela Standard Time"}
            '(UTC-04:00) Asuncion' {$tsenv:TimeZoneName = "Paraguay Standard Time"}
            '(UTC-04:00) Atlantic Time (Canada)' {$tsenv:TimeZoneName = "Atlantic Standard Time"}
            '(UTC-04:00) Cuiaba' {$tsenv:TimeZoneName = "Central Brazilian Standard Time"}
            '(UTC-04:00) Georgetown, La Paz, Manaus, San Juan' {$tsenv:TimeZoneName = "SA Western Standard Time"}
            '(UTC-03:30) Newfoundland' {$tsenv:TimeZoneName = "Newfoundland Standard Time"}
            '(UTC-03:00) Brasilia' {$tsenv:TimeZoneName = "E. South America Standard Time"}
            '(UTC-03:00) Cayenne, Fortaleza' {$tsenv:TimeZoneName = "SA Eastern Standard Time"}
            '(UTC-03:00) City of Buenos Aires' {$tsenv:TimeZoneName = "Argentina Standard Time"}
            '(UTC-03:00) Greenland' {$tsenv:TimeZoneName = "Greenland Standard Time"}
            '(UTC-03:00) Montevideo' {$tsenv:TimeZoneName = "Montevideo Standard Time"}
            '(UTC-03:00) Salvador' {$tsenv:TimeZoneName = "Bahia Standard Time"}
            '(UTC-03:00) Santiago' {$tsenv:TimeZoneName = "Pacific SA Standard Time"}
            '(UTC-02:00) Coordinated Universal Time-02' {$tsenv:TimeZoneName = "UTC-02"}
            '(UTC-02:00) Mid-Atlantic - Old' {$tsenv:TimeZoneName = "Mid-Atlantic Standard Time"}
            '(UTC-01:00) Azores' {$tsenv:TimeZoneName = "Azores Standard Time"}
            '(UTC-01:00) Cabo Verde Is.' {$tsenv:TimeZoneName = "Cabo Verde Standard Time"}
            Default {}
        }

        # Translate PSDLanguage to TSENV:UILanguage
        switch ($tsenv:PSDLanguage)
        {
            'Arabic (Saudi Arabia)'{$TSENV:UILanguage = "ar-SA"}
            'Bulgarian (Bulgaria)'{$tsenv:UILanguage = "bg-BG"}
            'Chinese (PRC)'{$tsenv:UILanguage = "zh-CN"}
            'Chinese (Taiwan)'{$tsenv:UILanguage = "zh-TW"}
            'Croatian (Croatia)'{$tsenv:UILanguage = "hr-HR"}
            'Czech (Czech Republic)'{$tsenv:UILanguage = "cs-CZ"}
            'Danish (Denmark)'{$tsenv:UILanguage = "da-DK"}
            'Dutch (Netherlands)'{$tsenv:UILanguage = "nl-NL"}
            'English (United States)'{$tsenv:UILanguage = "en-US"}
            'English (United Kingdom)'{$tsenv:UILanguage = "en-GB"}
            'Estonian (Estonia)'{$tsenv:UILanguage = "et-EE"}
            'Finnish (Finland)'{$tsenv:UILanguage = "fi-FI"}
            'French (Canada)'{$tsenv:UILanguage = "fr-CA"}
            'French (France)'{$tsenv:UILanguage = "fr-FR"}
            'German (Germany)'{$tsenv:UILanguage = "de-DE"}
            'Greek (Greece)'{$tsenv:UILanguage = "el-GR"}
            'Hebrew (Israel)'{$tsenv:UILanguage = "he-IL"}
            'Hungarian (Hungary)'{$tsenv:UILanguage = "hu-HU"}
            'Italian (Italy)'{$tsenv:UILanguage = "it-IT"}
            'Japanese (Japan)'{$tsenv:UILanguage = "ja-JP"}
            'Korean (Korea)'{$tsenv:UILanguage = "ko-KR"}
            'Latvian (Latvia)'{$tsenv:UILanguage = "lv-LV"}
            'Lithuanian (Lithuania)'{$tsenv:UILanguage = "lt-LT"}
            'Norwegian, Bokm�l (Norway)'{$tsenv:UILanguage = "nb-NO"}
            'Polish (Poland)'{$tsenv:UILanguage = "pl-PL"}
            'Portuguese (Brazil)'{$tsenv:UILanguage = "pt-BR"}
            'Portuguese (Portugal)'{$tsenv:UILanguage = "pt-PT"}
            'Romanian (Romania)'{$tsenv:UILanguage = "ro-RO"}
            'Russian (Russia)'{$tsenv:UILanguage = "ru-RU"}
            'Serbian (Latin, Serbia)'{$tsenv:UILanguage = "sr-Latn-RS"}
            'Slovak (Slovakia)'{$tsenv:UILanguage = "sk-SK"}
            'Slovenian (Slovenia)'{$tsenv:UILanguage = "sl-SI"}
            'Spanish (Mexico)'{$tsenv:UILanguage = "es-MX"}
            'Spanish (Spain)'{$tsenv:UILanguage = "es-ES"}
            'Swedish (Sweden)'{$tsenv:UILanguage = "sv-SE"}
            'Thai (Thailand)'{$tsenv:UILanguage = "th-TH"}
            'Turkish (Turkey)'{$tsenv:UILanguage = "tr-TR"}
            'Ukrainian (Ukraine)'{$tsenv:UILanguage = "uk-UA"}
            Default {}
        }

        # Translate PSDLocale to TSENV:SystemLocale and TSENV:UserLocale
        switch ($tsenv:PSDLocale)
        {
            'Arabic (Saudi Arabia)'{
                $TSENV:SystemLocale = "ar-SA"
                $TSENV:UserLocale = "ar-SA"
            }
            'Bulgarian (Bulgaria)'{
                $TSENV:SystemLocale = "bg-BG"
                $TSENV:UserLocale = "bg-BG"
            }
            'Chinese (PRC)'{
                $TSENV:SystemLocale = "zh-CN"
                $TSENV:UserLocale = "zh-CN"
            }
            'Chinese (Taiwan)'{
                $TSENV:SystemLocale = "zh-TW"
                $TSENV:UserLocale = "zh-TW"
            }
            'Croatian (Croatia)'{
                $TSENV:SystemLocale = "hr-HR"
                $TSENV:UserLocale = "hr-HR"
            }
            'Czech (Czech Republic)'{
                $TSENV:SystemLocale = "cs-CZ"
                $TSENV:UserLocale = "cs-CZ"
            }
            'Danish (Denmark)'{
                $TSENV:SystemLocale = "da-DK"
                $TSENV:UserLocale = "da-DK"
            }
            'Dutch (Netherlands)'{
                $TSENV:SystemLocale = "nl-NL"
                $TSENV:UserLocale = "nl-NL"
            }
            'English (United States)'{
                $TSENV:SystemLocale = "en-US"
                $TSENV:UserLocale = "en-US"
            }
            'English (United Kingdom)'{
                $TSENV:SystemLocale = "en-GB"
                $TSENV:UserLocale = "en-GB"
            }
            'Estonian (Estonia)'{
                $TSENV:SystemLocale = "et-EE"
                $TSENV:UserLocale = "et-EE"
            }
            'Finnish (Finland)'{
                $TSENV:SystemLocale = "fi-FI"
                $TSENV:UserLocale = "fi-FI"
            }
            'French (Canada)'{
                $TSENV:SystemLocale = "fr-CA"
                $TSENV:UserLocale = "fr-CA"
            }
            'French (France)'{
                $TSENV:SystemLocale = "fr-FR"
                $TSENV:UserLocale = "fr-FR"
            }
            'German (Germany)'{
                $TSENV:SystemLocale = "de-DE"
                $TSENV:UserLocale = "de-DE"
            }
            'Greek (Greece)'{
                $TSENV:SystemLocale = "el-GR"
                $TSENV:UserLocale = "el-GR"
            }
            'Hebrew (Israel)'{
                $TSENV:SystemLocale = "he-IL"
                $TSENV:UserLocale = "he-IL"
            }
            'Hungarian (Hungary)'{
                $TSENV:SystemLocale = "hu-HU"
                $TSENV:UserLocale = "hu-HU"
            }
            'Italian (Italy)'{
                $TSENV:SystemLocale = "it-IT"
                $TSENV:UserLocale = "it-IT"
            }
            'Japanese (Japan)'{
                $TSENV:SystemLocale = "ja-JP"
                $TSENV:UserLocale = "ja-JP"
            }
            'Korean (Korea)'{
                $TSENV:SystemLocale = "ko-KR"
                $TSENV:UserLocale = "ko-KR"
            }
            'Latvian (Latvia)'{
                $TSENV:SystemLocale = "lv-LV"
                $TSENV:UserLocale = "lv-LV"
            }
            'Lithuanian (Lithuania)'{
                $TSENV:SystemLocale = "lt-LT"
                $TSENV:UserLocale = "lt-LT"
            }
            'Norwegian, Bokm�l (Norway)'{
                $TSENV:SystemLocale = "nb-NO"
                $TSENV:UserLocale = "nb-NO"
            }
            'Polish (Poland)'{
                $TSENV:SystemLocale = "pl-PL"
                $TSENV:UserLocale = "pl-PL"
            }
            'Portuguese (Brazil)'{
                $TSENV:SystemLocale = "pt-BR"
                $TSENV:UserLocale = "pt-BR"
            }
            'Portuguese (Portugal)'{
                $TSENV:SystemLocale = "pt-PT"
                $TSENV:UserLocale = "pt-PT"
            }
            'Romanian (Romania)'{
                $TSENV:SystemLocale = "ro-RO"
                $TSENV:UserLocale = "ro-RO"
            }
            'Russian (Russia)'{
                $TSENV:SystemLocale = "ru-RU"
                $TSENV:UserLocale = "ru-RU"
            }
            'Serbian (Latin, Serbia)'{
                $TSENV:SystemLocale = "sr-Latn-RS"
                $TSENV:UserLocale = "sr-Latn-RS"
            }
            'Slovak (Slovakia)'{
                $TSENV:SystemLocale = "sk-SK"
                $TSENV:UserLocale = "sk-SK"
            }
            'Slovenian (Slovenia)'{
                $TSENV:SystemLocale = "sl-SI"
                $TSENV:UserLocale = "sl-SI"
            }
            'Spanish (Mexico)'{
                $TSENV:SystemLocale = "es-MX"
                $TSENV:UserLocale = "es-MX"
            }
            'Spanish (Spain)'{
                $TSENV:SystemLocale = "es-ES"
                $TSENV:UserLocale = "es-ES"
            }
            'Swedish (Sweden)'{
                $TSENV:SystemLocale = "sv-SE"
                $TSENV:UserLocale = "sv-SE"
            }
            'Thai (Thailand)'{
                $TSENV:SystemLocale = "th-TH"
                $TSENV:UserLocale = "th-TH"
            }
            'Turkish (Turkey)'{
                $TSENV:SystemLocale = "tr-TR"
                $TSENV:UserLocale = "tr-TR"
            }
            'Ukrainian (Ukraine)'{
                $TSENV:SystemLocale = "uk-UA"
                $TSENV:UserLocale = "uk-UA"
            }
            Default {}
        }

        # Translate PSDKeyboard to TSENV:InputLocale
        switch ($tsenv:PSDKeyboard)
        {
            'Arabic (Saudi Arabia)'{
                $TSENV:InputLocale = "ar-SA"
                $TSENV:KeyboardLocale = "ar-SA"
            }
            'Bulgarian (Bulgaria)'{
                $tsenv:InputLocale = "bg-BG"
                $tsenv:KeyboardLocale = "bg-BG"
            }
            'Chinese (PRC)'{
                $tsenv:InputLocale = "zh-CN"
                $tsenv:KeyboardLocale = "zh-CN"
            }
            'Chinese (Taiwan)'{
                $tsenv:InputLocale = "zh-TW"
                $tsenv:KeyboardLocale = "zh-TW"
            }
            'Croatian (Croatia)'{
                $tsenv:InputLocale = "hr-HR"
                $tsenv:KeyboardLocale = "hr-HR"
            }
            'Czech (Czech Republic)'{
                $tsenv:InputLocale = "cs-CZ"
                $tsenv:KeyboardLocale = "cs-CZ"
            }
            'Danish (Denmark)'{
                $tsenv:InputLocale = "da-DK"
                $tsenv:KeyboardLocale = "da-DK"
            }
            'Dutch (Netherlands)'{
                $tsenv:InputLocale = "nl-NL"
                $tsenv:KeyboardLocale = "nl-NL"
            }
            'English (United States)'{
                $tsenv:InputLocale = "en-US"
                $tsenv:KeyboardLocale = "en-US"
            }
            'English (United Kingdom)'{
                $tsenv:InputLocale = "en-GB"
                $tsenv:KeyboardLocale = "en-GB"
            }
            'Estonian (Estonia)'{
                $tsenv:InputLocale = "et-EE"
                $tsenv:KeyboardLocale = "et-EE"
            }
            'Finnish (Finland)'{
                $tsenv:InputLocale = "fi-FI"
                $tsenv:KeyboardLocale = "fi-FI"
            }
            'French (Canada)'{
                $tsenv:InputLocale = "fr-CA"
                $tsenv:KeyboardLocale = "fr-CA"
            }
            'French (France)'{
                $tsenv:InputLocale = "fr-FR"
                $tsenv:KeyboardLocale = "fr-FR"
            }
            'German (Germany)'{
                $tsenv:InputLocale = "de-DE"
                $tsenv:KeyboardLocale = "de-DE"
            }
            'Greek (Greece)'{
                $tsenv:InputLocale = "el-GR"
                $tsenv:KeyboardLocale = "el-GR"
            }
            'Hebrew (Israel)'{
                $tsenv:InputLocale = "he-IL"
                $tsenv:KeyboardLocale = "he-IL"
            }
            'Hungarian (Hungary)'{
                $tsenv:InputLocale = "hu-HU"
                $tsenv:KeyboardLocale = "hu-HU"
            }
            'Italian (Italy)'{
                $tsenv:InputLocale = "it-IT"
                $tsenv:KeyboardLocale = "it-IT"
            }
            'Japanese (Japan)'{
                $tsenv:InputLocale = "ja-JP"
                $tsenv:KeyboardLocale = "ja-JP"
            }
            'Korean (Korea)'{
                $tsenv:InputLocale = "ko-KR"
                $tsenv:KeyboardLocale = "ko-KR"
            }
            'Latvian (Latvia)'{
                $tsenv:InputLocale = "lv-LV"
                $tsenv:KeyboardLocale = "lv-LV"
            }
            'Lithuanian (Lithuania)'{
                $tsenv:InputLocale = "lt-LT"
                $tsenv:KeyboardLocale = "lt-LT"
            }
            'Norwegian, Bokm�l (Norway)'{
                $tsenv:InputLocale = "nb-NO"
                $tsenv:KeyboardLocale = "nb-NO"
            }
            'Polish (Poland)'{
                $tsenv:InputLocale = "pl-PL"
                $tsenv:KeyboardLocale = "pl-PL"
            }
            'Portuguese (Brazil)'{
                $tsenv:InputLocale = "pt-BR"
                $tsenv:KeyboardLocale = "pt-BR"
            }
            'Portuguese (Portugal)'{
                $tsenv:InputLocale = "pt-PT"
                $tsenv:KeyboardLocale = "pt-PT"
            }
            'Romanian (Romania)'{
                $tsenv:InputLocale = "ro-RO"
                $tsenv:KeyboardLocale = "ro-RO"
            }
            'Russian (Russia)'{
                $tsenv:InputLocale = "ru-RU"
                $tsenv:KeyboardLocale = "ru-RU"
            }
            'Serbian (Latin, Serbia)'{
                $tsenv:InputLocale = "sr-Latn-RS"
                $tsenv:KeyboardLocale = "sr-Latn-RS"
            }
            'Slovak (Slovakia)'{
                $tsenv:InputLocale = "sk-SK"
                $tsenv:KeyboardLocale = "sk-SK"
            }
            'Slovenian (Slovenia)'{
                $tsenv:InputLocale = "sl-SI"
                $tsenv:KeyboardLocale = "sl-SI"
            }
            'Spanish (Mexico)'{
                $tsenv:InputLocale = "es-MX"
                $tsenv:KeyboardLocale = "es-MX"
            }
            'Spanish (Spain)'{
                $tsenv:InputLocale = "es-ES"
                $tsenv:KeyboardLocale = "es-ES"
            }
            'Swedish (Sweden)'{
                $tsenv:InputLocale = "sv-SE"
                $tsenv:KeyboardLocale = "sv-SE"
            }
            'Thai (Thailand)'{
                $tsenv:InputLocale = "th-TH"
                $tsenv:KeyboardLocale = "th-TH"
            }
            'Turkish (Turkey)'{
                $tsenv:InputLocale = "tr-TR"
                $tsenv:KeyboardLocale = "tr-TR"
            }
            'Ukrainian (Ukraine)'{
                $tsenv:InputLocale = "uk-UA"
                $tsenv:KeyboardLocale = "uk-UA"
            }
            Default {}
        }

        # Set version for PSDToolkit in TSenv
        $TSenv:DeploymentToolkitVersion = $DeploymentToolkitVersion

        $variablesPath = Save-PSDVariables
        #Get-ChildItem -Path tsenv:

        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PSDWizard is done."
    }
    else{
        $PSDWizard = $tsenv:PSDWizard
        Write-PSDBootInfo -SleepSec 1 -Message "Loading the PSD Deployment Wizard"
        if($tsenv:PSDPrestartMode -eq "FullScreen"){Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Loading the PSD Deployment Wizard" -PercentComplete 100}
        switch ($PSDWizard)
        {
            'PSDWizardNew' {
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running the command Import-Module $PSDWizard -ErrorAction Stop -Force -Verbose:`$False"
                        Import-Module $PSDWizard -ErrorAction Stop -Force -Verbose:$False

                        [string]$PSDWizardPath = Join-Path -Path $scripts -ChildPath $($PSDWizard)

                        # Set a name if it is empty
                        if([string]::IsNullOrEmpty($tsenv:OSDComputername)){
                            $tsenv:OSDComputername = $env:COMPUTERNAME
                        }

                        # Set theme
                        if([string]::IsNullOrEmpty($tsenv:PSDWizardTheme)){
                            $PSDWizardTheme = "Classic"
                        }
                        else{
                            $PSDWizardTheme = $tsenv:PSDWizardTheme
                        }

                        # determine splash screen (defaults to YES)
                        if($tsenv:SkipPSDWizardSplashScreen -eq 'YES'){
                            $PSDWizardNoSplashScreen = $true
                        }
                        else{
                            $PSDWizardNoSplashScreen = $false
                        }

                        # Start the wizard
                        Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Running [Show-PSDWizard -ResourcePath {0} -AsAsyncJob:{1} -Theme {2} -NoSplashScreen:{3} -Passthru -Debug:{4}]" -f $PSDWizardPath,(!$Global:BootfromWinPE),$PSDWizardTheme,$PSDWizardNoSplashScreen,$PSDDebug)
                        # $result = Show-PSDWizard -ResourcePath $PSDWizardPath -AsAsyncJob:(!$Global:BootfromWinPE) -Passthru -Debug:$PSDDebug
                        $result = Show-PSDWizard -ResourcePath $PSDWizardPath -AsAsyncJob:(!$Global:BootfromWinPE) -Theme $PSDWizardTheme -NoSplashScreen:$PSDWizardNoSplashScreen -Passthru -Debug:$PSDDebug 
        
                        # Noting was selected...
                        if ($result -eq $false){
                            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Cancelling, aborting..."
                            Show-PSDInfo -Message "Cancelling, aborting..." -Severity Information -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
                            Stop-PSDLogging
                            Clear-PSDInformation
                            Start-Process PowerShell -Wait
                            Exit 0
                        }
                    }

            'PSDWizardRS' {
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running the command Import-Module $PSDWizard -ErrorAction Stop -Force -Verbose:`$False"
                        Import-Module $PSDWizard -ErrorAction Stop -Force -Verbose:$False

                        #uses same resources as PSDWizardNew
                        [string]$PSDWizardPath = Join-Path -Path $scripts -ChildPath PSDWizardNew

                        # Set a name if it is empty
                        if([string]::IsNullOrEmpty($tsenv:OSDComputername)){
                            $tsenv:OSDComputername = $env:COMPUTERNAME
                        }


                        # Set theme
                        if([string]::IsNullOrEmpty($tsenv:PSDWizardTheme)){
                            $PSDWizardTheme = "Classic"
                        }
                        else{
                            $PSDWizardTheme = $tsenv:PSDWizardTheme
                        }

                        # Start the wizard
                        Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Running [Show-PSDWizardRS -ResourcePath {0} -Passthru -Debug:{1}]" -f $PSDWizardPath,$PSDDebug)
                        # $result = Show-PSDWizardRS -ResourcePath $PSDWizardPath -AsAsyncJob:(!$Global:BootfromWinPE) -Passthru -Debug:$PSDDebug
                        $result = Show-PSDWizardRS -ResourcePath $PSDWizardPath -Passthru -Debug:$PSDDebug -Theme $PSDWizardTheme
        
                        # Noting was selected...
                        if ($result -eq $false){
                            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Cancelling, aborting..."
                            Show-PSDInfo -Message "Cancelling, aborting..." -Severity Information -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
                            Stop-PSDLogging
                            Clear-PSDInformationgp
                            Start-Process PowerShell -Wait
                            Exit 0
                        }
                    }

            Default {}
        }
    }

    # Wizard should be done here, moving on to running the Task Sequence
    # Find the task sequence engine
    if (Test-Path -Path "X:\Deploy\Tools\$($tsenv:Architecture)\tsmbootstrap.exe"){
        $tsEngine = "X:\Deploy\Tools\$($tsenv:Architecture)"
    }
    else{
        $tsEngine = Get-PSDContent "Tools\$($tsenv:Architecture)"
    }
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Task sequence engine located at $tsEngine."

    # Transfer $PSDDeBug to TSEnv: for task sequence to understand
    If($PSDDeBug -eq $true){
        $tsenv:PSDDebug = "YES"
    }

    # Start task sequence
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Preparing to start the task sequence"

    # Saving Variables
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Saving Variables"
    $variablesPath = Save-PSDVariables
    
    # Copy Variables
    $Null = Copy-Item -Path $variablesPath -Destination $tsEngine -Force
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copied $variablesPath to $tsEngine"
    
    # Copy ts.xml
    $Null = Copy-Item -Path "$control\$($tsenv:TaskSequenceID)\ts.xml" -Destination $tsEngine -Force
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
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIOSRole.wsf" /uninstall','PowerShell.exe -file "%SCRIPTROOT%\PSDRoleUnInstall.ps1" -Uninstall') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIOSRole.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDRoleInstall.ps1"') | Set-Content -Path $TSxml
    (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIPowerShell.wsf','PowerShell.exe -file "%SCRIPTROOT%\PSDPowerShell.ps1"') | Set-Content -Path $TSxml
    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Saving a copy of the updated TS.xml"
    Copy-Item -Path $tsEngine\ts.xml -Destination "$(Get-PSDLocalDataPath)\"

    # Validate access to TSMBootstrap.exe
    if((Test-Path -Path "$tsEngine\TSMBootstrap.exe") -ne $true){
        Show-PSDInfo -Message "Unable to access $tsEngine\TSMBootstrap.exe" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
    }

    If(Test-Path "$env:systemdrive\Windows\System32\RemoteRecovery.exe"){
        Write-PSDEvent -MessageID 41016 -severity 4 -Message "PSD beginning deployment with DaRT" -Dart
    }Else{
        Write-PSDEvent -MessageID 41016 -severity 4 -Message "PSD beginning deployment"
    }
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Done in PSDStart for now, handing over to Task Sequence by running $tsEngine\TSMBootstrap.exe /env:SAStart"
    Write-PSDBootInfo -SleepSec 0 -Message "Running Task Sequence"
    if($tsenv:PSDPrestartMode -eq "FullScreen"){Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Running Task Sequence" -PercentComplete 100}

    # close PSDStartLoaderDebugMenu
    Close-PSDStartLoaderDebugMenu

    Stop-PSDLogging
    $result = Start-Process -FilePath "$tsEngine\TSMBootstrap.exe" -ArgumentList "/env:SAStart" -Wait -Passthru
    
    #close prestart loader if found
    If($PSDStartLoader.isLoaded){
        Close-PSDStartLoader -Runspace $PSDStartLoader
        Close-PSDStartLoaderDebugMenu
    }
}

# Set PSDDirty since we are
$tsenv:PSDDirty = $true
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property PSDDirty is now = $($tsenv:PSDDirty)"

# If we are in WinPE and we have deployed an operating system, we should write logfiles to the new drive
if($BootfromWinPE -eq $True){
    
    # Assuming that the first Volume having mspaint.exe is the correct OS volume
    $Drives = Get-PSDrive | Where-Object { $_.Provider -like "*filesystem*" }
    Foreach ($Drive in $Drives){
        # TODO: Need to find a better file for detection of running OS
        #If (Test-Path -Path "$($Drive.Name):\Windows\System32\mspaint.exe"){
        If (Test-Path -Path "$($Drive.Name):\marker.psd"){
            Start-PSDLogging -Logpath "$($Drive.Name):\MININT\SMSOSD\OSDLOGS"
            Break
        }
    }
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property PSDDirty is now = $tsenv:PSDDirty"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Task Sequence is done, PSDStart.ps1 is now in charge.."





# Make sure variables.dat is in the current local directory
if (Test-Path -Path "$(Get-PSDLocalDataPath)\Variables.dat"){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Variables.dat found in the correct location, $(Get-PSDLocalDataPath)\Variables.dat, no need to copy."
}
else{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying Variables.dat to the current location, $(Get-PSDLocalDataPath)\Variables.dat."
    Copy-Item $variablesPath "$(Get-PSDLocalDataPath)\"
}

$variablesPath = Restore-PSDVariables

Switch ($result.ExitCode){
    0 {
        # Done with sucess
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PSD deployment completed successfully."
        Write-PSDEvent -MessageID 41015 -severity 4 -Message "PSD deployment completed successfully."
        
        # Reset and remove registry entries used to access the local deployment share
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reset HKLM:\Software\Microsoft\Deployment 4"
        Get-ItemProperty "HKLM:\Software\Microsoft\Deployment 4" | Remove-Item -Force -Recurse

        # Reset and remove registry entries used by the task sequence
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reset HKLM:\Software\Microsoft\SMS"
        Get-ItemProperty "HKLM:\Software\Microsoft\SMS" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse

        # Unregister Task Sequences objects
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

        # Prep to run PSDFinal.ps1
        Copy-Item -Path $env:SystemDrive\MININT\Cache\Scripts\PSDFinal.ps1 -Destination "$env:TEMP"
        Clear-PSDInformation

        #close prestart loader if found
        If($PSDStartLoader.isLoaded){
            Close-PSDStartLoader -Runspace $PSDStartLoader
            Close-PSDStartLoaderDebugMenu
        }
                
        #Checking for FinalSummary
        if(!($tsenv:SkipFinalSummary -eq "YES")){
            Show-PSDInfo -Message "OSD Success." -Severity Information -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
        }

        # Check for finish action debug
        $WindowsStyle = "Hidden"
        if($PSDDeBug -eq $true){
            $WindowsStyle = "Normal"
        }

        # Check for finish action
        if($tsenv:FinishAction){
            $FinishAction = $tsenv:FinishAction
        }
        else{
            $FinishAction = "Nothing"
        }

        Start-Process powershell -ArgumentList "$env:TEMP\PSDFinal.ps1 -Action $FinishAction -ParentPID $PID -WindowStyle $WindowsStyle -Debug $PSDDeBug" -Wait

        # Done
        Exit 0
    }
    -2147021886 {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Tasksequences has requested a reboot"
        
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property PSDDirty is now = false"
        $tsenv:PSDDirty = $false
        
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Restoring PSDVariables"
        $variablesPath = Restore-PSDVariables

        try{
            foreach($i in (Get-ChildItem -Path TSEnv:)){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property $($i.Name) is now = $($i.Value)"
            }
        }
        catch{
        }

        if ($env:SYSTEMDRIVE -eq "X:"){
            # We are running in WinPE and need to reboot, if we have a hard disk, then we need files to continute the task sequence after reboot, copy files...
            # Exit with a zero return code and let Windows PE reboot

            # Assuming that the first Volume having mspaint.exe is the correct OS volume
            $Drives = Get-PSDrive | Where-Object { $_.Provider -like "*filesystem*" }
            Foreach ($Drive in $Drives){
                # TODO: Need to find a better file for detection of running OS
                # If (Test-Path -Path "$($Drive.Name):\Windows\System32\mspaint.exe"){
                If (Test-Path -Path "$($Drive.Name):\marker.psd"){
                    #Copy files needed for full OS

                    Write-PSDLog -Message "Copy-Item $scripts\PSDStart.ps1 $($Drive.Name):\MININT\Scripts"
                    Initialize-PSDFolder "$($Drive.Name):\MININT\Scripts"
                    Copy-Item "$scripts\PSDStart.ps1" "$($Drive.Name):\MININT\Scripts"

                    try{
                        $drvcache = "$($Drive.Name):\MININT\Cache"
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy-Item X:\Deploy\Tools -Destination $drvcache"
                        $cres = Copy-Item -Path "X:\Deploy\Tools" -Destination "$drvcache" -Recurse -Force -Verbose -PassThru
                        foreach($item in $cres){
                            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying $item"
                        }
                        
                        # Download Tools folder
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy-Item X:\Deploy\Tools -Destination X:\MININT\Cache\Tools"
                        $cres = Copy-Item -Path "X:\Deploy\Tools" -Destination "X:\MININT\Cache" -Recurse -Force -Verbose -PassThru
                        foreach($item in $cres){
                            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying $item"
                        }

                        # Copy modules to target drive
                        $Modules = Get-PSDContent "Tools\Modules"
                        Write-PSDLog -Message "Copy-PSDFolder $Modules $($Drive.Name):\MININT\Tools\Modules"
                        Copy-PSDFolder "$Modules" "$($Drive.Name):\MININT\Tools\Modules"
                        
                        # Copy <arc> to target drive
                        $Tools = Get-PSDContent "Tools\$($tsenv:Architecture)"
                        Write-PSDLog -Message "Copy-PSDFolder $Tools $($Drive.Name):\MININT\Tools\$($tsenv:Architecture)"
                        Copy-PSDFolder "$Tools" "$($Drive.Name):\MININT\Tools\$($tsenv:Architecture)"

                        # Copy X:\SMSTSLog to target drive
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy X:\Windows\Temp\SMSTSLog from WinPE to $($Drive.Name):\MININT"
                        $null = Copy-Item -Path X:\Windows\Temp\SMSTSLog -Destination "$($Drive.Name):\MININT" -Force -Recurse
                    }
                    catch{
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy failed"
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $_"
                    }

                    Write-PSDLog -Message "Copy-PSDFolder $Certificates $($Drive.Name):\MININT\Certificates"
                    $Certificates = Get-PSDContent "PSDResources\Certificates"
                    Copy-PSDFolder "$Certificates" "$($Drive.Name):\MININT\Certificates"

                    if($PSDDeBug -eq $true){
                        New-Item -Path "$($Drive.Name):\MININT\PSDDebug.txt" -ItemType File -Force
                    }
                }
            }

            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Exit with a zero return code and let WinPE reboot"
            Stop-PSDLogging

            exit 0
        }
        else{
            # In full OS, need to initiate a reboot
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): In full OS, need to initiate a reboot"

            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Saving Variables"
            $variablesPath = Save-PSDVariables

            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Finding out where the tools folder is..."
            $Tools = Get-PSDContent -Content "Tools\$($tsenv:Architecture)"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Path to Tools is $Tools"
            
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

            # Restart-Computer -Force
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Restart, see you on the other side... (Shutdown.exe /r /t 30 /f)"
            Shutdown.exe /r /t 2 /f

            # Stop logging
            Stop-PSDLogging
            
            # Set return code to 0
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
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Path to Tools is $Tools"

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
        #Stop-PSDLogging

        #Invoke-PSDInfoGather
        Write-PSDEvent -MessageID 41014 -severity 1 -Message "PSD deployment failed, Return Code is $($result.ExitCode)"
        Show-PSDInfo -Message "Task sequence failed, Return Code is $($result.ExitCode)" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot

        exit $result.ExitCode
    }
}