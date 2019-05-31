# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDUtility.psd1
# // 
# // Purpose:   General utility routines useful for all PSD scripts.
# // 
# // ***************************************************************************

#$VerbosePreference = "SilentlyContinue"

Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global -Force -Verbose -ErrorAction Stop

#$verbosePreference = "Continue"

$global:psuDataPath = ""
$caller = Split-Path -Path $MyInvocation.PSCommandPath -Leaf

function Get-PSDLocalDataPath
{
    param (
        [switch] $move
    )
    # Return the cached local data path if possible
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Return the cached local data path if possible"
    if ($global:psuDataPath -ne "" -and (-not $move))
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): global:psuDataPath is $psuDataPath, testing access"
        if (Test-Path $global:psuDataPath)
        {
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Returning data $psuDataPath"
            Return $global:psuDataPath
        }
    }

    # Always prefer the OS volume
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Always prefer the OS volume"

    $localPath = ""

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localpath is $localPath"
    if ($tsenv:OSVolumeGuid -ne "")
    {
        if ($tsenv:OSVolumeGuid -eq "MBR")
        {
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVolumeGuid is now $($tsenv:OSVolumeGuid)"
            if($tsenv:OSVersion -eq "WinPE")
            {
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVersion is now $($tsenv:OSVersion)"

                # If the OS volume GUID is not set, we use the fake volume guid value "MBR"
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get the OS image details (MBR)"
            
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Using OS volume from tsenv:OSVolume: $($tsenv:OSVolume)."
            
                $localPath = "$($tsenv:OSVolume):\MININT"

                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localPath is now $localPath"
            }
            else
            {
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVersion is now $($tsenv:OSVersion)"
                # If the OS volume GUID is not set, we use the fake volume guid value "MBR"
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get the OS image details (MBR)"
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Using OS volume from env:SystemDrive $($env:SystemDrive)."
                $localPath = "$($env:SystemDrive)\MININT"
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localPath is now $localPath"
            }
        }
        else
        {
            # If the OS volume GUID is set, we should use that volume (UEFI)
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get the OS image details (UEFI)"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking for OS volume using $($tsenv:OSVolumeGuid)."
            Get-Volume | ? { $_.UniqueID -like "*$($tsenv:OSVolumeGuid)*" } | % {
                $localPath = "$($_.DriveLetter):\MININT"
            }
        }
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localpath is now $localPath"
    }
    
    if ($localPath -eq "")
    {
        # Look on all other volumes 
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Look on all other volumes"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking other volumes for a MININT folder."
        Get-Volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\MININT"} | Select-Object -First 1 | % {
            $localPath = "$($_.DriveLetter):\MININT"
        }
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localpath is now $localPath"
    }
    
    # Not found on any drive, create one on the current system drive
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Not found on any drive, create one on the current system drive"
    if ($localPath -eq "")
    {
        $localPath = "$($env:SYSTEMDRIVE)\MININT"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localpath is now $localPath"
    }
    
    # Create the MININT folder if it doesn't exist
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the MININT folder if it doesn't exist"
    if ((Test-Path $localPath) -eq $false) {
        New-Item -ItemType Directory -Force -Path $localPath | Out-Null
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localpath is now $localPath"
    }
    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): localpath set to $localPath"
    $global:psuDataPath = $localPath
    return $localPath
}

function Initialize-PSDFolder
{
    Param( 
        $folderPath
    ) 

    if ((Test-Path $folderPath) -eq $false) {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating $folderPath"
        New-Item -ItemType Directory -Force -Path $folderPath | Out-Null
    }
}

function Start-PSDLogging
{
    $logPath = "$(Get-PSDLocalDataPath)\SMSOSD\OSDLOGS"
    Initialize-PSDfolder $logPath
    Start-Transcript "$logPath\$caller.transcript.log" -Append
    Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Logging transcript to $logPath\$caller.transcript.log"

    #Writing to CMtrace file
    #Set PSDLogPath
    $PSDLogFile = "$($($caller).Substring(0,$($caller).Length-4)).log"
    $Global:PSDLogPath = "$logPath\$PSDLogFile"
    
    #Create logfile
    if (!(Test-Path $Global:PSDLogPath))
    {
        ## Create the log file
        New-Item $Global:PSDLogPath -Type File | Out-Null
    } 

    Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Logging CMtrace logs to $Global:PSDLogPath"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Logging CMtrace logs to $Global:PSDLogPath"
}

function Stop-PSDLogging
{
    Stop-Transcript
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Stop Transcript Logging"
}

Function Write-PSDLog
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
                                             
        [Parameter()]
        [ValidateSet(1, 2, 3)]
        [string]$LogLevel = 1
    )

    # Don't log any lines containing the word password
    if($Message -like '*password*') 
    {
        $Message = "<Message containing password has been suppressed>"
    }
    
    # PSDDebug settings
    if($tsenv:PSDDebug -eq "YES")
    {
        $WriteToScreen = $true
    }

    #check if we have a logpath set
    if($Global:PSDLogPath -ne $null)
    {
        if (!(Test-Path -Path $Global:PSDLogPath))
        {
            ## Create the log file
            New-Item $Global:PSDLogPath -Type File | Out-Null
        }

        $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
        $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
        $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
        $Line = $Line -f $LineFormat

        #Log to scriptfile
        Add-Content -Value $Line -Path $Global:PSDLogPath

        #Log to networkshare
        if($DynLogging -eq $true)
        {
            Add-Content -Value $Line -Path $PSDDynLogPath -ErrorAction SilentlyContinue
        }

        #Log to masterfile
        Add-Content -Value $Line -Path (($Global:PSDLogPath | Split-Path) + "\PSD.log")
    }

    if($writetoscreen -eq $true){
        switch ($LogLevel)
        {
            '1'{
                Write-Verbose -Message $Message 
                }
            '2'{
                Write-Warning -Message $Message
                }
            '3'{
                Write-Error -Message $Message
                }
            Default {}
        }
    }
}
Start-PSDLogging

function Save-PSDVariables
{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save-PSDVariables"
    $v = [xml]"<?xml version=`"1.0`" ?><MediaVarList Version=`"4.00.5345.0000`"></MediaVarList>"
    Get-ChildItem TSEnv: | % {
        $element = $v.CreateElement("var")
        $element.SetAttribute("name", $_.Name) | Out-Null
        $element.AppendChild($v.createCDATASection($_.Value)) | Out-Null
        $v.DocumentElement.AppendChild($element) | Out-Null
    }
    $path = "$(Get-PSDLocaldataPath)\Variables.dat"
    $v.Save($path)
    return $path
}

function Restore-PSDVariables
{
    $path = "$(Get-PSDLocaldataPath)\Variables.dat"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Restore-PSDVariables from $path"
    if (Test-Path -Path $path) {
        [xml] $v = Get-Content -Path $path
        $v | Select-Xml -Xpath "//var" | % { Set-Item tsenv:$($_.Node.name) -Value $_.Node.'#cdata-section' } 
    }
    return $path
}

function Clear-PSDInformation
{
    # Create a folder for the logs
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create a folder for the logs"
    $logDest = "$($env:SystemRoot)\Temp\DeploymentLogs"
    Initialize-PSDFolder $logDest

    # Process each volume looking for MININT folders
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Process each volume looking for MININT folders"
    Get-Volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\MININT"} | % {
        $localPath = "$($_.DriveLetter):\MININT"

        # Copy PSD logs
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy PSD logs"
        if (Test-Path "$localPath\SMSOSD\OSDLOGS")
        {
            Copy-Item "$localPath\SMSOSD\OSDLOGS\*" $logDest -Force
        }

        # Copy Panther logs
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy Panther logs"
        if (Test-Path "$localPath\Logs")
        {
            & xcopy $env:SystemRoot\Panther $logDest /s /e /v /d /y /i | Out-Null
        }

        # Copy SMSTS log
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy SMSTS log"
        if (Test-Path "$localPath\Logs")
        {
            Copy-Item -Path $env:LOCALAPPDATA\temp\smstslog\smsts.log -Destination $logDest
        }

        # Check if DEVRunCleanup is set to NO
        if ($($tsenv:DEVRunCleanup) -eq "NO")
        {
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:DEVRunCleanup is now $tsenv:DEVRunCleanup"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Cleanup will not remove MININT or Drivers folder"
        }
        else
        {

            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:DEVRunCleanup is now $tsenv:DEVRunCleanup"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Cleanup will remove MININT and Drivers folder"

            # Remove the MININT folder
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Remove the MININT folder"
            try
            {
                Remove-Item "$localPath" -Recurse -Force
            }
            catch
            {
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to completely remove $localPath."
            }

            # Remove the Drivers folder
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Remove the Drivers folder"
            try
            {
                Remove-Item "$($env:Systemdrive + "\Drivers")" -Recurse -Force
            }
            catch
            {
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to completely remove $($env:Systemdrive + "\Drivers")."
            }
        }
    }

    # Cleanup start folder
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Cleanup start folder"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Removing link to re-run $PSCommandPath from the all users Startup folder"

    # Remove shortcut to PSDStart.ps1 if it exists
    $allUsersStartup = [Environment]::GetFolderPath('CommonStartup')
    $linkPath = "$allUsersStartup\PSDStartup.lnk"
    if(Test-Path $linkPath)
    {
        $Null = Get-Item -Path $linkPath | Remove-Item -Force
    }

    # Cleanup AutoLogon
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Cleanup AutoLogon"

    $Null = New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoAdminLogon -Value 0 -Force
    $Null = New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultUserName -Value "" -Force
    $Null = New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultPassword -Value "" -Force

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): AutoLogon has been removed"
}

function Copy-PSDFolder
{
    param (
        [Parameter(Mandatory=$True,Position=1)]
        [string] $source,
        [Parameter(Mandatory=$True,Position=2)]
        [string] $destination
    )

    $s = $source.TrimEnd("\")
    $d = $destination.TrimEnd("\")
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying folder $source to $destination using XCopy"
    & xcopy $s $d /s /e /v /d /y /i | Out-Null
}

function Test-PSDNetCon
{
    Param
    (
        $Hostname, 
        $Protocol
    )


switch ($Protocol)
{
    SMB
    {
        $Port = 445
    }
    HTTP
    {
        $Port = 80
    }
    HTTPS
    {
        $Port = 443
    }
    WINRM
    {
        $Port = 5985
    }
    Default
    {
        exit
    }
}
    try
    {
        $ips = [System.Net.Dns]::GetHostAddresses($hostname) | Where-Object AddressFamily -EQ InterNetwork | Select-Object IPAddressToString -ExpandProperty  IPAddressToString
        if($ips.GetType().Name -eq "Object[]")
        {
            $ips
        }
    }
    catch
    {
        Write-Verbose "Possibly $hostname is wrong hostname or IP"
        $ips = "NA"
    }

    foreach($ip in $ips)
    {
        $TcpClient = New-Object Net.Sockets.TcpClient
        try
        {
            Write-Verbose "Testing $ip,$port"
            $TcpClient.Connect($ip,$port)
        }
        catch
        {
        }

        if($TcpClient.Connected)
        {
            $TcpClient.Close()
            $Result = $true
            Return $Result
            Break
        }
        else
        {
            $Result = $false
        }
    }
    Return $Result
}

Function Get-PSDDriverInfo
{
    Param
    (
        $Path = $Driver.FullName
    )

    #Get filename
    $InfName = $Path | Split-Path -Leaf

    $Pattern = 'DriverVer'
    $Content = Get-Content -Path $Path
    #$DriverVer = $Content | Select-String -Pattern $Pattern
    $DriverVer = (($Content | Select-String -Pattern $Pattern -CaseSensitive) -replace '.*=(.*)','$1') -replace ' ','' -replace ',','-' -split "-"

    $DriverVersion = ($DriverVer[1] -split ";")[0]

    $Pattern = 'Class'
    $Content = Get-Content -Path $Path
    $Class = ((($Content | Select-String -Pattern $Pattern) -notlike "ClassGUID*"))[0] -replace " ","" -replace '.*=(.*)','$1' -replace '"',''


    $Provider = ($Content | Select-String '^\s*Provider\s*=.*') -replace '.*=(.*)','$1'
    if ($Provider.Length -eq 0) {
        $Provider = ""
    }
    elseif($Provider.Length -gt 0 -And $Provider -is [system.array]) {
        if ($Provider.Length -gt 1 -And $Provider[0].Trim(" ").StartsWith("%")) {
            $Provider = $Provider[1];
        } else {
            $Provider = $Provider[0]
        }
    }
    $Provider = $Provider.Trim(' ')

    if ($Provider.StartsWith("%")) {
        $Provider = $Provider.Trim('%')
        $Manufacter = ($Content | Select-String "^$Provider\s*=") -replace '.*=(.*)','$1'
    }
    else {
        $Manufacter = ""
    }    

    if ($Manufacter.Length -eq 0) {
        $Manufacter = $Provider
    } elseif ($Manufacter.Length -gt 0 -And $Manufacter -is [system.array]) {
        if ($Manufacter.Length -gt 1 -And $Manufacter[0].Trim(" ").StartsWith("%")) {
            $Manufacter = $Manufacter[1];
        }
        else {
            $Manufacter = $Manufacter[0];
        }
    }
    $Manufacter = $Manufacter.Trim(' ').Trim('"')

    

    $HashTable = [Ordered]@{
        Name = $InfName
        Manufacturer = $Manufacter
        Class = $Class
        Date = $DriverVer[0]
        Version = $DriverVersion
    }
    
    New-Object -TypeName psobject -Property $HashTable
}Function Show-PSDInfo
{
    Param
    (
        $Message,
        [ValidateSet("Information","Warning","Error")]
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
    
switch ($Severity)
{
    'Error' 
    {
        $BackColor = "salmon"
        $Label1Text = "Error"
    }
    'Warning' 
    {
        $BackColor = "yellow"
        $Label1Text = "Warning"
    }
    'Information' 
    {
        $BackColor = "#F0F0F0"
        $Label1Text = "Information"
    }
    Default 
    {
        $BackColor = "#F0F0F0"
        $Label1Text = "Information"
    }
}

Get-WmiObject Win32_ComputerSystem | % {
    $Manufacturer = $_.Manufacturer
    $Model = $_.Model
    $Memory = [int] ($_.TotalPhysicalMemory / 1024 / 1024)
}

Get-WmiObject Win32_ComputerSystemProduct | % {
    $UUID = $_.UUID
}
    
Get-WmiObject Win32_BaseBoard | % {
    $Product = $_.Product
    $SerialNumber = $_.SerialNumber
}

try{Get-SecureBootUEFI -Name SetupMode | Out-Null ; $BIOSUEFI = "UEFI"}catch{$BIOSUEFI = "BIOS"}

Get-WmiObject Win32_SystemEnclosure | % {
    $AssetTag = $_.SMBIOSAssetTag.Trim()
    if ($_.ChassisTypes[0] -in "8", "9", "10", "11", "12", "14", "18", "21") { $ChassiType = "Laptop"}
    if ($_.ChassisTypes[0] -in "3", "4", "5", "6", "7", "15", "16") { $ChassiType = "Desktop"}
    if ($_.ChassisTypes[0] -in "23") { $ChassiType = "Server"}
    if ($_.ChassisTypes[0] -in "34", "35", "36") { $ChassiType = "Small Form Factor"}
    if ($_.ChassisTypes[0] -in "13", "31", "32", "30") { $ChassiType = "Tablet"} 
}

$ipList = @()
$macList = @()
$gwList = @()
Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1" | % {
    $_.IPAddress | % {$ipList += $_ }
    $_.MacAddress | % {$macList += $_ }
    if ($_.DefaultIPGateway) {
    $_.DefaultIPGateway | % {$gwList += $_ }
    }
}
$IPAddress = $ipList
$MacAddress = $macList
$DefaultGateway = $gwList

try
{
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

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = '600,390'
$Form.text                       = "PSD"
$Form.StartPosition              = "CenterScreen"
$Form.BackColor                  = $BackColor
$Form.TopMost                    = $true
$Form.Icon                       = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHome + "\powershell.exe")

$Label1                          = New-Object system.Windows.Forms.Label
$Label1.text                     = "$Label1Text"
$Label1.AutoSize                 = $true
$Label1.width                    = 25
$Label1.height                   = 10
$Label1.location                 = New-Object System.Drawing.Point(25,10)
$Label1.Font                     = 'Segoe UI,14'

$Label2                          = New-Object system.Windows.Forms.Label
$Label2.text                     = "OSDComputername: $OSDComputername"
$Label2.AutoSize                 = $true
$Label2.width                    = 25
$Label2.height                   = 10
$Label2.location                 = New-Object System.Drawing.Point(25,180)
$Label2.Font                     = 'Segoe UI,10'

$Label3                          = New-Object system.Windows.Forms.Label
$Label3.text                     = "DeployRoot: $Deployroot"
$Label3.AutoSize                 = $true
$Label3.width                    = 25
$Label3.height                   = 10
$Label3.location                 = New-Object System.Drawing.Point(25,200)
$Label3.Font                     = 'Segoe UI,10'

$Label4                          = New-Object system.Windows.Forms.Label
$Label4.text                     = "Model: $Model"
$Label4.AutoSize                 = $true
$Label4.width                    = 25
$Label4.height                   = 10
$Label4.location                 = New-Object System.Drawing.Point(25,220)
$Label4.Font                     = 'Segoe UI,10'

$Label5                          = New-Object system.Windows.Forms.Label
$Label5.text                     = "Manufacturer: $Manufacturer"
$Label5.AutoSize                 = $true
$Label5.width                    = 25
$Label5.height                   = 10
$Label5.location                 = New-Object System.Drawing.Point(25,240)
$Label5.Font                     = 'Segoe UI,10'

$Label6                          = New-Object system.Windows.Forms.Label
$Label6.text                     = "Memory(MB): $Memory"
$Label6.AutoSize                 = $true
$Label6.width                    = 25
$Label6.height                   = 10
$Label6.location                 = New-Object System.Drawing.Point(25,260)
$Label6.Font                     = 'Segoe UI,10'

$Label7                          = New-Object system.Windows.Forms.Label
$Label7.text                     = "BIOS/UEFI: $BIOSUEFI"
$Label7.AutoSize                 = $true
$Label7.width                    = 25
$Label7.height                   = 10
$Label7.location                 = New-Object System.Drawing.Point(25,280)
$Label7.Font                     = 'Segoe UI,10'

$Label8                          = New-Object system.Windows.Forms.Label
$Label8.text                     = "SerialNumber: $SerialNumber"
$Label8.AutoSize                 = $true
$Label8.width                    = 25
$Label8.height                   = 10
$Label8.location                 = New-Object System.Drawing.Point(25,300)
$Label8.Font                     = 'Segoe UI,10'

$Label9                          = New-Object system.Windows.Forms.Label
$Label9.text                     = "UUID: $UUID"
$Label9.AutoSize                 = $true
$Label9.width                    = 25
$Label9.height                   = 10
$Label9.location                 = New-Object System.Drawing.Point(25,320)
$Label9.Font                     = 'Segoe UI,10'

$Label10                          = New-Object system.Windows.Forms.Label
$Label10.text                     = "ChassiType: $ChassiType"
$Label10.AutoSize                 = $true
$Label10.width                    = 25
$Label10.height                   = 10
$Label10.location                 = New-Object System.Drawing.Point(25,340)
$Label10.Font                     = 'Segoe UI,10'

$TextBox1                        = New-Object system.Windows.Forms.TextBox
$TextBox1.multiline              = $True
$TextBox1.width                  = 550
$TextBox1.height                 = 100
$TextBox1.location               = New-Object System.Drawing.Point(25,60)
$TextBox1.Font                   = 'Segoe UI,12'
$TextBox1.Text                   = $Message
$TextBox1.ReadOnly               = $True

$Button1                         = New-Object system.Windows.Forms.Button
$Button1.text                    = "Ok"
$Button1.width                   = 60
$Button1.height                  = 30
$Button1.location                = New-Object System.Drawing.Point(500,300)
$Button1.Font                    = 'Segoe UI,12'

$Form.controls.AddRange(@($Label1,$Label2,$Label3,$Label4,$Label5,$Label6,$Label7,$Label8,$Label9,$Label10,$TextBox1,$Button1))

$Button1.Add_Click({ Ok })
    
function Ok (){$Form.close()}

[void]$Form.ShowDialog()
}
    $ScriptFile = $env:TEMP + "\Show-PSDInfo.ps1"
    $File | Out-File -Width 255 -FilePath $ScriptFile

    if(($OSDComputername -eq "") -or ($OSDComputername -eq $null)){$OSDComputername = $env:COMPUTERNAME}
    if(($Deployroot -eq "") -or ($Deployroot -eq $null)){$Deployroot = "NA"}

    Start-Process -FilePath PowerShell.exe -ArgumentList $ScriptFile, "'$Message'", $Severity, $OSDComputername, $Deployroot

    #$ScriptFile = $env:TEMP + "\Show-PSDInfo.ps1"
    #$RunFile = $env:TEMP + "\Show-PSDInfo.cmd"
    #$File | Out-File -Width 255 -FilePath $ScriptFile
    #Set-Content -Path $RunFile -Force -Value "PowerShell.exe -File $ScriptFile -Message ""$Message"" -Severity $Severity -OSDComputername $OSDComputername -Deployroot $Deployroot"
    #Start-Process -FilePath $RunFile
}

Function Get-PSDInputFromScreen
{
    Param
    (
        $Header,
        $Message,

        [ValidateSet("Ok","Yes")]
        $ButtonText
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Header
    $form.Size = New-Object System.Drawing.Size(400,200)
    $form.StartPosition = 'CenterScreen'

    $Button1 = New-Object System.Windows.Forms.Button
    $Button1.Location = New-Object System.Drawing.Point(290,110)
    $Button1.Size = New-Object System.Drawing.Size(80,30)
    $Button1.Text = $ButtonText
    $Button1.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $Button1
    $form.Controls.Add($Button1)

    $Label1 = New-Object System.Windows.Forms.Label
    $Label1.Location = New-Object System.Drawing.Point(10,20)
    $Label1.Size = New-Object System.Drawing.Size(300,20)
    $Label1.Text = $Message
    $form.Controls.Add($Label1)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10,40)
    $textBox.Size = New-Object System.Drawing.Size(360,20)
    $form.Controls.Add($textBox)

    $form.Topmost = $true
    $form.Add_Shown({$textBox.Select()})
    $result = $form.ShowDialog()

    Return $textBox.Text
}

Function Invoke-PSDHelper
{
    Param(
        $MDTDeploySharePath,
        $UserName,
        $Password
    )

    #Connect
    & net use $MDTDeploySharePath $Password /USER:$UserName

    #Import Env
    Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global -Force -Verbose
    Import-Module PSDUtility -Force -Verbose
    Import-Module PSDDeploymentShare -Force -Verbose
    Import-Module PSDGather -Force -Verbose

    dir tsenv: | Out-File "$($env:SystemDrive)\DumpVars.log"
    Get-Content -Path "$($env:SystemDrive)\DumpVars.log"
}

Function Invoke-PSDEXE
{
    [CmdletBinding(SupportsShouldProcess=$true)]

    param(
        [parameter(mandatory=$true,position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Executable,

        [parameter(mandatory=$false,position=1)]
        [string]
        $Arguments
    )

    if($Arguments -eq "")
    {
        Write-Verbose "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -NoNewWindow -Wait -Passthru
    }else{
        Write-Verbose "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru
    }
    Write-Verbose "Returncode is $($ReturnFromEXE.ExitCode)"
    Return $ReturnFromEXE.ExitCode
}

Function Set-PSDCommandWindowsSize
{
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
         [Parameter(Mandatory=$False,Position=0)]
         [int]
         $Height = 40,
         [Parameter(Mandatory=$False,Position=1)]
         [int]
         $Width = 120
         )
    $Console = $host.ui.rawui
    $Buffer  = $Console.BufferSize
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

Function Get-PSDNtpTime
{
(
    [String]$NTPServer
)

# From https://www.madwithpowershell.com/2016/06/getting-current-time-from-ntp-service.html

# Build NTP request packet. We'll reuse this variable for the response packet
$NTPData    = New-Object byte[] 48  # Array of 48 bytes set to zero
$NTPData[0] = 27                    # Request header: 00 = No Leap Warning; 011 = Version 3; 011 = Client Mode; 00011011 = 27

# Open a connection to the NTP service
$Socket = New-Object Net.Sockets.Socket ( 'InterNetwork', 'Dgram', 'Udp' )
$Socket.SendTimeOut    = 2000  # ms
$Socket.ReceiveTimeOut = 2000  # ms
$Socket.Connect( $NTPServer, 123 )

# Make the request
$Null = $Socket.Send(    $NTPData )
$Null = $Socket.Receive( $NTPData )

# Clean up the connection
$Socket.Shutdown( 'Both' )
$Socket.Close()

# Extract relevant portion of first date in result (Number of seconds since "Start of Epoch")
$Seconds = [BitConverter]::ToUInt32( $NTPData[43..40], 0 )

# Add them to the "Start of Epoch", convert to local time zone, and return
( [datetime]'1/1/1900' ).AddSeconds( $Seconds ).ToLocalTime()
} 

Function Write-PSDEvent
{
    param(
        $MessageID,
        $severity,
        $Message
    )

    if($tsenv:EventService -eq ""){return}
    
    # a Deployment has started (EventID 41016)
    # a Deployment completed successfully (EventID 41015)
    # a Deployment failed (EventID 41014)
    # an error occurred (EventID 3)
    # a warning occurred (EventID 2)

    if($tsenv:LTIGUID -eq "")
    {
        $LTIGUID = ([guid]::NewGuid()).guid
        New-Item -Path TSEnv: -Name "LTIGUID" -Value "$LTIGUID" -Force
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:LTIGUID is now: $tsenv:LTIGUID"
        Save-PSDVariables
    }

    $MacAddress = $tsenv:MacAddress001
    $Lguid = $tsenv:LTIGUID
    $id = $tsenv:UUID
    $vmhost = 'NA'
    $ComputerName = $tsenv:OSDComputerName

    $CurrentStep = $tsenv:_SMSTSNextInstructionPointer
	if($CurrentStep -eq ""){$CurrentStep = '0'}

	$TotalSteps = $tsenv:_SMSTSInstructionTableSize
	if($TotalSteps -eq ""){$TotalSteps= '0'}

    $Return = Invoke-WebRequest "$tsenv:EventService/MDTMonitorEvent/PostEvent?uniqueID=$Lguid&computerName=$ComputerName&messageID=$messageID&severity=$severity&stepName=$CurrentStep&totalSteps=$TotalSteps&id=$id,$macaddress&message=$Message&dartIP=&dartPort=&dartTicket=&vmHost=$vmhost&vmName=$ComputerName" -UseBasicParsing
}