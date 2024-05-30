<#
.SYNOPSIS

.DESCRIPTION

.LINK

.NOTES
          FileName: PSDUtility.psd1
          Solution: PowerShell Deployment for MDT
          Purpose: General utility routines useful for all PSD scripts.
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @PowerShellCrack
          Primary: @Mikael_Nystrom
          Created:
          Modified: 2022-09-18

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.0.1 - () - Added Import-PSDCertificate.
          Version - 0.0.2 - () - Replaced Get-PSDNtpTime
          Version - 0.0.3 - () - Added logic for smsts.log copy
          Version - 0.0.4 - (PC) - Set Show-PSDInfo to minimize powershell calling form
          Version - 0.0.5 - (PC) - Fixed caller output incase running outside of TS
          Version - 0.0.6 - (Mikael_Nystrom) - Added Clear-PSDDisk, Set-PSDEFIDiskpartition, Set-PSDRecoveryPartitionForMBR
          Version - 0.0.7 - (Mikael_Nystrom) - Removed a few Write-PSDLog

          TODO:
          - Convert Forms into WPF and as separate runspace

.Example
#>

# Import main module Microsoft.BDD.TaskSequenceModule
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global -Force -ErrorAction Stop -Verbose:$False

# Check for debug in PowerShell and TSEnv
if ($TSEnv:PSDDebug -eq "YES") {
    $Global:PSDDebug = $true
}
if ($PSDDebug -eq $true) {
    $verbosePreference = "Continue"
}

$global:psuDataPath = ""
#attempt to get the powershell caller script
#if no caller; just output PSD.ps1 as script file (does n)
try{
    $caller = Split-Path -Path $MyInvocation.PSCommandPath -Leaf -ErrorAction Stop
}Catch{
    $caller = 'PSD'
}

function Get-PSDLocalDataPath {
    param (
        [switch] $move
    )
    # Return the cached local data path if possible
    if ($global:psuDataPath -ne "" -and (-not $move)) {
        if (Test-Path $global:psuDataPath) {
            # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Returning data $global:psuDataPath"
            Return $global:psuDataPath
        }
    }

    # Always prefer the OS volume
    $localPath = ""
    if ($tsenv:OSVolumeGuid -ne "") {
        if ($tsenv:OSVolumeGuid -eq "MBR") {
            # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVolumeGuid is now $($tsenv:OSVolumeGuid)"
            if ($tsenv:OSVersion -eq "WinPE") {
                # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVersion is now $($tsenv:OSVersion)"
                # If the OS volume GUID is not set, we use the fake volume guid value "MBR"
                # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get the OS image details (MBR)"
                # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Using OS volume from tsenv:OSVolume: $($tsenv:OSVolume)."
                $localPath = "$($tsenv:OSVolume):\MININT"
                # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localPath is $localPath"
            }
            else {
                # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVersion is now $($tsenv:OSVersion)"
                # If the OS volume GUID is not set, we use the fake volume guid value "MBR"
                # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get the OS image details (MBR)"
                # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Using OS volume from env:SystemDrive $($env:SystemDrive)."
                $localPath = "$($env:SystemDrive)\MININT"
                # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localPath is $localPath"
            }
        }
        else {
            # If the OS volume GUID is set, we should use that volume (UEFI)
            #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get the OS image details (UEFI)"
            #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking for OS volume using $($tsenv:OSVolumeGuid)."
            Get-Volume | ? { $_.UniqueID -like "*$($tsenv:OSVolumeGuid)*" } | % {
                $localPath = "$($_.DriveLetter):\MININT"
            }
            # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localPath is $localPath"
        }
    }

    if ($localPath -eq "") {
        # Look on all other volumes
        #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking other volumes for a MININT folder."
        Get-Volume | ? { -not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? { $_.DriveType -eq 'Fixed' } | ? { $_.DriveLetter -ne 'X' } | ? { Test-Path "$($_.DriveLetter):\MININT" } | Select-Object -First 1 | % {
            $localPath = "$($_.DriveLetter):\MININT"
        }
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localPath is $localPath"
    }

    # Not found on any drive, create one on the current system drive
    #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Not found on any drive, create one on the current system drive"
    if ($localPath -eq "") {
        $localPath = "$($env:SYSTEMDRIVE)\MININT"
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localPath is $localPath"
    }

    # Create the MININT folder if it doesn't exist
    #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the MININT folder if it doesn't exist"
    if ((Test-Path $localPath) -eq $false) {
        New-Item -ItemType Directory -Force -Path $localPath | Out-Null
    }

    $global:psuDataPath = $localPath
    return $localPath
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localPath is $localPath"
}

function Find-PSDFile {
    Param(
        $FileName
    )
    $LocalPath = Get-PSDLocalDataPath
    $File = Get-ChildItem -Path $LocalPath -Recurse -Filter $FileName -File
    Return $File.FullName
}

function Initialize-PSDFolder {
    Param(
        $folderPath
    )

    if ((Test-Path $folderPath) -eq $false) {
        #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating $folderPath"
        New-Item -ItemType Directory -Force -Path $folderPath | Out-Null
    }
}

function Start-PSDLogging {
    Param(
        $Logpath = ""
    )

    if ($Logpath -eq "") {
        $logPath = "$(Get-PSDLocalDataPath)\SMSOSD\OSDLOGS"
        try {
            $tsenv:LogPath = $logPath | Out-Null
        }
        catch {
        }
    }
    Initialize-PSDfolder $logPath

    #Writing to CMtrace file
    #Set PSDLogPath
    $PSDLogFile = [IO.Path]::GetFileNameWithoutExtension($caller) + '.log'
    #$PSDLogFile = "$($($caller).Substring(0,$($caller).Length-4)).log"
    $Global:PSDLogPath = "$logPath\$PSDLogFile"

    #Create logfile
    if (!(Test-Path $Global:PSDLogPath)) {
        ## Create the log file
        New-Item $Global:PSDLogPath -Type File | Out-Null
    }

    if ($PSDDeBug -eq $true) {
        Start-Transcript "$logPath\$caller.transcript.log" -Append
        $Global:PSDTranscriptLog = "$logPath\$caller.transcript.log"
        Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Logging Transcript to $Global:PSDTranscriptLog"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Logging Transcript to $Global:PSDTranscriptLog"
    }

    Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Logging CMtrace logs to $Global:PSDLogPath"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Logging CMtrace logs to $Global:PSDLogPath"
}

function Stop-PSDLogging {
    if ($PSDDebug -ne $true) {
        Return
    }
    try {
        Stop-Transcript | Out-Null
    }
    catch {
    }
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Stop Transcript Logging"
}

Function Write-PSDLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
		[string]$Source,

        [Parameter(Mandatory=$false)]
        [ValidateSet(1, 2, 3)]
        [string]$LogLevel = 1,

        [Parameter(Mandatory=$false, HelpMessage="Name of the log file that the entry will written to.")]
        [ValidateNotNullOrEmpty()]
        $OutputLogFile = $Global:PSDLogPath
    )

    #get BIAS time
    [string]$LogTime = (Get-Date -Format 'HH:mm:ss.fff').ToString()
	[string]$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString()
	[int32]$script:LogTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes
	[string]$LogTimePlusBias = $LogTime + $script:LogTimeZoneBias

    #  Get the file name of the source script
    If($Source){
        [string]$ScriptName = $Source
        [string]$ScriptComponent = $Source
    }
    Else{
        Try {
    	    [string]$ScriptName = Split-Path $MyInvocation.ScriptName -Leaf -ErrorAction 'Stop'
    		[string]$ScriptComponent = ($ScriptName + ':' + $($MyInvocation.ScriptLineNumber))
        }
        Catch {
    	    [string]$ScriptName = 'PSD'
            [string]$ScriptComponent = 'PSD'
        }
    }

    # Don't log any lines containing the word password
    if ($Message -like '*password*') {
        $Message = "<Message containing password has been suppressed>"
    }

    #generate CMTrace log format
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="{7}">'
    $LineFormat = $Message, $LogTimePlusBias, $LogDate, $ScriptComponent, $([Security.Principal.WindowsIdentity]::GetCurrent().Name),$LogLevel,$PID,$ScriptName
    $LogFormat = $Line -f $LineFormat

    try {
        Out-File -InputObject $LogFormat -Append -NoClobber -Encoding Default -FilePath $OutputLogFile -ErrorAction Stop
    }
    catch {
        Write-Error ("[{0}] [{1}] :: Unable to append log entry to [{1}], error: {2}" -f $LogTimePlusBias,$ScriptComponent,$OutputLogFile,$_.Exception.ErrorMessage)
    }

    if ($PSDDebug -eq $true) {
        switch ($LogLevel) {
            '1' { Write-Verbose -Message $Message }
            '2' { Write-Warning -Message $Message }
            '3' { Write-Error -Message $Message }
            Default {}
        }
    }
}

Function Write-PSDDebugLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
		[string]$Source,

        [Parameter(Mandatory=$false)]
        [ValidateSet(1, 2, 3)]
        [string]$LogLevel = 1,

        [Parameter(Mandatory=$false, HelpMessage="Name of the log file that the entry will written to.")]
        [ValidateNotNullOrEmpty()]
        $OutputLogFile = $Global:PSDLogPath
    )

    if($Global:PSDDebug -eq $true){
            #get BIAS time
        [string]$LogTime = (Get-Date -Format 'HH:mm:ss.fff').ToString()
	    [string]$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString()
	    [int32]$script:LogTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes
	    [string]$LogTimePlusBias = $LogTime + $script:LogTimeZoneBias

        #  Get the file name of the source script
        If($Source){
            [string]$ScriptName = $Source
            [string]$ScriptComponent = $Source
        }
        Else{
            Try {
    	        [string]$ScriptName = Split-Path $MyInvocation.ScriptName -Leaf -ErrorAction 'Stop'
    		    [string]$ScriptComponent = ($ScriptName + ':' + $($MyInvocation.ScriptLineNumber))
            }
            Catch {
    	        [string]$ScriptName = 'PSD'
                [string]$ScriptComponent = 'PSD'
            }
        }

        # Don't log any lines containing the word password
        if ($Message -like '*password*') {
            $Message = "<Message containing password has been suppressed>"
        }

        #generate CMTrace log format
        $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="{7}">'
        $LineFormat = $Message, $LogTimePlusBias, $LogDate, $ScriptComponent, $([Security.Principal.WindowsIdentity]::GetCurrent().Name),$LogLevel,$PID,$ScriptName
        $LogFormat = $Line -f $LineFormat

        try {
            Out-File -InputObject $LogFormat -Append -NoClobber -Encoding Default -FilePath $OutputLogFile -ErrorAction Stop
        }
        catch {
            Write-Error ("[{0}] [{1}] :: Unable to append log entry to [{1}], error: {2}" -f $LogTimePlusBias,$ScriptComponent,$OutputLogFile,$_.Exception.ErrorMessage)
        }

        if ($PSDDebug -eq $true) {
            switch ($LogLevel) {
                '1' { Write-Verbose -Message $Message }
                '2' { Write-Warning -Message $Message }
                '3' { Write-Error -Message $Message }
                Default {}
            }
        }
    }
}

Start-PSDLogging

function Save-PSDVariables {
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running Save-PSDVariables"
    $PSDLocaldataPath = Get-PSDLocaldataPath
    $v = [xml]"<?xml version=`"1.0`" ?><MediaVarList Version=`"4.00.5345.0000`"></MediaVarList>"
    $Items = Get-ChildItem TSEnv:
    foreach ($Item in $Items) {
        $element = $v.CreateElement("var")
        $element.SetAttribute("name", $Item.Name) | Out-Null
        $element.AppendChild($v.createCDATASection($Item.Value)) | Out-Null
        $v.DocumentElement.AppendChild($element) | Out-Null
    }

    $path = "$PSDLocaldataPath\Variables.dat"
    $v.Save($path)
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PSDVariables are saved in: $path"
    $path
}

function Restore-PSDVariables {
    $path = "$(Get-PSDLocaldataPath)\Variables.dat"
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Restore-PSDVariables from $path"
    if (Test-Path -Path $path) {
        [xml] $v = Get-Content -Path $path
        $v | Select-Xml -Xpath "//var" | % { Set-Item tsenv:$($_.Node.name) -Value $_.Node.'#cdata-section' }
    }
    return $path
}

Function Copy-PSDLogs {
    param(
        $FolderPath,
        $Name
    )
    if ($tsenv:SLShare -eq $null -or $tsenv:SLShare -eq "") {
        Return
    }
    if ($tsenv:SLShare -ilike "http*") {
        If ((Test-Path -Path $FolderPath) -eq $true) {
            $SecurePassword = $tsenv:LogUserPassword | ConvertTo-SecureString -AsPlainText -Force
            $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList "$tsenv:LogUserDomain\$tsenv:LogUserID", $SecurePassword
            $guid = (New-Guid).Guid
            $TempArchiveFolder = "$env:TEMP\$guid"

            Try {
                $Null = New-Item -Path $TempArchiveFolder -ItemType Directory -Force
            }
            catch {
            }

            Try {
                $Null = Copy-Item -Path "$FolderPath" -Destination "$TempArchiveFolder" -Recurse
            }
            catch {
            }

            $LogArchive = "$env:TEMP\$($Name).zip"
            if (!(Test-Path -Path $TempArchiveFolder)) {
            }

            $DarnFolder = "$TempArchiveFolder\*"
            if ($PSDDebug -eq $true) {
                Start PowerShell -ArgumentList "Compress-Archive -Path $DarnFolder -DestinationPath $LogArchive -Force -ErrorAction Stop -WarningAction Stop -Verbose" -Wait
            }
            else {
                Start PowerShell -ArgumentList "Compress-Archive -Path $DarnFolder -DestinationPath $LogArchive -Force -ErrorAction Stop -WarningAction Stop" -Wait
            }

            if (!(Test-Path -Path $LogArchive)) {
            }

            $RemoteFileName = $($env:COMPUTERNAME) + "-" + $Name + ".zip"
            try {
                Start-BitsTransfer -Authentication Ntlm -Source $LogArchive -Destination $("$tsenv:SLshare/$RemoteFileName") -TransferType Upload -Credential $Credentials -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
            catch {
            }
            Start-Sleep -Seconds 5
            Remove-Item -Path $TempArchiveFolder -Recurse -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            Remove-Item -Path $LogArchive -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
        else {
        }
    }
    if ($tsenv:SLShare -like "\\*") {
        Return
    }
}

function Clear-PSDInformation {
    # Create a folder for the logs
    $logDest = "$($env:SystemRoot)\Temp\DeploymentLogs"
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating folder $logDest"
    Initialize-PSDFolder $logDest

    # Process each volume looking for MININT folders
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Process each volume looking for MININT folders"
    Get-Volume | ? { -not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? { $_.DriveType -eq 'Fixed' } | ? { $_.DriveLetter -ne 'X' } | ? { Test-Path "$($_.DriveLetter):\MININT" } | % {
        $localPath = "$($_.DriveLetter):\MININT"

        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Working on $localPath"

        # Copy Panther,Debug and other logs
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy Panther,Debug and other logs"
        if (Test-Path "$env:SystemRoot\Panther") {
            New-Item -Path "$logDest\Panther" -ItemType Directory -Force | Out-Null
            New-Item -Path "$logDest\Debug" -ItemType Directory -Force | Out-Null
            New-Item -Path "$logDest\Panther\UnattendGC" -ItemType Directory -Force | Out-Null

            # Check for log files in different locations
            $Logfiles = @(
                "wpeinit.log"
                "Debug\DCPROMO.LOG"
                "Debug\DCPROMOUI.LOG"
                "Debug\Netsetup.log"
                "Panther\cbs_unattend.log"
                "Panther\setupact.log"
                "Panther\setuperr.log"
                "Panther\UnattendGC\setupact.log"
                "Panther\UnattendGC\setuperr.log"
            )

            foreach ($Logfile in $Logfiles) {

                $Sources = "$env:TEMP\$Logfile", "$env:SystemRoot\$Logfile", "$env:SystemRoot\System32\$Logfile", "$env:Systemdrive\`$WINDOWS.~BT\Sources"
                foreach ($Source in $Sources) {
                    If (Test-Path -Path "$Source") {
                        Write-Verbose "$($MyInvocation.MyCommand.Name): Copying $Source to $logDest\$Logfile"
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying $Source to $logDest\$Logfile"
                        Copy-Item -Path "$Source" -Destination $logDest\$Logfile
                    }
                }
            }
        }

        # Copy variables.dat (TODO: Password needs to be cleaned out)
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy variables.dat"
        if (Test-Path "$localPath\Variables.dat") {
            Copy-Item "$localPath\Variables.dat" $logDest -Force
        }

        # Copy PSD logs
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy PSD logs"
        if (Test-Path "$localPath\SMSOSD\OSDLOGS") {
            Write-Verbose "Copy-Item $localPath\SMSOSD\OSDLOGS\* $logDest"
            Copy-Item "$localPath\SMSOSD\OSDLOGS\*" $logDest -Force
        }

        # Copy SMSts logs
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy SMSTS logs"
        if (Test-Path "$localPath\SMSOSD\OSDLOGS") {
            Write-Verbose "Copy-Item $localPath\*.log $logDest"
            Copy-Item "$localPath\*.log" $logDest -Force
        }

        # Copy logs to SLShare
        Copy-PSDLogs -FolderPath $logDest -Name "OSDLogs"

    }

    # Remove shortcut to PSDStart.ps1 if it exists
    $allUsersStartup = [Environment]::GetFolderPath('CommonStartup')
    $linkPath = "$allUsersStartup\PSDStartup.lnk"
    if (Test-Path $linkPath) {
        $Null = Get-Item -Path $linkPath | Remove-Item -Force
    }

    # Cleanup AutoLogon
    $Null = New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoAdminLogon -Value 0 -Force
    $Null = New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultUserName -Value "" -Force
    $Null = New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultPassword -Value "" -Force

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): This will be the last log entry."

    # Copy logs to SLShare
    Copy-PSDLogs -FolderPath $logDest -Name "OSDLogs"
}

function Copy-PSDFolder {
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        [string] $source,
        [Parameter(Mandatory = $True, Position = 2)]
        [string] $destination
    )

    $s = $source.TrimEnd("\")
    $d = $destination.TrimEnd("\")
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying folder $source to $destination using XCopy"
    $null = Start-Process xcopy -ArgumentList "$s $d /s /e /v /d /y /i" -NoNewWindow -Wait -Passthru -RedirectStandardOutput xcopy
}

function Test-PSDNetCon {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        $Hostname,
        $Protocol
    )

    switch ($Protocol) {
        SMB {
            $Port = 445
        }
        HTTP {
            $Port = 80
        }
        HTTPS {
            $Port = 443
        }
        WINRM {
            $Port = 5985
        }
        Default {
            exit
        }
    }

    try {
        $ips = [System.Net.Dns]::GetHostAddresses($hostname) | Where-Object AddressFamily -EQ InterNetwork | Select-Object IPAddressToString -ExpandProperty  IPAddressToString
        if ($ips.GetType().Name -eq "Object[]") {
            $ips
        }
    }
    catch {
        Write-Verbose "Possibly $hostname is wrong hostname or IP"
        $ips = "NA"
    }

    $maxAttempts = 5
    $attempts = 0

    foreach ($ip in $ips) {
        While ($true) {
            $attempts++
            $TcpClient = New-Object Net.Sockets.TcpClient
            try {
                Write-Verbose "Testing $ip,$port, attempt $attempts"
                $TcpClient.Connect($ip, $port)
            }
            catch {
                Write-Verbose "Attempt $attempts of $maxAttempts failed"
                if ($attempts -ge $maxAttempts) {
                    Throw
                }
                else {
                    sleep -s 2
                }
            }
            if ($TcpClient.Connected) {
                $TcpClient.Close()
                $Result = $true
                Return $Result
                Break
            }
            else {
                $Result = $false
            }
        }
        Return $Result
    }
}

Function Get-PSDDriverInfo {
    Param
    (
        $Path = $Driver.FullName
    )

    #Get filename
    $InfName = $Path | Split-Path -Leaf

    $Pattern = 'DriverVer'
    $Content = Get-Content -Path $Path
    #$DriverVer = $Content | Select-String -Pattern $Pattern
    $DriverVer = (($Content | Select-String -Pattern $Pattern -CaseSensitive) -replace '.*=(.*)', '$1') -replace ' ', '' -replace ',', '-' -split "-"

    $DriverVersion = ($DriverVer[1] -split ";")[0]

    $Pattern = 'Class'
    $Content = Get-Content -Path $Path
    $Class = ((($Content | Select-String -Pattern $Pattern) -notlike "ClassGUID*"))[0] -replace " ", "" -replace '.*=(.*)', '$1' -replace '"', ''


    $Provider = ($Content | Select-String '^\s*Provider\s*=.*') -replace '.*=(.*)', '$1'
    if ($Provider.Length -eq 0) {
        $Provider = ""
    }
    elseif ($Provider.Length -gt 0 -And $Provider -is [system.array]) {
        if ($Provider.Length -gt 1 -And $Provider[0].Trim(" ").StartsWith("%")) {
            $Provider = $Provider[1];
        }
        else {
            $Provider = $Provider[0]
        }
    }
    $Provider = $Provider.Trim(' ')

    if ($Provider.StartsWith("%")) {
        $Provider = $Provider.Trim('%')
        $Manufacter = ($Content | Select-String "^$Provider\s*=") -replace '.*=(.*)', '$1'
    }
    else {
        $Manufacter = ""
    }

    if ($Manufacter.Length -eq 0) {
        $Manufacter = $Provider
    }
    elseif ($Manufacter.Length -gt 0 -And $Manufacter -is [system.array]) {
        if ($Manufacter.Length -gt 1 -And $Manufacter[0].Trim(" ").StartsWith("%")) {
            $Manufacter = $Manufacter[1];
        }
        else {
            $Manufacter = $Manufacter[0];
        }
    }
    $Manufacter = $Manufacter.Trim(' ').Trim('"')



    $HashTable = [Ordered]@{
        Name         = $InfName
        Manufacturer = $Manufacter
        Class        = $Class
        Date         = $DriverVer[0]
        Version      = $DriverVersion
    }

    New-Object -TypeName psobject -Property $HashTable
}

Function Show-PSDInfoForm {
    Param
    (
        $Message,
        [ValidateSet("Information", "Warning", "Error")]
        $Severity = "Information",
        $OSDComputername,
        $Deployroot
    )

    $File = {
        Param
        (
            $Message,
            $Severity = "Information",
            $OSDComputername,
            $Deployroot
        )

        #�Make�PowerShell�window disappear�while using GUI
        $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
        $asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
        $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

        switch ($Severity) {
            'Error' {
                $BackColor = "salmon"
                $Label1Text = "Error"
            }
            'Warning' {
                $BackColor = "yellow"
                $Label1Text = "Warning"
            }
            'Information' {
                $BackColor = "#F0F0F0"
                $Label1Text = "Information"
            }
            Default {
                $BackColor = "#F0F0F0"
                $Label1Text = "Information"
            }
        }

        Get-CimInstance -ClassName Win32_ComputerSystem | % {
            $Manufacturer = $_.Manufacturer
            $Model = $_.Model
            $Memory = [int] ($_.TotalPhysicalMemory / 1024 / 1024)
        }

        Get-CimInstance -ClassName Win32_ComputerSystemProduct | % {
            $UUID = $_.UUID
        }

        Get-CimInstance -ClassName Win32_BaseBoard | % {
            $Product = $_.Product
            $SerialNumber = $_.SerialNumber
        }

        try { Get-SecureBootUEFI -Name SetupMode -ErrorAction Stop; $BIOSUEFI = "UEFI" } catch { $BIOSUEFI = "BIOS" }

        Get-CimInstance -ClassName Win32_SystemEnclosure | % {
            $AssetTag = $_.SMBIOSAssetTag.Trim()
            if ($_.ChassisTypes[0] -in "8", "9", "10", "11", "12", "14", "18", "21") { $ChassisType = "Laptop" }
            if ($_.ChassisTypes[0] -in "3", "4", "5", "6", "7", "15", "16") { $ChassisType = "Desktop" }
            if ($_.ChassisTypes[0] -in "23") { $ChassisType = "Server" }
            if ($_.ChassisTypes[0] -in "34", "35", "36") { $ChassisType = "Small Form Factor" }
            if ($_.ChassisTypes[0] -in "13", "31", "32", "30") { $ChassisType = "Tablet" }
        }

        $ipList = @()
        $macList = @()
        $gwList = @()
        Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1" | % {
            $_.IPAddress | % { $ipList += $_ }
            $_.MacAddress | % { $macList += $_ }
            if ($_.DefaultIPGateway) {
                $_.DefaultIPGateway | % { $gwList += $_ }
            }
        }
        $IPAddress = $ipList
        $MacAddress = $macList
        $DefaultGateway = $gwList

        try {
            Add-Type -AssemblyName System.Windows.Forms -IgnoreWarnings
            [System.Windows.Forms.Application]::EnableVisualStyles()
        }
        catch [System.UnauthorizedAccessException] {
            # This should never happen, but we're catching if it does anyway.
            Start-Process PowerShell -ArgumentList {
                Write-warning -Message 'Access denied when trying to load required assemblies, cannot display the summary window.'
                Pause
            } -Wait
            exit 1
        }
        catch [System.Exception] {
            # This should never happen either, but we're catching if it does anyway.
            Start-Process PowerShell -ArgumentList {
                Write-warning -Message 'Unable to load required assemblies, cannot display the summary window.'
                Pause
            } -Wait
            exit 1
        }

        $Form = New-Object system.Windows.Forms.Form
        $Form.ClientSize = '600,390'
        $Form.text = "PSD"
        $Form.StartPosition = "CenterScreen"
        $Form.BackColor = $BackColor
        $Form.TopMost = $true
        $Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHome + "\powershell.exe")

        $Label1 = New-Object system.Windows.Forms.Label
        $Label1.text = "$Label1Text"
        $Label1.AutoSize = $true
        $Label1.width = 25
        $Label1.height = 10
        $Label1.location = New-Object System.Drawing.Point(25, 10)
        $Label1.Font = 'Segoe UI,14'

        $Label2 = New-Object system.Windows.Forms.Label
        $Label2.text = "OSDComputername: $OSDComputername"
        $Label2.AutoSize = $true
        $Label2.width = 25
        $Label2.height = 10
        $Label2.location = New-Object System.Drawing.Point(25, 180)
        $Label2.Font = 'Segoe UI,10'

        $Label3 = New-Object system.Windows.Forms.Label
        $Label3.text = "DeployRoot: $Deployroot"
        $Label3.AutoSize = $true
        $Label3.width = 25
        $Label3.height = 10
        $Label3.location = New-Object System.Drawing.Point(25, 200)
        $Label3.Font = 'Segoe UI,10'

        $Label4 = New-Object system.Windows.Forms.Label
        $Label4.text = "Model: $Model"
        $Label4.AutoSize = $true
        $Label4.width = 25
        $Label4.height = 10
        $Label4.location = New-Object System.Drawing.Point(25, 220)
        $Label4.Font = 'Segoe UI,10'

        $Label5 = New-Object system.Windows.Forms.Label
        $Label5.text = "Manufacturer: $Manufacturer"
        $Label5.AutoSize = $true
        $Label5.width = 25
        $Label5.height = 10
        $Label5.location = New-Object System.Drawing.Point(25, 240)
        $Label5.Font = 'Segoe UI,10'

        $Label6 = New-Object system.Windows.Forms.Label
        $Label6.text = "Memory(MB): $Memory"
        $Label6.AutoSize = $true
        $Label6.width = 25
        $Label6.height = 10
        $Label6.location = New-Object System.Drawing.Point(25, 260)
        $Label6.Font = 'Segoe UI,10'

        $Label7 = New-Object system.Windows.Forms.Label
        $Label7.text = "BIOS/UEFI: $BIOSUEFI"
        $Label7.AutoSize = $true
        $Label7.width = 25
        $Label7.height = 10
        $Label7.location = New-Object System.Drawing.Point(25, 280)
        $Label7.Font = 'Segoe UI,10'

        $Label8 = New-Object system.Windows.Forms.Label
        $Label8.text = "SerialNumber: $SerialNumber"
        $Label8.AutoSize = $true
        $Label8.width = 25
        $Label8.height = 10
        $Label8.location = New-Object System.Drawing.Point(25, 300)
        $Label8.Font = 'Segoe UI,10'

        $Label9 = New-Object system.Windows.Forms.Label
        $Label9.text = "UUID: $UUID"
        $Label9.AutoSize = $true
        $Label9.width = 25
        $Label9.height = 10
        $Label9.location = New-Object System.Drawing.Point(25, 320)
        $Label9.Font = 'Segoe UI,10'

        $Label10 = New-Object system.Windows.Forms.Label
        $Label10.text = "ChassisType: $ChassisType"
        $Label10.AutoSize = $true
        $Label10.width = 25
        $Label10.height = 10
        $Label10.location = New-Object System.Drawing.Point(25, 340)
        $Label10.Font = 'Segoe UI,10'

        $TextBox1 = New-Object system.Windows.Forms.TextBox
        $TextBox1.multiline = $True
        $TextBox1.width = 550
        $TextBox1.height = 100
        $TextBox1.location = New-Object System.Drawing.Point(25, 60)
        $TextBox1.Font = 'Segoe UI,12'
        $TextBox1.Text = $Message
        $TextBox1.ReadOnly = $True

        $Button1 = New-Object system.Windows.Forms.Button
        $Button1.text = "Ok"
        $Button1.width = 60
        $Button1.height = 30
        $Button1.location = New-Object System.Drawing.Point(500, 300)
        $Button1.Font = 'Segoe UI,12'

        $Form.controls.AddRange(@($Label1, $Label2, $Label3, $Label4, $Label5, $Label6, $Label7, $Label8, $Label9, $Label10, $TextBox1, $Button1))

        $Button1.Add_Click( { Ok })

        function Ok () { $Form.close() }

        [void]$Form.ShowDialog()
    }
    $ScriptFile = $env:TEMP + "\Show-PSDInfo.ps1"
    $File | Out-File -Width 255 -FilePath $ScriptFile

    if (($OSDComputername -eq "") -or ($OSDComputername -eq $null)) { $OSDComputername = $env:COMPUTERNAME }
    if (($Deployroot -eq "") -or ($Deployroot -eq $null)) { $Deployroot = "NA" }

    Start-Process -FilePath PowerShell.exe -ArgumentList $ScriptFile, "'$Message'", $Severity, $OSDComputername, $Deployroot -Wait

    #$ScriptFile = $env:TEMP + "\Show-PSDInfo.ps1"
    #$RunFile = $env:TEMP + "\Show-PSDInfo.cmd"
    #$File | Out-File -Width 255 -FilePath $ScriptFile
    #Set-Content -Path $RunFile -Force -Value "PowerShell.exe -File $ScriptFile -Message ""$Message"" -Severity $Severity -OSDComputername $OSDComputername -Deployroot $Deployroot"
    #Start-Process -FilePath $RunFile
}

Function Show-PSDInfo {
    Param
    (
        $Message,
        [ValidateSet("Information", "Warning", "Error")]
        $Severity = "Information",
        $OSDComputername,
        $Deployroot
    )

    [string]$xaml = @"
    <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        mc:Ignorable="d"
        Title="PSDInfo"
        ResizeMode="NoResize"
        WindowStyle="None"
        WindowStartupLocation="CenterScreen"
        BorderBrush="Black"
        BorderThickness="1"
        Height="450" Width="600">
    <Grid>
        <StackPanel Margin="10">
            <Label x:Name="lblInformation" Content="Information" HorizontalAlignment="Left" FontSize="20" Foreground="Black" Height="36" Width="173" HorizontalContentAlignment="Left"/>

            <TextBox x:Name="txtInformation" HorizontalAlignment="Center" TextWrapping="Wrap" FontSize="18" IsReadOnly="True" Margin="0,10,0,15" Width="560" VerticalContentAlignment="Top" Padding="2,0,0,0" Height="91"/>

            <Grid Height="265" Width="470" HorizontalAlignment="Left" >
                <Grid.ColumnDefinitions>
                    <ColumnDefinition MinWidth="150" Width="171*"></ColumnDefinition>
                    <ColumnDefinition Width="299*"></ColumnDefinition>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                </Grid.RowDefinitions>
                <Label Content="OSDComputerName:" Grid.Row="0" Grid.Column="0" HorizontalAlignment="Center" FontSize="16" VerticalAlignment="Center" Foreground="Black" Width="168" HorizontalContentAlignment="Right"/>
                <TextBox x:Name="txtOSDComputerName" Grid.Row="0" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="16" IsReadOnly="True" Width="289" VerticalContentAlignment="Center" BorderThickness="0" Background="Transparent"/>
                <Label Content="DeployRoot:" Grid.Row="1" Grid.Column="0" HorizontalAlignment="Center" FontSize="16" VerticalAlignment="Center" Foreground="Black" Width="168" HorizontalContentAlignment="Right"/>
                <TextBox x:Name="txtDeployRoot" Grid.Row="1" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="16" IsReadOnly="True" Width="289" VerticalContentAlignment="Center" BorderThickness="0" Background="Transparent"/>
                <Label Content="Manufacturer:" Grid.Row="2" Grid.Column="0" FontSize="16" VerticalAlignment="Center" Foreground="Black" Width="168" HorizontalContentAlignment="Right"/>
                <TextBox x:Name="txtManufacturer" Grid.Row="2" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="16" IsReadOnly="True" Width="289" VerticalContentAlignment="Center" BorderThickness="0" Background="Transparent"/>
                <Label Content="Model:" Grid.Row="3" Grid.Column="0" FontSize="16" VerticalAlignment="Center" Foreground="Black" Width="168" HorizontalContentAlignment="Right"/>
                <TextBox x:Name="txtModel" Grid.Row="3" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="16" IsReadOnly="True" Width="289" VerticalContentAlignment="Center" BorderThickness="0" Background="Transparent"/>
                <Label Content="Memory(MB):" Grid.Row="4" Grid.Column="0" FontSize="16" VerticalAlignment="Center" Foreground="Black" Width="168" HorizontalContentAlignment="Right"/>
                <TextBox x:Name="txtMemory" Grid.Row="4" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="16" IsReadOnly="True" Width="289" VerticalContentAlignment="Center" BorderThickness="0" Background="Transparent"/>
                <Label Content="BIOS/UEFI:" Grid.Row="5" Grid.Column="0" FontSize="16" VerticalAlignment="Center" Foreground="Black" Width="168" HorizontalContentAlignment="Right"/>
                <TextBox x:Name="txtBIOSUEFI" Grid.Row="5" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="16" IsReadOnly="True" Width="289" VerticalContentAlignment="Center" BorderThickness="0" Background="Transparent"/>
                <Label Content="SerialNumber:" Grid.Row="6" Grid.Column="0" FontSize="16" VerticalAlignment="Center" Foreground="Black" Width="168" HorizontalContentAlignment="Right"/>
                <TextBox x:Name="txtSerialNumber"  Grid.Row="6" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="16" IsReadOnly="True" Width="289" VerticalContentAlignment="Center" BorderThickness="0" Background="Transparent"/>
                <Label Content="UUID:" Grid.Row="7" Grid.Column="0" FontSize="16" VerticalAlignment="Center" Foreground="Black" Width="168" HorizontalContentAlignment="Right"/>
                <TextBox x:Name="txtUUID" Grid.Row="7" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="16" IsReadOnly="True" Width="289" VerticalContentAlignment="Center" BorderThickness="0" Background="Transparent"/>
                <Label Content="ChassisType:" Grid.Row="8" Grid.Column="0" FontSize="16" VerticalAlignment="Center" Foreground="Black" Width="168" HorizontalContentAlignment="Right"/>
                <TextBox x:Name="txtChassis"  Grid.Row="8" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="16" IsReadOnly="True" Width="289" VerticalContentAlignment="Center" BorderThickness="0" Background="Transparent"/>
            </Grid>

        </StackPanel>
        <Button Name="btnOK" Content="OK" Height="30" Width="100" HorizontalAlignment="Right" VerticalAlignment="Bottom" FontSize="12" Padding="2" Margin="0,0,10,10" />
    </Grid>
</Window>


"@
    #=======================================================
    # LOAD ASSEMBLIES
    #=======================================================
    [System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')      | out-null #required for WPF
    [System.Reflection.Assembly]::LoadWithPartialName('PresentationCore')           | out-null #required for WPF

    [xml]$xaml = $xaml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)

    $script:PSDInfo = @{}
    $PSDInfo.Window=[Windows.Markup.XamlReader]::Load( $reader )
    #===========================================================================
    # Store Form Objects In PowerShell
    #===========================================================================
    # Add window and it's named elements to a hash table
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object -Process {$PSDInfo.$($_.Name) = $PSDInfo.Window.FindName($_.Name)}

    switch ($Severity) {
        'Error' {
            $PSDInfo.Window.Background = "salmon"
            $PSDInfo.Window.BorderBrush = "Red"
            $PSDInfo.lblInformation.Content = "Error"
        }
        'Warning' {
            $PSDInfo.Window.Background = "LightYellow"
            $PSDInfo.Window.BorderBrush = "Yellow"
            $PSDInfo.lblInformation.Content = "Warning"
        }
        'Information' {
            $PSDInfo.Window.Background = "#F0F0F0"
            $PSDInfo.Window.BorderBrush = "#012456"
            $PSDInfo.lblInformation.Content = "Information"
        }
        Default {
            $PSDInfo.Window.Background = "#F0F0F0"
            $PSDInfo.Window.BorderBrush = "#012456"
            $PSDInfo.lblInformation.Content = "Information"
        }
    }

    $PSDInfo.txtInformation.text = $Message
    $PSDInfo.txtOSDComputerName.text = $OSDComputername
    $PSDInfo.txtDeployRoot.text = $Deployroot

    #get system details
    $DeviceInfo = Get-PSDLocalInfo -PassThru

    #populate info
    $PSDInfo.txtMemory.text = ('{0:n0}' -f $DeviceInfo.Memory)
    #$PSDInfo.txtMemory.text = [math]::round($DeviceInfo.Memory/1kb, 2).ToString() + ' Gb'
    $PSDInfo.txtUUID.text = $DeviceInfo.UUID
    $PSDInfo.txtChassis.text = $DeviceInfo.Chassis
    $PSDInfo.txtBIOSUEFI.text = $DeviceInfo.SetupMode
    $PSDInfo.txtSerialNumber.text = $DeviceInfo.SerialNumber
    $PSDInfo.txtManufacturer.text = $DeviceInfo.Manufacturer
    $PSDInfo.txtModel.text = $DeviceInfo.Model

    $PSDInfo.btnOK.Add_Click({
        $PSDInfo.Window.Close() | Out-Null
    })

    #Allow UI to be dragged around screen
    If ($PSDInfo.Window.WindowStyle -eq 'None') {
        $PSDInfo.Window.Add_MouseLeftButtonDown( {
                $PSDInfo.Window.DragMove()
            })
    }

    $PSDInfo.Window.Add_Closing({
        $PSDInfo.isClosing = $True
    })

    #make sure this display on top of every window
    $PSDInfo.Window.Topmost = $true

    $PSDInfo.window.ShowDialog()
}

Function Get-PSDInputFromScreen {
    Param
    (
        $Header,
        $Message,

        [ValidateSet("Ok", "Yes")]
        $ButtonText,
        [switch]$PasswordText
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Header
    $form.Size = New-Object System.Drawing.Size(400, 200)
    $form.StartPosition = 'CenterScreen'

    $Button1 = New-Object System.Windows.Forms.Button
    $Button1.Location = New-Object System.Drawing.Point(290, 110)
    $Button1.Size = New-Object System.Drawing.Size(80, 30)
    $Button1.Text = $ButtonText
    $Button1.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $Button1
    $form.Controls.Add($Button1)

    $Label1 = New-Object System.Windows.Forms.Label
    $Label1.Location = New-Object System.Drawing.Point(10, 20)
    $Label1.Size = New-Object System.Drawing.Size(360, 20)
    $Label1.Text = $Message
    $form.Controls.Add($Label1)

    if ($PasswordText) {
        $textBox = New-Object System.Windows.Forms.MaskedTextBox
        $textBox.Location = New-Object System.Drawing.Point(10, 60)
        $textBox.Size = New-Object System.Drawing.Size(360, 20)
        $textBox.PasswordChar = '*'
        $form.Controls.Add($textBox)
    }
    else {
        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Location = New-Object System.Drawing.Point(10, 60)
        $textBox.Size = New-Object System.Drawing.Size(360, 20)
        $form.Controls.Add($textBox)
    }

    $form.Topmost = $true
    $form.Add_Shown( { $textBox.Select() })
    $result = $form.ShowDialog()

    Return $textBox.Text
}

Function Show-PSDSimpleNotify {
    Param
    (
        $Message
    )

    $Header = "PSD"

    $ButtonText = "Ok"

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Header
    $form.Size = New-Object System.Drawing.Size(400, 200)
    $form.StartPosition = 'CenterScreen'

    $Button1 = New-Object System.Windows.Forms.Button
    $Button1.Location = New-Object System.Drawing.Point(290, 110)
    $Button1.Size = New-Object System.Drawing.Size(80, 30)
    $Button1.Text = $ButtonText
    $Button1.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $Button1
    $form.Controls.Add($Button1)

    $Label1 = New-Object System.Windows.Forms.Label
    $Label1.Location = New-Object System.Drawing.Point(10, 20)
    $Label1.Size = New-Object System.Drawing.Size(360, 20)
    $Label1.Text = $Message
    $form.Controls.Add($Label1)
    $form.Topmost = $true
    $result = $form.ShowDialog()
}

Function Invoke-PSDHelper {
    Param(
        $MDTDeploySharePath,
        $UserName,
        $Password
    )

    #Connect
    & net use $MDTDeploySharePath $Password /USER:$UserName

    #Import Env
    Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global -Force -Verbose:$False
    Import-Module PSDUtility -Force -Verbose:$False
    Import-Module PSDDeploymentShare -Force -Verbose:$False
    Import-Module PSDGather -Force -Verbose:$False

    dir tsenv: | Out-File "$($env:SystemDrive)\DumpVars.log"
    Get-Content -Path "$($env:SystemDrive)\DumpVars.log"
}

Function Invoke-PSDEXE {
    [CmdletBinding(SupportsShouldProcess = $true)]

    param(
        [parameter(mandatory = $true, position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Executable,

        [parameter(mandatory = $false, position = 1)]
        [string]
        $Arguments
    )

    if ($Arguments -eq "") {
        Write-Verbose "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -NoNewWindow -Wait -Passthru
    }
    else {
        Write-Verbose "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru
    }
    Write-Verbose "Returncode is $($ReturnFromEXE.ExitCode)"
    Return $ReturnFromEXE.ExitCode
}

Function Set-PSDCommandWindowsSize {
    <#
    .Synopsis
    Resets the size of the current console window
    .Description
    Set-myConSize resets the size of the current console window. By default, it
    sets the windows to a height of 40 lines, with a 3000 line buffer, and sets the
    the width and width buffer to 120 characters.
    .Example
    Set-myConSize
    Restores the console window to 120x40
    .Example
    Set-myConSize -Height 30 -Width 180
    Changes the current console to a height of 30 lines and a width of 180 characters.
    .Parameter Height
    The number of lines to which to set the current console. The default is 40 lines.
    .Parameter Width
    The number of characters to which to set the current console. Default is 120. Also sets the buffer to the same value
    .Inputs
    [int]
    [int]
    .Notes
        Author: Charlie Russel
     Copyright: 2017 by Charlie Russel
              : Permission to use is granted but attribution is appreciated
       Initial: 28 April, 2017 (cpr)
       ModHist:
              :
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False, Position = 0)]
        [int]
        $Height = 40,
        [Parameter(Mandatory = $False, Position = 1)]
        [int]
        $Width = 120
    )
    $Console = $host.ui.rawui
    $Buffer = $Console.BufferSize
    $ConSize = $Console.WindowSize

    # If the Buffer is wider than the new console setting, first reduce the buffer, then do the resize
    If ($Buffer.Width -gt $Width ) {
        $ConSize.Width = $Width
        $Console.WindowSize = $ConSize
    }
    $Buffer.Width = $Width
    $ConSize.Width = $Width
    $Buffer.Height = 3000
    $Console.BufferSize = $Buffer
    $ConSize = $Console.WindowSize
    $ConSize.Width = $Width
    $ConSize.Height = $Height
    $Console.WindowSize = $ConSize
}

Function Get-PSDNtpTime {
    [CmdletBinding()]
    [OutputType()]
    Param (
        [String]$Server = 'pool.ntp.org'
        # [Switch]$NoDns    # Do not attempt to lookup V3 secondary-server referenceIdentifier
    )

    # --------------------------------------------------------------------
    # From https://gallery.technet.microsoft.com/scriptcenter/Get-Network-NTP-Time-with-07b216ca
    # Modifications via https://www.mathewjbray.com/powershell/powershell-get-ntp-time/
    # --------------------------------------------------------------------

    # NTP Times are all UTC and are relative to midnight on 1/1/1900
    $StartOfEpoch = New-Object DateTime(1900, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)


    Function OffsetToLocal($Offset) {
        # Convert milliseconds since midnight on 1/1/1900 to local time
        $StartOfEpoch.AddMilliseconds($Offset).ToLocalTime()
    }


    # Construct a 48-byte client NTP time packet to send to the specified server
    # (Request Header: [00=No Leap Warning; 011=Version 3; 011=Client Mode]; 00011011 = 0x1B)

    [Byte[]]$NtpData = , 0 * 48
    $NtpData[0] = 0x1B    # NTP Request header in first byte

    $Socket = New-Object Net.Sockets.Socket([Net.Sockets.AddressFamily]::InterNetwork,
        [Net.Sockets.SocketType]::Dgram,
        [Net.Sockets.ProtocolType]::Udp)
    $Socket.SendTimeOut = 2000  # ms
    $Socket.ReceiveTimeOut = 2000   # ms

    Try {
        $Socket.Connect($Server, 123)
    }
    Catch {
        Write-Warning "Failed to connect to server $Server"
        Return
    }


    # NTP Transaction -------------------------------------------------------

    $t1 = Get-Date    # t1, Start time of transaction...

    Try {
        [Void]$Socket.Send($NtpData)
        [Void]$Socket.Receive($NtpData)
    }
    Catch {
        Write-Warning "Failed to communicate with server $Server"
        Return
    }

    $t4 = Get-Date    # End of NTP transaction time

    # End of NTP Transaction ------------------------------------------------

    $Socket.Shutdown("Both")
    $Socket.Close()

    # We now have an NTP response packet in $NtpData to decode.  Start with the LI flag
    # as this is used to indicate errors as well as leap-second information

    # Decode the 64-bit NTP times

    # The NTP time is the number of seconds since 1/1/1900 and is split into an
    # integer part (top 32 bits) and a fractional part, multipled by 2^32, in the
    # bottom 32 bits.

    # Convert Integer and Fractional parts of the (64-bit) t3 NTP time from the byte array
    $IntPart = [BitConverter]::ToUInt32($NtpData[43..40], 0)
    $FracPart = [BitConverter]::ToUInt32($NtpData[47..44], 0)

    # Convert to Millseconds (convert fractional part by dividing value by 2^32)
    $t3ms = $IntPart * 1000 + ($FracPart * 1000 / 0x100000000)

    # Perform the same calculations for t2 (in bytes [32..39])
    $IntPart = [BitConverter]::ToUInt32($NtpData[35..32], 0)
    $FracPart = [BitConverter]::ToUInt32($NtpData[39..36], 0)
    $t2ms = $IntPart * 1000 + ($FracPart * 1000 / 0x100000000)

    # Calculate values for t1 and t4 as milliseconds since 1/1/1900 (NTP format)
    $t1ms = ([TimeZoneInfo]::ConvertTimeToUtc($t1) - $StartOfEpoch).TotalMilliseconds
    $t4ms = ([TimeZoneInfo]::ConvertTimeToUtc($t4) - $StartOfEpoch).TotalMilliseconds

    # Calculate the NTP Offset and Delay values
    $Offset = (($t2ms - $t1ms) + ($t3ms - $t4ms)) / 2
    $Delay = ($t4ms - $t1ms) - ($t3ms - $t2ms)

    # Make sure the result looks sane...
    # If ([Math]::Abs($Offset) -gt $MaxOffset) {
    #     # Network server time is too different from local time
    #     Throw "Network time offset exceeds maximum ($($MaxOffset)ms)"
    # }

    # Decode other useful parts of the received NTP time packet

    # We already have the Leap Indicator (LI) flag.  Now extract the remaining data
    # flags (NTP Version, Server Mode) from the first byte by masking and shifting (dividing)

    $LI_text = Switch ($LI) {
        0 { 'no warning' }
        1 { 'last minute has 61 seconds' }
        2 { 'last minute has 59 seconds' }
        3 { 'alarm condition (clock not synchronized)' }
    }

    $VN = ($NtpData[0] -band 0x38) -shr 3    # Server version number

    $Mode = ($NtpData[0] -band 0x07)     # Server mode (probably 'server')
    $Mode_text = Switch ($Mode) {
        0 { 'reserved' }
        1 { 'symmetric active' }
        2 { 'symmetric passive' }
        3 { 'client' }
        4 { 'server' }
        5 { 'broadcast' }
        6 { 'reserved for NTP control message' }
        7 { 'reserved for private use' }
    }

    # Other NTP information (Stratum, PollInterval, Precision)

    $Stratum = [UInt16]$NtpData[1]   # Actually [UInt8] but we don't have one of those...
    $Stratum_text = Switch ($Stratum) {
        0 { 'unspecified or unavailable' }
        1 { 'primary reference (e.g., radio clock)' }
        { $_ -ge 2 -and $_ -le 15 } { 'secondary reference (via NTP or SNTP)' }
        { $_ -ge 16 } { 'reserved' }
    }

    $PollInterval = $NtpData[2]              # Poll interval - to neareast power of 2
    $PollIntervalSeconds = [Math]::Pow(2, $PollInterval)

    $PrecisionBits = $NtpData[3]      # Precision in seconds to nearest power of 2
    # ...this is a signed 8-bit int
    If ($PrecisionBits -band 0x80) {
        # ? negative (top bit set)
        [Int]$Precision = $PrecisionBits -bor 0xFFFFFFE0    # Sign extend
    }
    else {
        # ..this is unlikely - indicates a precision of less than 1 second
        [Int]$Precision = $PrecisionBits   # top bit clear - just use positive value
    }
    $PrecisionSeconds = [Math]::Pow(2, $Precision)


    # Determine the format of the ReferenceIdentifier field and decode

    If ($Stratum -le 1) {
        # Response from Primary Server.  RefId is ASCII string describing source
        $ReferenceIdentifier = [String]([Char[]]$NtpData[12..15] -join '')
    }
    Else {

        # Response from Secondary Server; determine server version and decode

        Switch ($VN) {
            3 {
                # Version 3 Secondary Server, RefId = IPv4 address of reference source
                $ReferenceIdentifier = $NtpData[12..15] -join '.'

                # If (-Not $NoDns) {
                #     If ($DnsLookup =  Resolve-DnsName $ReferenceIdentifier -QuickTimeout -ErrorAction SilentlyContinue) {
                #         $ReferenceIdentifier = "$ReferenceIdentifier <$($DnsLookup.NameHost)>"
                #    }
                # }
                # Break
            }

            4 {
                # Version 4 Secondary Server, RefId = low-order 32-bits of
                # latest transmit time of reference source
                $ReferenceIdentifier = [BitConverter]::ToUInt32($NtpData[15..12], 0) * 1000 / 0x100000000
                Break
            }

            Default {
                # Unhandled NTP version...
                $ReferenceIdentifier = $Null
            }
        }
    }


    # Calculate Root Delay and Root Dispersion values

    $RootDelay = [BitConverter]::ToInt32($NtpData[7..4], 0) / 0x10000
    $RootDispersion = [BitConverter]::ToUInt32($NtpData[11..8], 0) / 0x10000


    # Finally, create output object and return

    $NtpTimeObj = [PSCustomObject]@{
        NtpServer           = $Server
        NtpTime             = OffsetToLocal($t4ms + $Offset)
        Offset              = $Offset
        OffsetSeconds       = [Math]::Round($Offset / 1000, 3)
        Delay               = $Delay
        t1ms                = $t1ms
        t2ms                = $t2ms
        t3ms                = $t3ms
        t4ms                = $t4ms
        t1                  = OffsetToLocal($t1ms)
        t2                  = OffsetToLocal($t2ms)
        t3                  = OffsetToLocal($t3ms)
        t4                  = OffsetToLocal($t4ms)
        LI                  = $LI
        LI_text             = $LI_text
        NtpVersionNumber    = $VN
        Mode                = $Mode
        Mode_text           = $Mode_text
        Stratum             = $Stratum
        Stratum_text        = $Stratum_text
        PollIntervalRaw     = $PollInterval
        PollInterval        = New-Object TimeSpan(0, 0, $PollIntervalSeconds)
        Precision           = $Precision
        PrecisionSeconds    = $PrecisionSeconds
        ReferenceIdentifier = $ReferenceIdentifier
        RootDelay           = $RootDelay
        RootDispersion      = $RootDispersion
        Raw                 = $NtpData   # The undecoded bytes returned from the NTP server
    }

    # Set the default display properties for the returned object
    [String[]]$DefaultProperties = 'NtpServer', 'NtpTime', 'OffsetSeconds', 'NtpVersionNumber',
    'Mode_text', 'Stratum', 'ReferenceIdentifier'

    # Create the PSStandardMembers.DefaultDisplayPropertySet member
    $ddps = New-Object Management.Automation.PSPropertySet('DefaultDisplayPropertySet', $DefaultProperties)

    # Attach default display property set and output object
    $PSStandardMembers = [Management.Automation.PSMemberInfo[]]$ddps
    $NtpTimeObj | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers -PassThru
}

Function Write-PSDEvent {
    param(
        $MessageID,
        $Severity,
        $Message
    )

    if ($tsenv:EventService -eq "") {
        return
    }

    # a Deployment has started (EventID 41016)
    # a Deployment completed successfully (EventID 41015)
    # a Deployment failed (EventID 41014)
    # an error occurred (EventID 3)
    # a warning occurred (EventID 2)

    if ($tsenv:LTIGUID -eq "") {
        $LTIGUID = ([guid]::NewGuid()).guid
        New-Item -Path TSEnv: -Name "LTIGUID" -Value "$LTIGUID" -Force
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property LTIGUID is $tsenv:LTIGUID"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Saving Variables"
        $variablesPath = Save-PSDVariables
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Variables was saved to $variablesPath"
    }

    $MacAddress = $tsenv:MacAddress001
    $Lguid = $tsenv:LTIGUID
    $id = $tsenv:UUID
    $vmhost = 'NA'
    $ComputerName = $tsenv:OSDComputerName

    $CurrentStep = $tsenv:_SMSTSNextInstructionPointer
    if ($CurrentStep -eq "") {
        $CurrentStep = '0'
    }

    $TotalSteps = $tsenv:_SMSTSInstructionTableSize
    if ($TotalSteps -eq "") {
        $TotalSteps = '0'
    }
    $stepName = $tsenv:_SMSTSCurrentActionName
    $Return = Invoke-WebRequest "$tsenv:EventService/MDTMonitorEvent/PostEvent?uniqueID=$Lguid&computerName=$ComputerName&messageID=$messageID&severity=$severity&stepName=$stepName&currentStep=$CurrentStep&totalSteps=$TotalSteps&id=$id,$macaddress&message=$Message&dartIP=&dartPort=&dartTicket=&vmHost=$vmhost&vmName=$ComputerName" -UseBasicParsing
}

Function Show-PSDActionProgress {
    Param(
        $Message,
        $Step,
        $MaxStep
    )
    $ts = New-Object -ComObject Microsoft.SMS.TSEnvironment
    $tsui = New-Object -ComObject Microsoft.SMS.TSProgressUI
    $MaxStep = 100
    $tsui.ShowActionProgress($ts.Value("_SMSTSOrgName"), $ts.Value("_SMSTSPackageName"), $ts.Value("_SMSTSCustomProgressDialogMessage"), $ts.Value("_SMSTSCurrentActionName"), [Convert]::ToUInt32($ts.Value("_SMSTSNextInstructionPointer")), [Convert]::ToUInt32($ts.Value("_SMSTSInstructionTableSize")), $Message, $Step, $MaxStep)

    New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name ProgressPercent -Value $Step -PropertyType DWORD -Force -ErrorAction SilentlyContinue
    New-ItemProperty -Path 'HKLM:\Software\Microsoft\Deployment 4' -Name ProgressText -Value $Message -PropertyType STRING -Force -ErrorAction SilentlyContinue
}

function Import-PSDCertificate {
    Param(
        $Path,
        $CertStoreScope,
        $CertStoreName
    )

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Adding $Path to Certificate Store: $CertStoreName in Certificate Scope: $CertStoreScope"
    # Create Object
    $CertStore = New-Object System.Security.Cryptography.X509Certificates.X509Store  -ArgumentList  $CertStoreName, $CertStoreScope
    $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2

    # Import Certificate
    $CertStore.Open('ReadWrite')
    $Cert.Import($Path)
    $CertStore.Add($Cert)
    $Result = $CertStore.Certificates | Where-Object Subject -EQ $Cert.Subject
    $CertStore.Close()
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Certificate Subject    : $($Result.Subject)"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Certificate Issuer     : $($Result.Issuer)"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Certificate Thumbprint : $($Result.Thumbprint)"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Certificate NotAfter   : $($Result.NotAfter)"
    Return "0"
}

Function Set-PSDDebugPause {
    Param(
        $Prompt
    )
    if ($Global:PSDDebug -eq $True) {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name)"
        Read-Host -Prompt "$Prompt"
    }
}

Function Clear-PSDDisk{
    Param(
        $Number
    )

    $Name = $($MyInvocation.MyCommand.Name)
    $Script = "$env:TEMP\$Name.txt"

    if($Global:PSDLogPath -ne $null){
        $logfolder = $Global:PSDLogPath | Split-Path
    }

    Set-Content -Path $Script -Value "REM $Name - $(get-date)"
    Add-Content -Path $Script -Value "select disk $Number"
    Add-Content -Path $Script -Value "clean"


    if($Global:PSDLogPath -ne $null){
        Copy-Item -Path $Script -Destination $logfolder
    }

    $Executable = "diskpart.exe"
    $Arguments = "/s $Script"

    Invoke-PSDEXE -Executable $Executable -Arguments $Arguments -Verbose
    Start-Sleep -Seconds 15
}

Function Set-PSDEFIDiskpartition{
    param(
        $Volume
    )
    $Name = $($MyInvocation.MyCommand.Name)
    $Script = "$env:TEMP\$Name.txt"

    if($Global:PSDLogPath -ne $null){
        $logfolder = $Global:PSDLogPath | Split-Path
    }

    Set-Content -Path $Script -Value "REM $Name - $(get-date)"
    Add-Content -Path $Script -Value "select volume $Volume"
    Add-Content -Path $Script -Value "select partition 1"
    Add-Content -Path $Script -Value "set id=c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
    Add-Content -Path $Script -Value "GPT Attributes=0x8000000000000000"


    if($Global:PSDLogPath -ne $null){
        Copy-Item -Path $Script -Destination $logfolder
    }

    $Executable = "diskpart.exe"
    $Arguments = "/s $Script"

    Invoke-PSDEXE -Executable $Executable -Arguments $Arguments -Verbose
    Start-Sleep -Seconds 15
}

Function Set-PSDRecoveryPartitionForMBR{
    param(
        $Volume
    )
    $Name = $($MyInvocation.MyCommand.Name)
    $Script = "$env:TEMP\$Name.txt"

    if($Global:PSDLogPath -ne $null){
        $logfolder = $Global:PSDLogPath | Split-Path
    }

    Set-Content -Path $Script -Value "REM $Name - $(get-date)"
    Add-Content -Path $Script -Value "select volume $Volume"
    Add-Content -Path $Script -Value "set id=27 override"

    if($Global:PSDLogPath -ne $null){
        Copy-Item -Path $Script -Destination $logfolder
    }

    $Executable = "diskpart.exe"
    $Arguments = "/s $Script"

    Invoke-PSDEXE -Executable $Executable -Arguments $Arguments -Verbose
    Start-Sleep -Seconds 15
}