<#
.SYNOPSIS
    Module for the PSD Start to Load a UI
.DESCRIPTION
    Module to replace the PSDstart BGInfo wallpaper with a WPF UI
.LINK
    https://github.com/FriendsOfMDT/PSD

.NOTES
        FileName: PSDStartLoader.psm1
        Solution: PowerShell Deployment for MDT
        Author: PSD Development Team
        Contact: @PowershellCrack
        Primary: @PowershellCrack
        Created: 2022-02-21
        Modified: 2024-06-25
        Version: 1.1.2

        SEE PSDSTARTLOADER.MD

        TODO:

.EXAMPLE
    $PSDStartLoader = New-PSDStartLoader -LogoImgPath 'D:\DeploymentShares\PSDRestartUIv2\Scripts\powershell.png' -MenuPosition VerticalRight -FullScreen
    Update-PSDStartLoaderProgressBar -Runspace $PSDStartLoader -Status "Loading core PowerShell modules..." -Indeterminate
    Close-PSDStartLoader -Runspace $PSDStartLoader
#>


#region FUNCTION: Check if running in ISE
Function Test-PSDStartLoaderIsISE {
    # trycatch accounts for:
    # Set-StrictMode -Version latest
    try {
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}
#endregion

#region FUNCTION: Check if running in Visual Studio Code
Function Test-PSDStartLoaderVSCode{
    if($env:TERM_PROGRAM -eq 'vscode') {
        return $true;
    }
    Else{
        return $false;
    }
}
#endregion

#region FUNCTION: Check if running in WinPE
Function Test-PSDStartLoaderInWinPE{
    return Test-Path -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlset\Control\MiniNT
}
#endregion


#region FUNCTION: Check for cmtrace path
Function Get-PSDStartLoaderCmtrace {
    #grab current registered path for exe to open log file
    $UserLogpath = "HKCU:\SOFTWARE\Classes\Log.File\shell\open\command"
    
    #check other known paths
    If(Test-Path "$env:windir\System32\cmtrace.exe"){
        return "$env:windir\System32\cmtrace.exe"
    }
    ElseIf(Test-Path "$env:windir\CCM\cmtrace.exe"){
        return "$env:windir\CCM\cmtrace.exe"
    }
    ElseIf(Test-Path $UserLogpath){
        $LoggerTool = (Get-Item $UserLogpath).GetValue("").split('"')[1]
        If(Test-Path $LoggerTool){
            Return $LoggerTool
        }Else{
            Return $false
        }
    }
    Else{
        return $false
    }
}
#endregion

#region FUNCTION: Check for Dart tools
Function Test-PSDStartLoaderHasDartPE{
    If(Test-PSDStartLoaderInWinPE){
        Return Test-Path X:\Sources\Recovery\Tools\MsDartTools.exe
    }
    Else{
        Return $false
    }
}
#endregion

#region FUNCTION: convert chassis Types to friendly name
Function ConvertTo-PSDStartLoaderChassisType{
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
Function Get-PSDStartLoaderPlatformInfo {
    # Returns device Manufacturer, Model and BIOS version, populating global variables for use in other functions/ validation
    # Note that platformType is appended to psobject by Get-PlatformValid - type is manually defined by user to ensure accuracy
    [CmdletBinding()]
    [OutputType([PsObject])]
    Param()
    [string]${CmdletName} = $MyInvocation.MyCommand
    try{
        $CIMSystemEncloure = Get-CIMInstance Win32_SystemEnclosure -ErrorAction Stop
        $CIMComputerSystem = Get-CIMInstance CIM_ComputerSystem -ErrorAction Stop
        $CIMBios = Get-CIMInstance Win32_BIOS -ErrorAction Stop

        $ChassisType = ConvertTo-PSDStartLoaderChassisType -ChassisId $CIMSystemEncloure.chassistypes

        [boolean]$Is64Bit = [boolean]((Get-WmiObject -Class 'Win32_Processor' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)
        If ($Is64Bit) { [string]$envOSArchitecture = '64-bit' } Else { [string]$envOSArchitecture = '32-bit' }

        New-Object -TypeName PsObject -Property @{
            "ComputerName" = [system.environment]::MachineName
            "ComputerDomain" = $CIMComputerSystem.Domain
            "BIOS" = $CIMBios.SMBIOSBIOSVersion
            "Manufacturer" = $CIMComputerSystem.Manufacturer
            "Model" = $CIMComputerSystem.Model
            "AssetTag" = $CIMSystemEncloure.SMBiosAssetTag
            "SerialNumber" = $CIMBios.SerialNumber
            "Architecture" = $envOSArchitecture
            "Chassis" = $ChassisType
            }
    }
    catch{
        Write-PSDLog -Message ("{0}: Failed to get information from Win32_Computersystem/ Win32_BIOS" -f ${CmdletName}) -loglevel 3
    }
}
#endregion

#region FUNCTION: Converts IP Address to integer
Function Convert-PSDStartLoaderIPv4ToInt {
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
Function Convert-PSDStartLoaderIntToIPv4 {
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
Function Add-PSDStartLoaderIntToIPv4 {
    Param(
        [String]$IPv4Address,
        [int64]$Integer
    )
    Try{
        $ipInt = Convert-PSDStartLoaderIPv4ToInt -IPv4Address $IPv4Address -ErrorAction Stop
        $ipInt += $Integer

        Convert-PSDStartLoaderIntToIPv4 -Integer $ipInt
    }Catch{
        Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
    }
}
#endregion

#region FUNCTION: Converts a CIDR to a subnet address
Function Convert-PSDStartLoaderCIDRToNetmask {
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
Function Convert-PSDStartLoaderNetmaskToCIDR {
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
Function Get-PSDStartLoaderIPv4Subnet {
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
                $PrefixLength= Convert-PSDStartLoaderNetmaskToCIDR -SubnetMask $SubnetMask -ErrorAction Stop
            }else{
                $SubnetMask = Convert-PSDStartLoaderCIDRToNetmask -PrefixLength $PrefixLength -ErrorAction Stop
            }

            $netMaskInt = Convert-PSDStartLoaderIPv4ToInt -IPv4Address $SubnetMask
            $ipInt = Convert-PSDStartLoaderIPv4ToInt -IPv4Address $IPAddress

            $networkID = Convert-PSDStartLoaderIntToIPv4 -Integer ($netMaskInt -band $ipInt)

            $maxHosts=[math]::Pow(2,(32-$PrefixLength)) - 2
            $broadcast = Add-PSDStartLoaderIntToIPv4 -IPv4Address $networkID -Integer ($maxHosts+1)

            $firstIP = Add-PSDStartLoaderIntToIPv4 -IPv4Address $networkID -Integer 1
            $lastIP = Add-PSDStartLoaderIntToIPv4 -IPv4Address $broadcast -Integer -1

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
Function Get-PSDStartLoaderGateway
{
# Uses WMI to return IPv4-enabled network adapter gateway address for use in location identification
    [CmdletBinding()]
    [OutputType([PsObject])]
    Param()
    [string]${CmdletName} = $MyInvocation.MyCommand

    $arrGateways = (Get-CIMInstance Win32_networkAdapterConfiguration | Where-Object {$_.IPEnabled}).DefaultIPGateway
    foreach ($gateway in $arrGateways) {If ([string]::IsNullOrWhiteSpace($gateway)){}Else{$clientGateway = $gateway}}
    If ($clientGateway) {
        New-Object -TypeName PsObject -Property @{"IPv4address" = $clientGateway}
    }
    Else {
        Write-PSDLog -Message ("{0}: Unable to detect Client IPv4 Gateway Address, check IPv4 network adapter/ DHCP configuration" -f ${CmdletName}) -loglevel 3
    }
}
#endregion


#region FUNCTION: Get the primary interface not matter the number of nics
Function Get-PSDStartLoaderInterfaceDetails
{
    Param(
        [switch]$Passthru
    )
    [string]${CmdletName} = $MyInvocation.MyCommand
    Write-PSDLog -Message ("{0}: Collecting Network Interface details..." -f ${CmdletName})

    #pull each network interface on device
    #use .net class due to limited commands in PE
    $nics=[Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where {($_.NetworkInterfaceType -ne 'Loopback') -and ($_.NetworkInterfaceType -ne 'Ppp') -and ($_.Supports('IPv4'))}

    #grab all nic in wmi to compare later (its faster than querying individually)
    $wminics = Get-CimInstance win32_NetworkAdapter | Where {($null -ne $_.MACAddress) -and ($_.Name -notlike '*Bluetooth*') -and ($_.Name -notlike '*Miniport*') -and ($_.Name -notlike '*Xbox*') }

    Write-PSDLog -Message ("{0}: Detected {1} Network Inferfaces" -f ${CmdletName},$nics.Count)

    #TEST $interface = $nics[0]
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

                $subnetInfo = Get-PSDStartLoaderIPv4Subnet -IPAddress $_.Address.IPAddressToString -PrefixLength $_.PrefixLength
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
            }
    }

    #Pass all interfaces
    If($Passthru){
        return $InterfaceDetails
    }
    Else{
        #pass only interface that is connected and has a gateway
        $currentGateway = Get-PSDStartLoaderGateway
        $PrimaryInterface = $InterfaceDetails | where {($_.GatewayAddresses -eq $currentGateway.IPv4address) -and ($_.Status -eq 'Connected')}
        return $PrimaryInterface
    }
}
#endregion

function Get-PSDStartTSProgress {
    <#
    https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/clients/client-classes/iprogressui-interface
    #>

    Begin{
        $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
        #$TSProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI -ErrorAction SilentlyContinue
    }
    Process
    {
        Try{
            $TSProgressData = @{
                "OrgName" = $tsenv.Value("_SMSTSOrgName")
                "PackageName" = $tsenv.Value("_SMSTSPackageName")
                "DialogMessage" = $tsenv.Value("_SMSTSCustomProgressDialogMessage")
                "ActionName" = $tsenv.Value("_SMSTSCurrentActionName")
                "Step" = [Convert]::ToUInt32($tsenv.Value("_SMSTSNextInstructionPointer"))
                "MaxSteps" = [Convert]::ToUInt32($tsenv.Value("_SMSTSInstructionTableSize"))
            } 
        }Catch{}
    }
    End{
        return $TSProgressData
    }
}

function Set-PSDStartTSProgress
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
    .LINK
    https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/clients/client-classes/iprogressui--showactionprogress-method
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $ActionMessage,
        [Parameter(Mandatory=$true)]
        [string] $Message,
        [Parameter(Mandatory=$true)]
        [int]$ActionStep,
        [int]$ActionMaxStep,
        [int]$Step,
        [int]$MaxStep
    )

    Begin{
        $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
        $TSProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI -ErrorAction SilentlyContinue
        If($RunningAction){
            $Action = $RunningAction
        }Else{
            $Action = $tsenv.Value("_SMSTSCurrentActionName")
        }
    }
    Process
    {
        If($tsenv){
            #ShowActionProgress(string, string, string, string, uint, uint, string, uint, uint)
            $TSProgressUi.ShowActionProgress(`
                $tsenv.Value("_SMSTSOrgName"),`
                $tsenv.Value("_SMSTSPackageName"),`
                $tsenv.Value("_SMSTSCustomProgressDialogMessage"),`
                $Action,`
                [Convert]::ToUInt32($tsenv.Value("_SMSTSNextInstructionPointer")),`
                [Convert]::ToUInt32($tsenv.Value("_SMSTSInstructionTableSize")),`
                $Message,`
                $Step,`
                $Maxstep)
        }
    }
    End{

    }
}

#region FUNCTION: Loader for modern checkbox style
Function Add-PSDStartLoaderCheckboxStyle{
    [string]$ChkStyleXaml = @"

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
"@
    return $ChkStyleXaml
}
#endregion

#region FUNCTION: Loader for network configuration menu
Function Show-PSDStartLoaderNetCfgWindow
{
    [string]${CmdletName} = $MyInvocation.MyCommand
    Write-PSDLog -Message ("{0}: Network configurator window started" -f ${CmdletName})

    #build runspace
    $syncHash = [hashtable]::Synchronized(@{})
    $PSDRunSpace =[runspacefactory]::CreateRunspace()
    $syncHash.Runspace = $PSDRunSpace
    $syncHash.CheckBoxStyle = (Add-PSDStartLoaderCheckboxStyle)
    $PSDRunSpace.ApartmentState = "STA"
    $PSDRunSpace.ThreadOptions = "ReuseThread"
    $PSDRunSpace.Open() | Out-Null
    $PSDRunSpace.SessionStateProxy.SetVariable("syncHash",$syncHash)
    $PowerShellCommand = [PowerShell]::Create().AddScript({

    [string]$xaml = @"
        <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="Network Settings"
        mc:Ignorable="d"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Height="600" Width="410"
        AllowsTransparency="True"
        WindowStyle="None">
    <Window.Resources>
        <ResourceDictionary>
            <Style TargetType="{x:Type Window}">
                <Setter Property="FontFamily" Value="Segoe UI" />
                <Setter Property="BorderBrush" Value="Black" />
                <Setter Property="BorderThickness" Value="1" />
                <Setter Property="Border.Effect">
                    <Setter.Value>
                        <DropShadowEffect Color="Black" BlurRadius="100" Opacity="0.5" />
                    </Setter.Value>
                </Setter>
            </Style>

            $($syncHash.CheckBoxStyle)

            <ControlTemplate x:Key="ComboBoxToggleButtonStyle" TargetType="{x:Type ToggleButton}">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition />
                        <ColumnDefinition Width="20" />
                    </Grid.ColumnDefinitions>
                    <Border x:Name="Border"
                    Grid.ColumnSpan="2"
                    BorderThickness="1">
                        <Border.BorderBrush>
                            <SolidColorBrush Color="#FF1D3245"/>
                        </Border.BorderBrush>
                        <Border.Background>
                            <SolidColorBrush Color="White"/>
                        </Border.Background>
                    </Border>
                    <Border Grid.Column="0"
                    Margin="1" >
                        <Border.BorderBrush>
                            <SolidColorBrush Color="LightBlue"/>
                        </Border.BorderBrush>
                        <Border.Background>
                            <SolidColorBrush Color="LightGray"/>
                        </Border.Background>
                    </Border>
                    <Path x:Name="Arrow"
                Grid.Column="1"
                HorizontalAlignment="Center"
                VerticalAlignment="Center"
                Data="M0,0 L0,2 L4,6 L8,2 L8,0 L4,4 z"
                Fill="#444444">
                    </Path>
                </Grid>
            </ControlTemplate>

            <Style x:Key="SimpleComboBoxStyle" TargetType="{x:Type ComboBox}">
                <Setter Property="SnapsToDevicePixels" Value="true" />
                <Setter Property="OverridesDefaultStyle" Value="true" />
                <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Auto" />
                <Setter Property="ScrollViewer.VerticalScrollBarVisibility" Value="Auto" />
                <Setter Property="ScrollViewer.CanContentScroll" Value="true" />
                <Setter Property="MinWidth" Value="120" />
                <Setter Property="MinHeight" Value="20" />
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="{x:Type ComboBox}">
                            <Grid>
                                <ToggleButton x:Name="ToggleButton"
                                        Template="{StaticResource ComboBoxToggleButtonStyle}"
                                        Grid.Column="2"
                                        Focusable="false"
                                        ClickMode="Press"
                                        IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"/>
                                <ContentPresenter x:Name="ContentSite"
                                            IsHitTestVisible="False"
                                            Content="{TemplateBinding SelectionBoxItem}"
                                            ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                            ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                            Margin="3,3,23,3"
                                            VerticalAlignment="Stretch"
                                            HorizontalAlignment="Left">
                                </ContentPresenter>
                                <TextBox x:Name="PART_EditableTextBox"
                                HorizontalAlignment="Left"
                                VerticalAlignment="Bottom"
                                Margin="3,3,23,3"
                                Focusable="True"
                                Background="White"
                                Visibility="Hidden"
                                IsReadOnly="{TemplateBinding IsReadOnly}" >
                                    <TextBox.Template>
                                        <ControlTemplate TargetType="TextBox" >
                                            <Border Name="PART_ContentHost" Focusable="False" />
                                        </ControlTemplate>
                                    </TextBox.Template>
                                </TextBox>
                                <Popup x:Name="Popup"
                                Placement="Bottom"
                                IsOpen="{TemplateBinding IsDropDownOpen}"
                                AllowsTransparency="False"
                                Focusable="False"
                                PopupAnimation="Slide">
                                    <Grid x:Name="DropDown"
                                Background="White"
                                SnapsToDevicePixels="True"
                                MinWidth="{TemplateBinding ActualWidth}"
                                MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                        <Border x:Name="DropDownBorder"
                                        BorderThickness="1">
                                            <Border.BorderBrush>
                                                <SolidColorBrush Color="{DynamicResource BorderMediumColor}" />
                                            </Border.BorderBrush>
                                            <Border.Background>
                                                <SolidColorBrush Color="{DynamicResource ControlLightColor}" />
                                            </Border.Background>
                                        </Border>
                                        <ScrollViewer Margin="4,6,4,6"
                                            SnapsToDevicePixels="True">
                                            <StackPanel IsItemsHost="True"
                                                KeyboardNavigation.DirectionalNavigation="Contained" />
                                        </ScrollViewer>
                                    </Grid>
                                </Popup>
                            </Grid>
                            <ControlTemplate.Triggers>
                                <Trigger Property="HasItems" Value="false">
                                    <Setter TargetName="DropDownBorder" Property="MinHeight" Value="95" />
                                </Trigger>
                                <Trigger Property="HasItems" Value="True">
                                    <Setter Property="Background" Value="White" />
                                </Trigger>
                                <Trigger Property="IsGrouping" Value="true">
                                    <Setter Property="ScrollViewer.CanContentScroll" Value="false" />
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
        </ResourceDictionary>
    </Window.Resources>
    <Grid>
        <StackPanel Margin="10,0,10,0">
            <ComboBox x:Name="cmbNetAdapters" FontSize="18" Style="{DynamicResource SimpleComboBoxStyle}" Height="28" Margin="10" />
            <Label Content="Network Settings:" HorizontalAlignment="Left" FontWeight="Bold" FontSize="16" Foreground="Black" Height="31" HorizontalContentAlignment="Left"/>
            <StackPanel Orientation="Horizontal">
                <TextBlock Text="Edit" Foreground="Black" VerticalAlignment="Center" Margin="10" FontSize="18"/>
                <CheckBox x:Name="chkEdit" Style="{DynamicResource ModernCircleSlider}" Margin="0,10,10,10" Width="58" HorizontalAlignment="Right" />
                <TextBlock x:Name="txtDhcp" Text="Automatic (Use DHCP)" Foreground="Gray" VerticalAlignment="Center" Margin="10" FontSize="18"/>
            </StackPanel>
            <Grid x:Name="Ipv4settings" HorizontalAlignment="Left" Height="360" Width="381" >
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="auto" MinWidth="121"/>
                    <ColumnDefinition/>
                    <ColumnDefinition Width="auto"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition/>
                    <RowDefinition/>
                    <RowDefinition/>
                    <RowDefinition/>
                    <RowDefinition/>
                    <RowDefinition/>
                    <RowDefinition/>
                    <RowDefinition/>
                </Grid.RowDefinitions>
                <Label Content="MAC Address" Grid.Row="0" Grid.Column="0" HorizontalAlignment="Right" IsEnabled="False" FontSize="16" VerticalAlignment="Center" Height="31" Width="121" HorizontalContentAlignment="Right" Margin="0,9"/>
                <TextBox x:Name="txtMac" Grid.Row="0" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" IsEnabled="False" IsReadOnly="True" BorderThickness="0" FontSize="16" Margin="0,5,0,5" Width="249" VerticalContentAlignment="Center" Padding="2,0,0,0"/>
                <Label Content="IP Address v4:" Grid.Row="1" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" Margin="0,9"/>
                <TextBox x:Name="txtNetIPv4" Grid.Row="1" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="16" Margin="0,5,0,5" Width="249" VerticalContentAlignment="Center" Padding="2,0,0,0"/>
                <Label x:Name="lblNetIPv6" Content="IP Address v6:" Grid.Row="2" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" Margin="0,9"/>
                <TextBox x:Name="txtNetIPv6" Grid.Row="2" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="16" Margin="0,5,0,5" Width="249" VerticalContentAlignment="Center" Padding="2,0,0,0"/>
                <Label Content="Subnet:" Grid.Row="3" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                <TextBox x:Name="txtNetSubnet" Grid.Row="3" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="16" Margin="0,5,0,5" Width="249" VerticalContentAlignment="Center" Padding="2,0,0,0"/>
                <Label Content="Gateway:" Grid.Row="4" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" Margin="0,9"/>
                <TextBox x:Name="txtNetGateway" Grid.Row="4" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="16" Margin="0,5,0,5" Width="249" VerticalContentAlignment="Center" Padding="2,0,0,0"/>
                <Label Content="Primary DNS:" Grid.Row="5" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" Margin="0,9"/>
                <TextBox x:Name="txtNetDNS1" Grid.Row="5" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="16" Margin="0,5,0,5" Width="249" VerticalContentAlignment="Center" Padding="2,0,0,0"/>
                <Label Content="Secondary DNS:" Grid.Row="6" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" Margin="0,9"/>
                <TextBox x:Name="txtNetDNS2" Grid.Row="6" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="16" Margin="0,5,0,5" Width="249" VerticalContentAlignment="Center" Padding="2,0,0,0"/>
                <Label Content="DNS Suffix(s):" Grid.Row="7" Grid.Column="0" HorizontalAlignment="Right" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" Margin="0,9"/>
                <TextBox x:Name="txtNetSuffix" Grid.Row="7" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="16" Margin="0,5,0,5" Width="249" VerticalContentAlignment="Center" Padding="2,0,0,0"/>
            </Grid>
            <Viewbox Stretch="Uniform" Width="306" Margin="75,10,0,0" Height="39" HorizontalAlignment="Left">
                <TextBox x:Name="txtTestResult" TextWrapping="Wrap" IsReadOnly="True" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
            </Viewbox>
        </StackPanel>
        <Button x:Name="btnTest" Content="Test" Height="42" Width="75" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="18" Padding="2" Margin="10,0,0,61" />
        <Button x:Name="btnSave" Content="Save" Height="42" Width="163" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="18" Padding="2" Margin="10,0,0,10" />
        <Button x:Name="btnCancel" Content="Cancel" Height="42" Width="163" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="18" Padding="2" Margin="227,0,0,10" />
    </Grid>
</Window>
"@

        #Load assembies to display UI
        [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')

        [xml]$xaml = $xaml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
        $reader=(New-Object System.Xml.XmlNodeReader $xaml)
        $syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
        #===========================================================================
        # Store Form Objects In PowerShell
        #===========================================================================
        $xaml.SelectNodes("//*[@Name]") | %{ $syncHash."$($_.Name)" = $syncHash.Window.FindName($_.Name)}

        # INNER  FUNCTIONS
        #Closes UI objects and exits (within runspace)
        Function Close-NetSettingsWindow
        {
            if ($syncHash.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
            #if runspace has not errored Dispose the UI
            if (!($syncHash.isClosing)) { $syncHash.Window.Close() | Out-Null }
        }

        Function Get-NetAdapterInfo {
            Param (
                [Parameter(Mandatory = $false)]
                [ArgumentCompleter( {
                    param ( $commandName,
                            $parameterName,
                            $wordToComplete,
                            $commandAst,
                            $fakeBoundParameters )


                    $Adapters = Get-WmiObject win32_networkadapterconfiguration -filter "ipenabled ='true'"

                    $Adapters | Where-Object {
                        $_ -like "$wordToComplete*"
                    } | Select @{Name='description';Expression={"'" + $_.description + "'"}} | Select -ExpandProperty description

                } )]
                [Alias("config")]
                [string]$Adapter
            )
            $NetInfo = @{}
            $NetInfo = Get-WmiObject win32_networkadapterconfiguration -filter "ipenabled ='true'"
            If($Adapter)
            {
                $NetInfo = $NetInfo | Where Description -eq $Adapter
            }
            Return $NetInfo
        }

        #hide features not ready
        $syncHash.btnTest.Visibility = 'Hidden'
        $syncHash.txtNetIPv6.Visibility = 'Hidden'
        $syncHash.lblNetIPv6.Visibility = 'Hidden'

        #immediately grab all network adapters
        $syncHash.NetAdapters = Get-NetAdapterInfo
        $syncHash.NetAdapters.description | ForEach-object {$syncHash.cmbNetAdapters.Items.Add($_) | Out-Null}

        #Disable edit options until adapter has been choosen
        $syncHash.chkEdit.IsEnabled = $False
        $syncHash.btnSave.IsEnabled = $false
        $syncHash.GetEnumerator() | where Key -like 'txtNet*' | %{$_.Value.IsEnabled = $False}

        #update interface based on selection
        $syncHash.cmbNetAdapters.Add_SelectionChanged( {
            $syncHash.chkEdit.IsEnabled = $True
            #store current selected adapter
            $syncHash.SelectedAdapter = Get-NetAdapterInfo -Adapter $syncHash.cmbNetAdapters.SelectedItem
            $syncHash.txtMAC.text = $syncHash.SelectedAdapter.MACAddress
            If($syncHash.SelectedAdapter.IPAddress){
                $syncHash.txtNetIPv4.text = $syncHash.SelectedAdapter.IPAddress[0]
                $syncHash.txtNetIPv6.text = $syncHash.SelectedAdapter.IPAddress[1]
            }
            If($syncHash.SelectedAdapter.IPSubnet){$syncHash.txtNetSubnet.text = $syncHash.SelectedAdapter.IPSubnet[0]}
            If($syncHash.SelectedAdapter.DefaultIPGateway){$syncHash.txtNetGateway.text = $syncHash.SelectedAdapter.DefaultIPGateway[0]}
            If($syncHash.SelectedAdapter.DNSServerSearchOrder){
                $syncHash.txtNetDNS1.text = $syncHash.SelectedAdapter.DNSServerSearchOrder[0]
                $syncHash.txtNetDNS2.text = $syncHash.SelectedAdapter.DNSServerSearchOrder[1]
            }
            $syncHash.txtNetSuffix.text = ($syncHash.SelectedAdapter.DNSDomainSuffixSearchOrder -join ',').ToString()
        })

        [System.Windows.RoutedEventHandler]$Script:CheckedEventHandler = {
            $syncHash.GetEnumerator() | Where-Object Key -like 'txtNet*' | %{$_.Value.IsEnabled = $True}
            $syncHash.txtDhcp.text = 'Static Assigned'
            #$syncHash.chkEdit.IsEnabled = $false
        }
        #Do editing actions when checked
        $syncHash.chkEdit.AddHandler([System.Windows.Controls.CheckBox]::CheckedEvent, $CheckedEventHandler)

        [System.Windows.RoutedEventHandler]$Script:UnCheckedEventHandler = {
            $syncHash.GetEnumerator() | Where-Object Key -like 'txtNet*' | %{$_.Value.IsEnabled = $False}
            $syncHash.txtDhcp.text = 'Automatic (Use DHCP)'
            #reset adapter when unchecked
            $syncHash.txtMAC.text = $syncHash.SelectedAdapter.MACAddress
            If($syncHash.SelectedAdapter.IPAddress){
                $syncHash.txtNetIPv4.text = $syncHash.SelectedAdapter.IPAddress[0]
                $syncHash.txtNetIPv6.text = $syncHash.SelectedAdapter.IPAddress[1]
            }
            If($syncHash.SelectedAdapter.IPSubnet){$syncHash.txtNetSubnet.text = $syncHash.SelectedAdapter.IPSubnet[0]}
            If($syncHash.SelectedAdapter.DefaultIPGateway){$syncHash.txtNetGateway.text = $syncHash.SelectedAdapter.DefaultIPGateway[0]}
            If($syncHash.SelectedAdapter.DNSServerSearchOrder){
                $syncHash.txtNetDNS1.text = $syncHash.SelectedAdapter.DNSServerSearchOrder[0]
                $syncHash.txtNetDNS2.text = $syncHash.SelectedAdapter.DNSServerSearchOrder[1]
            }
            $syncHash.txtNetSuffix.text = ($syncHash.SelectedAdapter.DNSDomainSuffixSearchOrder -join ',').ToString()
        }
        #Do readonly action when unchecked
        $syncHash.chkEdit.AddHandler([System.Windows.Controls.CheckBox]::UncheckedEvent, $UnCheckedEventHandler)

        $ipv4regex = '^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)$'
        $ipv6regex = '(([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4})'
        $syncHash.txtNetIPv4.Add_GotFocus( {
            #CHECK VALUE AS TYPED
            $syncHash.txtNetIPv4.AddHandler(
                [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                [System.Windows.RoutedEventHandler] {
                    $syncHash.btnSave.IsEnabled = ($syncHash.txtNetIPv4.Text -match $ipv4regex)
                }
            )
        })

        <#
        $syncHash.txtNetIPv6.Add_GotFocus( {
            #CHECK VALUE AS TYPED
            $syncHash.txtNetIPv4.AddHandler(
                [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                [System.Windows.RoutedEventHandler] {
                    $syncHash.btnSave.IsEnabled = ($syncHash.txtNetIPv6.Text -match $ipv6regex)
                }
            )
        })
        #>

        $syncHash.txtNetSubnet.Add_GotFocus( {
            #CHECK VALUE AS TYPED
            $syncHash.txtNetSubnet.AddHandler(
                [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                [System.Windows.RoutedEventHandler] {
                    $syncHash.btnSave.IsEnabled = ($syncHash.txtNetSubnet.Text -match $ipv4regex)
                }
            )
        })

        $syncHash.txtNetGateway.Add_GotFocus( {
            #CHECK VALUE AS TYPED
            $syncHash.txtNetGateway.AddHandler(
                [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                [System.Windows.RoutedEventHandler] {
                    $syncHash.btnSave.IsEnabled = ($syncHash.txtNetGateway.Text -match $ipv4regex)
                }
            )
        })

        $syncHash.btnSave.Add_Click({
            If($syncHash.chkEdit.IsChecked){
                $syncHash.SelectedAdapter.EnableStatic($syncHash.txtNetIPv4.Text, $syncHash.txtNetSubnet.Text);
                $syncHash.SelectedAdapter.SetGateways($syncHash.txtNetGateway.Text, 1);
                If($syncHash.txtNetDNS1.Text -and $syncHash.txtNetDNS2.Text){
                    $syncHash.SelectedAdapter.SetDNSServerSearchOrder($syncHash.txtNetDNS1.Text,$syncHash.txtNetDNS2.Text);
                }
                ElseIf($syncHash.txtNetDNS1.Text){
                    $syncHash.SelectedAdapter.SetDNSServerSearchOrder($syncHash.txtNetDNS1.Text);
                }
            }
            Else{
                $syncHash.SelectedAdapter.EnableDHCP();
                $syncHash.SelectedAdapter.SetDNSServerSearchOrder();
            }
            $syncHash.chkEdit.IsChecked = $False
            Close-NetSettingsWindow
        })

        $syncHash.btnCancel.Add_Click({
            Close-NetSettingsWindow
        })

        #Allow UI to be dragged around screen
        $syncHash.Window.Add_MouseLeftButtonDown( {
            $syncHash.Window.DragMove()
        })

        #Add smooth closing for Window
        $syncHash.Window.Add_Loaded({ $syncHash.isLoaded = $True })
        $syncHash.Window.Add_Closing({ $syncHash.isClosing = $True; Close-NetSettingsWindow })
        $syncHash.Window.Add_Closed({ $syncHash.isClosed = $True })

        #make sure this display on top of every window
        $syncHash.Window.Topmost = $true

        $syncHash.window.ShowDialog()
        $syncHash.Error = $Error
    }) # end scriptblock

    #collect data from runspace
    $Data = $syncHash

    #invoke scriptblock in runspace
    $PowerShellCommand.Runspace = $PSDRunSpace
    $AsyncHandle = $PowerShellCommand.BeginInvoke()

    #wait until runspace is completed before ending
    do {
        Start-sleep -m 100 }
    while (!$AsyncHandle.IsCompleted)
    #end invoked process
    $null = $PowerShellCommand.EndInvoke($AsyncHandle)

    #cleanup registered object
    Register-ObjectEvent -InputObject $syncHash.Runspace `
            -EventName 'AvailabilityChanged' `
            -Action {

                    if($Sender.RunspaceAvailability -eq "Available")
                    {
                        $Sender.Closeasync()
                        $Sender.Dispose()
                        # Speed up resource release by calling the garbage collector explicitly.
                        # Note that this will pause *all* threads briefly.
                        [GC]::Collect()
                    }

                } | Out-Null

    If($Data.Error){Write-PSDLog -Message ("{0}: Network configurator window errored: {1}" -f ${CmdletName}, $Data.Error) -LogLevel 3}
    Else{Write-PSDLog -Message ("{0}: Network configurator Window closed" -f ${CmdletName})}
    return $Data

}#end networksettings runspace
#endregion

#region FUNCTION: Loader for disk cleaner menu
Function Show-PSDStartLoaderDiskCleanWindow
{
    [string]${CmdletName} = $MyInvocation.MyCommand
    Write-PSDLog -Message ("{0}: Disk Cleaner window started" -f ${CmdletName})

    #build runspace
    $syncHash = [hashtable]::Synchronized(@{})
    $PSDRunSpace =[runspacefactory]::CreateRunspace()
    $syncHash.Runspace = $PSDRunSpace
    $syncHash.CheckBoxStyle = (Add-PSDStartLoaderCheckboxStyle)
    $PSDRunSpace.ApartmentState = "STA"
    $PSDRunSpace.ThreadOptions = "ReuseThread"
    $PSDRunSpace.Open() | Out-Null
    $PSDRunSpace.SessionStateProxy.SetVariable("syncHash",$syncHash)
    $PowerShellCommand = [PowerShell]::Create().AddScript({

    [string]$xaml = @"
    <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="DiskClean"
        mc:Ignorable="d"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Height="350" Width="800"
        AllowsTransparency="True"
        WindowStyle="None">
    <Window.Resources>
        <ResourceDictionary>

            <Canvas x:Key="icons_refresh" Width="24" Height="24">
                <Path Stretch="Fill" Fill="White" Data="M17.65,6.35C16.2,4.9 14.21,4 12,4A8,8 0 0,0 4,12A8,8 0 0,0 12,20C15.73,20 18.84,17.45 19.73,14H17.65C16.83,16.33 14.61,18 12,18A6,6 0 0,1 6,12A6,6 0 0,1 12,6C13.66,6 15.14,6.69 16.22,7.78L13,11H20V4L17.65,6.35Z" />
            </Canvas>

            <Style TargetType="{x:Type Window}">
                <Setter Property="FontFamily" Value="Segoe UI" />
                <Setter Property="BorderBrush" Value="Red" />
                <Setter Property="BorderThickness" Value="1" />
                <Setter Property="Border.Effect">
                    <Setter.Value>
                        <DropShadowEffect Color="Black" BlurRadius="100" Opacity="0.1" />
                    </Setter.Value>
                </Setter>
            </Style>

            $($syncHash.CheckBoxStyle)

            <Style x:Key="ButtonClean" TargetType="{x:Type Button}">
                <Setter Property="Background" Value="Pink" />
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
                    Background="Pink">
                                <ContentPresenter HorizontalAlignment="Center"
                                    VerticalAlignment="Center"
                                    TextBlock.TextAlignment="Center"
                                    />
                            </Border>

                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="border" Property="BorderBrush" Value="Black" />
                                    <Setter TargetName="border" Property="Background" Value="Red" />
                                    <Setter Property="Foreground" Value="White" />
                                </Trigger>

                                <Trigger Property="IsPressed" Value="True">
                                    <Setter TargetName="border" Property="BorderBrush" Value="Darkred" />
                                    <Setter Property="Foreground" Value="White" />
                                </Trigger>

                                <Trigger Property="IsEnabled" Value="False">
                                    <Setter TargetName="border" Property="BorderBrush" Value="Pink" />
                                    <Setter Property="Foreground" Value="White" />
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
        </ResourceDictionary>
    </Window.Resources>
    <Grid>
        <StackPanel  Margin="10,0,10,0">
            <StackPanel Orientation="Horizontal">
                <Label Content="Disk Selection" HorizontalAlignment="Left" FontWeight="Bold" FontSize="16" Foreground="Black" Height="31" HorizontalContentAlignment="Left"/>

                <Button x:Name="btnRefresh" Width="20" HorizontalAlignment="Right" Margin="5" Height="20" Background="White" >
                    <Rectangle Width="16" Height="16" Fill="Black" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_refresh}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </Button>
            </StackPanel>

            <ListView x:Name="lstDisks" HorizontalAlignment="Center" Height="137" Width="765">
                <ListView.View>
                    <GridView>
                        <GridViewColumn Header="Disk Number" DisplayMemberBinding="{Binding Number}" />
                        <GridViewColumn Header="Drive Name" DisplayMemberBinding="{Binding FriendlyName}" />
                        <GridViewColumn Header="Partition Table" DisplayMemberBinding="{Binding PartitionStyle}" />
                        <GridViewColumn Header="Disk Type" DisplayMemberBinding="{Binding ProvisioningType}" />
                        <GridViewColumn Header="Total Size" DisplayMemberBinding="{Binding Size}" />
                    </GridView>
                </ListView.View>
            </ListView>
            <StackPanel Orientation="Horizontal">
                <TextBlock Text="Acknowledge" Foreground="Black" VerticalAlignment="Center" Margin="10" FontSize="18"/>
                <CheckBox x:Name="chkAck" Style="{DynamicResource ModernCircleSlider}" Margin="0,10,10,10" Width="58" HorizontalAlignment="Right" />
                <TextBlock x:Name="txtAckStatement" Text="I understand the risks. This will DELETE ALL DATA on disk(s)" Foreground="Red" VerticalAlignment="Center" Margin="10" FontSize="18"/>
            </StackPanel>
            <TextBox x:Name="txtResult" TextWrapping="NoWrap" IsReadOnly="True" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0" Margin="10" Height="41"/>
        </StackPanel>
        <Button x:Name="btnCleanDisk" Style="{DynamicResource ButtonClean}" Content="Clean Selected Disk" Height="61" Width="188" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="18" Padding="2" Margin="10,0,0,8" />
        <Button x:Name="btnCleanAll" Style="{DynamicResource ButtonClean}" Content="Clean All Disks" Height="61" Width="163" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="18" Padding="2" Margin="203,0,0,8" />
        <Button x:Name="btnCancel" Content="Close" Height="42" Width="163" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="18" Padding="2" Margin="626,0,0,10" />
    </Grid>
</Window>
"@
        #Load assembies to display UI
        [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')

        [xml]$xaml = $xaml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
        $reader=(New-Object System.Xml.XmlNodeReader $xaml)
        $syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
        #===========================================================================
        # Store Form Objects In PowerShell
        #===========================================================================
        $xaml.SelectNodes("//*[@Name]") | %{ $syncHash."$($_.Name)" = $syncHash.Window.FindName($_.Name)}

        # INNER  FUNCTIONS
        #Closes UI objects and exits (within runspace)
        Function Close-DiskCleanWindow
        {
            if ($syncHash.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
            #if runspace has not errored Dispose the UI
            if (!($syncHash.isClosing)) { $syncHash.Window.Close() | Out-Null }
        }

        #populate data on start
        $syncHash.Disks = Get-Disk
        $syncHash.txtResult.Visibility = 'Hidden'
        $syncHash.btnCleanAll.IsEnabled = $False
        $syncHash.btnCleanAll.Visibility = 'Hidden'
        $syncHash.btnCleanDisk.IsEnabled = $False
        $syncHash.chkAck.IsEnabled = $False
        $syncHash.txtAckStatement.Visibility = 'Hidden'


        $syncHash.lstDisks.ItemsSource = @($syncHash.Disks | Sort DiskNumber | Select Number,FriendlyName,PartitionStyle,ProvisioningType,
                                    @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}})

        #enable clean disk button if ack is checkec and disk selected
        $syncHash.lstDisks.Add_SelectionChanged({
            $syncHash.chkAck.IsEnabled = $true
            $syncHash.chkAck.IsChecked = $false
            $Global:SelectedDisks = $syncHash.lstDisks.SelectedItems
            $Global:DisksListString =  $Global:SelectedDisks.Number -Join ','
            $syncHash.txtAckStatement.Visibility = 'Visible'
            $syncHash.txtAckStatement.Text = ("You have selected disk(s) [{0}]" -f $Global:DisksListString )
            $syncHash.txtAckStatement.Foreground = 'Black'
            If($syncHash.chkAck.IsChecked -and ($Global:SelectedDisks.count -gt 0) ){
                $syncHash.btnCleanDisk.IsEnabled = $True
            }
        })

        [System.Windows.RoutedEventHandler]$Script:CheckedEventHandler = {
            $syncHash.btnCleanAll.IsEnabled = $True
            If($Global:SelectedDisks.count -gt 0)
            {
                $syncHash.btnCleanDisk.IsEnabled = $True
            }
            $syncHash.txtAckStatement.Visibility = 'Visible'
            $syncHash.txtAckStatement.Foreground = 'Red'
            If( $Global:SelectedDisks.count -gt 0 ){
                $syncHash.txtAckStatement.Text = ('I understand the risks. This will DELETE ALL DATA on disk(s) [{0}]!'-f $Global:DisksListString)
            }Else{
                $syncHash.txtAckStatement.Text = 'I understand the risks. This will DELETE ALL DATA on disk(s)'
            }
        }
        #Do editing actions when checked
        $syncHash.chkAck.AddHandler([System.Windows.Controls.CheckBox]::CheckedEvent, $CheckedEventHandler)

        [System.Windows.RoutedEventHandler]$Script:UnCheckedEventHandler = {
            $syncHash.btnCleanAll.IsEnabled = $False
            $syncHash.btnCleanDisk.IsEnabled = $False
            $syncHash.txtAckStatement.Foreground = 'Black'
            If( $Global:SelectedDisks.count -gt 0 ){
                $syncHash.txtAckStatement.Text = ("You have selected disk(s) [{0}]" -f $Global:DisksListString )
            }Else{
                $syncHash.txtAckStatement.Text = 'You have selected no disk(s)'
            }
            #$syncHash.txtAckStatement.Visibility = 'Hidden'
        }
        #Do disable button action when unchecked
        $syncHash.chkAck.AddHandler([System.Windows.Controls.CheckBox]::UncheckedEvent, $UnCheckedEventHandler)

        $syncHash.btnRefresh.Add_Click({
            $syncHash.lstDisks.UnselectAll()

            $syncHash.Disks = Get-Disk
            $syncHash.lstDisks.ItemsSource = @($syncHash.Disks | Sort DiskNumber | Select Number,FriendlyName,PartitionStyle,ProvisioningType,
                                            @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}})
            $syncHash.txtAckStatement.Text = ''
            $syncHash.chkAck.IsChecked = $false
            $syncHash.chkAck.IsEnabled = $False
        })

        $syncHash.btnCleanDisk.Add_Click({
            $SelectedDisks = $syncHash.lstDisks.SelectedItems
            $syncHash.txtResult.Text = ("Cleaning disk(s) [{0}], please wait..." -f $Global:DisksListString)
            Try{
                $syncHash.Disks | Where {$_.Number -in $Global:SelectedDisks.Number} | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false | Out-Null
                Get-PhysicalDisk | Where {$_.DeviceNumber -in $Global:SelectedDisks.Number} | Reset-PhysicalDisk | Out-Null
                $syncHash.txtResult.Foreground = 'Green'
                $syncHash.txtResult.Text = ("Successfully cleaned disk(s) [{0}]!" -f $Global:DisksListString)
            }
            Catch{
                $syncHash.txtResult.Foreground = 'Red'
                $syncHash.txtResult.Text = ("Failed to clean disk(s) [{0}]: {1}" -f $Global:DisksListString,$_.exception.message)
            }
            Finally{
                $syncHash.lstDisks.ItemsSource = @($syncHash.Disks | Sort DiskNumber | Select Number,FriendlyName,PartitionStyle,ProvisioningType,
                                    @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}})
                $syncHash.btnCancel.Text = 'Done'
            }
        })

        <#
        $syncHash.btnClearSelected.Add_Click({
            #unslect everything
            $syncHash.lstDisks.UnselectAll()
        })

        $syncHash.btnCleanAll.Add_Click({
            $syncHash.txtResult.Text = "Cleaning disks, please wait..."
            Try{
                Get-Disk | Clear-Disk -RemoveData -RemoveOEM -Confirm:$false | Out-Null
                Get-PhysicalDisk | Reset-PhysicalDisk | Out-Null
                $syncHash.txtResult.Foreground = 'Green'
                $syncHash.txtResult.Text = "Successfully cleaned all disks!"
            }
            Catch{
                $syncHash.txtResult.Foreground = 'Red'
                $syncHash.txtResult.Text = ("Failed to clean disks! {0}" -f $_.exception.message)
            }
            Finally{
                $syncHash.lstDisks.ItemsSource = @(Get-Disk | Sort DiskNumber | Select Number,FriendlyName,PartitionStyle,ProvisioningType,
                                    @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}})
                $syncHash.btnCancel.Text = 'Done'
            }
        })
        #>

        $syncHash.btnCancel.Add_Click({
            Close-DiskCleanWindow
        })

        #Allow UI to be dragged around screen
        $syncHash.Window.Add_MouseLeftButtonDown( {
            $syncHash.Window.DragMove()
        })

        #Add smooth closing for Window
        $syncHash.Window.Add_Loaded({ $syncHash.isLoaded = $True })
        $syncHash.Window.Add_Closing({ $syncHash.isClosing = $True; Close-DiskCleanWindow })
        $syncHash.Window.Add_Closed({ $syncHash.isClosed = $True })

        #make sure this display on top of every window
        $syncHash.Window.Topmost = $true

        $syncHash.window.ShowDialog()
        $syncHash.Error = $Error
    }) # end scriptblock

    #collect data from runspace
    $Data = $syncHash

    #invoke scriptblock in runspace
    $PowerShellCommand.Runspace = $PSDRunSpace
    $AsyncHandle = $PowerShellCommand.BeginInvoke()

    #wait until runspace is completed before ending
    do {
        Start-sleep -m 100 }
    while (!$AsyncHandle.IsCompleted)
    #end invoked process
    $null = $PowerShellCommand.EndInvoke($AsyncHandle)

    #cleanup registered object
    Register-ObjectEvent -InputObject $syncHash.Runspace `
            -EventName 'AvailabilityChanged' `
            -Action {

                    if($Sender.RunspaceAvailability -eq "Available")
                    {
                        $Sender.Closeasync()
                        $Sender.Dispose()
                        # Speed up resource release by calling the garbage collector explicitly.
                        # Note that this will pause *all* threads briefly.
                        [GC]::Collect()
                    }

                } | Out-Null

    If($Data.Error){Write-PSDLog -Message ("{0}: Disk Cleaner window errored: {1}" -f ${CmdletName}, $Data.Error) -LogLevel 3}
    Else{Write-PSDLog -Message ("{0}: Disk Cleaner Window closed" -f ${CmdletName})}
    return $Data

}#end diskclean runspace
#endregion

#region FUNCTION: Loader for disk viewer menu
Function Show-PSDStartLoaderDiskViewerWindow
{
    [string]${CmdletName} = $MyInvocation.MyCommand
    Write-PSDLog -Message ("{0}: Disk Manager window started" -f ${CmdletName})

    #build runspace
    $syncHash = [hashtable]::Synchronized(@{})
    $PSDRunSpace =[runspacefactory]::CreateRunspace()
    $syncHash.Runspace = $PSDRunSpace
    $PSDRunSpace.ApartmentState = "STA"
    $PSDRunSpace.ThreadOptions = "ReuseThread"
    $PSDRunSpace.Open() | Out-Null
    $PSDRunSpace.SessionStateProxy.SetVariable("syncHash",$syncHash)
    $PowerShellCommand = [PowerShell]::Create().AddScript({

    [string]$xaml = @"
    <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="DiskMgr"
        mc:Ignorable="d"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Height="450" Width="800"
        AllowsTransparency="True"
        WindowStyle="None">
    <Window.Resources>
        <ResourceDictionary>

            <Style TargetType="{x:Type Window}">
                <Setter Property="FontFamily" Value="Segoe UI" />
                <Setter Property="BorderBrush" Value="DarkGray" />
                <Setter Property="BorderThickness" Value="1" />
                <Setter Property="Border.Effect">
                    <Setter.Value>
                        <DropShadowEffect Color="Black" BlurRadius="100" Opacity="0.1" />
                    </Setter.Value>
                </Setter>
            </Style>

        </ResourceDictionary>
    </Window.Resources>
    <Grid>
        <StackPanel  Margin="10,0,10,0">
            <Label Content="Disk viewer" HorizontalAlignment="Left" FontWeight="Bold" FontSize="16" Foreground="Black" Height="31" HorizontalContentAlignment="Left"/>
            <ListView x:Name="lstDisks" HorizontalAlignment="Center" Height="137" Width="765" SelectionMode="Single">
                <ListView.View>
                    <GridView>
                        <GridViewColumn Header="Disk Number" DisplayMemberBinding="{Binding Number}" />
                        <GridViewColumn Header="Drive Name" DisplayMemberBinding="{Binding FriendlyName}" />
                        <GridViewColumn Header="Partition Table" DisplayMemberBinding="{Binding PartitionStyle}" />
                        <GridViewColumn Header="Disk Type" DisplayMemberBinding="{Binding ProvisioningType}" />
                        <GridViewColumn Header="Total Size" DisplayMemberBinding="{Binding Size}" />
                    </GridView>
                </ListView.View>
            </ListView>

            <Label Content="Volume viewer" HorizontalAlignment="Left" FontWeight="Bold" FontSize="16" Foreground="Black" Height="31" HorizontalContentAlignment="Left"/>
            <StackPanel Orientation="Horizontal">
                <ListView x:Name="lstVolumes" Height="160" Width="564" SelectionMode="Single" Margin="5,0,0,0" >
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Disk Number" DisplayMemberBinding="{Binding Disk}" />
                            <GridViewColumn Header="Drive Letter" DisplayMemberBinding="{Binding DriveLetter}" />
                            <GridViewColumn Header="Partition Name" DisplayMemberBinding="{Binding FileSystemLabel}" />
                            <GridViewColumn Header="Format" DisplayMemberBinding="{Binding FileSystem}" />
                            <GridViewColumn Header="Drive Type" DisplayMemberBinding="{Binding DriveType}" />
                            <GridViewColumn Header="Partition Size" DisplayMemberBinding="{Binding Size}" />
                            <GridViewColumn Header="Remaining Size" DisplayMemberBinding="{Binding SizeRemaining}" />
                        </GridView>
                    </ListView.View>
                </ListView>
                <Image x:Name="imgPieChart" VerticalAlignment="Top" Width="200" Height="160" />
            </StackPanel>
        </StackPanel>
        <Button x:Name="btnRefresh" Content="Refresh" Height="42" Width="163" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="18" Padding="2" Margin="10,0,0,10" />
        <Button x:Name="btnOk" Content="Ok" Height="42" Width="163" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="18" Padding="2" Margin="626,0,0,10" />
    </Grid>
</Window>
"@

        #Load assembies to display UI
        [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')

        [xml]$xaml = $xaml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
        $reader=(New-Object System.Xml.XmlNodeReader $xaml)
        $syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
        #===========================================================================
        # Store Form Objects In PowerShell
        #===========================================================================
        $xaml.SelectNodes("//*[@Name]") | %{ $syncHash."$($_.Name)" = $syncHash.Window.FindName($_.Name)}

        # INNER  FUNCTIONS
        #Closes UI objects and exits (within runspace)
        Function Close-DiskMgrWindow
        {
            if ($syncHash.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
            #if runspace has not errored Dispose the UI
            if (!($syncHash.isClosing)) { $syncHash.Window.Close() | Out-Null }
        }

        # Function to create a Windows Forms pie chart
        # Modified from https://www.simple-talk.com/sysadmin/powershell/building-a-daily-systems-report-email-with-powershell/
        Function New-PieChart {
            param(
                [hashtable]$Window,
                [hashtable]$Data,
                [string]$Name,
                [switch]$SaveAsFile,
                [switch]$Passthru
            )
            Add-Type -AssemblyName System.Windows.Forms,System.Windows.Forms.DataVisualization

            #Create our chart object
            $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
            $Chart.Width = 200
            $Chart.Height = 160
            $Chart.Left = 0
            $Chart.Top = 0

            #Create a chartarea to draw on and add this to the chart
            $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
            $Chart.ChartAreas.Add($ChartArea)
            [void]$Chart.Series.Add("Data")

            #Add a datapoint for each value specified in the parameter hash table
            $Data.GetEnumerator() | foreach {
                $datapoint = new-object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $_.Value.Value)
                $datapoint.AxisLabel = "$($_.Value.Header)" + "(" + $($_.Value.Value) + " GB)"
                $Chart.Series["Data"].Points.Add($datapoint)
            }

            $Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
            $Chart.Series["Data"]["PieLabelStyle"] = "Outside"
            $Chart.Series["Data"]["PieLineColor"] = "Black"
            $Chart.Series["Data"]["PieDrawingStyle"] = "Concave"
            ($Chart.Series["Data"].Points.FindMaxByValue())["Exploded"] = $true

            #Set the title of the Chart
            $Title = new-object System.Windows.Forms.DataVisualization.Charting.Title
            $Chart.Titles.Add($Title)
            $Chart.Titles[0].Text = $Name

            If($SaveAsFile){
                # save chart to file
                $FileName = $Name -replace '[\W+]', ' ' -replace '\s+','_'
                $File = ($env:Temp + '\' + $FileName + '_' + $(get-date -format "yyyyMMdd_hhmmsstt") + '.png')
                Try{$Chart.SaveImage($File, "PNG")}
                Catch{Remove-Item $File -Force -ErrorAction SilentlyContinue;$Chart.SaveImage($File, "PNG")}

                If($Passthru){
                    Return $File
                }
            }
            Else{
                #Save the chart to a memory stream, then to the hash table as a byte array
                #$Stream = New-Object System.IO.MemoryStream
                #$Chart.SaveImage($Stream,"png")
                #$Window.Stream = $Stream.GetBuffer()
                #$Stream.Dispose()
                $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
                $bitmap.BeginInit()
                $bitmap.StreamSource = [System.IO.MemoryStream]
                [System.Convert]::FromBase64String($Chart)
                $bitmap.EndInit()
                $bitmap.Freeze()

                If($Passthru){
                    Return $bitmap
                }
            }
            $Chart.Dispose()
        }

        #populate data on start
        $syncHash.Disks = Get-Disk
        $syncHash.Volumes = $syncHash.Disks | Get-Partition | Get-Volume

        $syncHash.lstDisks.ItemsSource = @($syncHash.Disks | Sort DiskNumber | Select Number,FriendlyName,PartitionStyle,ProvisioningType,
                                    @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}})

        $syncHash.lstVolumes.ItemsSource = @($syncHash.Volumes | Sort DriveLetter |
                                    Select @{Name="Disk";Expression={Get-Partition -DriveLetter $_.Driveletter | Select-Object -ExpandProperty DiskNumber}},
                                        DriveLetter,FileSystemLabel,FileSystem,DriveType,
                                        @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}},
                                        @{Name="SizeRemaining";Expression={([math]::round($_.SizeRemaining /1Gb, 2)).ToString() + ' GB'}})

        <#
        $syncHash.lstDisks.Add_SelectionChanged({
            $VolumeDisk = Get-Disk -Number ($syncHash.lstDisks.SelectedItem).Number | Get-Partition | Get-Volume | Sort DriveLetter |
                                    Select @{Name = 'Disk'; Expression={($syncHash.lstDisks.SelectedItem).Number}},DriveLetter,FileSystemLabel,FileSystem,DriveType,
                                        @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}},
                                        @{Name="SizeRemaining";Expression={([math]::round($_.SizeRemaining /1Gb, 2)).ToString() + ' GB'}}

            $syncHash.lstVolumes.ItemsSource = $VolumeDisk
        })
        #>
        $syncHash.lstVolumes.Add_SelectionChanged({
            #$syncHash.Window.Add_ContentRendered({
                # Create a hash table to store values
                $VolDataSet = @{}
                # Get local Volume usage from WMI
                $Vol = $syncHash.Volumes | Where-Object{$_.DriveLetter -eq ($syncHash.lstVolumes.SelectedItem).DriveLetter}
                # Add Free Volume to a hash table
                $VolDataSet.FreeVol = @{}
                $VolDataSet.FreeVol.Header = "Free Space"
                $VolDataSet.FreeVol.Value = [math]::Round(($Vol.SizeRemaining / 1Gb),2)
                # Add used Volume to a hash table
                $VolDataSet.UsedVol = @{}
                $VolDataSet.UsedVol.Header = "Used Space"
                $VolDataSet.UsedVol.Value = [math]::Round(($Vol.Size / 1Gb - $Vol.SizeRemaining / 1Gb),2)
                # Create the Chart

                # Set the image source
                #$syncHash.imgPieChart.Source = New-PieChart -Window $syncHash -Data $VolDataSet -Name ('Volume Usage for: {0}' -f ($syncHash.lstVolumes.SelectedItem).DriveLetter) -Passthru
                $syncHash.imgPieChart.Source = New-PieChart -Data $VolDataSet -Name ('Volume Usage for: {0}' -f ($syncHash.lstVolumes.SelectedItem).DriveLetter) -SaveAsFile -Passthru
            #})
        })

        $syncHash.btnRefresh.Add_Click({
            #unslect everything
            $syncHash.lstDisks.UnselectAll()
            $syncHash.lstVolumes.UnselectAll()

            #refresh disks and volumes
            $syncHash.Disks = Get-Disk
            $syncHash.Volumes = $syncHash.Disks | Get-Partition | Get-Volume

            $syncHash.lstDisks.ItemsSource = @($syncHash.Disks | Sort DiskNumber | Select Number,FriendlyName,PartitionStyle,ProvisioningType,
                                    @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}})

            $syncHash.lstVolumes.ItemsSource = @($syncHash.Volumes | Sort DriveLetter | Select Disk,DriveLetter,FileSystemLabel,FileSystem,DriveType,
                                        @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}},
                                        @{Name="SizeRemaining";Expression={([math]::round($_.SizeRemaining /1Gb, 2)).ToString() + ' GB'}})
        })

        $syncHash.btnOK.Add_Click({
            Close-DiskMgrWindow
        })

        #Allow UI to be dragged around screen
        $syncHash.Window.Add_MouseLeftButtonDown( {
            $syncHash.Window.DragMove()
        })

        #Add smooth closing for Window
        $syncHash.Window.Add_Loaded({ $syncHash.isLoaded = $True })
        $syncHash.Window.Add_Closing({ $syncHash.isClosing = $True; Close-DiskMgrWindow })
        $syncHash.Window.Add_Closed({ $syncHash.isClosed = $True })

        #make sure this display on top of every window
        $syncHash.Window.Topmost = $true

        $syncHash.window.ShowDialog()
        $syncHash.Error = $Error
    }) # end scriptblock

    #collect data from runspace
    $Data = $syncHash

    #invoke scriptblock in runspace
    $PowerShellCommand.Runspace = $PSDRunSpace
    $AsyncHandle = $PowerShellCommand.BeginInvoke()

    #wait until runspace is completed before ending
    do {
        Start-sleep -m 100 }
    while (!$AsyncHandle.IsCompleted)
    #end invoked process
    $null = $PowerShellCommand.EndInvoke($AsyncHandle)

    #cleanup registered object
    Register-ObjectEvent -InputObject $syncHash.Runspace `
            -EventName 'AvailabilityChanged' `
            -Action {

                    if($Sender.RunspaceAvailability -eq "Available")
                    {
                        $Sender.Closeasync()
                        $Sender.Dispose()
                        # Speed up resource release by calling the garbage collector explicitly.
                        # Note that this will pause *all* threads briefly.
                        [GC]::Collect()
                    }

                } | Out-Null

    If($Data.Error){Write-PSDLog -Message ("{0}: Disk Manager window errored: {1}" -f ${CmdletName}, $Data.Error) -LogLevel 3}
    Else{Write-PSDLog -Message ("{0}: Disk Manager Window closed" -f ${CmdletName})}
    return $Data

}#end diskmgr runspace
#endregion

#region FUNCTION: Loader for confirmation menu
Function Show-PSDStartLoaderConfirmWindow
{
    <#
        .SYNOPSIS
        Present PSD Prestart Action Menu

        .LINK
        https://tiberriver256.github.io/powershell/PowerShellProgress-Pt3/
    #>
    [CmdletBinding()]
    Param(
        [string]$Message,
        [scriptblock]$Action,
        [switch]$Passthru
    )
    [string]${CmdletName} = $MyInvocation.MyCommand
    Write-PSDLog -Message ("{0}: Confirm window started" -f ${CmdletName})

    #build runspace
    $syncHash = [hashtable]::Synchronized(@{})
    $PSDRunSpace =[runspacefactory]::CreateRunspace()
    $syncHash.Runspace = $PSDRunSpace
    $syncHash.InPE = Test-PSDStartLoaderInWinPE
    $syncHash.ConfirmAction = $Action
    $syncHash.ConfirmPassthru = $Passthru
    $syncHash.Message = $Message
    $syncHash.TriggerAction = $false
    $PSDRunSpace.ApartmentState = "STA"
    $PSDRunSpace.ThreadOptions = "ReuseThread"
    $PSDRunSpace.Open() | Out-Null
    $PSDRunSpace.SessionStateProxy.SetVariable("syncHash",$syncHash)
    $PowerShellCommand = [PowerShell]::Create().AddScript({

    [string]$xaml = @"
    <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="Confirm Action"
        mc:Ignorable="d"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Height="120" Width="400"
        AllowsTransparency="True"
        WindowStyle="None">
    <Window.Effect>
        <DropShadowEffect Color="Gray" BlurRadius="20" Direction="-90" RenderingBias="Quality" ShadowDepth="4"/>
    </Window.Effect>
    <Window.Resources>
        <ResourceDictionary>
            <Style TargetType="{x:Type Window}">
                <Setter Property="FontFamily" Value="Segoe UI" />
                <Setter Property="BorderBrush" Value="#004275" />
                <Setter Property="BorderThickness" Value="1" />

            </Style>
        </ResourceDictionary>
    </Window.Resources>
    <Grid>
        <TextBox x:Name="txtMessage" Text="Do you confirm?" TextWrapping="Wrap" IsReadOnly="True" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0" Margin="12,10,8,52" FontSize="18"/>
        <Button x:Name="btnConfirm" Content="Yes" Height="42" Width="94" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="18" Padding="2" Margin="10,0,0,10" />
        <Button x:Name="btnCancel" Content="No" Height="42" Width="94" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontSize="18" Padding="2" Margin="296,0,0,10" />
    </Grid>
</Window>

"@

        #Load assembies to display UI
        [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')

        [xml]$xaml = $xaml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
        $reader=(New-Object System.Xml.XmlNodeReader $xaml)
        $syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
        #===========================================================================
        # Store Form Objects In PowerShell
        #===========================================================================
        $xaml.SelectNodes("//*[@Name]") | %{ $syncHash."$($_.Name)" = $syncHash.Window.FindName($_.Name)}


        # INNER  FUNCTIONS
        #Closes UI objects and exits (within runspace)
        Function Close-ConfirmWindow
        {
            if ($syncHash.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
            #if runspace has not errored Dispose the UI
            if (!($syncHash.isClosing)) { $syncHash.Window.Close() | Out-Null }
        }

        If($syncHash.Message){
            $syncHash.txtMessage.text = $syncHash.Message
        }

        $syncHash.btnCancel.Add_Click({
            Close-ConfirmWindow
        })

        $syncHash.btnConfirm.Add_Click({
            $syncHash.TriggerAction = $true
            #$syncHash.btnConfirm.Dispatcher.Invoke([action]{
                #If($syncHash.ConfirmAction){
                    #$syncHash.ConfirmResult = Invoke-Command -ScriptBlock $syncHash.ConfirmAction
                    #Invoke-Command -ScriptBlock $syncHash.ConfirmAction
                #}
            #},'Normal')
            If($syncHash.ConfirmPassthru){
                $syncHash.ConfirmResult = Invoke-Command -ScriptBlock $syncHash.ConfirmAction
            }Else{
                $syncHash.ConfirmResult = Invoke-Command -ScriptBlock $syncHash.ConfirmAction -ComputerName $env:COMPUTERNAME -AsJob
            }
                
            Close-ConfirmWindow
        })

        #Allow UI to be dragged around screen
        $syncHash.Window.Add_MouseLeftButtonDown( {
            $syncHash.Window.DragMove()
        })

        #Add smooth closing for Window
        $syncHash.Window.Add_Loaded({ $syncHash.isLoaded = $True })
        $syncHash.Window.Add_Closing({ $syncHash.isClosing = $True; Close-ConfirmWindow })
        $syncHash.Window.Add_Closed({ $syncHash.isClosed = $True })

        #make sure this display on top of every window
        $syncHash.Window.Topmost = $true

        $syncHash.window.ShowDialog()
        $syncHash.Error = $Error
    }) # end scriptblock

    #collect data from runspace
    $Data = $syncHash

    #invoke scriptblock in runspace
    $PowerShellCommand.Runspace = $PSDRunSpace
    $AsyncHandle = $PowerShellCommand.BeginInvoke()

    If($Wait){
        #wait until runspace is completed before ending
        do {
            Start-sleep -m 100 }
        while (!$AsyncHandle.IsCompleted)
        #end invoked process
        $null = $PowerShellCommand.EndInvoke($AsyncHandle)
    }

    #cleanup registered object
    Register-ObjectEvent -InputObject $syncHash.Runspace `
            -EventName 'AvailabilityChanged' `
            -Action {

                    if($Sender.RunspaceAvailability -eq "Available")
                    {
                        $Sender.Closeasync()
                        $Sender.Dispose()
                        # Speed up resource release by calling the garbage collector explicitly.
                        # Note that this will pause *all* threads briefly.
                        [GC]::Collect()
                    }

                } | Out-Null

    If($Data.Error){Write-PSDLog -Message ("{0}: Confirm Window errored: {1}" -f ${CmdletName}, $Data.Error) -LogLevel 3}
    Else{Write-PSDLog -Message ("{0}: Confirm Window closed" -f ${CmdletName})}
    return $Data

}#end confirm runspace
#endregion

#region FUNCTION: Loader for debug menu
Function New-PSDStartLoaderPrestartMenu
{
    <#
        .SYNOPSIS
        Present PSD Prestart Action Menu

        .LINK
        https://tiberriver256.github.io/powershell/PowerShellProgress-Pt3/
    #>
    [CmdletBinding()]
    Param(
        [ValidateSet('HorizontalTop','HorizontalBottom','VerticalLeft','VerticalRight')]
        [string]$Position = 'VerticalRight',
        [switch]$OnTop,
        [switch]$Wait
    )
    [string]${CmdletName} = $MyInvocation.MyCommand
    Write-PSDLog -Message ("{0}: Debug Menu started" -f ${CmdletName})

    #build runspace
    $syncHash = [hashtable]::Synchronized(@{})
    $PSDRunSpace =[runspacefactory]::CreateRunspace()
    $syncHash.Runspace = $PSDRunSpace
    $syncHash.InPE = Test-PSDStartLoaderInWinPE
    $syncHash.CmtracePath = Get-PSDStartLoaderCmtrace
    $syncHash.DartTools = Test-PSDStartLoaderHasDartPE
    $syncHash.Test = Test-PSDStartLoaderVSCode
    $syncHash.LogPath = "X:\MININT\SMSOSD\OSDLOGS\PSDStart.log"
    $syncHash.Position = $Position
    $syncHash.TopMost = $OnTop
    $syncHash.NicWindow = {Show-PSDStartLoaderNetCfgWindow}
    $syncHash.PEShutdownConfirm = {Start-Process 'wpeutil' -ArgumentList 'shutdown' -PassThru}
    $syncHash.OSShutdownConfirm = {Show-PSDStartLoaderConfirmWindow -Message "Are you sure you want to shutdown this device?" -Action {Stop-Computer -Force}}
    $syncHash.DiskWindow = {Show-PSDStartLoaderDiskViewerWindow}
    $syncHash.CleanWindow = {Show-PSDStartLoaderDiskCleanWindow}
    $PSDRunSpace.ApartmentState = "STA"
    $PSDRunSpace.ThreadOptions = "ReuseThread"
    $PSDRunSpace.Open() | Out-Null
    $PSDRunSpace.SessionStateProxy.SetVariable("syncHash",$syncHash)
    $PowerShellCommand = [PowerShell]::Create().AddScript({

        [string]$xaml = @"
        <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="PrestartMenu"
        mc:Ignorable="d"
        ResizeMode="NoResize"
        Height="480" Width="120"
        AllowsTransparency="True"
        WindowStyle="None">
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

            <Canvas x:Key="icons_searchlog" Width="24" Height="24">
                <Path Fill="Black" Data="M9 6V8H2V6H9M9 11V13H2V11H9M18 16V18H2V16H18M19.31 11.5C19.75 10.82 20 10 20 9.11C20 6.61 18 4.61 15.5 4.61S11 6.61 11 9.11 13 13.61 15.5 13.61C16.37 13.61 17.19 13.36 17.88 12.93L21 16L22.39 14.61L19.31 11.5M15.5 11.61C14.12 11.61 13 10.5 13 9.11S14.12 6.61 15.5 6.61 18 7.73 18 9.11 16.88 11.61 15.5 11.61Z" />
            </Canvas>

            <Canvas x:Key="icons_wipe" Width="24" Height="24">
                <Path Fill="Black" Data="M12,4C5,4 2,9 2,9L9,16C9,16 9.5,15.1 10.4,14.5L10.7,16.5C10.3,16.8 10,17.4 10,18A2,2 0 0,0 12,20A2,2 0 0,0 14,18C14,17.1 13.5,16.4 12.7,16.1L12.3,14C14.1,14.2 15,16 15,16L22,9C22,9 19,4 12,4M15.1,13.1C14.3,12.5 13.3,12 12,12L11,6.1C11.3,6 11.7,6 12,6C15.7,6 18.1,7.7 19.3,8.9L15.1,13.1M8.9,13.1L4.7,8.9C5.5,8 7,7 9,6.4L10,12.4C9.6,12.6 9.2,12.8 8.9,13.1Z" />
            </Canvas>

            <Canvas x:Key="icons_exit"  Width="24" Height="24">
                <Path Fill="Black" Data="M22 12L18 8V11H10V13H18V16M20 18A10 10 0 1 1 20 6H17.27A8 8 0 1 0 17.27 18Z" />
            </Canvas>

            <Canvas x:Key="icons_shutdown"  Width="24" Height="24">
                <Path Fill="Black" Data="M16.56,5.44L15.11,6.89C16.84,7.94 18,9.83 18,12A6,6 0 0,1 12,18A6,6 0 0,1 6,12C6,9.83 7.16,7.94 8.88,6.88L7.44,5.44C5.36,6.88 4,9.28 4,12A8,8 0 0,0 12,20A8,8 0 0,0 20,12C20,9.28 18.64,6.88 16.56,5.44M13,3H11V13H13" />
            </Canvas>

            <Style TargetType="{x:Type Window}">
                <Setter Property="FontFamily" Value="Segoe UI" />
                <Setter Property="FontWeight" Value="Light" />
                <Setter Property="Background" Value="Transparent"/>
            </Style>

            <Style x:Key="ButtonLightGrayRounded" TargetType="{x:Type Button}">
                <Setter Property="Background" Value="LightGray" />
                <Setter Property="Foreground" Value="Black" />
                <Setter Property="FontSize" Value="15" />
                <Setter Property="SnapsToDevicePixels" Value="True" />
                <Setter Property="Button.Effect">
                    <Setter.Value>
                        <DropShadowEffect Color="Black" BlurRadius="5" Opacity="0.1" />
                    </Setter.Value>
                </Setter>
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
                                    <Setter TargetName="border" Property="BorderBrush" Value="#012456" />
                                    <Setter TargetName="border" Property="BorderThickness" Value="2" />
                                </Trigger>

                                <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="DarkGray" />
                                </Trigger>

                                <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="DarkGray"/>
                                </Trigger>

                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>


        </ResourceDictionary>
    </Window.Resources>
    <Grid>

        <StackPanel x:Name="stackButtons" HorizontalAlignment="Center" VerticalAlignment="Center">

            <Button x:Name="btnWipeDisk" Style="{DynamicResource ButtonLightGrayRounded}" Width="100" HorizontalAlignment="Right" Margin="5" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblWipeDisk" Content="Wipe Disks" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="24" Height="20" Fill="Black" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_wipe}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>

            <Button x:Name="btnOpenDisk" Style="{DynamicResource ButtonLightGrayRounded}" Width="100" HorizontalAlignment="Right" Margin="5" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblOpenDisk" Content="Show Disks" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="DarkGoldenrod" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_disk}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>

            <Button x:Name="btnOpenPSDLog" Style="{DynamicResource ButtonLightGrayRounded}" Width="100" HorizontalAlignment="Right" Margin="5" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblOpenPSDLog" Content="Open PSD log" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="26" Height="18" Fill="BlueViolet" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_searchlog}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>

            <Button x:Name="btnOpenPSWindow" Style="{DynamicResource ButtonLightGrayRounded}" Width="100" HorizontalAlignment="Right" Margin="5" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblOpenPSWindow" Content="Launch PowerShell" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="Blue" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_ps}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>

            <Button x:Name="btnDartPE" Style="{DynamicResource ButtonLightGrayRounded}" Width="100" HorizontalAlignment="Right" Margin="5" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblDartPE" Content="Launch Dart PE" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="Green" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_target}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>

            <Button x:Name="btnAddStaticIP" Style="{DynamicResource ButtonLightGrayRounded}" Width="100" HorizontalAlignment="Right" Margin="5" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblAddStaticIP" Content="Configure Static IP" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="Black" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_cog}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>

            <Button x:Name="btnShutdown" Style="{DynamicResource ButtonLightGrayRounded}" Width="100" HorizontalAlignment="Right" Margin="5" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblShutdown" Content="Shutdown PE" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="Red" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_shutdown}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>

            <Button x:Name="btnExit" Style="{DynamicResource ButtonLightGrayRounded}" Width="100" HorizontalAlignment="Right" Margin="5" >
                <StackPanel Width="91" Height="44">
                    <Label x:Name="lblExit" Content="Continue" BorderThickness="0" HorizontalAlignment="Center" FontSize="10" VerticalContentAlignment="Center" />
                    <Rectangle Width="20" Height="20" Fill="Green" HorizontalAlignment="Center">
                        <Rectangle.OpacityMask>
                            <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_exit}"/>
                        </Rectangle.OpacityMask>
                    </Rectangle>
                </StackPanel>
            </Button>


        </StackPanel>
    </Grid>
</Window>
"@

        #Load assembies to display UI
        [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')

        [xml]$xaml = $xaml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
        $reader=(New-Object System.Xml.XmlNodeReader $xaml)
        $syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
        #===========================================================================
        # Store Form Objects In PowerShell
        #===========================================================================
        $xaml.SelectNodes("//*[@Name]") | %{ $syncHash."$($_.Name)" = $syncHash.Window.FindName($_.Name)}

        # INNER  FUNCTIONS
        #Closes UI objects and exits (within runspace)
        Function Close-PSDStartLoaderDebugMenu
        {
            if ($syncHash.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
            #if runspace has not errored Dispose the UI
            if (!($syncHash.isClosing)) { $syncHash.Window.Close() | Out-Null }
        }

        Function Set-MenuPosition{
            Param(
                $Runspace,
                [string]$Location = 'Right'
            )

            Switch ($Location) {
                "Up"
                {
                    $syncHash.MenuPosition = 'HorizontalTop'
                    $Runspace.stackButtons.Orientation = "Horizontal"
                    $Runspace.Window.Height = 60
                    $Runspace.Window.Width = 880
                    $Runspace.Window.Left = $([System.Windows.SystemParameters]::WorkArea.Width-$Runspace.Window.Width)/2
                    $Runspace.Window.Top = 10
                }
                "Left"
                {
                    $syncHash.MenuPosition = 'VerticalLeft'
                    $Runspace.stackButtons.Orientation = "Vertical"
                    $Runspace.Window.Height = 480
                    $Runspace.Window.Width = 120
                    $Runspace.Window.Left = 20
                    $Runspace.Window.Top = $([System.Windows.SystemParameters]::WorkArea.Height-$Runspace.Window.Height)/2
                }
                "Right"
                {
                    $syncHash.MenuPosition = 'VerticalRight'
                    $Runspace.stackButtons.Orientation = "Vertical"
                    $Runspace.Window.Height = 480
                    $Runspace.Window.Width = 120
                    $Runspace.Window.Left = $([System.Windows.SystemParameters]::WorkArea.Width-$Runspace.Window.Width)-20
                    $Runspace.Window.Top = $([System.Windows.SystemParameters]::WorkArea.Height-$Runspace.Window.Height)/2
                }
                "Down"
                {
                    $syncHash.MenuPosition = 'HorizontalBottom'
                    $Runspace.stackButtons.Orientation = "Horizontal"
                    $Runspace.Window.Height = 60
                    $Runspace.Window.Width = 880
                    $Runspace.Window.Left = $([System.Windows.SystemParameters]::WorkArea.Width-$Runspace.Window.Width)/2
                    $Runspace.Window.Top = $([System.Windows.SystemParameters]::WorkArea.Height-$Runspace.Window.Height)-15
                }
            }
        }

        #put menu in correct position on load
        Switch ($syncHash.Position)
        {
            "HorizontalTop" { Set-MenuPosition -Runspace $syncHash -Location Up}
            "VerticalLeft" { Set-MenuPosition -Runspace $syncHash -Location Left}
            "VerticalRight" { Set-MenuPosition -Runspace $syncHash -Location Right }
            "HorizontalBottom" { Set-MenuPosition -Runspace $syncHash -Location Down}
        }

        If(-Not($syncHash.Test) )
        {
            #hide options not allowed in Windows
            If(-Not($syncHash.InPE) ){
                $syncHash.btnDartPE.Visibility = 'Collapsed'
                $syncHash.btnWipeDisk.Visibility = 'Collapsed'
                $syncHash.btnAddStaticIP.Visibility = 'Collapsed'
            }

            If(-Not($syncHash.DartTools)){
                $syncHash.btnDartPE.Visibility = 'Collapsed'
            }

            #check to see if cmtrace exists
            If(-Not($syncHash.CmtracePath)){
                $syncHash.btnOpenPSDLog.Visibility = 'Collapsed'
            }
        }

        #change label of shutdown based on environment
        If($syncHash.InPE){
            $syncHash.lblShutdown.Content = 'Shutdown PE'
        }Else{
            $syncHash.lblShutdown.Content = 'Shutdown Windows'
        }

        $syncHash.btnWipeDisk.Add_Click({
            # Temporarily disable this button to prevent re-entry.
            $this.IsEnabled = $false
            #$syncHash.Window.Dispatcher.Invoke([action]{ 
                $syncHash.WipeDiskMenu = Invoke-Command -ScriptBlock $syncHash.CleanWindow 
            #},'Normal')
            $this.IsEnabled = $syncHash.WipeDiskMenu.isClosed
        })

        $syncHash.btnOpenDisk.Add_Click({
            # Temporarily disable this button to prevent re-entry.
            $this.IsEnabled = $false
            #$syncHash.btnOpenDisk.Dispatcher.Invoke([action]{
                $syncHash.DiskViewerMenu = Invoke-Command -ScriptBlock $syncHash.DiskWindow
            #},'Normal')
            $this.IsEnabled = $syncHash.DiskViewerMenu.isClosed
        })

        #action for poshwindow button
        $syncHash.btnOpenPSDLog.Add_Click({
            #check to see if psd.log exists
            If(Test-Path $syncHash.LogPath){
                $StartArg = @{
                    ArgumentList=$syncHash.LogPath
                    WindowStyle='Normal'
                    PassThru=$true
                }
            }
            Else{
                $StartArg = @{
                    WindowStyle='Normal'
                    PassThru=$true
                }
            }

            #run cmtrace is found
            If($LogTool = $syncHash.CmtracePath){
                $syncHash.OpenPSDLog = Start-Process $LogTool @StartArg
            }
        })

        #action for poshwindow button
        $syncHash.btnOpenPSWindow.Add_Click({
            If($syncHash.InPE){
                $syncHash.OpenPoSH = Start-Process 'powershell.exe' -WorkingDirectory 'X:\' -PassThru
            }
            Else{
                $syncHash.OpenPoSH = Start-Process 'powershell.exe' -WorkingDirectory $env:windir -PassThru
            }
        })

        $syncHash.btnDartPE.Add_Click({
            # Temporarily disable this button to prevent re-entry.
            $this.IsEnabled = $false
            If($syncHash.DartTools){
                $syncHash.OpenDaRT = Start-Process 'X:\Sources\Recovery\Tools\MsDartTools.exe' -Wait -PassThru
            }
            #hide incase this button shows back up and its clicked but no Dart is installed
            Else{
                $syncHash.btnDartPE.Visibility = 'Collapsed'
                $syncHash.OpenDaRT = $false
            }
            $this.IsEnabled = $true
        })

        $syncHash.btnAddStaticIP.Add_Click({
            #$syncHash.btnAddStaticIP.Dispatcher.Invoke([action]{
                # Temporarily disable this button to prevent re-entry.
                $this.IsEnabled = $false
                $syncHash.NicConfigMenu = Invoke-Command -ScriptBlock $syncHash.NicWindow
                $this.IsEnabled = $syncHash.NicConfigMenu.isClosed
            #},'Normal')
        })

        #action for exit button
        $syncHash.btnShutdown.Add_Click({
            # Temporarily disable this button to prevent re-entry.
            $this.IsEnabled = $false
            If($syncHash.InPE){
                $syncHash.ConfirmWindow = Invoke-Command -ScriptBlock $syncHash.PEShutdownConfirm
            }Else{
                $syncHash.ConfirmWindow = Invoke-Command -ScriptBlock $syncHash.OSShutdownConfirm
            }
            $this.IsEnabled = $syncHash.ConfirmWindow
        })

        #action for exit button
        $syncHash.btnExit.Add_Click({
            Close-PSDStartLoaderDebugMenu
        })

        #change position of menu based on arrow keys
        $syncHash.Window.Add_KeyDown( {
            Set-MenuPosition -Runspace $syncHash -Location $_.Key
        })

        #Add smooth closing for Window
        $syncHash.Window.Add_Loaded({ $syncHash.isLoaded = $True })
    	$syncHash.Window.Add_Closing({ $syncHash.isClosing = $True; Close-PSDStartLoaderDebugMenu })
    	$syncHash.Window.Add_Closed({ $syncHash.isClosed = $True })

        #make sure this display on top of every window
        $syncHash.Window.Topmost = $syncHash.TopMost

        $syncHash.Window.ShowDialog()
        #$PSDRunspace.Close()
        #$PSDRunspace.Dispose()
        $syncHash.Error = $Error
    }) # end scriptblock

    #collect data from runspace
    $Data = $syncHash

    #invoke scriptblock in runspace
    $PowerShellCommand.Runspace = $PSDRunSpace
    $AsyncHandle = $PowerShellCommand.BeginInvoke()

    If($Wait){
        #wait until runspace is completed before ending
        do {
            Start-sleep -m 100
        }
        while (!$AsyncHandle.IsCompleted)
        #end invoked process
        $null = $PowerShellCommand.EndInvoke($AsyncHandle)
    }
    #cleanup registered object
    Register-ObjectEvent -InputObject $syncHash.Runspace `
            -EventName 'AvailabilityChanged' `
            -Action {

                    if($Sender.RunspaceAvailability -eq "Available")
                    {
                        $Sender.Closeasync()
                        $Sender.Dispose()
                        # Speed up resource release by calling the garbage collector explicitly.
                        # Note that this will pause *all* threads briefly.
                        [GC]::Collect()
                    }

                } | Out-Null

    If($Data.Error){Write-PSDLog -Message ("{0}: Debug Menu errored: {1}" -f ${CmdletName}, $Data.Error) -LogLevel 3}
    Else{Write-PSDLog -Message ("{0}: Debug Menu closed" -f ${CmdletName})}
    return $Data

}#end runspacce
#endregion

#region FUNCTION: Loader for main start UI
Function New-PSDStartLoader
{
    <#
        .SYNOPSIS
        Present PSDLoader like interface with status

        .LINK
        https://tiberriver256.github.io/powershell/PowerShellProgress-Pt3/
    #>
    [CmdletBinding()]
    Param(
        [string]$LogoImgPath,
        [ValidateSet('HorizontalTop','HorizontalBottom','VerticalLeft','VerticalRight')]
        [string]$MenuPosition = 'VerticalRight',
        [switch]$Preload,
        [switch]$FullScreen
    )
    [string]${CmdletName} = $MyInvocation.MyCommand
    Write-PSDLog -Message ("{0}: PSDStartLoader started" -f ${CmdletName})

    #build runspace
    $syncHash = [hashtable]::Synchronized(@{})
    $PSDRunSpace =[runspacefactory]::CreateRunspace()
    $syncHash.Runspace = $PSDRunSpace
    $syncHash.Test = Test-PSDStartLoaderVSCode
    $syncHash.InPE = Test-PSDStartLoaderInWinPE
    $syncHash.PreloadInfo = $Preload
    $syncHash.DebugMode = $False
    $syncHash.SyncTSProgress = $False
    $syncHash.HideTSProgress = $False
    #$syncHash.TSProgressStatus = {Get-PSDStartTSProgress}
    $syncHash.DartTools = Test-PSDStartLoaderHasDartPE
    $syncHash.MenuPosition = $MenuPosition
    $syncHash.ShowPrestartMenu = {New-PSDStartLoaderPrestartMenu -Position $args[0] -OnTop}
    $syncHash.CheckboxStyle = Add-PSDStartLoaderCheckboxStyle
    $syncHash.DeviceInfoCommand = {Get-PSDLocalInfo -PassThru}
    $syncHash.NetworkInfoCommand  = {Get-PSDStartLoaderInterfaceDetails}
    $syncHash.LogoImg = $LogoImgPath
    $syncHash.OrgName = "PowerShell Deployment"
    $syncHash.Fullscreen = $FullScreen
    $syncHash.PrestartCounter = 0
    $PSDRunSpace.ApartmentState = "STA"
    $PSDRunSpace.ThreadOptions = "ReuseThread"
    $PSDRunSpace.Open() | Out-Null
    $PSDRunSpace.SessionStateProxy.SetVariable("syncHash",$syncHash)
    $PowerShellCommand = [PowerShell]::Create().AddScript({

        [string]$xaml = @"
        <Window
            xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
            xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
            xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
            Title="PSDLoader"
            Width="1024"
            Height="768"
            WindowStartupLocation="CenterScreen"
            mc:Ignorable="d">
            <Window.Resources>
                <ResourceDictionary>
                    <Canvas x:Key="icons_menu" Width="24" Height="24">
                        <Path Stretch="Fill" Fill="White" Data="M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2M6,7H18V9H6V7M6,11H18V13H6V11M6,15H18V17H6V15Z" />
                    </Canvas>

                    <Style TargetType="{x:Type Window}">
                        <Setter Property="FontFamily" Value="Segoe UI" />
                        <Setter Property="FontWeight" Value="Light" />
                        <Setter Property="Background" Value="#012456" />
                        <Setter Property="Foreground" Value="white" />
                    </Style>

                    $($syncHash.CheckboxStyle)

                    <Style x:Key="ButtonBlueRounded" TargetType="{x:Type Button}">
                        <Setter Property="Background" Value="#012456" />
                        <Setter Property="Foreground" Value="White" />
                        <Setter Property="FontSize" Value="15" />
                        <Setter Property="SnapsToDevicePixels" Value="True" />
                        <Setter Property="Button.Effect">
                            <Setter.Value>
                                <DropShadowEffect Color="Gray" BlurRadius="20" Direction="-90" RenderingBias="Quality" ShadowDepth="4"/>
                            </Setter.Value>
                        </Setter>
                        <Setter Property="Template">
                            <Setter.Value>
                                <ControlTemplate TargetType="Button" >

                                    <Border Name="border"
                            BorderThickness="1"
                            Padding="4,2"
                            BorderBrush="#012456"
                            CornerRadius="5,5,5,5"
                            Background="#2e5894">
                                        <ContentPresenter HorizontalAlignment="Center"
                                            VerticalAlignment="Center"
                                            TextBlock.TextAlignment="Center"
                                            />
                                    </Border>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter TargetName="border" Property="BorderBrush" Value="#00308f" />
                                        </Trigger>

                                        <Trigger Property="IsPressed" Value="True">
                                            <Setter TargetName="border" Property="BorderBrush" Value="#72a0c1" />
                                            <Setter TargetName="border" Property="Background" Value="#2e5894" />
                                        </Trigger>

                                        <Trigger Property="IsEnabled" Value="False">
                                            <Setter TargetName="border" Property="BorderBrush" Value="LightGray" />
                                            <Setter TargetName="border" Property="Background" Value="#bcd4e6" />
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
                    <StackPanel Margin="20,0,192,0">
                        <Label Content="Progress:" HorizontalAlignment="Left" FontWeight="Bold" FontSize="16" VerticalAlignment="Top" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Left"/>
                        <TextBlock x:Name="txtStatus" Text="Loading PSD status messages..." Foreground="Black" FontSize="18" HorizontalAlignment="Left" Margin="10,0,0,0" TextWrapping="Wrap" />

                        <Label Content="Computer Info:" HorizontalAlignment="Left" FontWeight="Bold" FontSize="16" Margin="0,20,0,0" VerticalAlignment="Top" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Left"/>
                        <Grid Height="109" Width="323" HorizontalAlignment="Left" >
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="auto" MinWidth="121"></ColumnDefinition>
                                <ColumnDefinition Width="189*"/>
                                <ColumnDefinition Width="auto"></ColumnDefinition>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions>
                                <RowDefinition></RowDefinition>
                                <RowDefinition></RowDefinition>
                                <RowDefinition></RowDefinition>
                                <RowDefinition></RowDefinition>
                            </Grid.RowDefinitions>
                            <Label Content="Manufacturer:" HorizontalAlignment="Center" FontSize="12"  VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right"/>
                            <TextBox x:Name="txtManufacturer" Grid.Row="0" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="12" IsReadOnly="True" Margin="0,5,0,5" Width="202" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0" Grid.ColumnSpan="2"/>
                            <Label Content="Model:" Grid.Row="1" HorizontalAlignment="Center" FontSize="12" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                            <TextBox x:Name="txtModel" Grid.Row="1" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="12" IsReadOnly="True" Margin="0,5,0,6" Width="202" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0" Grid.ColumnSpan="2"/>
                            <Label Content="Serial Number:" Grid.Row="2" HorizontalAlignment="Center" FontSize="12" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right"/>
                            <TextBox x:Name="txtSerialNumber" Grid.Row="2" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="12" IsReadOnly="True" Margin="0,4,0,5" Width="202" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0" Grid.ColumnSpan="2"/>
                            <Label Content="Asset Tag:" Grid.Row="3" HorizontalAlignment="Center" FontSize="12" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right"/>
                            <TextBox x:Name="txtAssetTag" Grid.Row="3" Grid.Column="1" HorizontalAlignment="Center" TextWrapping="NoWrap" FontSize="12" IsReadOnly="True" Margin="0,5,0,5" Width="202" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0" Grid.ColumnSpan="2"/>
                        </Grid>
                        <Label Content="Network Info:" HorizontalAlignment="Left" FontWeight="Bold" FontSize="16" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Left"/>

                        <Grid Height="126" Width="314" HorizontalAlignment="Left" >
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
                            <Label Content="Mac Address:" Grid.Row="0" Grid.Column="0" HorizontalAlignment="Right" FontSize="12" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                            <TextBox x:Name="txtMac" Grid.Row="0" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="12" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                            <Label Content="IP Address:" Grid.Row="1" Grid.Column="0" HorizontalAlignment="Right" FontSize="12" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                            <TextBox x:Name="txtIP" Grid.Row="1" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="12" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                            <Label Content="Subnet:" Grid.Row="2" Grid.Column="0" HorizontalAlignment="Right" FontSize="12" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                            <TextBox x:Name="txtSubnet" Grid.Row="2" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="12" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                            <Label Content="Default Gateway:" Grid.Row="3" Grid.Column="0" HorizontalAlignment="Right" FontSize="12" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right"/>
                            <TextBox x:Name="txtGateway" Grid.Row="3" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="12" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                            <Label Content="DHCP Server:" Grid.Row="4" Grid.Column="0" HorizontalAlignment="Right" FontSize="12" VerticalAlignment="Center" Foreground="Black" Height="31" Width="121" HorizontalContentAlignment="Right" />
                            <TextBox x:Name="txtDHCP" Grid.Row="4" Grid.Column="1" HorizontalAlignment="Left" TextWrapping="NoWrap" FontSize="12" IsReadOnly="True" Margin="0,5,0,5" Width="189" VerticalContentAlignment="Center" Padding="2,0,0,0" BorderThickness="0"/>
                        </Grid>

                    </StackPanel>

                    <TextBlock x:Name="txtPercentage" HorizontalAlignment="Center" VerticalAlignment="Top" Foreground="#012456" Margin="0,543,0,0" />
                    <ProgressBar x:Name="ProgressBar" Width="724" Height="4" Margin="0,564,0,0" HorizontalAlignment="Center" VerticalAlignment="Top" Background="White" Foreground="LightGreen" />
                    <TextBlock x:Name="txtTSStatus" HorizontalAlignment="Center" VerticalAlignment="Top" Foreground="#012456" Margin="0,571,0,0" />
                    <ProgressBar x:Name="TSProgressBar" Width="724" Height="4" Margin="0,592,0,0" HorizontalAlignment="Center" VerticalAlignment="Top" Background="White" Foreground="LightGreen" />

                    <StackPanel HorizontalAlignment="Center" Width="1024" VerticalAlignment="Center" Height="614">

                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" >
                            <TextBlock x:Name="txtDebug" Text="Debug Mode" Foreground="Black" VerticalAlignment="Center" Margin="10" FontSize="18"/>
                            <CheckBox x:Name="chkDebug" Style="{DynamicResource ModernCircleSlider}" Margin="0,10,20,10" Width="58" HorizontalAlignment="Right" />
                        </StackPanel>


                        <Button x:Name="btnPrestart" Style="{DynamicResource ButtonBlueRounded}" Width="197" Margin="0,100,0,0" Height="112">
                            <StackPanel Width="187" Height="91">
                                <Label x:Name="lblPrestart" Content="Launch Prestart" BorderThickness="0" HorizontalAlignment="Center" FontSize="24" VerticalContentAlignment="Center" Foreground="#f0f8ff" Height="46" />
                                <Rectangle Width="40" Height="40" Fill="#f0f8ff" HorizontalAlignment="Center">
                                    <Rectangle.OpacityMask>
                                        <VisualBrush Stretch="Fill" Visual="{DynamicResource icons_menu}"/>
                                    </Rectangle.OpacityMask>
                                </Rectangle>
                            </StackPanel>
                        </Button>
                        <TextBlock x:Name="txtCountdown" HorizontalAlignment="Center" FontSize="18" Height="96" Foreground="#012456" Margin="10" />

                    </StackPanel>
                </Grid>
                <Image x:Name="imgLogo" Width="72" Height="66" Margin="20,0,0,18" HorizontalAlignment="Left" VerticalAlignment="Bottom"  />
                <Label x:Name="lblOrg" Width="882" Margin="0,0,20,18" HorizontalAlignment="Right" VerticalAlignment="Bottom" VerticalContentAlignment="Center" HorizontalContentAlignment="Right" FontSize="36" Foreground="White" Height="70" />
            </Grid>
        </Window>
"@

        #Load assembies to display UI
        [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')

        [xml]$xaml = $xaml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
        $reader=(New-Object System.Xml.XmlNodeReader $xaml)
        $syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
        #===========================================================================
        # Store Form Objects In PowerShell
        #===========================================================================
        $xaml.SelectNodes("//*[@Name]") | %{ $syncHash."$($_.Name)" = $syncHash.Window.FindName($_.Name)}

        #close caller window if debugging or testing mode in not enabled
        If ( ($syncHash.DebugMode -eq $false) -or ($syncHash.Test -eq $false) ) {
            # Make PowerShell Disappear
            $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
            $asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
            $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
        }

        # INNER  FUNCTIONS
        #Closes UI objects and exits (within runspace)
        Function Close-PSDStartLoader
        {
            if ($syncHash.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
            #if runspace has not errored Dispose the UI
            if (!($syncHash.isClosing)) { $syncHash.Window.Close() | Out-Null }
        }

        #add elements that you want to update often
        #the value must also be added to top of function as synchash property
        #then it can be called by the timer to update
        $updateBlock = {
            #monitor menu close status
            If($syncHash.PrestartMenu.isClosed){
                $syncHash.btnPrestart.IsEnabled = $True
            }

            #Update Label
            $syncHash.lblOrg.Content = $syncHash.OrgName
            
            #Update Debug Checkbox
            $syncHash.chkDebug.IsChecked = $syncHash.DebugMode

            if($syncHash.LogoImg){
                $syncHash.imgLogo.Source = $syncHash.LogoImg
            }

            #syncronize with TS progress and display results in Loader
            If($syncHash.SyncTSProgress -eq $true)
            {
                #check if tsenvrionemt is loaded in runspace
                If(!$tsenv){
                    $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
                }
                #check if tsprogreessui is loaded in runspace
                If(!$TSProgressUI){
                    $TSProgressUI = New-Object -ComObject Microsoft.SMS.TSProgressUI -ErrorAction SilentlyContinue
                    If($syncHash.HideTSProgress -eq $true){
                        $TSProgressUI.CloseProgressDialog()
                    }
                }
                #attempt to update progressbar with TS values
                Try{
                    $syncHash.txtPercentage.Text = $tsenv.Value("_SMSTSCurrentActionName")
                    $syncHash.ProgressBar.Value = ( ([Convert]::ToUInt32($tsenv.Value("_SMSTSNextInstructionPointer")) / [Convert]::ToUInt32($tsenv.Value("_SMSTSInstructionTableSize"))) * 100)
                }Catch{}
            }

            #refesh window
            #[Windows.Input.InputEventHandler]{ $syncHash.Window.UpdateLayout() }
        }

        #update devcie details
        If($syncHash.PreloadInfo -eq $true){
            $syncHash.DeviceInfo = Invoke-Command -ScriptBlock $syncHash.DeviceInfoCommand
            $syncHash.NetworkInfo = Invoke-Command -ScriptBlock $syncHash.NetworkInfoCommand
            $syncHash.txtManufacturer.text = ($syncHash.DeviceInfo).Manufacturer
            $syncHash.txtModel.text = ($syncHash.DeviceInfo).Model
            $syncHash.txtSerialNumber.text = ($syncHash.DeviceInfo).SerialNumber
            $syncHash.txtAssetTag.text = ($syncHash.DeviceInfo).assettag
            $syncHash.txtMac.text = ($syncHash.NetworkInfo).MacAddress
            $syncHash.txtIP.text = ($syncHash.NetworkInfo).IPAddress
            $syncHash.txtSubnet.text = ($syncHash.NetworkInfo).SubnetMask
            $syncHash.txtGateway.text = ($syncHash.NetworkInfo).GatewayAddresses
            $syncHash.txtDHCP.text = ($syncHash.NetworkInfo).DhcpServer
        }

        $syncHash.btnPrestart.Visibility = 'Hidden'
        $syncHash.txtCountdown.Visibility = 'Hidden'
        #Currently hide second progressbar
        $syncHash.txtTSStatus.Visibility = 'Hidden'
        $syncHash.TSProgressBar.Visibility = 'Hidden'

        #monitor checkbox event
        [System.Windows.RoutedEventHandler]$Script:CheckedEventHandler = {
            $syncHash.DebugMode = $true
        }

        #Do Debug actions when checked
        $syncHash.chkDebug.AddHandler([System.Windows.Controls.CheckBox]::CheckedEvent, $CheckedEventHandler)

        [System.Windows.RoutedEventHandler]$Script:UnCheckedEventHandler = {
            $syncHash.DebugMode = $false
        }

        #Do Debug action when unchecked
        $syncHash.chkDebug.AddHandler([System.Windows.Controls.CheckBox]::UncheckedEvent, $UnCheckedEventHandler)

        #action for exit button
        $syncHash.btnPrestart.Add_Click({
            # Temporarily disable this button to prevent re-entry.
            $this.IsEnabled = $false

            $syncHash.Window.Dispatcher.Invoke([action]{
                $syncHash.PrestartMenu = Invoke-Command -ScriptBlock $syncHash.ShowPrestartMenu -ArgumentList $syncHash.MenuPosition
            },'Normal')
            #$this.IsEnabled = $syncHash.PrestartMenu.isClosed
        })

        If(-Not($syncHash.Test) )
        {
            #maximze window if called
            If($syncHash.Fullscreen){
                $syncHash.Window.WindowState = "Maximized"
                $syncHash.Window.WindowStyle = "None"
            }
        }

        #Allow space to hide start wizard
        $syncHash.Window.Add_KeyDown( {
            if ($_.Key -match 'F9') {
                If($syncHash.Window.WindowState -eq "Maximized"){
                    #$syncHash.Window.ShowInTaskbar = $true
                    $syncHash.Window.WindowState = 'Normal'
                    $syncHash.Window.WindowStyle = 'SingleBorderWindow'
                }
                Else{
                    $syncHash.Window.WindowState = "Maximized"
                    $syncHash.Window.WindowStyle = "None"
                }
            }
        })


        # Before the UI is displayed
        # Create a timer dispatcher to watch for value change externally on regular interval
        # update those values when found using scriptblock ($updateblock)
        $syncHash.Window.Add_SourceInitialized({
            ## create a timer
            $timer = new-object System.Windows.Threading.DispatcherTimer
            ## set to fire 4 times every second
            $timer.Interval = [TimeSpan]"0:0:0.01"
            ## invoke the $updateBlock after each fire
            $timer.Add_Tick( $updateBlock )
            ## start the timer
            $timer.Start()

            if( -Not($timer.IsEnabled) ) {
               $syncHash.Error = "Timer didn't start"
            }
        })

        #Add smooth closing for Window
        $syncHash.Window.Add_Loaded({ $syncHash.isLoaded = $True })
    	$syncHash.Window.Add_Closing({ $syncHash.isClosing = $True; Close-PSDStartLoader })
    	$syncHash.Window.Add_Closed({ $syncHash.isClosed = $True })

        #always force windows on bottom
        $syncHash.Window.Topmost = $False

        $syncHash.Window.ShowDialog()
        #$PSDRunspace.Close()
        #$PSDRunspace.Dispose()
        $syncHash.Error = $Error
    }) # end scriptblock

    #collect data from runspace
    $Data = $syncHash

    #invoke scriptblock in runspace
    $PowerShellCommand.Runspace = $PSDRunSpace
    $AsyncHandle = $PowerShellCommand.BeginInvoke()

    #cleanup registered object
    Register-ObjectEvent -InputObject $syncHash.Runspace `
            -EventName 'AvailabilityChanged' `
            -Action {

                    if($Sender.RunspaceAvailability -eq "Available")
                    {
                        $Sender.Closeasync()
                        $Sender.Dispose()
                        # Speed up resource release by calling the garbage collector explicitly.
                        # Note that this will pause *all* threads briefly.
                        [GC]::Collect()
                    }

                } | Out-Null

    If($Data.Error){Write-PSDLog -Message ("{0}: PSDStartLoader errored: {1}" -f ${CmdletName}, $Data.Error) -LogLevel 3}
    Else{Write-PSDLog -Message ("{0}: PSDStartLoader closed" -f ${CmdletName})}
    Return $Data
}
#endregion

#region FUNCTION: Initiate countdown for main loader
Function Invoke-PSDStartLoaderCountdown
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Runspace,
        [Parameter(Mandatory=$true)]
        [String]$Element,
        [Parameter(Mandatory=$true)]
        [int]$StartCount,
        [Parameter(Mandatory=$false)]
        [String]$CustomOutput,
        [Parameter(Mandatory=$false)]
        [int]$WarnCount,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Small','Medium','Large')]
        [String]$Size = 'Small',
        [scriptblock]$EndAction,
        [string[]]$Arguments
    )

    [string]${CmdletName} = $MyInvocation.MyCommand

    Switch($Size){
        'Small' {$FontSize = '18'}
        'Medium' {$FontSize = '32'}
        'Large' {$FontSize = '48'}
    }

    #detemine supported elements and the property to update
    Switch($Runspace.$Element.GetType().Name){
        'Button' {$property = 'Content'}
        'Label' {$property = 'Content'}
        'TextBox' {$property = 'Text'}
        'TextBlock' {$property = 'Text'}
        default {$property = 'Text'}
    }

    #ensure TS progress is hidden
    Set-PSDStartLoaderProperty -Runspace $Runspace -PropertyName SyncTSProgress -Value $false

    Write-PSDLog -Message ("{0}: Started count down from {1} seconds" -f ${CmdletName},$StartCount)

    Set-PSDStartLoaderElement -Runspace $Runspace -ElementName txtCountdown -Property FontSize -Value $FontSize

    #ensure element is visable
    Set-PSDStartLoaderElement -Runspace $Runspace -ElementName $Element -Property Visibility -Value 'Visible'

    while ($StartCount -ge 0)
    {
        #update the elements countdown value
        If($CustomOutput){
            $CounterOutput = $CustomOutput.replace('{0}',$StartCount)
            Set-PSDStartLoaderElement -Runspace $Runspace -ElementName $Element -Property $property -Value $CounterOutput
        }Else{
            Set-PSDStartLoaderElement -Runspace $Runspace -ElementName $Element -Property $property -Value $StartCount
        }

        If($StartCount -le $WarnCount){
            Set-PSDStartLoaderElement -Runspace $Runspace -ElementName txtCountdown -Property Foreground -Value "Red"
        }

        start-sleep 1
        $StartCount -= 1
    }
    Write-PSDLog -Message ("{0}: Completed count down" -f ${CmdletName})

    #ensure element is visable
    Set-PSDStartLoaderElement -Runspace $Runspace -ElementName $Element -Property Visibility -Value 'Hidden'
    Set-PSDStartLoaderElement -Runspace $Runspace -ElementName txtCountdown -Property Foreground -Value "Black"

    #invoke an action if specified
    If($EndAction){
        If($Arguments.Count -gt 0){
            $invokeparam = @{
                ScriptBlock=$EndAction
                ArgumentList=$arguments
            }
        }Else{
            $invokeparam = @{
                ScriptBlock=$EndAction
            }
        }
        Invoke-Command @invokeparam
    }
}
#endregion


#region FUNCTION: Initiate countdown for prestart menu
Function Invoke-PSDStartPrestartButton
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Runspace,
        [Parameter(Mandatory=$true)]
        [int]$HideCountdown,
        [switch]$Wait
    )

    [string]${CmdletName} = $MyInvocation.MyCommand

    #ensure TS progress is hidden
    Set-PSDStartLoaderProperty -Runspace $Runspace -PropertyName SyncTSProgress -Value $false

    #Show counter and button
    Set-PSDStartLoaderElement -Runspace $Runspace -ElementName btnPrestart -Property Visibility -Value 'Visible'
    Set-PSDStartLoaderElement -Runspace $Runspace -ElementName txtCountdown -Property Visibility -Value 'Visible'

    Invoke-PSDStartLoaderCountdown -Runspace $PSDStartLoader -Element 'txtCountdown' -StartCount '10' -CustomOutput '[ Hiding in {0} ]' -WarnCount 3

    #Hide button and counter
    Set-PSDStartLoaderElement -Runspace $Runspace -ElementName txtCountdown -Property Visibility -Value 'Hidden'
    Set-PSDStartLoaderElement -Runspace $Runspace -ElementName btnPrestart -Property Visibility -Value 'Hidden'


    If($Runspace.PrestartMenu.isLoaded -and $Wait)
    {
        Set-PSDStartLoaderElement -Runspace $Runspace -ElementName txtStatus -Property Text -Value 'Prestart menu shown, click Continue to proceed.'
        #wait until runspace is completed before continuing preloader
        do {
            Start-sleep -m 100
        }
        until ($Runspace.PrestartMenu.isClosed)
        Set-PSDStartLoaderElement -Runspace $Runspace -ElementName txtStatus -Property Text -Value 'Prestart menu has closed, proceeding.'
    }

    Write-PSDLog -Message ("{0}: Completed count down; hiding Prestart menu button" -f ${CmdletName})
    #ensure element is visable
}
#endregion


#region TESTING A more incremental progress bar
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
        [ValidateSet("LightGreen", "Yellow", "Red", "Blue")]
        [string]$Color = 'LightGreen'
    )

    [string]${CmdletName} = $MyInvocation.MyCommand

    #ensure TS progress is hidden
    Set-PSDStartLoaderProperty -Runspace $Runspace -PropertyName SyncTSProgress -Value $false

    Try{
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
            Write-PSDLog -Message ("{0}: Setting progress bar to indeterminate with status: {1}" -f ${CmdletName},$Status)
            #default to blue when scrolling unless specified otherwise
            if(!$PSBoundParameters.ContainsKey('Color')){$Color = "Blue"}

            $Runspace.ProgressBar.Dispatcher.Invoke([action]{
                $Runspace.ProgressBar.IsIndeterminate = $True
                $Runspace.ProgressBar.Foreground = $Color

                $Runspace.txtPercentage.Visibility = 'Hidden'
                $Runspace.txtPercentage.Text = ' '

                $Runspace.txtStatus.Text = $Status
            },'Normal')

        }
        else
        {
            if(($PercentComplete -gt 0) -and ($PercentComplete -lt 100))
            {
                If($Timespan -gt 1){
                    $Runspace.ProgressBar.Dispatcher.Invoke([action]{
                        $t=1
                        #Determine the incement to go by based on timespan and difference
                        Do{
                            $IncrementTo = $IncrementFrom + ($IncrementBy * $t)
                            Runspace.ProgressBar.IsIndeterminate = $False
                            $Runspace.ProgressBar.Value = $IncrementTo
                            $Runspace.ProgressBar.Foreground = $Color

                            $Runspace.txtPercentage.Visibility = 'Visible'
                            $Runspace.txtPercentage.Text = ('' + $IncrementTo + '%')

                            $Runspace.txtStatus.Text = $Status

                            $t++
                            Start-Sleep 1

                        } Until ($IncrementTo -ge $PercentComplete -or $t -gt $Timespan)
                    },'Normal')
                }
                Else{
                    Write-PSDLog -Message ("{0}: Setting progress bar to {1}% with status: {2}" -f ${CmdletName},$PercentComplete,$Status)
                    $Runspace.ProgressBar.Dispatcher.Invoke([action]{
                        $Runspace.ProgressBar.IsIndeterminate = $False
                        $Runspace.ProgressBar.Value = $PercentComplete
                        $Runspace.ProgressBar.Foreground = $Color

                        $Runspace.txtPercentage.Visibility = 'Visible'
                        $Runspace.txtPercentage.Text = ('' + $PercentComplete + '%')

                        $Runspace.txtStatus.Text = $Status
                    },'Normal')
                }
            }
            elseif($PercentComplete -eq 100)
            {
                Write-PSDLog -Message ("{0}: Setting progress bar to complete with status: {1}" -f ${CmdletName},$Status)
                $Runspace.ProgressBar.Dispatcher.Invoke([action]{
                        $Runspace.ProgressBar.IsIndeterminate = $False
                        $Runspace.ProgressBar.Value = $PercentComplete
                        $Runspace.ProgressBar.Foreground = $Color

                        $Runspace.txtPercentage.Visibility = 'Visible'
                        $Runspace.txtPercentage.Text = ('' + $PercentComplete + '%')

                        $Runspace.txtStatus.Text = $Status
                },'Normal')
            }
            else{
                Write-PSDLog ("{0}: progress bar is out of range" -f ${CmdletName}) -LogLevel 3
            }
        }
    }Catch{}
}
#endregion

#region FUNCTION: retrieve element within runspace
Function Get-PSDStartLoaderElement{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Runspace,

        [Parameter(Mandatory=$true, Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$ElementName,

        [Parameter(Mandatory=$true)]
        [String]$Property
    )
    Begin{
        [string]${CmdletName} = $MyInvocation.MyCommand
    }
    Process{
        If($Value)
        {
            Write-PSDLog -Message ("{0}: Getting element [{1}] property [{2}]" -f ${CmdletName}, $ElementName,$Property)
            Try{
                ($Runspace.GetEnumerator() | Where Name -eq $ElementName | Select -ExpandProperty Value).$Property
            }Catch{
                Write-PSDLog -Message ("{0}: Failed to get element: {1} " -f ${CmdletName}, $_.Exception.Message) -LogLevel 3
            }
        }
    }
}
#endregion

#region FUNCTION: control element within main loader
Function Set-PSDStartLoaderElement{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Runspace,

        [Parameter(Mandatory=$true, Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$ElementName,

        [Parameter(Mandatory=$False)]
        [ValidateSet('Visibility','Text','Content','Foreground','Background','IsReadOnly','IsChecked','IsEnabled','Fill','BorderThickness','BorderBrush','FontSize')]
        [String]$Property = 'Text',

        [Parameter(Mandatory=$False)]
        [String]$Value
    )
    Begin{
        [string]${CmdletName} = $MyInvocation.MyCommand
    }
    Process{
        If($Value)
        {
            Write-PSDLog -Message ("{0}: Setting element [{1}] property [{2}] to [{3}]" -f ${CmdletName}, $ElementName,$Property,$Value)
            Try{
                $Runspace.Window.Dispatcher.invoke([action]{
                    $Runspace.$ElementName.$Property = $Value
                },'Normal')
            }Catch{
                Write-PSDLog -Message ("{0}: Failed to set element: {1} " -f ${CmdletName}, $_.Exception.Message) -LogLevel 3
            }
        }
    }
}
#endregion

#region FUNCTION: Get runspace properties
Function Get-PSDStartLoaderProperty{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Runspace,

        [Parameter(Mandatory=$true, Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$PropertyName
    )
    Begin{
        [string]${CmdletName} = $MyInvocation.MyCommand
    }
    Process{
        Write-PSDLog -Message ("{0}: Getting property [{1}]" -f ${CmdletName}, $PropertyName)
        Try{
            ($Runspace.GetEnumerator() | Where Name -eq $PropertyName).Value
        }Catch{
            Write-PSDLog -Message ("{0}: Failed to get property: {1} " -f ${CmdletName}, $_.Exception.Message) -LogLevel 3
        }
    }
}
#endregion

#region FUNCTION: control properties in runspace
Function Set-PSDStartLoaderProperty{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Runspace,

        [Parameter(Mandatory=$true, Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$PropertyName,

        [Parameter(Mandatory=$true)]
        [String]$Value
    )
    Begin{
        [string]${CmdletName} = $MyInvocation.MyCommand
    }
    Process{
        Write-PSDLog -Message ("{0}: Setting property [{1}] to [{2}]" -f ${CmdletName}, $PropertyName,$Value)
        Try{
            $Runspace.Window.Dispatcher.invoke([action]{
                $Runspace.$PropertyName = $Value
            },'Normal')
        }Catch{
            Write-PSDLog -Message ("{0}: Failed to set property: {1} " -f ${CmdletName}, $_.Exception.Message) -LogLevel 3
        }
    }
}
#endregion


#region FUNCTION: close main loader
function Close-PSDStartLoader
{
    Param (
        [Parameter(Mandatory=$true, Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $Runspace,
        $Dispatcher = 'Window'
    )
    [string]${CmdletName} = $MyInvocation.MyCommand

    Write-PSDLog -Message ("{0}: Closing PSDStartLoader" -f ${CmdletName})
    $Runspace.Window.Dispatcher.Invoke([action]{
      $Runspace.$Dispatcher.close()
    },'Normal')

}
#endregion

$exportModuleMemberParams = @{
    Function = @(
        'Get-PSDStartLoaderPlatformInfo'
        'Get-PSDStartLoaderInterfaceDetails'
        'Get-PSDStartLoaderProperty'
        'Set-PSDStartLoaderProperty'
        'Get-PSDStartLoaderElement'
        'Set-PSDStartLoaderElement' 
        'Update-PSDStartLoaderProgressBar'
        'Update-PSDStartLoaderProgressStatus'
        'Invoke-PSDStartLoaderCountdown'
        'Invoke-PSDStartPrestartButton'
        'New-PSDStartLoader'
        'New-PSDStartLoaderPrestartMenu'
        'Show-PSDStartLoaderConfirmWindow'
        'Show-PSDStartLoaderDiskViewerWindow'
        'Show-PSDStartLoaderDiskCleanWindow'
        'Show-PSDStartLoaderNetCfgWindow'
        'Close-PSDStartLoader'
    )
}

#Expose cmdlets needed
Export-ModuleMember @exportModuleMemberParams