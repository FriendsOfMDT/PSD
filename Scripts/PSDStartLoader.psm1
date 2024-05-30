<#
.SYNOPSIS
    Module for the PSD Start
.DESCRIPTION
    Module for the PSD Start to replace the PSDstart BGInfo wallpaper
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
        FileName: PSDStartLoader.psm1
        Solution: PowerShell Deployment for MDT
        Author: PSD Development Team
        Contact: @PowershellCrack
        Primary: @PowershellCrack
        Created: 2022-02-21
        Modified: 2022-04-23
        Version: 1.0.4b

        SEE CHANGELOG.MD

        TODO:
            - Add functionality to WipeDisk button
            - Add functionality to Disk Manager button
            - Add functionality to StatIP buttone
            - Replace Chassis and IP retrivable cmdlets with PSDGather
.Example
#>

#region FUNCTION: Check if running in WinPE
Function Test-WinPE{
    return Test-Path -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlset\Control\MiniNT
}
#endregion

Function Test-DartPE{
    If(Test-WinPE){
        Return Test-Path X:\Sources\Recovery\Tools\MsDartTools.exe
    }
    Else{
        Return $false
    }
}

#region FUNCTION: convert chassis Types to friendly name
Function ConvertTo-ChassisType{
    [CmdletBinding()]
    Param($ChassisId)
    Switch ($ChassisId)
        {
            "1" {$Type = "Other"}
            "2" {$Type = "Virtual Machine"}
            "3" {$Type = "Desktop"}
            "4" {$type = "Low Profile Desktop"}
            "5" {$type = "Pizza Box"}
            "6" {$type = "Mini Tower"}
            "7" {$type = "Tower"}
            "8" {$type = "Portable"}
            "9" {$type = "Laptop"}
            "10" {$type = "Notebook"}
            "11" {$type = "Handheld"}
            "12" {$type = "Docking Station"}
            "13" {$type = "All-in-One"}
            "14" {$type = "Sub-Notebook"}
            "15" {$type = "Space Saving"}
            "16" {$type = "Lunch Box"}
            "17" {$type = "Main System Chassis"}
            "18" {$type = "Expansion Chassis"}
            "19" {$type = "Sub-Chassis"}
            "20" {$type = "Bus Expansion Chassis"}
            "21" {$type = "Peripheral Chassis"}
            "22" {$type = "Storage Chassis"}
            "23" {$type = "Rack Mount Chassis"}
            "24" {$type = "Sealed-Case PC"}
            Default {$type = "Unknown"}
         }
    Return $Type
}
#endregion

#region FUNCTION: Grab all machine platform details
Function Get-PlatformInfo {
# Returns device Manufacturer, Model and BIOS version, populating global variables for use in other functions/ validation
# Note that platformType is appended to psobject by Get-PlatformValid - type is manually defined by user to ensure accuracy
    [CmdletBinding()]
    [OutputType([PsObject])]
    Param()
    try{
        $CIMSystemEncloure = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction Stop
        $CIMComputerSystem = Get-CimInstance -ClassName CIM_ComputerSystem -ErrorAction Stop
        $CIMBios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop

        $ChassisType = ConvertTo-ChassisType -ChassisId $CIMSystemEncloure.chassistypes

        [boolean]$Is64Bit = [boolean]((Get-CimInstance -ClassName 'Win32_Processor' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)
        If ($Is64Bit) { [string]$envOSArchitecture = '64-bit' } Else { [string]$envOSArchitecture = '32-bit' }

        New-Object -TypeName PsObject -Property @{
            "computerName" = [system.environment]::MachineName
            "computerDomain" = $CIMComputerSystem.Domain
            "platformBIOS" = $CIMBios.SMBIOSBIOSVersion
            "platformManufacturer" = $CIMComputerSystem.Manufacturer
            "platformModel" = $CIMComputerSystem.Model
            "AssetTag" = $CIMSystemEncloure.SMBiosAssetTag
            "SerialNumber" = $CIMBios.SerialNumber
            "Architecture" = $envOSArchitecture
            "Chassis" = $ChassisType
            }
    }
    catch{Write-Output "CRITICAL" "Failed to get information from Win32_Computersystem/ Win32_BIOS"}
}
#endregion

#region FUNCTION: Converts IP Address to binary
Function Convert-IPv4AddressToBinaryString {
    Param(
        [IPAddress]$IPAddress='0.0.0.0'
    )
    $addressBytes=$IPAddress.GetAddressBytes()

    $strBuilder=New-Object -TypeName Text.StringBuilder
    foreach($byte in $addressBytes){
        $8bitString=[Convert]::ToString($byte,2).PadRight(8,'0')
        [void]$strBuilder.Append($8bitString)
    }
    Return $strBuilder.ToString()
}
#endregion

#region FUNCTION: Converts IP Address to integer
Function Convert-IPv4ToInt {
    [CmdletBinding()]
    Param(
        [String]$IPv4Address
    )
    Try{
        $ipAddress=[IPAddress]::Parse($IPv4Address)

        $bytes=$ipAddress.GetAddressBytes()
        [Array]::Reverse($bytes)

        [System.BitConverter]::ToUInt32($bytes,0)
    }Catch{
        Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
    }
}
#endregion

#region FUNCTION: Converts integer to IP Address
Function Convert-IntToIPv4 {
    [CmdletBinding()]
    Param(
        [uint32]$Integer
    )
    Try{
        $bytes=[System.BitConverter]::GetBytes($Integer)
        [Array]::Reverse($bytes)
        ([IPAddress]($bytes)).ToString()
    }Catch{
        Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
    }
}
#endregion

#region FUNCTION: Converts subnet to a CIDR address (eg. /24)
Function Add-IntToIPv4Address {
    Param(
        [String]$IPv4Address,
        [int64]$Integer
    )
    Try{
        $ipInt = Convert-IPv4ToInt -IPv4Address $IPv4Address -ErrorAction Stop
        $ipInt += $Integer

        Convert-IntToIPv4 -Integer $ipInt
    }Catch{
        Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
    }
}
#endregion

#region FUNCTION: Converts a CIDR to a subnet address
Function Convert-CIDRToNetmask {
    [CmdletBinding()]
    Param(
    [ValidateRange(0,32)]
        [int16]$PrefixLength=0
    )
    $bitString=('1' * $PrefixLength).PadRight(32,'0')

    $strBuilder = New-Object -TypeName Text.StringBuilder

    for($i=0;$i -lt 32;$i+=8){
        $8bitString=$bitString.Substring($i,8)
        [void]$strBuilder.Append("$([Convert]::ToInt32($8bitString,2)).")
    }

    Return $strBuilder.ToString().TrimEnd('.')
}
#endregion

#region FUNCTION: Converts subnet to a CIDR address (eg. /24)
Function Convert-NetmaskToCIDR {
    [CmdletBinding()]
    Param(
        [String]$SubnetMask='255.255.255.0'
    )
    $byteRegex='^(0|128|192|224|240|248|252|254|255)$'
    $invalidMaskMsg="Invalid SubnetMask specified [$SubnetMask]"
    Try{
        $netMaskIP=[IPAddress]$SubnetMask
        $addressBytes=$netMaskIP.GetAddressBytes()

        $strBuilder=New-Object -TypeName Text.StringBuilder

        $lastByte=255
        foreach($byte in $addressBytes){

            # Validate byte matches net mask value
            if($byte -notmatch $byteRegex){
                Write-Error -Message $invalidMaskMsg -Category InvalidArgument -ErrorAction Stop
            }
            elseif($lastByte -ne 255 -and $byte -gt 0){
                Write-Error -Message $invalidMaskMsg -Category InvalidArgument -ErrorAction Stop
            }

            [void]$strBuilder.Append([Convert]::ToString($byte,2))
            $lastByte=$byte
        }

        Return ($strBuilder.ToString().TrimEnd('0')).Length
    }
    Catch{
        Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
    }
}
#endregion

#region FUNCTION: Get the subnet information
Function Get-IPv4Subnet {
    [CmdletBinding(DefaultParameterSetName='PrefixLength')]
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [IPAddress]$IPAddress,

        [Parameter(Position=1,ParameterSetName='PrefixLength')]
        [Int16]$PrefixLength=24,

        [Parameter(Position=1,ParameterSetName='SubnetMask')]
        [IPAddress]$SubnetMask
    )
    Begin{
        $outputObject = New-Object -TypeName PSObject
    }
    Process{
        Try{
            if($PSCmdlet.ParameterSetName -eq 'SubnetMask'){
                $PrefixLength= Convert-NetmaskToCIDR -SubnetMask $SubnetMask -ErrorAction Stop
            }else{
                $SubnetMask = Convert-CIDRToNetmask -PrefixLength $PrefixLength -ErrorAction Stop
            }

            $netMaskInt = Convert-IPv4ToInt -IPv4Address $SubnetMask
            $ipInt = Convert-IPv4ToInt -IPv4Address $IPAddress

            $networkID = Convert-IntToIPv4 -Integer ($netMaskInt -band $ipInt)

            $maxHosts=[math]::Pow(2,(32-$PrefixLength)) - 2
            $broadcast = Add-IntToIPv4Address -IPv4Address $networkID -Integer ($maxHosts+1)

            $firstIP = Add-IntToIPv4Address -IPv4Address $networkID -Integer 1
            $lastIP = Add-IntToIPv4Address -IPv4Address $broadcast -Integer -1

            if($PrefixLength -eq 32){
                $broadcast=$networkID
                $firstIP=$null
                $lastIP=$null
                $maxHosts=0
            }

            $memberParam=@{
                InputObject=$outputObject;
                MemberType='NoteProperty';
                Force=$true;
            }
            Add-Member @memberParam -Name CidrID -Value "$networkID/$PrefixLength"
            Add-Member @memberParam -Name NetworkID -Value $networkID
            Add-Member @memberParam -Name SubnetMask -Value $SubnetMask
            Add-Member @memberParam -Name PrefixLength -Value $PrefixLength
            Add-Member @memberParam -Name HostCount -Value $maxHosts
            Add-Member @memberParam -Name FirstHostIP -Value $firstIP
            Add-Member @memberParam -Name LastHostIP -Value $lastIP
            Add-Member @memberParam -Name Broadcast -Value $broadcast
        }
        Catch{
            Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
        }
    }
    End{
        Return $outputObject
    }
}
#endregion

#region FUNCTION: Convert network status integer to status message
function ConvertTo-NetworkStatus{
    Param([int]$Value)

    switch($Value){
       0 {$status = "Disconnected" }
       1 {$status = "Connecting" }
       2 {$status = "Connected" }
       3 {$status = "Disconnecting" }
       4 {$status = "Hardware not present" }
       5 {$status = "Hardware disabled" }
       6 {$status = "Hardware malfunction" }
       7 {$status = "Media disconnected" }
       8 {$status = "Authenticating" }
       9 {$status = "Authentication succeeded" }
       10 {$status = "Authentication failed" }
       11 {$status = "Invalid Address" }
       12 {$status = "Credentials Required" }
       Default {$status =  "Not connected" }
  }

  return $status

}
#endregion

#region FUNCTION: Grabs current client gateway
Function Get-ClientGateway
{
# Uses WMI to return IPv4-enabled network adapter gateway address for use in location identification
    [CmdletBinding()]
    [OutputType([PsObject])]
    Param()
    $arrGateways = (Get-CIMInstance -ClassName Win32_networkAdapterConfiguration | Where-Object {$_.IPEnabled}).DefaultIPGateway
    foreach ($gateway in $arrGateways) {If ([string]::IsNullOrWhiteSpace($gateway)){}Else{$clientGateway = $gateway}}
    If ($clientGateway) {
        New-Object -TypeName PsObject -Property @{"IPv4address" = $clientGateway}
    }
    Else {
        Write-Host "Unable to detect Client IPv4 Gateway Address, check IPv4 network adapter/ DHCP configuration" -ForegroundColor Red
    }
}
#endregion

Function Get-NetworkInterface {
    [CmdletBinding()]
    Param(
        [switch]$PassThru
    )
    #pull each network interface on device
    $netInt = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Where-Object { $_.IPEnabled -eq $true }
    $Interfaces = $netInt | Where-Object { $_ -notmatch '\b(?:0{1,3}\.){3}\d{1,3}\b|(169.254)|::' }

    #grab all nic in wmi to compare later (its faster than querying individually)
    $wminics = Get-CimInstance -ClassName Win32_NetworkAdapter | Where-Object {($null -ne $_.MACAddress) -and ($_.Name -notlike '*Bluetooth*') -and ($_.Name -notlike '*Miniport*') -and ($_.Name -notlike '*Xbox*') }


    $InterfaceDetails = @()
    Foreach($Interface in $Interfaces){
        $Status = (ConvertTo-NetworkStatus ($wminics | Where-Object {$_.Name -eq $Interface.Description}).NetConnectionStatus)

        $InterfaceDetails += New-Object -TypeName PSObject -Property @{
            InterfaceName=$Interface.Description;
            MacAddress=$Interface.MACAddress;
            IPAddressv4=$Interface.IPAddress[0];
            IPAddressv6=$Interface.IPAddress[1];
            DefaultGateway=$Interface.DefaultIPGateway | Select -ExpandProperty $_
            Status = $Status
        }
    }

    If($PassThru){
        return $InterfaceDetails
    }Else{
        $PrimaryInterface = $InterfaceDetails | where {$null -ne $_.DefaultGateway}
        return $PrimaryInterface
    }
}


#region FUNCTION: Get the primary interface not matter the number of nics
Function Get-InterfaceDetails
{
    #pull each network interface on device
    #use .net class due to limited commands in PE
    $nics=[Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {($_.NetworkInterfaceType -ne 'Loopback') -and ($_.NetworkInterfaceType -ne 'Ppp') -and ($_.Supports('IPv4'))}

    #grab all nic in wmi to compare later (its faster than querying individually)
    $wminics = Get-CimInstance -ClassName win32_NetworkAdapter | Where-Object {($null -ne $_.MACAddress) -and ($_.Name -notlike '*Bluetooth*') -and ($_.Name -notlike '*Miniport*') -and ($_.Name -notlike '*Xbox*') }

    Write-Debug ("Detected {0} Network Inferfaces" -f $nics.Count)

    #$InterfaceDetails =
    $interface = $nics[0]
    foreach($interface in $nics ){

        $ipProperties=$interface.GetIPProperties()
        $ipv4Properties=$ipProperties.GetIPv4Properties()

        $ipProperties.UnicastAddresses | where Address -NotLike fe80* | Foreach {
            if(!($_.Address.IPAddressToString)){
                continue
            }


            if($null -ne $ipProperties.GatewayAddresses.Address.IPAddressToString){
                $gateway=$ipProperties.GatewayAddresses.Address.IPAddressToString

                $adapterInfo = $wminics | Where Name -eq $interface.Description |
                        select MACAddress,Manufacturer,netconnectionstatus

                $subnetInfo = Get-IPv4Subnet -IPAddress $_.Address.IPAddressToString -PrefixLength $_.PrefixLength
                New-Object -TypeName PSObject -Property @{
                        InterfaceName=$interface.Name;
                        InterfaceDescription=$interface.Description;
                        InterfaceType=$interface.NetworkInterfaceType;
                        MacAddress=$adapterInfo.MACAddress;
                        AdapterManufacturer=$adapterInfo.Manufacturer;
                        NetworkID=$subnetInfo.NetworkID;
                        IPAddress=$_.Address.IPAddressToString;
                        SubnetMask=$subnetInfo.SubnetMask;
                        CidrID=$subnetInfo.CidrID;
                        DnsAddresses=$ipProperties.DnsAddresses.IPAddressToString;
                        GatewayAddresses=$gateway;
                        DhcpEnabled=$ipv4Properties.IsDhcpEnabled;
                        DhcpServer=$ipProperties.DhcpServerAddresses.IPAddressToString
                        Status=(ConvertTo-NetworkStatus $adapterInfo.netconnectionstatus)
                    }

                }
                Write-Debug ("Interface Detected: {0}" -f $interface.Name)
                Write-Debug ("MAC Address: {0}" -f $adapterInfo.MACAddress)
                Write-Debug ("IP Address assigned: {0}" -f $_.Address.IPAddressToString)
                Write-Debug ("Gateway assigned: {0}" -f $gateway)
            }
    }

    #grab local route to find primary interface
    #wmi class is not avaliable WinPE, instead parse route print command
    <#
    Try{
        Write-Debug "Processing routing table..."
        $computer = 'localhost'
        $wmi = Get-CimInstance -namespace root\StandardCimv2 -ComputerName 'localhost' -Query "Select * from MSFT_NetRoute" -ErrorAction Stop
        $route = $wmi | ? { $_.DestinationPrefix -eq '0.0.0.0/0' } |
            Select @{Name = "Destination"; Expression = {$_.DestinationPrefix}},
                     @{Name = "Gateway"; Expression = {$_.NextHop}},
                     @{Name = "Metric"; Expression = {$_.InterfaceMetric}} -First 1
    }
    Catch{
        $tmpRoute = ((route print | ? { $_.trimstart() -like "0.0.0.0*" }) | % {$_}).split() | ? { $_ }
        $route = @{'Destination' = $tmpRoute[0];
               'Netmask'     = $tmpRoute[1];
               'Gateway'     = $tmpRoute[2];
               #'Interface'   = $tmpRoute[3];
               'Metric'      = $tmpRoute[4];
              }
    }
    #>
    $currentGateway = Get-ClientGateway

    Write-Debug "Determining primary interface by using routing table..."

    $PrimaryInterface = $InterfaceDetails | where {($_.GatewayAddresses -eq $currentGateway.IPv4address) -and ($_.Status -eq 'Connected')}
    return $PrimaryInterface
}
#endregion

Function New-PSDStartLoader {
    <#
        .SYNOPSIS
        Present PSDStartLoader like interface with status

        .LINK
        https://tiberriver256.github.io/powershell/PowerShellProgress-Pt3/
    #>
    [CmdletBinding()]
    Param(
        [string]$LogoImgPath,
        [switch]$FullScreen
    )
    
    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    $syncHash = [hashtable]::Synchronized(@{})
    $PSDRunSpace =[runspacefactory]::CreateRunspace()
    $syncHash.Runspace = $PSDRunSpace
    $syncHash.InPE = Test-WinPE
    $syncHash.DartTools = Test-DartPE
    $SyncHash.DebugMode = $PSDDeBug
    $SyncHash.Indeterminate = $False
    $SyncHash.ProgressColor = 'LightGreen'
    $SyncHash.ShowPercentage = 'Visible'
    $SyncHash.LogoImg = $LogoImgPath
    $syncHash.Status = ''
    $syncHash.PercentComplete = 0
    $syncHash.Countdown = 0
    $syncHash.Fullscreen = $FullScreen
    $PSDRunSpace.ApartmentState = "STA"
    $PSDRunSpace.ThreadOptions = "ReuseThread"
    $data = $PSDRunSpace.Open() | Out-Null
    $PSDRunSpace.SessionStateProxy.SetVariable("syncHash",$syncHash)
    $PowerShellCommand = [PowerShell]::Create().AddScript({

    [string]$xaml = @"
    <Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    Title="PSDStartLoader"
    Width="1024"
    Height="768"
    Background="#012456"
    WindowStartupLocation="CenterScreen"
    mc:Ignorable="d">
<Window.Resources>
    <ResourceDictionary>

        <Canvas x:Key="icons_cog" Width="24" Height="24">
            <Path Stretch="Fill" Fill="White" Data="M12,8A4,4 0 0,1 16,12A4,4 0 0,1 12,16A4,4 0 0,1 8,12A4,4 0 0,1 12,8M12,10A2,2 0 0,0 10,12A2,2 0 0,0 12,14A2,2 0 0,0 14,12A2,2 0 0,0 12,10M10,22C9.75,22 9.54,21.82 9.5,21.58L9.13,18.93C8.5,18.68 7.96,18.34 7.44,17.94L4.95,18.95C4.73,19.03 4.46,18.95 4.34,18.73L2.34,15.27C2.21,15.05 2.27,14.78 2.46,14.63L4.57,12.97L4.5,12L4.57,11L2.46,9.37C2.27,9.22 2.21,8.95 2.34,8.73L4.34,5.27C4.46,5.05 4.73,4.96 4.95,5.05L7.44,6.05C7.96,5.66 8.5,5.32 9.13,5.07L9.5,2.42C9.54,2.18 9.75,2 10,2H14C14.25,2 14.46,2.18 14.5,2.42L14.87,5.07C15.5,5.32 16.04,5.66 16.56,6.05L19.05,5.05C19.27,4.96 19.54,5.05 19.66,5.27L21.66,8.73C21.79,8.95 21.73,9.22 21.54,9.37L19.43,11L19.5,12L19.43,13L21.54,14.63C21.73,14.78 21.79,15.05 21.66,15.27L19.66,18.73C19.54,18.95 19.27,19.04 19.05,18.95L16.56,17.95C16.04,18.34 15.5,18.68 14.87,18.93L14.5,21.58C14.46,21.82 14.25,22 14,22H10M11.25,4L10.88,6.61C9.68,6.86 8.62,7.5 7.85,8.39L5.44,7.35L4.69,8.65L6.8,10.2C6.4,11.37 6.4,12.64 6.8,13.8L4.68,15.36L5.43,16.66L7.86,15.62C8.63,16.5 9.68,17.14 10.87,17.38L11.24,20H12.76L13.13,17.39C14.32,17.14 15.37,16.5 16.14,15.62L18.57,16.66L19.32,15.36L17.2,13.81C17.6,12.64 17.6,11.37 17.2,10.2L19.31,8.65L18.56,7.35L16.15,8.39C15.38,7.5 14.32,6.86 13.12,6.62L12.75,4H11.25Z" />
        </Canvas>

        <Canvas x:Key="icons_ps" Width="24" Height="24">
            <Path Fill="White" Data="M20,19V7H4V19H20M20,3A2,2 0 0,1 22,5V19A2,2 0 0,1 20,21H4A2,2 0 0,1 2,19V5C2,3.89 2.9,3 4,3H20M13,17V15H18V17H13M9.58,13L5.57,9H8.4L11.7,12.3C12.09,12.69 12.09,13.33 11.7,13.72L8.42,17H5.59L9.58,13Z" />
        </Canvas>

        <Canvas x:Key="icons_target" Width="24" Height="24">
            <Path Width="20" Height="20" Fill="White" Stretch="Uniform" Data="M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2M12,4A8,8 0 0,1 20,12A8,8 0 0,1 12,20A8,8 0 0,1 4,12A8,8 0 0,1 12,4M12,6A6,6 0 0,0 6,12A6,6 0 0,0 12,18A6,6 0 0,0 18,12A6,6 0 0,0 12,6M12,8A4,4 0 0,1 16,12A4,4 0 0,1 12,16A4,4 0 0,1 8,12A4,4 0 0,1 12,8M12,10A2,2 0 0,0 10,12A2,2 0 0,0 12,14A2,2 0 0,0 14,12A2,2 0 0,0 12,10Z"/>
        </Canvas>

        <Canvas x:Key="icons_disk" Width="24" Height="24">
            <Path Fill="Black" Data="M6,2H18A2,2 0 0,1 20,4V20A2,2 0 0,1 18,22H6A2,2 0 0,1 4,20V4A2,2 0 0,1 6,2M12,4A6,6 0 0,0 6,10C6,13.31 8.69,16 12.1,16L11.22,13.77C10.95,13.29 11.11,12.68 11.59,12.4L12.45,11.9C12.93,11.63 13.54,11.79 13.82,12.27L15.74,14.69C17.12,13.59 18,11.9 18,10A6,6 0 0,0 12,4M12,9A1,1 0 0,1 13,10A1,1 0 0,1 12,11A1,1 0 0,1 11,10A1,1 0 0,1 12,9M7,18A1,1 0 0,0 6,19A1,1 0 0,0 7,20A1,1 0 0,0 8,19A1,1 0 0,0 7,18M12.09,13.27L14.58,19.58L17.17,18.08L12.95,12.77L12.09,13.27Z" />
        </Canvas>

        <Canvas x:Key="icons_wipe" Width="24" Height="24">
            <Path Fill="Black" Data="M12,4C5,4 2,9 2,9L9,16C9,16 9.5,15.1 10.4,14.5L10.7,16.5C10.3,16.8 10,17.4 10,18A2,2 0 0,0 12,20A2,2 0 0,0 14,18C14,17.1 13.5,16.4 12.7,16.1L12.3,14C14.1,14.2 15,16 15,16L22,9C22,9 19,4 12,4M15.1,13.1C14.3,12.5 13.3,12 12,12L11,6.1C11.3,6 11.7,6 12,6C15.7,6 18.1,7.7 19.3,8.9L15.1,13.1M8.9,13.1L4.7,8.9C5.5,8 7,7 9,6.4L10,12.4C9.6,12.6 9.2,12.8 8.9,13.1Z" />
        </Canvas>

        <Canvas x:Key="icons_exit"  Width="24" Height="24">
            <Path Fill="Black" Data="M16.56,5.44L15.11,6.89C16.84,7.94 18,9.83 18,12A6,6 0 0,1 12,18A6,6 0 0,1 6,12C6,9.83 7.16,7.94 8.88,6.88L7.44,5.44C5.36,6.88 4,9.28 4,12A8,8 0 0,0 12,20A8,8 0 0,0 20,12C20,9.28 18.64,6.88 16.56,5.44M13,3H11V13H13" />
        </Canvas>

        <Style TargetType="{x:Type Window}">
            <Setter Property="FontFamily" Value="Segoe UI" />
            <Setter Property="FontWeight" Value="Light" />
            <Setter Property="Background" Value="#012456" />
            <Setter Property="Foreground" Value="white" />
        </Style>

        <Style x:Key="CheckRadioFocusVisual">
            <Setter Property="Control.Template">
                <Setter.Value>
                    <ControlTemplate>
                        <Rectangle Margin="24,0,0,0" SnapsToDevicePixels="true" Stroke="{DynamicResource {x:Static SystemColors.ControlTextBrushKey}}" StrokeThickness="1" StrokeDashArray="1 2"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ModernCircleSlider" TargetType="{x:Type CheckBox}">
            <Setter Property="Foreground" Value="{DynamicResource {x:Static SystemColors.ControlTextBrushKey}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type CheckBox}">
                        <ControlTemplate.Resources>
                            <Storyboard x:Key="StoryboardIsChecked">
                                <DoubleAnimationUsingKeyFrames Storyboard.TargetProperty="(UIElement.RenderTransform).(TransformGroup.Children)[3].(TranslateTransform.X)" Storyboard.TargetName="CheckFlag">
                                    <EasingDoubleKeyFrame KeyTime="0" Value="0"/>
                                    <EasingDoubleKeyFrame KeyTime="0:0:0.2" Value="24"/>
                                </DoubleAnimationUsingKeyFrames>
                            </Storyboard>
                            <Storyboard x:Key="StoryboardIsCheckedOff">
                                <DoubleAnimationUsingKeyFrames Storyboard.TargetProperty="(UIElement.RenderTransform).(TransformGroup.Children)[3].(TranslateTransform.X)" Storyboard.TargetName="CheckFlag">
                                    <EasingDoubleKeyFrame KeyTime="0" Value="24"/>
                                    <EasingDoubleKeyFrame KeyTime="0:0:0.2" Value="0"/>
                                </DoubleAnimationUsingKeyFrames>
                            </Storyboard>
                        </ControlTemplate.Resources>
                        <BulletDecorator Background="Transparent" SnapsToDevicePixels="true">
                            <BulletDecorator.Bullet>
                                <Border x:Name="ForegroundPanel" BorderThickness="1" Width="55" Height="30" CornerRadius="15">
                                    <Canvas>
                                        <Border Background="White" x:Name="CheckFlag" CornerRadius="15" VerticalAlignment="Center" BorderThickness="1" Width="29" Height="28" RenderTransformOrigin="0.5,0.5">
                                            <Border.RenderTransform>
                                                <TransformGroup>
                                                    <ScaleTransform/>
                                                    <SkewTransform/>
                                                    <RotateTransform/>
                                                    <TranslateTransform/>
                                                </TransformGroup>
                                            </Border.RenderTransform>
                                            <Border.Effect>
                                                <DropShadowEffect ShadowDepth="1" Direction="180" />
                                            </Border.Effect>
                                        </Border>
                                    </Canvas>
                                </Border>
                            </BulletDecorator.Bullet>
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" Margin="{TemplateBinding Padding}" RecognizesAccessKey="True" SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}" VerticalAlignment="Center"/>
                        </BulletDecorator>
                        <ControlTemplate.Triggers>
                            <Trigger Property="HasContent" Value="true">
                                <Setter Property="FocusVisualStyle" Value="{StaticResource CheckRadioFocusVisual}"/>
                                <Setter Property="Padding" Value="4,0,0,0"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="false">
                                <Setter Property="Foreground" Value="{DynamicResource {x:Static SystemColors.GrayTextBrushKey}}"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <!--<Setter TargetName="ForegroundPanel" Property="Background" Value="{DynamicResource Accent}" />-->
                                <Setter TargetName="ForegroundPanel" Property="Background" Value="Green" />
                                <Trigger.EnterActions>
                                    <BeginStoryboard x:Name="BeginStoryboardCheckedTrue" Storyboard="{StaticResource StoryboardIsChecked}" />
                                    <RemoveStoryboard BeginStoryboardName="BeginStoryboardCheckedFalse" />
                                </Trigger.EnterActions>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="False">
                                <Setter TargetName="ForegroundPanel" Property="Background" Value="Gray" />
                                <Trigger.EnterActions>
                                    <BeginStoryboard x:Name="BeginStoryboardCheckedFalse" Storyboard="{StaticResource StoryboardIsCheckedOff}" />
                                    <RemoveStoryboard BeginStoryboardName="BeginStoryboardCheckedTrue" />
                                </Trigger.EnterActions>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>


        <Style x:Key="ButtonLightGrayRounded" TargetType="{x:Type Button}">
            <Setter Property="Background" Value="LightGray" />
            <Setter Property="Foreground" Value="Black" />
            <Setter Property="FontSize" Value="15" />
            <Setter Property="SnapsToDevicePixels" Value="True" />

            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button" >

                        <Border Name="border"
                    BorderThickness="1"
                    Padding="4,2"
                    BorderBrush="DarkGray"
                    CornerRadius="5,0,5,0"
                    Background="#FFE8EDF9">
                            <ContentPresenter HorizontalAlignment="Center"
                                    VerticalAlignment="Center"
                                    TextBlock.TextAlignment="Center"
                                    />
                        </Border>

                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="lightblue" />
                            </Trigger>

                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="LightGray" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>


    </ResourceDictionary>
</Window.Resources>
<Grid x:Name="background" Height="768" HorizontalAlignment="Center" VerticalAlignment="Center">

    <Grid Width="1024" Height="614" HorizontalAlignment="Center" VerticalAlignment="Top" Background="#FFFFFFFF" Margin="0,50,0,0" >
        <StackPanel Margin="20,0,512,0">
            <Label Content="Progress:" HorizontalAlignment="Left" FontWeight="Bold" FontSize="16" VerticalAlignment="Top" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Left"/>
            <TextBlock x:Name="txtStatus" Text="Status" Foreground="Black" FontSize="18" HorizontalAlignment="Left" Width="962" Margin="10,0,0,0" />

            <Label Content="Computer Info:" HorizontalAlignment="Left" FontWeight="Bold" FontSize="16" Margin="0,20,0,0" VerticalAlignment="Top" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Left"/>
            <Grid Height="135" Width="323" HorizontalAlignment="Left" >
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="auto" MinWidth="121"></ColumnDefinition>
                    <ColumnDefinition></ColumnDefinition>
                    <ColumnDefinition Width="auto"></ColumnDefinition>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                </Grid.RowDefinitions>
                <Label Content="Manufacturer:" Grid.Row="0" Grid.Column="0" HorizontalAlignment="Right" FontSize="16"  VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" Margin="0,9"/>
                <TextBox x:Name="txtManufacturer" Text="Demo" Grid.Row="0" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="18" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                <Label Content="Model:" Grid.Row="1" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                <TextBox x:Name="txtModel" Text="Demo" Grid.Row="1" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="18" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                <Label Content="Serial Number:" Grid.Row="2" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" Margin="0,9"/>
                <TextBox x:Name="txtSerialNumber" Text="Demo" Grid.Row="2" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="18" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                <Label Content="Asset Tag:" Grid.Row="3" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" Margin="0,9"/>
                <TextBox x:Name="txtAssetTag" Text="Demo" Grid.Row="3" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="18" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
            </Grid>
            <Label Content="Network Info:" HorizontalAlignment="Left" FontWeight="Bold" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Left"/>

            <Grid Height="165" Width="314" HorizontalAlignment="Left" >
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="auto" MinWidth="121"></ColumnDefinition>
                    <ColumnDefinition></ColumnDefinition>
                    <ColumnDefinition Width="auto"></ColumnDefinition>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                    <RowDefinition></RowDefinition>
                </Grid.RowDefinitions>
                <Label Content="Mac Address:" Grid.Row="0" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                <TextBox x:Name="txtMac" Text="Demo" Grid.Row="0" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="18" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                <Label Content="IP Address:" Grid.Row="1" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                <TextBox x:Name="txtIP" Text="Demo" Grid.Row="1" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="18" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                <Label Content="Subnet:" Grid.Row="2" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                <TextBox x:Name="txtSubnet" Text="Demo" Grid.Row="2" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="18" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                <Label Content="Default Gateway:" Grid.Row="3" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right"/>
                <TextBox x:Name="txtGateway" Text="Demo" Grid.Row="3" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="18" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                <Label Content="DHCP Server:" Grid.Row="4" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                <TextBox x:Name="txtDHCP" Text="Demo" Grid.Row="4" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="18" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
            </Grid>



            <Button x:Name="btnAddStaticIP" Style="{DynamicResource ButtonLightGrayRounded}" Width="129" HorizontalAlignment="Left" Margin="20">
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblAddStaticIP" Content="Configure Static IP" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="Black" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_cog}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>
        </StackPanel>

        <TextBlock x:Name="txtPercentage" Text="{Binding ElementName=ProgressBar, Path=Value, StringFormat={}{0:0}%}" HorizontalAlignment="Center" VerticalAlignment="Top" Foreground="#012456" Margin="0,564,0,0" />
        <ProgressBar x:Name="ProgressBar" Width="724" Height="4" Margin="0,585,0,0" HorizontalAlignment="Center" VerticalAlignment="Top" Background="white" Foreground="Green" />
        <StackPanel HorizontalAlignment="Left" Width="200" VerticalAlignment="Center" Height="478" Margin="824,0,0,0">
            <TextBlock x:Name="txtCountdown" Text="10" HorizontalAlignment="Center" VerticalAlignment="Top" Foreground="#012456" FontSize="24" />

            <StackPanel Orientation="Horizontal" Margin="0,0,20,10" >
                <TextBlock x:Name="txtDebug" Text="Debug Mode" Foreground="Black" VerticalAlignment="Center" Margin="10" FontSize="18"/>
                <CheckBox x:Name="chkDebug" Style="{DynamicResource ModernCircleSlider}" Margin="0,10,20,10" Width="58" HorizontalAlignment="Right" />
            </StackPanel>


            <Button x:Name="btnWipeDisk" Style="{DynamicResource ButtonLightGrayRounded}" Width="122" HorizontalAlignment="Right" Margin="0,0,20,10" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblWipeDisk" Content="Wipe Disks" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="24" Height="20" Fill="Black" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_wipe}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>

            <Button x:Name="btnOpenDisk" Style="{DynamicResource ButtonLightGrayRounded}" Width="122" HorizontalAlignment="Right" Margin="0,10,20,10" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblOpenDisk" Content="Show Disks" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="DarkGray" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_disk}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>


            <Button x:Name="btnOpenPSWindow" Style="{DynamicResource ButtonLightGrayRounded}" Width="122" HorizontalAlignment="Right" Margin="0,10,20,10" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblOpenPSWindow" Content="Launch PowerShell" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="Blue" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_ps}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>

            <Button x:Name="btnDartPE" Style="{DynamicResource ButtonLightGrayRounded}" Width="122" HorizontalAlignment="Right" Margin="0,10,20,10" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblDartPE" Content="Launch Dart PE" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="Green" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_target}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>

            <Button x:Name="btnExit" Style="{DynamicResource ButtonLightGrayRounded}" Width="122" HorizontalAlignment="Right" Margin="0,10,20,10" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblExit" Content="Exit" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="Red" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_exit}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>


        </StackPanel>


    </Grid>
    <Image x:Name="imgLogo" Width="72" Height="66" Margin="23,688,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" />
    <Label Width="423" Margin="0,0,20,10" HorizontalAlignment="Right" VerticalAlignment="Bottom" VerticalContentAlignment="Center" HorizontalContentAlignment="Right" Content="Powershell Deployment" FontSize="36" Foreground="White" Height="70" />


</Grid>
</Window>
"@

        [xml]$xaml = $xaml -replace 'mc:Ignorable="d"',$FullScreenXaml -replace "x:N",'N' -replace '^<Win.*', '<Window'
        $reader=(New-Object System.Xml.XmlNodeReader $xaml)
        $syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
        #===========================================================================
        # Store Form Objects In PowerShell
        #===========================================================================
        $xaml.SelectNodes("//*[@Name]") | %{ $SyncHash."$($_.Name)" = $SyncHash.Window.FindName($_.Name)}
        
        # INNER  FUNCTIONS
        #Closes UI objects and exits (within runspace)
        Function Close-PSDStartLoader
        {
            if ($syncHash.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
            #if runspace has not errored Dispose the UI
            if (!($syncHash.isClosing)) { Stop-PSDStartLoader }
        }

        #Disposes UI objects and exits (within runspace)
        Function Stop-PSDStartLoader
        {
            $syncHash.Window.Close()
            $PSDRunSpace.Close()
            $PSDRunSpace.Dispose()
        }

        #add xaml elements that you want to update often
        #the value must also be added to top of function as synchash property
        #then it can be called by that value later on
        $updateBlock = {
            #progress bar
            $SyncHash.ProgressBar.IsIndeterminate = $SyncHash.Indeterminate
            $SyncHash.ProgressBar.Value = $SyncHash.PercentComplete
            #$SyncHash.ProgressBar.Foreground = $Runspace.ProgressColor

            #Text boxes
            $SyncHash.txtPercentage.Visibility = $SyncHash.ShowPercentage
                       
            $SyncHash.txtStatus.Text = $SyncHash.Status
        }

        $syncHash.Window.Add_SourceInitialized( {
            ## Before the window's even displayed ...
            ## We'll create a timer
            $timer = new-object System.Windows.Threading.DispatcherTimer
            ## Which will fire 4 times every second
            $timer.Interval = [TimeSpan]"0:0:0.01"
            ## And will invoke the $updateBlock
            $timer.Add_Tick( $updateBlock )
            ## Now start the timer running
            $timer.Start()
            if( $timer.IsEnabled ) {
               Write-Host "Clock is running. Don't forget: RIGHT-CLICK to close it."
            } else {
               $clock.Close()
               Write-Error "Timer didn't start"
            }
        } )

        #maximze window if called
        If($SyncHash.Fullscreen){
            $syncHash.Window.WindowState = "Maximized"
            $syncHash.Window.WindowStyle = "None"
        }

        #Image
        $SyncHash.imgLogo.Source = $SyncHash.LogoImg

        #Update Debug Checkbox
        $SyncHash.txtCountdown.Visibility = 'Hidden'
        $SyncHash.chkDebug.IsChecked = $SyncHash.DebugMode
        [System.Windows.RoutedEventHandler]$Script:CheckedEventHandler = {
            $SyncHash.DebugMode = $true
        }
        #Do Debug actions when checked
        $SyncHash.chkDebug.AddHandler([System.Windows.Controls.CheckBox]::CheckedEvent, $CheckedEventHandler)

        [System.Windows.RoutedEventHandler]$Script:UnCheckedEventHandler = {
            $SyncHash.DebugMode = $false
        }
        #Do Debug action when unchecked
        $SyncHash.chkDebug.AddHandler([System.Windows.Controls.CheckBox]::UncheckedEvent, $UnCheckedEventHandler)
        
        #hide options not allowed in Windows
        If(-Not($SyncHash.InPE) ){
            $syncHash.btnDartPE.Visibility = 'Hidden'
            $syncHash.btnWipeDisk.Visibility = 'Hidden'
            $syncHash.btnAddStaticIP.Visibility = 'Hidden'
        }

        If(-Not($syncHash.DartTools)){
            $syncHash.btnDartPE.Visibility = 'hidden'
        }

        #Add smooth closing for Window
        $syncHash.Window.Add_Loaded({ $syncHash.isLoaded = $True })
    	$syncHash.Window.Add_Closing({ $syncHash.isClosing = $True; Close-PSDStartLoader })
    	$syncHash.Window.Add_Closed({ $syncHash.isClosed = $True })

        #action for poshwindow button
        $syncHash.btnOpenPSWindow.Dispatcher.Invoke([action]{
            $syncHash.btnOpenPSWindow.Add_Click({
                If($syncHash.InPE){
                    Start-Process 'powershell.exe' -WorkingDirectory 'X:\deploy'
                }Else{
                    Start-Process 'powershell.exe' -WorkingDirectory $env:windir
                }
            })
        })

        $syncHash.btnDartPE.Dispatcher.Invoke([action]{
            $syncHash.btnDartPE.Add_Click({
                If($syncHash.DartTools){
                    Start-Process X:\Sources\Recovery\Tools\MsDartTools.exe -Wait
                }
            })
        })
          

        #action for exit button
        $syncHash.btnExit.Dispatcher.Invoke([action]{
            $syncHash.btnExit.Add_Click({
                $syncHash.Window.Dispatcher.Invoke([action]{ 
                    Close-PSDStartLoader 
                })
            })
        })
        
        $syncHash.Window.ShowDialog() | Out-Null
        $syncHash.Error = $Error
    })


    $PowerShellCommand.Runspace = $PSDRunSpace
    $data = $PowerShellCommand.BeginInvoke()

    Register-ObjectEvent -InputObject $SyncHash.Runspace `
            -EventName 'AvailabilityChanged' `
            -Action {

                    if($Sender.RunspaceAvailability -eq "Available")
                    {
                        $Sender.Closeasync()
                        $Sender.Dispose()
                    }

                } | Out-Null



    return $syncHash

}#end runspacce

Function Set-PSDStartLoaderWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Object[]]$Runspace,

        [boolean]$OnTop
    )
    Try{
        $Runspace.Window.Dispatcher.invoke([action]{
            $Runspace.Window.Topmost = $OnTop
        },'Normal')
    }Catch{}
}


Function Invoke-PSDStartLoaderCountdown
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Runspace,    
        [Parameter(Position=0,Mandatory=$true)]
        [int]$StartCount,
        [String]$TextElement,
        [scriptblock]$Action
    )

    #detemine supported elements and the property to update
    Switch($Runspace.$TextElement.GetType().Name){
        'Button' {$property = 'Content'}
        'Label' {$property = 'Content'}
        'TextBox' {$property = 'Text'}
        'TextBlock' {$property = 'Text'}
        default {$property = 'Text'}
    }

    #ensure element is visable
    Set-PSDStartLoaderElement -Runspace $Runspace -ElementName $TextElement -Property Visibility -Value 'Visible'

    #display the elements countdown value
    Set-PSDStartLoaderElement -Runspace $Runspace -ElementName $TextElement -Property $property -Value $StartCount

    while ($StartCount -ge 0)
    {
        #update the elements countdown value
        Set-PSDStartLoaderElement -Runspace $Runspace -ElementName $TextElement -Property $property -Value $StartCount
        start-sleep 1
        $StartCount -= 1
    }

    #invoke an action if specified
    If($Action){
        Invoke-Command $Action
    }
}

function Update-PSDStartLoaderProgressBar
{
    [CmdletBinding(DefaultParameterSetName='percent')]
    Param (
        [Parameter(Mandatory=$true)]
        $Runspace,
        [parameter(Mandatory=$true, ParameterSetName="percent")]
        [int]$PercentComplete,
        [parameter(Mandatory=$true, ParameterSetName="steps")]
        [int]$Step,
        [parameter(Mandatory=$true, ParameterSetName="steps")]
        [int]$MaxSteps,
        [parameter(Mandatory=$false, ParameterSetName="steps")]
        [int]$Timespan = 1,
        [parameter(Mandatory=$true, ParameterSetName="indeterminate")]
        [switch]$Indeterminate,
        [String]$Status = $Null,
        [ValidateSet("Green", "Yellow", "Red")]
        [string]$Color = 'Green'
    )

    #build field object from name
    If ($PSCmdlet.ParameterSetName -eq "steps")
    {
        #calculate percentage
        $PercentComplete = (($Step / $MaxSteps) * 100)
        #determine where increment will start
        If($Step -eq 1){
            $IncrementFrom = 1
        }Else{
            $IncrementFrom = ((($Step-1) / $MaxSteps) * 100)
        }
        $IncrementBy = ($PercentComplete-$IncrementFrom)/$Timespan
    }

    if($PSCmdlet.ParameterSetName -eq "indeterminate"){
        $Runspace.Indeterminate = $True
        $Runspace.ShowPercentage ='Hidden'
        $Runspace.ProgressColor = $Color
        $Runspace.Status = $Status
    }
    else
    {
        if($PercentComplete -gt 0)
        {
            if($Timespan -gt 1){
                $t=1
                #Determine the incement to go by based on timespan and difference
                Do{                   
                    $IncrementTo = $IncrementFrom + ($IncrementBy * $t)
                    $Runspace.Indeterminate = $False
                    $Runspace.ShowPercentage ='Visible'
                    $Runspace.ProgressColor = $Color
                    $Runspace.PercentComplete = $IncrementTo
                    $Runspace.Status = $Status
                    $t++
                    Start-Sleep 1
                } Until ($IncrementTo -ge $PercentComplete -or $t -gt $Timespan)
            }
            Else{
                $Runspace.Indeterminate = $False
                $Runspace.ShowPercentage ='Visible'
                $Runspace.ProgressColor = $Color
                $Runspace.PercentComplete = $PercentComplete
                $Runspace.Status = $Status
            }
        }
        Else{
            $Runspace.Status = $Status
        }
    }
}


function Show-TSProgressStatus
{
    <#
    .SYNOPSIS
        Shows task sequence secondary progress of a specific step

    .DESCRIPTION
        Adds a second progress bar to the existing Task Sequence Progress UI.
        This progress bar can be updated to allow for a real-time progress of
        a specific task sequence sub-step.
        The Step and Max Step parameters are calculated when passed. This allows
        you to have a "max steps" of 400, and update the step parameter. 100%
        would be achieved when step is 400 and max step is 400. The percentages
        are calculated behind the scenes by the Com Object.

    .PARAMETER Message
        The message to display the progress
    .PARAMETER Step
        Integer indicating current step
    .PARAMETER MaxStep
        Integer indicating 100%. A number other than 100 can be used.
    .INPUTS
         - Message: String
         - Step: Long
         - MaxStep: Long
    .OUTPUTS
        None
    .EXAMPLE
        Set's "Custom Step 1" at 30 percent complete
        Show-ProgressStatus -Message "Running Custom Step 1" -Step 100 -MaxStep 300

    .EXAMPLE
        Set's "Custom Step 1" at 50 percent complete
        Show-ProgressStatus -Message "Running Custom Step 1" -Step 150 -MaxStep 300
    .EXAMPLE
        Set's "Custom Step 1" at 100 percent complete
        Show-ProgressStatus -Message "Running Custom Step 1" -Step 300 -MaxStep 300
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $Message,
        [Parameter(Mandatory=$true)]
        [int]$Step,
        [Parameter(Mandatory=$true)]
        [int]$MaxStep,
        [string]$SubMessage,
        [int]$IncrementSteps,
        [switch]$Outhost
    )

    Begin{

        If($SubMessage){
            $StatusMessage = ("{0} [{1}]" -f $Message,$SubMessage)
        }
        Else{
            $StatusMessage = $Message

        }
    }
    Process
    {
        If($tsenv){
            $TSProgressUi.ShowActionProgress(`
                $tsenv.Value("_SMSTSOrgName"),`
                $tsenv.Value("_SMSTSPackageName"),`
                $tsenv.Value("_SMSTSCustomProgressDialogMessage"),`
                $tsenv.Value("_SMSTSCurrentActionName"),`
                [Convert]::ToUInt32($tsenv.Value("_SMSTSNextInstructionPointer")),`
                [Convert]::ToUInt32($tsenv.Value("_SMSTSInstructionTableSize")),`
                $StatusMessage,`
                $Step,`
                $Maxstep)
        }
        Else{
            Write-Progress -Activity "$Message ($Step of $Maxstep)" -Status $StatusMessage -PercentComplete (($Step / $Maxstep) * 100) -id 1
        }
    }
    End{
        Write-LogEntry $Message -Severity 1 -Outhost:$Outhost
    }
}


Function Get-PSDStartLoaderElement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position=1)]
        $Runspace,

        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [String]$ElementName,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Visibility','Text','Content','Foreground','Background','IsReadOnly','IsChecked','IsEnabled','Fill','BorderThickness','BorderBrush')]
        [String]$Property
    )

    If($Property){
        Return $Runspace.$ElementName.$Property
    }
    Else{
        Return $Runspace.$ElementName
    }

}


Function Set-PSDStartLoaderElement{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Runspace,

        [Parameter(Mandatory=$true, Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$ElementName,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Visibility','Text','Content','Foreground','Background','IsReadOnly','IsChecked','IsEnabled','Fill','BorderThickness','BorderBrush')]
        [String]$Property,

        [Parameter(Mandatory=$true)]
        [String]$Value
    )
    Begin{}
    Process{
        Try{
            $Runspace.Window.Dispatcher.invoke([action]{
                $Runspace.$ElementName.$Property=$Value
            },'Normal')
        }Catch{}
    }
    End{}
}

Function Set-PSDStartLoaderButtonAction{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Runspace,

        [Parameter(Mandatory=$true)]
        [String]$Button,

        [Parameter(,Mandatory=$true)]
        [scriptblock]$Action
    )
    
    Try{
        $Runspace.$Button.Dispatcher.Invoke([action]{
            $Runspace.$Button.Add_Click({
                $Runspace.Window.Dispatcher.Invoke([action]{ 
                    Invoke-Command $Action
                })
            })
        },'Normal')
    }Catch{}
}

function Close-PSDStartLoader
{
    Param (
        [Parameter(Mandatory=$true)]
        [System.Object[]]$Runspace
    )

    $Runspace.Window.Dispatcher.Invoke([action]{
      $Runspace.Window.close()
    }, "Normal")

}

#Expose cmdlets needed
Export-ModuleMember -Function New-PSDStartLoader,Close-PSDStartLoader,
                            Update-PSDStartLoaderProgressBar,Update-PSDStartLoaderProgressStatus,
                            Get-PlatformInfo,Get-InterfaceDetails,
                            Get-PSDStartLoaderElement,Set-PSDStartLoaderElement,
                            Set-PSDStartLoaderButtonAction,
                            Set-PSDStartLoaderWindow,
                            Invoke-PSDStartLoaderCountdown