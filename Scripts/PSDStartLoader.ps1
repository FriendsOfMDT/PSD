<#
.SYNOPSIS
    Start or continue a PSD task sequence.
.DESCRIPTION
    Start or continue a PSD task sequence.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDStartLoader.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy, @PowerShellCrack
          Primary: @Mikael_Nystrom
          Created:
          Modified: 2022-04-24

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
          version - 0.9.10 - (PC) - Added NewUI switch
		  version - 0.9.11 - (PC) - Replaced BGInfo with add PSDStartLoader module
		  version - 0.9.12 - (PC) - Loaded more PSDtartLoader status screens after Wizard to show errors

		TODO:
.Example
#>
param (
	[switch] $Start,
	[switch] $NewUI,
	[switch] $Debug
)
$DeploymentToolkitVersion = "2.2.7"

# Set the module path based on the current script path
$deployRoot = Split-Path -Path "$PSScriptRoot"
$env:PSModulePath = $env:PSModulePath + ";$deployRoot\Tools\Modules"

$Global:PSDDebug = $false
if (Test-Path -Path "C:\MININT\PSDDebug.txt") {
	$DeBug = $true
	$Global:PSDDebug = $True
}


if ($DeBug -eq $true) {
	$Global:PSDDebug = $True
	$verbosePreference = "Continue"
}

if ($PSDDeBug -eq $true) {
	Write-Verbose "Property PSDDeBug is $PSDDeBug"
	Write-Verbose "PowerShell variable verbosePreference is $verbosePreference"
	Write-Verbose $env:PSModulePath
	Set-PSDDebugPause -Prompt "PSDebug is active"
}

Import-Module PSDUtility -Force -Verbose:$False
Import-Module PSDStartLoader -Global -Force -Verbose:$False
##* =================================
##* BEGIN LOADER
##* =================================
#grab all Update-PSDStartLoaderProgressBar commands in script and count them (but subtract the ones after psdwizard launch); this will set appropiate progess quantity
$Maxsteps = ([System.Management.Automation.PsParser]::Tokenize((Get-Content $MyInvocation.MyCommand.Path), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Update-PSDStartLoaderProgressBar' }).Count - 7
$i = 0
#Put a Start-Sleep back in if you actually want to see the progress bar up.
$PSDStartLoader = New-PSDStartLoader -LogoImgPath "$deployRoot\scripts\powershell.png" -MenuPosition VerticalRight -FullScreen

#wait for UI to loaded on screen
Do{
    Start-Sleep -m 300
}
Until($PSDStartLoader.isLoaded)

#start the progress bar scrolling
Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Gathering device details and loading modules..." -Indeterminate
Import-Module PSDGather -Force -Verbose:$False
Import-Module Storage -Global -Force -Verbose:$False

$DeviceInfo = Get-PSDLocalInfo -Passthru
$primaryinterface = Get-PSDStartLoaderInterfaceDetails

Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Populating device details..." -PercentComplete (($i++ / $Maxsteps) * 100)
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

# Check if we booted from WinPE
$Global:BootfromWinPE = $false
if ($env:SYSTEMDRIVE -eq "X:") {rgLabel
	$Global:BootfromWinPE = $true
}

# Process bootstrap early
Write-PSDLog -Message ("{0}: Processing Bootstrap.ini" -f $MyInvocation.MyCommand.Name)
if ($Global:BootfromWinPE) {
	$mappingFile = "X:\Deploy\Tools\Modules\PSDGather\ZTIGather.xml"
	Invoke-PSDRules -FilePath "X:\Deploy\Scripts\Bootstrap.ini" -MappingFile $mappingFile
}

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

Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Beginning initial process in PSDStart..." -PercentComplete (($i++ / $Maxsteps) * 100)
Write-PSDLog -Message ("{0}: Beginning initial process in PSDStartLoader.ps1" -f $MyInvocation.MyCommand.Name)

# Make sure we run at full power
Write-PSDLog -Message ("{0}: Setting power to High performance" -f $MyInvocation.MyCommand.Name)
& powercfg.exe /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

Write-PSDLog -Message ("{0}: PowerShell variable BootfromWinPE is $BootfromWinPE" -f $MyInvocation.MyCommand.Name)

# Write Debug status to logfile
Write-PSDLog -Message ("{0}: PowerShell variable PSDDeBug is $PSDDeBug" -f $MyInvocation.MyCommand.Name)

# Install PSDRoot certificate if exist in WinPE
Write-PSDLog -Message ("{0}: Looking for certificates..." -f $MyInvocation.MyCommand.Name)

$Certificates = @()
$CertificateLocations = "$($env:SYSTEMDRIVE)\Deploy\Certificates", "$($env:SYSTEMDRIVE)\MININT\Certificates"
foreach ($CertificateLocation in $CertificateLocations) {
	if ((Test-Path -Path $CertificateLocation) -eq $true) {
		Write-PSDLog -Message ("{0}: Looking for certificates in $CertificateLocation" -f $MyInvocation.MyCommand.Name)
		$Certificates += Get-ChildItem -Path "$CertificateLocation" -Filter *.cer
	}
}

foreach ($Certificate in $Certificates) {
	Write-PSDLog -Message ("{0}: Found {1}, trying to add as root certificate" -f $MyInvocation.MyCommand.Name, $Certificate.FullName)
	# Write-PSDBootInfo -SleepSec 1 -Message "Installing PSDRoot certificate"
	$Return = Import-PSDCertificate -Path $Certificate.FullName -CertStoreScope "LocalMachine" -CertStoreName "Root"
	If ($Return -eq "0") {
		Write-PSDLog -Message ("{0}: Succesfully imported {1}" -f $MyInvocation.MyCommand.Name, $Certificate.FullName)
	}
	else {
		Write-PSDLog -Message ("{0}: Failed to import {1}" -f $MyInvocation.MyCommand.Name, $Certificate.FullName)
	}
}

# Set Command Window size
# Reason for 99 is that 99 seems to use the screen in the best possible way, 100 is just one pixel to much
if ($Global:PSDDebug -ne $True) {
	Set-PSDCommandWindowsSize -Width 99 -Height 15
}

if ($BootfromWinPE -eq $true) {
	# Windows ADK v1809 could be missing certain files, we need to check for that.
	if ($(Get-WmiObject Win32_OperatingSystem).BuildNumber -eq "17763") {
		Write-PSDLog -Message ("{0}: Check for BCP47Langs.dll and BCP47mrm.dll, needed for WPF" -f $MyInvocation.MyCommand.Name)
		if (-not(Test-Path -Path X:\Windows\System32\BCP47Langs.dll) -or -not(Test-Path -Path X:\Windows\System32\BCP47mrm.dll)) {
			Start-Process PowerShell -ArgumentList {
				"Write-warning -Message 'We are missing the BCP47Langs.dll and BCP47mrm.dll files required for WinPE 1809.';Write-warning -Message 'Please check the PSD documentation on how to add those files.';Write-warning -Message 'Critical error, deployment can not continue..';Pause"
			} -Wait
			exit 1
		}
	}
	Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Checking that there is at least 1.5 GB of RAM..." -PercentComplete (($i++ / $Maxsteps) * 100)

	Write-PSDLog -Message ("{0}: Check for minimum amount of memory in WinPE to run PSD" -f $MyInvocation.MyCommand.Name)
	if ((Get-WmiObject -Class Win32_computersystem).TotalPhysicalMemory -le 1499MB) {
		Show-PSDInfo -Message "Not enough memory to run PSD, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
		Start-Process PowerShell -Wait
		exit 1
	}
	# All tests succeded, log that info
	Write-PSDLog -Message ("{0}: Completed WinPE prerequisite checks" -f $MyInvocation.MyCommand.Name)

	# Create SMSTS.ini (TESTING)
	Write-PSDLog -Message ("{0}: Creating SMSTS.INI for WinPE" -f $MyInvocation.MyCommand.Name)
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

#determine which UI to load
If ($NewUI) {
	Import-Module PSDWizardNew -ErrorAction Stop -Force -Verbose:$False
}
Else {
	Import-Module PSDWizard -ErrorAction Stop -Force -Verbose:$False
}

# Gather local info to make sure key variables are set (e.g. Architecture)
Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Running local gather..." -PercentComplete (($i++ / $Maxsteps) * 100)
Get-PSDLocalInfo
Write-PSDLog -Message ("{0}: Powershell variable Deployroot is $deployRoot" -f $MyInvocation.MyCommand.Name)

Write-PSDLog -Message ("{0}: Checking if there is an in-progress task sequence" -f $MyInvocation.MyCommand.Name)
Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Checking if there is an in-progress task sequence..." -PercentComplete (($i++ / $Maxsteps) * 100)

#See if loader debug is checked and set main variable
$PSDDeBug = $PSDStartLoader.DebugMode

$tsInProgress = $false
Get-Volume | ? { -not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? { $_.DriveType -eq 'Fixed' } | ? { $_.DriveLetter -ne 'X' } | ? { Test-Path "$($_.DriveLetter):\_SMSTaskSequence\TSEnv.dat" } | % {

	# Found it, save the location
	if ($PSDDeBug -eq $true) { Set-PSDDebugPause -Prompt "Existing TS found" }
	Write-PSDLog -Message ("{0}: In-progress task sequence found at {1}:\_SMSTaskSequence" -f $MyInvocation.MyCommand.Name, $_.DriveLetter)
	$tsInProgress = $true
	$tsDrive = $_.DriveLetter

	# Restore the task sequence variables
	$variablesPath = Restore-PSDVariables
	try {
		foreach ($i in (Get-ChildItem -Path TSEnv:)) {
			Write-PSDLog -Message ("{0}: Property {1} is {2}" -f $MyInvocation.MyCommand.Name, $i.Name, $i.Value)
		}
	}
	catch {
		Write-PSDLog -Message ("{0}: Unable to restore variables from $variablesPath." -f $MyInvocation.MyCommand.Name)
		Show-PSDInfo -Message "Unable to restore variables from $variablesPath." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
		Start-Process PowerShell -Wait
		Exit 1
	}
	Write-PSDLog -Message ("{0}: Restored variables from $variablesPath." -f $MyInvocation.MyCommand.Name)

	# Reconnect to the deployment share
	Write-PSDLog -Message ("{0}: Reconnecting to the deployment share at $($tsenv:DeployRoot)." -f $MyInvocation.MyCommand.Name)
	if ($tsenv:UserDomain -ne "") {
		Get-PSDConnection -deployRoot $tsenv:DeployRoot -username "$($tsenv:UserDomain)\$($tsenv:UserID)" -password $tsenv:UserPassword
	}
	else {
		Get-PSDConnection -deployRoot $tsenv:DeployRoot -username $tsenv:UserID -password $tsenv:UserPassword
	}

	# Updating SMSTSlogpath
	Write-PSDLog -Message ("{0}: Setting SMSTSlog path to {1}:\MININT" -f $MyInvocation.MyCommand.Name, $tsDrive)
	$Null = New-Item -Path HKLM:\SOFTWARE\Microsoft\CCM -Force
	$Null = New-Item -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging -Force
	$Null = New-Item -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence  -Force

	$Result = Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence -Name LogDirectory $($tsDrive + ":\MININT") -Force -PassThru
	Write-PSDLog -Message ("{0}: HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence LogDirectory is {1}" -f $MyInvocation.MyCommand.Name, $Result.LogDirectory)

	$Result = Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence -Name LogEnabled -Type DWord 1 -Force -PassThru
	Write-PSDLog -Message ("{0}: HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence LogEnabled is {1}" -f $MyInvocation.MyCommand.Name, $Result.LogEnabled)

	$Result = Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence -Name LogLevel -Type DWord 0 -Force -PassThru
	Write-PSDLog -Message ("{0}: HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence LogLevel is {1}" -f $MyInvocation.MyCommand.Name, $Result.LogLevel)

	$Result = Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence -Name LogMaxHistory -Type DWord 1 -Force -PassThru
	Write-PSDLog -Message ("{0}: HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence LogMaxHistory is {1}" -f $MyInvocation.MyCommand.Name, $Result.LogMaxHistory)

	$Result = Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence -Name LogMaxSize -Type DWord 10000000 -Force -PassThru
	Write-PSDLog -Message ("{0}: HKLM:\SOFTWARE\Microsoft\CCM\Logging\TaskSequence LogMaxSize is {1}" -f $MyInvocation.MyCommand.Name, $Result.LogMaxSize)
}

#See if loader debug is checked and set main variable
$PSDDeBug = $PSDStartLoader.DebugMode

# If running from RunOnce, create a startup folder item and then exit
if ($start) {
	Write-PSDLog -Message ("{0}: Running with the /start switch, need to determine how to re-run PSDStartLoader.ps1 after reboot" -f $MyInvocation.MyCommand.Name)

	Write-PSDLog -Message ("{0}: Running Get-PSDLocalInfo to determine what we are" -f $MyInvocation.MyCommand.Name)
	Get-PSDLocalInfo

	Write-PSDLog -Message ("{0}: Property HideShell is {1}" -f $MyInvocation.MyCommand.Name, $tsenv:HideShell)
	Write-PSDLog -Message ("{0}: Property IsServerCoreOS is {1}" -f $MyInvocation.MyCommand.Name, $tsenv:IsServerCoreOS)

	Write-PSDLog -Message ("{0}: PSDDirtyOS is false" -f $MyInvocation.MyCommand.Name)
	$tsenv:PSDDirtyOS = $false

	If (!($tsenv:HideShell -eq "YES" -or $tsenv:IsServerCoreOS -eq "True")) {
		Write-PSDLog -Message ("{0}: Creating a link to re-run {1} from the all users Startup folder" -f $MyInvocation.MyCommand.Name, $PSCommandPath)

		# Create a shortcut to run this script
		$allUsersStartup = [Environment]::GetFolderPath('CommonStartup')
		$linkPath = "$allUsersStartup\PSDStartup.lnk"
		$wshShell = New-Object -comObject WScript.Shell
		$shortcut = $WshShell.CreateShortcut($linkPath)
		$shortcut.TargetPath = "powershell.exe"



		if ($PSDDebug -eq $True) {
			Write-PSDLog -Message ("{0}: Command set to:PowerShell.exe -Noprofile -Executionpolicy Bypass -File {1} -Debug" -f $MyInvocation.MyCommand.Name, $PSCommandPath)
			$shortcut.Arguments = "-Noprofile -Executionpolicy Bypass -File $PSCommandPath -Debug"
		}
		else {
			Write-PSDLog -Message ("{0}: Command set to:PowerShell.exe -Noprofile -Executionpolicy Bypass -Windowstyle Hidden -File {1}" -f $MyInvocation.MyCommand.Name, $PSCommandPath)
			$shortcut.Arguments = "-Noprofile -Executionpolicy Bypass -Windowstyle Hidden -File $PSCommandPath"
		}
		$shortcut.Save()
		exit 0
	}
	else {
		Write-PSDLog -Message ("{0}: Setting RunOnceKey, since we are in ServerCore or Hideshell" -f $MyInvocation.MyCommand.Name)

		$RunOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
		Write-PSDLog -Message ("{0}: Setting RunOnceKey" -f $MyInvocation.MyCommand.Name)
		if ($PSDDebug -eq $True) {
			$Arguments = "-Noprofile -Executionpolicy Bypass -File $PSCommandPath -Debug -Start"
		}
		else {
			$Arguments = "-Noprofile -Executionpolicy Bypass -Windowstyle Hidden -File $PSCommandPath -Start"
		}
		Set-ItemProperty -Path $RunOnceKey -Name "NextRun" ("C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe $Arguments")
		$Command = (Get-ItemProperty -Path $RunOnceKey -Name "NextRun").NextRun
		Write-PSDLog -Message ("{0}: {1} is set to {2}" -f $MyInvocation.MyCommand.Name, $RunOnceKey, $Command)
	}
}

Write-PSDLog -Message ("{0}: If a task sequence is in progress, resume it. Otherwise, start a new one" -f $MyInvocation.MyCommand.Name)

Write-PSDLog -Message ("{0}: PowerShell varibale Deployroot is {1}" -f $MyInvocation.MyCommand.Name, $deployRoot)

# If a task sequence is in progress, resume it.  Otherwise, start a new one
[Environment]::CurrentDirectory = "$($env:WINDIR)\System32"
if ($tsInProgress) {
	# Find the task sequence engine
	if (Test-Path -Path "X:\Deploy\Tools\$($tsenv:Architecture)\tsmbootstrap.exe") {
		$tsEngine = "X:\Deploy\Tools\$($tsenv:Architecture)"
	}
	else {
		$tsEngine = Get-PSDContent "Tools\$($tsenv:Architecture)"
	}
	Write-PSDLog -Message ("{0}: Task sequence engine located at {1}." -f $MyInvocation.MyCommand.Name, $tsEngine)

	# Get full scripts location
	$scripts = Get-PSDContent -Content "Scripts"
	$env:ScriptRoot = $scripts

	# Set the PSModulePath
	$modules = Get-PSDContent -Content "Tools\Modules"
	$env:PSModulePath = $env:PSModulePath + ";$modules"

	# Resume task sequence
	Write-PSDLog -Message ("{0}: PowerShell variable Deployroot is {1}" -f $MyInvocation.MyCommand.Name, $deployRoot)
	Stop-PSDLogging
	Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Resuming existing task sequence..." -PercentComplete (($i++ / $Maxsteps) * 100)
	$result = Start-Process -FilePath "$tsEngine\TSMBootstrap.exe" -ArgumentList "/env:SAContinue" -Wait -Passthru
}
else {
	Write-PSDLog -Message ("{0}: No task sequence is in progress." -f $MyInvocation.MyCommand.Name)

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
	Write-PSDLog -Message ("{0}: Check if we should run PSDPrestart.ps1" -f $MyInvocation.MyCommand.Name)
	if ($tsenv:SkipBDDWelcome -ne "YES") {
		if ($BootfromWinPE -eq $true) {
			Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Providing option to open Prestart menu..." -PercentComplete (($i++ / $Maxsteps) * 100)
			Invoke-PSDStartPrestartButton -Runspace $PSDStartLoader -HideCountdown 10 -Wait
		}
	}
	else {
		Write-PSDLog -Message ("{0}: We should not run PSDPrestart.ps1, skipping" -f $MyInvocation.MyCommand.Name)
	}

	# Check if we are deploying from media
	Write-PSDLog -Message ("{0}: Check if we are deploying from media" -f $MyInvocation.MyCommand.Name)

	Get-Volume | ? { -not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? { $_.DriveType -eq 'Fixed' } | ? { $_.DriveLetter -ne 'X' } | ? { Test-Path "$($_.DriveLetter):Deploy\Scripts\Media.tag" } | % {
		# Found it, save the location
		Write-PSDLog -Message ("{0}: Found Media Tag $($_.DriveLetter):Deploy\Scripts\Media.tag" -f $MyInvocation.MyCommand.Name)
		$tsDrive = $_.DriveLetter
		$tsenv:DeployRoot = $tsDrive + ":\Deploy"
		$tsenv:ResourceRoot = $tsDrive + ":\Deploy"
		$tsenv:DeploymentMethod = "MEDIA"

		Write-PSDLog -Message ("{0}: DeploymentMethod is {1}, this solution does not currently support deploying from media, sorry, aborting" -f $MyInvocation.MyCommand.Name, $tsenv:DeploymentMethod)
		Show-PSDInfo -Message "No deployroot set, this solution does not currently support deploying from media, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
		Start-Process PowerShell -Wait
		Break
	}

	# Determine the deployment method
	switch ($tsenv:DeploymentMethod) {
		'MEDIA' {
			Write-PSDLog -Message ("{0}: DeploymentMethod is {1}, this solution does not currently support deploying from media, sorry, aborting" -f $MyInvocation.MyCommand.Name, $tsenv:DeploymentMethod)
			Show-PSDInfo -Message "No deployroot set, this solution does not currently support deploying from media, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
			Start-Process PowerShell -Wait
			Break
		}
		Default {
			Write-PSDLog -Message ("{0}: We are deploying from Network, checking IP's," -f $MyInvocation.MyCommand.Name)

			# Check Network
			Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Checking for a valid network configuration..." -PercentComplete (($i++ / $Maxsteps) * 100)
			Write-PSDLog -Message ("{0}: Invoking DHCP refresh..." -f $MyInvocation.MyCommand.Name)
			$Null = Invoke-PSDexe -Executable ipconfig.exe -Arguments "/renew"

			$NICIPOK = $False

			$ipList = @()
			$ipListv4 = @()
			$macList = @()
			$gwList = @()
			Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1" | % {
				$_.IPAddress | % { $ipList += $_ }
				$_.MacAddress | % { $macList += $_ }
				if ($_.DefaultIPGateway) {
					$_.DefaultIPGateway | % { $gwList += $_ }
				}
			}
			$ipListv4 = $ipList | Where-Object Length -EQ 15

			foreach ($IPv4 in $ipListv4) {
				Write-PSDLog -Message ("{0}: Found IP address {1}" -f $MyInvocation.MyCommand.Name, $IPv4)
			}

			if (((Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1").Index).count -ge 1) {
				$NICIPOK = $True
				Write-PSDLog -Message ("{0}: We have at least one network adapter with a IP address, we should be able to continue" -f $MyInvocation.MyCommand.Name)
			}


			if ($NICIPOK -ne $True) {
				$Message = "Sorry, it seems that you don't have a valid IP, aborting..."
				Write-PSDLog -Message ("{0}: {1}" -f $MyInvocation.MyCommand.Name, $Message)
				Show-PSDInfo -Message "$Message" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
				Start-Process PowerShell -Wait
				break
			}

			# Log if we are running APIPA as warning
			# Log IP, Networkadapter name, if exist GW and DNS
			# Return Network as deployment method, with Yes we have network
		}
	}

	Write-PSDLog -Message ("{0}: Looking for PSDeployRoots in the usual places..." -f $MyInvocation.MyCommand.Name)

	if ($tsenv:PSDDeployRoots -ne "") {
		Write-PSDLog -Message ("{0}: PSDeployRoots definition found!" -f $MyInvocation.MyCommand.Name)
		$items = $tsenv:PSDDeployRoots.Split(",")
		foreach ($item in $items) {
			Write-PSDLog -Message ("{0}: Testing PSDDeployRoots value: {1}" -f $MyInvocation.MyCommand.Name, $item)
			if ($item -ilike "https://*") {
				$ServerName = $item.Replace("https://", "") | Split-Path
				$Result = Test-PSDNetCon -Hostname $ServerName -Protocol HTTPS
				if (($Result) -ne $true) {
					Write-PSDLog -Message ("{0}: Unable to access PSDDeployRoots value {1} using HTTP" -f $MyInvocation.MyCommand.Name, $item)
				}
				else {
					$tsenv:DeployRoot = $item
					# Write-PSDLog -Message ("{0}: Deployroot is now $tsenv:DeployRoot"
					Break
				}
			}
			if ($item -ilike "http://*") {
				$ServerName = $item.Replace("http://", "") | Split-Path
				$Result = Test-PSDNetCon -Hostname $ServerName -Protocol HTTP
				if (($Result) -ne $true) {
					Write-PSDLog -Message ("{0}: Unable to access PSDDeployRoots value {1} using HTTPS" -f $MyInvocation.MyCommand.Name, $item)
				}
				else {
					$tsenv:DeployRoot = $item
					# Write-PSDLog -Message ("{0}: Deployroot is now $tsenv:DeployRoot"
					Break
				}
			}
			if ($item -like "\\*") {
				$ServerName = $item.Split("\\")[2]
				$Result = Test-PSDNetCon -Hostname $ServerName -Protocol SMB
				if (($Result) -ne $true) {
					Write-PSDLog -Message ("{0}: Unable to access {1} using SMB" -f $MyInvocation.MyCommand.Name, $item)
				}
				else {
					$tsenv:DeployRoot = $item
					# Write-PSDLog -Message ("{0}: Deployroot is now $tsenv:DeployRoot"
					Break
				}
			}
		}
	}
	else {
		$deployRoot = $tsenv:DeployRoot
	}
	Write-PSDLog -Message ("{0}: Property Deployroot is {1}" -f $MyInvocation.MyCommand.Name, $tsenv:DeployRoot)

	Write-PSDLog -Message ("{0}: Validating network access to {1}" -f $MyInvocation.MyCommand.Name, $tsenv:DeployRoot)
	Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status ("Validating network access to {0}..." -f $tsenv:DeployRoot) -PercentComplete (($i++ / $Maxsteps) * 100)

	if (!($tsenv:DeployRoot -notlike $null -or "")) {
		$Message = "Since we are deploying from network, we should be able to access the deploymentshare, but we can't, please check your network."
		Write-PSDLog -Message ("{0}: {1}" -f $MyInvocation.MyCommand.Name, $Message)
		Show-PSDInfo -Message "$Message" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
		Start-Process PowerShell -Wait
		Break
	}

	if ($NICIPOK -eq $False) {
		if ($deployRoot -notlike $null -or "") {
			$Message = "Since we are deploying from network, we should have network access but we don't, check networking"
			Write-PSDLog -Message ("{0}: {1}" -f $MyInvocation.MyCommand.Name, $Message)
			Show-PSDInfo -Message "$Message" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
			Start-Process PowerShell -Wait
			Break
		}
	}

	# Validate network route to $deployRoot
	if ($deployRoot -notlike $null -or "") {
		Write-PSDLog -Message ("{0}: New deploy root is {1}." -f $MyInvocation.MyCommand.Name, $deployRoot)
		if ($deployRoot -ilike "https://*") {
			$ServerName = $deployRoot.Replace("https://", "") | Split-Path
			$Result = Test-PSDNetCon -Hostname $ServerName -Protocol HTTPS
			if (($Result) -ne $true) {
				Write-PSDLog -Message ("{0}: Unable to access {1}" -f $MyInvocation.MyCommand.Name, $ServerName)
				Show-PSDInfo -Message "Unable to access $ServerName, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
				Start-Process PowerShell -Wait
				Break
			}
		}

		if ($deployRoot -ilike "http://*") {
			$ServerName = $deployRoot.Replace("http://", "") | Split-Path
			$Result = Test-PSDNetCon -Hostname $ServerName -Protocol HTTP
			if (($Result) -ne $true) {
				Write-PSDLog -Message ("{0}: Unable to access {1}" -f $MyInvocation.MyCommand.Name, $ServerName)
				Show-PSDInfo -Message "Unable to access $ServerName, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
				Start-Process PowerShell -Wait
				Break
			}
		}

		if ($deployRoot -like "\\*") {
			$ServerName = $deployRoot.Split("\\")[2]
			$Result = Test-PSDNetCon -Hostname $ServerName -Protocol SMB -ErrorAction SilentlyContinue
			if (($Result) -ne $true) {
				Write-PSDLog -Message ("{0}: Unable to access {1}" -f $MyInvocation.MyCommand.Name, $ServerName)
				Show-PSDInfo -Message "Unable to access $ServerName, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
				Start-Process PowerShell -Wait
				Break
			}
		}
	}
	else {
		Write-PSDLog -Message ("{0}: Deployroot is empty, this solution does not currently support deploying from media, sorry, aborting" -f $MyInvocation.MyCommand.Name)
		Show-PSDInfo -Message "No deployroot set, this solution does not currently support deploying from media, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
		Start-Process PowerShell -Wait
		Break
	}

	Write-PSDLog -Message ("{0}: New deploy root is {1}." -f $MyInvocation.MyCommand.Name, $deployRoot)
	Get-PSDConnection -DeployRoot $tsenv:DeployRoot -Username "$tsenv:UserDomain\$tsenv:UserID" -Password $tsenv:UserPassword

	# Set time on client
	$Time = Get-Date
	Write-PSDLog -Message ("{0}: Current time on computer is: {1}." -f $MyInvocation.MyCommand.Name, $Time)
	Write-PSDLog -Message ("{0}: Set time on client" -f $MyInvocation.MyCommand.Name)
	If ($tsenv:DeploymentMethod -ne "MEDIA") {
		if ($deployRoot -like "\\*") {
			$Null = & net time \\$ServerName /set /y
		}
		if ($deployRoot -ilike "https://*") {
			$NTPTime = Get-PSDNtpTime -Server time.windows.com
			if ($NTPTime -ne $null) {
				Set-Date -Date $NTPTime.NtpTime
			}
			else {
				Write-PSDLog -Message ("{0}: Failed to set time/date" -f $MyInvocation.MyCommand.Name) -LogLevel 2
			}

		}
		if ($deployRoot -ilike "http://*") {
			$NTPTime = Get-PSDNtpTime -Server time.windows.com
			if ($NTPTime -ne $null) {
				Set-Date -Date $NTPTime.NtpTime
			}
			else {
				Write-PSDLog -Message ("{0}: Failed to set time/date" -f $MyInvocation.MyCommand.Name) -LogLevel 2
			}
		}
	}

	$Time = Get-Date
	Write-PSDLog -Message ("{0}: New time on computer is: {1}" -f $MyInvocation.MyCommand.Name, $Time)

	# Process CustomSettings.ini
	$control = Get-PSDContent -Content "Control"

	#verify access to "$control\CustomSettings.ini"
	if ((Test-path -Path "$control\CustomSettings.ini") -ne $true) {
		Write-PSDLog -Message ("{0}: Unable to access {1}\CustomSettings.ini" -f $MyInvocation.MyCommand.Name, $control)
		Show-PSDInfo -Message "Unable to access $control\CustomSettings.ini, aborting..." -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
		Start-Process PowerShell -Wait
		Break
	}

	Write-PSDLog -Message ("{0}: Processing CustomSettings.ini" -f $MyInvocation.MyCommand.Name)
	Invoke-PSDRules -FilePath "$control\CustomSettings.ini" -MappingFile $mappingFile

	if ($tsenv:EventService -notlike $null -or "") {
		Write-PSDLog -Message ("{0}: Eventlogging is set to {1}" -f $MyInvocation.MyCommand.Name, $tsenv:EventService)
	}
	else {
		Write-PSDLog -Message ("{0}: Eventlogging is not enabled" -f $MyInvocation.MyCommand.Name)
	}

	# Get full scripts location
	$scripts = Get-PSDContent -Content "Scripts"
	$env:ScriptRoot = $scripts

	# Set the PSModulePath
	$modules = Get-PSDContent -Content "Tools\Modules"
	$env:PSModulePath = $env:PSModulePath + ";$modules"
	# Process wizard
	Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Launching the PSD Deployment Wizard..." -PercentComplete (($i++ / $Maxsteps) * 100)

	$PSDDeBug = $PSDStartLoader.DebugMode


	# $tsenv:TaskSequenceID = ""
	if ($tsenv:SkipWizard -ine "YES") {

		Write-PSDLog -Message ("{0}: Property PSDDirty is true" -f $MyInvocation.MyCommand.Name)
		$tsenv:PSDDirty = $true
		If($NewUI) {
			[string]$PSDWizardPath = Join-Path -Path $scripts -ChildPath 'PSDWizardNew'
		}
		Else {
			[string]$PSDWizardPath = Join-Path -Path $scripts -ChildPath 'PSDWizard'
		}
		Write-PSDLog -Message ("{0}: PSDWizard path is {1}" -f $MyInvocation.MyCommand.Name, $PSDWizardPath)

		#call PSD Wizard
		If (Test-Path $PSDWizardPath) {

			Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Launching PSD Deployment Wizard..." -PercentComplete 100 -Color Blue

			If ($NewUI) {
				Write-PSDLog -Message ("{0}: Running [Show-PSDWizard -ResourcePath {1} -AsAsyncJob:{2} -Passthru -Debug:{3}]" -f $MyInvocation.MyCommand.Name, $PSDWizardPath, (!$Global:BootfromWinPE), $PSDDebug)
				$result = Show-PSDWizard -ResourcePath $PSDWizardPath -AsAsyncJob:(!$Global:BootfromWinPE) -Passthru -Debug:$PSDDebug
			}
			Else {
				Write-PSDLog -Message ("{0}: Running [Show-PSDWizard {1} -Passthru]" -f $MyInvocation.MyCommand.Name, $PSDWizardPath)
				$result = Show-PSDWizard "$PSDWizardPath\PSDWizard.xaml"
			}

			if ($result -eq $false) {
				Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader  -Status "PSD Deployment Wizard was cancelled!" -PercentComplete 100 -Color Yellow
				Write-PSDLog -Message ("{0}: Cancelling, aborting..." -f $MyInvocation.MyCommand.Name)
				Show-PSDInfo -Message "Cancelling, aborting..." -Severity Information -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
				
				Stop-PSDLogging
				Clear-PSDInformation
		
				#Kill Loader
				Close-PSDStartLoader $PSDStartLoader

				Start-Process PowerShell -Wait
				Exit 0
			}
		}
		Else {
			Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status ("{0} was not found!" -f $PSDWizardPath) -PercentComplete 100 -Color Red
			Write-PSDLog -Message ("{0}: {1} path not found, aborting..." -f $MyInvocation.MyCommand.Name, $PSDWizardPath)
			Show-PSDInfo -Message ("{0} not found, aborting..." -f $PSDWizardPath) -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot

			Stop-PSDLogging
			Clear-PSDInformation

			#Kill Loader
			Close-PSDStartLoader $PSDStartLoader

			Start-Process PowerShell -Wait
			Exit 0
		}
	}

	If ($tsenv:TaskSequenceID -eq "") {
		Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "No TaskSequence selected!" -PercentComplete 100 -Color Yellow
		Write-PSDLog -Message ("{0}: No TaskSequence selected, aborting..." -f $MyInvocation.MyCommand.Name)
		Show-PSDInfo -Message "No TaskSequence selected, aborting..." -Severity Information -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
		
		Stop-PSDLogging
		Clear-PSDInformation

		#Kill Loader
		Close-PSDStartLoader $PSDStartLoader

		Start-Process PowerShell -Wait
		Exit 0
	}

	if ($tsenv:OSDComputerName -eq "") {
		$tsenv:OSDComputerName = $env:COMPUTERNAME
	}

	# Set version for PSDToolkit in TSenv
	$TSenv:DeploymentToolkitVersion = $DeploymentToolkitVersion

	$variablesPath = Save-PSDVariables
	#Get-ChildItem -Path tsenv:

	# Find the task sequence engine
	if (Test-Path -Path "X:\Deploy\Tools\$($tsenv:Architecture)\tsmbootstrap.exe") {
		$tsEngine = "X:\Deploy\Tools\$($tsenv:Architecture)"
	}
	else {
		$tsEngine = Get-PSDContent "Tools\$($tsenv:Architecture)"
	}
	Write-PSDLog -Message ("{0}: Task sequence engine located at {1}." -f $MyInvocation.MyCommand.Name, $tsEngine)

	# Transfer $PSDDeBug to TSEnv: for TS to understand
	If ($PSDDeBug -eq $true) {
		$tsenv:PSDDebug = "YES"
	}

	# Start task sequence
	Write-PSDLog -Message ("{0}: Start the task sequence" -f $MyInvocation.MyCommand.Name)

	# Saving Variables
	Write-PSDLog -Message ("{0}: Saving Variables" -f $MyInvocation.MyCommand.Name)
	$variablesPath = Save-PSDVariables

	Write-PSDLog -Message ("{0}: Copy Variables" -f $MyInvocation.MyCommand.Name)
	$Null = Copy-Item -Path $variablesPath -Destination $tsEngine -Force
	Write-PSDLog -Message ("{0}: Copied $variablesPath to {1}" -f $MyInvocation.MyCommand.Name, $tsEngine)

	Write-PSDLog -Message ("{0}: Copy ts.xml" -f $MyInvocation.MyCommand.Name)
	$Null = Copy-Item -Path "$control\$($tsenv:TaskSequenceID)\ts.xml" -Destination $tsEngine -Force
	Write-PSDLog -Message ("{0}: Copied {1}\{2}\ts.xml to {3}" -f $MyInvocation.MyCommand.Name, $control, $tsenv:TaskSequenceID, $tsEngine)

	#Update TS.XML before using it, changing workbench specific .WSF scripts to PowerShell to avoid issues
	Write-PSDLog -Message ("{0}: Update ts.xml before using it, changing workbench specific .WSF scripts to PowerShell to avoid issues" -f $MyInvocation.MyCommand.Name)

	$TSxml = "$tsEngine\ts.xml"
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIDrivers.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDDrivers.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIGather.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDGather.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIValidate.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDValidate.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIBIOSCheck.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIDiskpart.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDPartition.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIUserState.wsf" /capture', 'PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1" /capture') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIBackup.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTISetVariable.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDSetVariable.ps1"') | Set-Content -Path $TSxml
	# (Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTINextPhase.wsf"','PowerShell.exe -file "%SCRIPTROOT%\PSDNextPhase.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\LTIApply.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDApplyOS.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIWinRE.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIPatches.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIApplications.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDApplications.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIWindowsUpdate.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDWindowsUpdate.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIBde.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIBDE.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIGroups.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDTBA.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIOSRole.wsf" /uninstall', 'PowerShell.exe -file "%SCRIPTROOT%\PSDRoleUnInstall.ps1" -Uninstall') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIOSRole.wsf"', 'PowerShell.exe -file "%SCRIPTROOT%\PSDRoleInstall.ps1"') | Set-Content -Path $TSxml
	(Get-Content -Path $TSxml).replace('cscript.exe "%SCRIPTROOT%\ZTIPowerShell.wsf', 'PowerShell.exe -file "%SCRIPTROOT%\PSDPowerShell.ps1"') | Set-Content -Path $TSxml

	Write-PSDLog -Message ("{0}: Saving a copy of the updated TS.xml" -f $MyInvocation.MyCommand.Name)
	Copy-Item -Path $tsEngine\ts.xml -Destination "$(Get-PSDLocalDataPath)\"

	Write-PSDLog -Message ("{0}: PowerShell variable Deployroot is {1}" -f $MyInvocation.MyCommand.Name, $deployRoot)
	Write-PSDEvent -MessageID 41016 -severity 4 -Message "PSD beginning deployment"
	Write-PSDLog -Message ("{0}: Done in PSDStart for now, handing over to Task Sequence by running {1}\TSMBootstrap.exe /env:SAStart" -f $MyInvocation.MyCommand.Name, $tsEngine)

	Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Running Task Sequence..." -Indeterminate
	Stop-PSDLogging
	if ((Test-Path -Path "$tsEngine\TSMBootstrap.exe") -ne $true) {
		Show-PSDInfo -Message "Unable to access $tsEngine\TSMBootstrap.exe" -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
	}
	#Sync with task sequence progress
	Set-PSDStartLoaderProperty -Runspace $PSDStartLoader -PropertyName SyncTSProgress -Value $true
	#Then hide actual TS progress
	Set-PSDStartLoaderProperty -Runspace $PSDStartLoader -PropertyName HideTSProgress -Value $true
	
	#start the task sequence bootstrappper
	$result = Start-Process -FilePath "$tsEngine\TSMBootstrap.exe" -ArgumentList "/env:SAStart" -Wait -Passthru
}


# Set PSDDirty since we are
$tsenv:PSDDirty = $true
Write-PSDLog -Message ("{0}: Property PSDDirty is {1}" -f $MyInvocation.MyCommand.Name, $tsenv:PSDDirty)

# If we are in WinPE and we have deployed an operating system, we should write logfiles to the new drive
if ($BootfromWinPE -eq $True) {

	# Assuming that the first Volume having mspaint.exe is the correct OS volume
	$Drives = Get-PSDrive | Where-Object { $_.Provider -like "*filesystem*" }
	Foreach ($Drive in $Drives) {
		# TODO: Need to find a better file for detection of running OS
		#If (Test-Path -Path "$($Drive.Name):\Windows\System32\mspaint.exe"){
		If (Test-Path -Path "$($Drive.Name):\marker.psd") {
			Start-PSDLogging -Logpath "$($Drive.Name):\MININT\SMSOSD\OSDLOGS"
			Break
		}
	}
}

Write-PSDLog -Message ("{0}: Property PSDDirty is {1}" -f $MyInvocation.MyCommand.Name, $tsenv:PSDDirty)
Write-PSDLog -Message ("{0}: Task Sequence is done, PSDStartLoader.ps1 is now in charge.." -f $MyInvocation.MyCommand.Name)

# Make sure variables.dat is in the current local directory
if (Test-Path -Path "$(Get-PSDLocalDataPath)\Variables.dat") {
	Write-PSDLog -Message ("{0}: Variables.dat found in the correct location, $(Get-PSDLocalDataPath)\Variables.dat, no need to copy." -f $MyInvocation.MyCommand.Name)
}
else {
	Write-PSDLog -Message ("{0}: Copying Variables.dat to the current location, $(Get-PSDLocalDataPath)\Variables.dat." -f $MyInvocation.MyCommand.Name)
	Copy-Item $variablesPath "$(Get-PSDLocalDataPath)\"
}

Write-PSDLog -Message ("{0}: PowerShell variable Deployroot is {1}" -f $MyInvocation.MyCommand.Name, $deployRoot)
$variablesPath = Restore-PSDVariables

$items = Get-ChildItem -Path tsenv:
foreach ($i in $items) {
	Write-PSDLog -Message ("{0}: Property {1} is {2}" -f $MyInvocation.MyCommand.Name, $i.Name, $i.Value)
}

Switch ($result.ExitCode) {
	0 {
		#Kill Loader
		Close-PSDStartLoader $PSDStartLoader

		# Done with sucess
		Write-PSDLog -Message ("{0}: SUCCESS!" -f $MyInvocation.MyCommand.Name)
		Write-PSDEvent -MessageID 41015 -severity 4 -Message "PSD deployment completed successfully."

		# Reset and remove registry entries used to access the local deployment share
		Write-PSDLog -Message ("{0}: Reset HKLM:\Software\Microsoft\Deployment 4" -f $MyInvocation.MyCommand.Name)
		Get-ItemProperty "HKLM:\Software\Microsoft\Deployment 4" | Remove-Item -Force -Recurse

		# Unregister Task Sequences objects
		$Executable = "regsvr32.exe"
		$Arguments = "/u /s $tools\tscore.dll"
		if ((Test-Path -Path "$tools\tscore.dll") -eq $true) {
			Write-PSDLog -Message ("{0}: About to run: {1} {2}" -f $MyInvocation.MyCommand.Name, $Executable, $Arguments)
			$return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
			Write-PSDLog -Message ("{0}: Exitcode: {1}" -f $MyInvocation.MyCommand.Name, $return)
		}

		$Executable = "$Tools\TSProgressUI.exe"
		$Arguments = "/Unregister"
		if ((Test-Path -Path "$Tools\TSProgressUI.exe") -eq $true) {
			Write-PSDLog -Message ("{0}: About to run: {1} {2}" -f $MyInvocation.MyCommand.Name, $Executable, $Arguments)
			$return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
			Write-PSDLog -Message ("{0}: Exitcode: {1}" -f $MyInvocation.MyCommand.Name, $return)
		}

		# Prep to run PSDFinal.ps1
		Copy-Item -Path $env:SystemDrive\MININT\Cache\Scripts\PSDFinal.ps1 -Destination "$env:TEMP"
		Clear-PSDInformation

		#Checking for FinalSummary
		if (!($tsenv:SkipFinalSummary -eq "YES")) {
			Show-PSDInfo -Message "OSD SUCCESS!" -Severity Information -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
		}

		# Check for finish action
		$WindowsStyle = "Hidden"
		if ($PSDDeBug -eq $true) {
			$WindowsStyle = "Normal"
		}
		Start-Process powershell -ArgumentList "$env:TEMP\PSDFinal.ps1 -Action $tsenv:FinishAction -ParentPID $PID -WindowStyle $WindowsStyle -Debug $PSDDeBug" -Wait

		# Done
		Exit 0
	}
	-2147021886 {
		Write-PSDLog -Message ("{0}: Tasksequences has requested a reboot" -f $MyInvocation.MyCommand.Name)

		Write-PSDLog -Message ("{0}: Property PSDDirty is false" -f $MyInvocation.MyCommand.Name)
		$tsenv:PSDDirty = $false

		Write-PSDLog -Message ("{0}: Restoring PSDVariables" -f $MyInvocation.MyCommand.Name)
		$variablesPath = Restore-PSDVariables

		try {
			foreach ($i in (Get-ChildItem -Path TSEnv:)) {
				Write-PSDLog -Message ("{0}: Property {1} is {2}" -f $MyInvocation.MyCommand.Name, $i.Name, $i.Value)
			}
		}
		catch {
		}

		if ($env:SYSTEMDRIVE -eq "X:") {
			# We are running in WinPE and need to reboot, if we have a hard disk, then we need files to continute the TS after reboot, copy files...
			# Exit with a zero return code and let Windows PE reboot

			#Update PSD progressbar
			Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Preparing system for reboot..." -Indeterminate

			# Assuming that the first Volume having mspaint.exe is the correct OS volume
			$Drives = Get-PSDrive | Where-Object { $_.Provider -like "*filesystem*" }
			Foreach ($Drive in $Drives) {
				# TODO: Need to find a better file for detection of running OS
				# If (Test-Path -Path "$($Drive.Name):\Windows\System32\mspaint.exe"){
				If (Test-Path -Path "$($Drive.Name):\marker.psd") {
					#Copy files needed for full OS

					Write-PSDLog -Message ("{0}: Copy-Item {1}\PSDStartLoader.ps1 {2}:\MININT\Scripts" -f $MyInvocation.MyCommand.Name, $scripts, $Drive.Name)
					Initialize-PSDFolder "$($Drive.Name):\MININT\Scripts"
					Copy-Item "$scripts\PSDStartLoader.ps1" "$($Drive.Name):\MININT\Scripts"
					Copy-Item "$scripts\PSDStartLoader.ps1" "$($Drive.Name):\MININT\Scripts"

					try {
						$drvcache = "$($Drive.Name):\MININT\Cache"
						Write-PSDLog -Message ("{0}: Copy-Item X:\Deploy\Tools -Destination {1}" -f $MyInvocation.MyCommand.Name, $drvcache)
						$cres = Copy-Item -Path "X:\Deploy\Tools" -Destination "$drvcache" -Recurse -Force -Verbose -PassThru
						foreach ($item in $cres) {
							Write-PSDLog -Message ("{0}: Copying {1}" -f $MyInvocation.MyCommand.Name, $item)
						}


						# simulate download to x:\MININT\Cache\Tools
						Write-PSDLog -Message ("{0}: Copy-Item X:\Deploy\Tools -Destination X:\MININT\Cache\Tools" -f $MyInvocation.MyCommand.Name)
						$cres = Copy-Item -Path "X:\Deploy\Tools" -Destination "X:\MININT\Cache" -Recurse -Force -Verbose -PassThru
						foreach ($item in $cres) {
							Write-PSDLog -Message ("{0}: Copying {1}" -f $MyInvocation.MyCommand.Name, $item)
						}


						# Copies from x:\MININT\Cache to target drive
						$Modules = Get-PSDContent "Tools\Modules"
						Write-PSDLog -Message ("Copy-PSDFolder {0} {1}:\MININT\Tools\Modules" -f $Modules, $Drive.Name)
						Copy-PSDFolder "$Modules" "$($Drive.Name):\MININT\Tools\Modules"

						# Copies from x:\MININT\Cache\Tools\<arc> to target drive
						$Tools = Get-PSDContent "Tools\$($tsenv:Architecture)"
						Write-PSDLog -Message ("Copy-PSDFolder {0} {1}:\MININT\Tools\{2}" -f $Tools, $Drive.Name, $tsenv:Architecture)
						Copy-PSDFolder "$Tools" "$($Drive.Name):\MININT\Tools\$($tsenv:Architecture)"

						# Copies from X:\SMSTSLog to target drive
						Write-PSDLog -Message ("{0}: Copy X:\Windows\Temp\SMSTSLog from WinPE to {1}:\MININT" -f $MyInvocation.MyCommand.Name, $Drive.Name)
						$null = Copy-Item -Path X:\Windows\Temp\SMSTSLog -Destination "$($Drive.Name):\MININT" -Force -Recurse
					}
					catch {
						Write-PSDLog -Message ("{0}: Copy failed" -f $MyInvocation.MyCommand.Name)
						Write-PSDLog -Message ("{0}: {1}" -f $MyInvocation.MyCommand.Name, $_)
					}

					Write-PSDLog -Message ("Copy-PSDFolder {0} {1}:\MININT\Certificates" -f $Certificates, $Drive.Name)
					$Certificates = Get-PSDContent "PSDResources\Certificates"
					Copy-PSDFolder "$Certificates" "$($Drive.Name):\MININT\Certificates"

					if ($PSDDeBug -eq $true) {
						New-Item -Path "$($Drive.Name):\MININT\PSDDebug.txt" -ItemType File -Force
					}
				}
			}

			Write-PSDLog -Message ("{0}: Exit with a zero return code and let WinPE reboot" -f $MyInvocation.MyCommand.Name)
			Stop-PSDLogging

			#Kill Loader
			Close-PSDStartLoader $PSDStartLoader

			exit 0
		}
		else {
			#Update PSD progressbar
			Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Preparing system for reboot..." -Indeterminate

			# In full OS, need to initiate a reboot
			Write-PSDLog -Message ("{0}: In full OS, need to initiate a reboot" -f $MyInvocation.MyCommand.Name)

			Write-PSDLog -Message ("{0}: Saving Variables" -f $MyInvocation.MyCommand.Name)
			$variablesPath = Save-PSDVariables

			Write-PSDLog -Message ("{0}: Finding out where the tools folder is..." -f $MyInvocation.MyCommand.Name)
			$Tools = Get-PSDContent -Content "Tools\$($tsenv:Architecture)"
			Write-PSDLog -Message ("{0}: Path to Tools is {1}" -f $MyInvocation.MyCommand.Name, $Tools)

			$Executable = "regsvr32.exe"
			$Arguments = "/u /s $tools\tscore.dll"
			if ((Test-Path -Path "$tools\tscore.dll") -eq $true) {
				Write-PSDLog -Message ("{0}: About to run: {1} {2}" -f $MyInvocation.MyCommand.Name, $Executable, $Arguments)
				$return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
				Write-PSDLog -Message ("{0}: Exitcode: {1}" -f $MyInvocation.MyCommand.Name, $return)
			}
			if ($return -ne 0) {
				Write-PSDLog -Message ("{0}: Unable to unload {1}\tscore.dll" -f $MyInvocation.MyCommand.Name, $Tools) -Loglevel 2
			}

			$Executable = "$Tools\TSProgressUI.exe"
			$Arguments = "/Unregister"
			if ((Test-Path -Path "$Tools\TSProgressUI.exe") -eq $true) {
				Write-PSDLog -Message ("{0}: About to run: {1} {2}" -f $MyInvocation.MyCommand.Name, $Executable, $Arguments)
				$return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
				Write-PSDLog -Message ("{0}: Exitcode: {1}" -f $MyInvocation.MyCommand.Name, $return)
			}
			if ($return -ne 0) {
				Write-PSDLog -Message ("{0}: Unable to unload {1}\TSProgressUI.exe" -f $MyInvocation.MyCommand.Name, $Tools) -Loglevel 2
			}

			# Restart-Computer -Force
			Write-PSDLog -Message ("{0}: Restart, see you on the other side... (Shutdown.exe /r /t 30 /f)" -f $MyInvocation.MyCommand.Name)

			Shutdown.exe /r /t 2 /f

			# Stop logging
			Stop-PSDLogging

			# Set return code to 0
			exit 0
		}
	}
	default {
		Update-PSDStartLoaderProgressBar -Status ("Task sequence failed, Return Code is {0}" -f $result.ExitCode)  -Runspace $PSDStartLoader -PercentComplete 100 -Color Red

		# Exit with a non-zero return code
		Write-PSDLog -Message ("{0}: Task sequence failed, rc = {1}" -f $MyInvocation.MyCommand.Name, $result.ExitCode)

		Write-PSDLog -Message ("{0}: Reset HKLM:\Software\Microsoft\Deployment 4" -f $MyInvocation.MyCommand.Name)
		Get-ItemProperty "HKLM:\Software\Microsoft\Deployment 4"  -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse

		Write-PSDLog -Message ("{0}: Reset HKLM:\Software\Microsoft\SMS" -f $MyInvocation.MyCommand.Name)
		Get-ItemProperty "HKLM:\Software\Microsoft\SMS" -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse

		Write-PSDLog -Message ("{0}: Findig out where the tools folder is..." -f $MyInvocation.MyCommand.Name)
		$Tools = Get-PSDContent -Content "Tools\$($tsenv:Architecture)"
		Write-PSDLog -Message ("{0}: Path to Tools is {1}" -f $MyInvocation.MyCommand.Name, $Tools)

		$Executable = "regsvr32.exe"
		$Arguments = "/u /s $tools\tscore.dll"
		if ((Test-Path -Path "$tools\tscore.dll") -eq $true) {
			Write-PSDLog -Message ("{0}: About to run: {1} {2}" -f $MyInvocation.MyCommand.Name, $Executable, $Arguments)
			$return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
			Write-PSDLog -Message ("{0}: Exitcode: {1}" -f $MyInvocation.MyCommand.Name, $return)
		}

		$Executable = "$Tools\TSProgressUI.exe"
		$Arguments = "/Unregister"
		if ((Test-Path -Path "$Tools\TSProgressUI.exe") -eq $true) {
			Write-PSDLog -Message ("{0}: About to run: {1} {2}" -f $MyInvocation.MyCommand.Name, $Executable, $Arguments)
			$return = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
			Write-PSDLog -Message ("{0}: Exitcode: {1}" -f $MyInvocation.MyCommand.Name, $return)
		}

		Clear-PSDInformation
		#Stop-PSDLogging

		#Invoke-PSDInfoGather
		Write-PSDEvent -MessageID 41014 -severity 1 -Message ("PSD deployment failed, Return Code is {0}" -f $result.ExitCode)
		Show-PSDInfo -Message ("Task sequence failed, Return Code is {0}" -f $result.ExitCode) -Severity Error -OSDComputername $OSDComputername -Deployroot $global:psddsDeployRoot
		
		#Kill Loader
		Close-PSDStartLoader $PSDStartLoader

		exit $result.ExitCode
	}
}