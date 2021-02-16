<#
.SYNOPSIS

.DESCRIPTION

.LINK

.NOTES
          FileName: PSDUtility.psd1
          Solution: PowerShell Deployment for MDT
          Purpose: Module for gathering information about the OS and environment
                    (mostly from WMI), and for processing rules (Bootstrap.ini, 
                    CustomSettings.ini).  All the resulting information is saved
          into task sequence variables.
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2019-05-09

          Version - 0.0.0 - () - Finalized functional version 1.

          TODO:

.Example
#>

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true){
    $verbosePreference = "Continue"
}

Function Get-PSDLocalInfo{
  Process
  {
    # Look up OS details
    $tsenv:IsServerCoreOS = "False"
    $tsenv:IsServerOS = "False"

    Get-WmiObject Win32_OperatingSystem | % { $tsenv:OSCurrentVersion = $_.Version; $tsenv:OSCurrentBuild = $_.BuildNumber }
    if (Test-Path HKLM:System\CurrentControlSet\Control\MiniNT) {
      $tsenv:OSVersion = "WinPE"
    }
    else
    {
      $tsenv:OSVersion = "Other"
      if (Test-Path "$env:WINDIR\Explorer.exe") {
        $tsenv:IsServerCoreOS = "True"
      }
      if (Test-Path HKLM:\System\CurrentControlSet\Control\ProductOptions\ProductType)
      {
        $productType = Get-Item HKLM:System\CurrentControlSet\Control\ProductOptions\ProductType
        if ($productType -eq "ServerNT" -or $productType -eq "LanmanNT") {
          $tsenv:IsServerOS = "True"
        }
      }
    }

    # Look up network details
    $ipList = @()
    $macList = @()
    $gwList = @()
    Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1" | % {
      $_.IPAddress | % {$ipList += $_ }
      $_.MacAddress | % {$macList += $_ }
      if ($_.DefaultGateway) {
        $_.DefaultGateway | % {$gwList += $_ }
      }
    }
    $tsenvlist:IPAddress = $ipList
    $tsenvlist:MacAddress = $macList
    $tsenvlist:DefaultGateway = $gwList

    # Look up asset information
    $tsenv:IsDesktop = "False"
    $tsenv:IsLaptop = "False"
    $tsenv:IsServer = "False"
    $tsenv:IsSFF = "False"
    $tsenv:IsTablet = "False"
    Get-WmiObject Win32_SystemEnclosure | % {
      $tsenv:AssetTag = $_.SMBIOSAssetTag.Trim()
      if ($_.ChassisTypes[0] -in "8", "9", "10", "11", "12", "14", "18", "21") { $tsenv:IsLaptop = "True" }
      if ($_.ChassisTypes[0] -in "3", "4", "5", "6", "7", "15", "16") { $tsenv:IsDesktop = "True" }
      if ($_.ChassisTypes[0] -in "23") { $tsenv:IsServer = "True" }
      if ($_.ChassisTypes[0] -in "34", "35", "36") { $tsenv:IsSFF = "True" }
      if ($_.ChassisTypes[0] -in "13", "31", "32", "30") { $tsenv:IsTablet = "True" } 
    }

    Get-WmiObject Win32_BIOS | % {
      $tsenv:SerialNumber = $_.SerialNumber.Trim()
    }

    if ($env:PROCESSOR_ARCHITEW6432) {
      if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
        $tsenv:Architecture = "x64"
      }
      else {
        $tsenv:Architecture = $env:PROCESSOR_ARCHITEW6432.ToUpper()
      }
    }
    else {
      if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
        $tsenv:Architecture = "x64"
      }
      else {
        $tsenv:Architecture = $env:PROCESSOR_ARCHITECTURE.ToUpper()
      }
    }

    Get-WmiObject Win32_Processor | % {
      $tsenv:ProcessorSpeed = $_.MaxClockSpeed
      $tsenv:SupportsSLAT = $_.SecondLevelAddressTranslationExtensions
    }

    # TODO: Capable architecture
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Capable architecture" 

    Get-WmiObject Win32_ComputerSystem | % {
      $tsenv:Make = $_.Manufacturer
      $tsenv:Model = $_.Model
      $tsenv:Memory = [int] ($_.TotalPhysicalMemory / 1024 / 1024)
    }

    Get-WmiObject Win32_ComputerSystemProduct | % {
      $tsenv:UUID = $_.UUID
    }
    
    Get-WmiObject Win32_BaseBoard | % {
      $tsenv:Product = $_.Product
    }

    # UEFI
    try
    {
        Get-SecureBootUEFI -Name SetupMode | Out-Null
        $tsenv:IsUEFI = "True"
    }
    catch
    {
        $tsenv:IsUEFI = "False"
    }

    # TEST: Battery
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TEST: Battery" 

 	$bFoundAC = $false
    $bOnBattery = $false
	$bFoundBattery = $false
    foreach($Battery in (Get-WmiObject -Class Win32_Battery))
    {
        $bFoundBattery = $true
        if ($Battery.BatteryStatus -eq "2")
        {
            $bFoundAC = $true
        }
    }
    If ($bFoundBattery -and !$bFoundAC)
    {
        $tsenv.IsOnBattery = $true
    }
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): bFoundAC: $bFoundAC" 
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): bOnBattery :$bOnBattery" 
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): bFoundBattery: $bFoundBattery"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv.IsOnBattery is now $($tsenv.IsOnBattery)"

    # TODO: GetDP
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: GetDP" 

    # TODO: GetWDS
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: GetWDS" 

    # TODO: GetHostName
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: GetHostName" 
    
    # TODO: GetOSSKU
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: GetOSSKU" 

    # TODO: GetCurrentOSInfo
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: GetCurrentOSInfo" 

    # TODO: Virtualization
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TEST: Virtualization" 
    
    $Win32_ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    switch ($Win32_ComputerSystem.model)
    {
        "Virtual Machine"
        {
            $tsenv:IsVM = "True"
        }
        "VMware Virtual Platform"
        {
            $tsenv:IsVM = "True"
        }
        "VMware7,1"
        {
            $tsenv:IsVM = "True"
        }
        "Virtual Box"
        {
            $tsenv:IsVM = "True"
        }
        Default
        {
            $tsenv:IsVM = "False"
        }
    }

    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Model is $($Win32_ComputerSystem.model)" 
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:IsVM is now $tsenv:IsVM" 
    
    # TODO: BitLocker
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: BitLocker" 

  }
}
Function Invoke-PSDRules{
    [CmdletBinding()] 
    Param( 
        [ValidateNotNullOrEmpty()] 
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)] 
        [string]$FilePath,
        [ValidateNotNullOrEmpty()] 
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)] 
        [string]$MappingFile
    ) 
    Begin
    {
        $global:iniFile = Get-IniContent $FilePath
        [xml]$global:variableFile = Get-Content $MappingFile

        # Process custom properties
        if ($global:iniFile["Settings"]["Properties"])
        {
          $global:iniFile["Settings"]["Properties"].Split(",").Trim() | % {
            $newVar = $global:variableFile.properties.property[0].Clone()
            if ($_.EndsWith("(*)"))
            {
              $newVar.id = $_.Replace("(*)","")
              $newVar.type = "list"
            }
            else
            {
              $newVar.id = "$_"
              $newVar.type = "string"
            }
            $newVar.overwrite = "false"
            $newVar.description = "Custom property"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Adding custom property $($newVar.id)" 
            $null = $global:variableFile.properties.appendChild($newVar)
          }
        }
        $global:variables = $global:variableFile.properties.property
    }
    Process
    {
        $global:iniFile["Settings"]["Priority"].Split(",").Trim() | Invoke-PSDRule
    }
}
Function Invoke-PSDRule{
    [CmdletBinding()] 
    Param( 
        [ValidateNotNullOrEmpty()] 
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)] 
        [string]$RuleName
    ) 
    Begin
    {

    }
    Process
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing rule $RuleName" 

        $v = $global:variables | ? {$_.id -ieq $RuleName}
        if ($RuleName.ToUpper() -eq "DEFAULTGATEWAY") {
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Process default gateway" 
        }
        elseif ($v) {
            if ($v.type -eq "list") {
              Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing values of $RuleName" 
              (Get-Item tsenvlist:$($v.id)).Value | Invoke-PSDRule
            }
            else
            {
              $s = (Get-Item tsenv:$($v.id)).Value
              if ($s -ne "")
              {
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing value of $RuleName" 
                Invoke-PSDRule $s
              }
              else
              {
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Skipping rule $RuleName, value is blank" 
              }
            }
        }
        else
        {
            Get-PSDSettings $global:iniFile[$RuleName]
        }
    }
}
Function Get-PSDSettings{
    [CmdletBinding()] 
    Param( 
        $section
    ) 
    Begin
    {

    }
    Process
    {
      $skipProperties = $false

      # Exit if the section doesn't exist
      if (-not $section)
      {
        return
      }

      # Process special sections and exits
      if ($section.Contains("UserExit"))
      {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Process UserExit Before" 
      }

      if ($section.Contains("SQLServer")) {
        $skipProperties = $true
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Database" 
      }

      if ($section.Contains("WebService")) {
        $skipProperties = $true
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: WebService" 
      }

      if ($section.Contains("Subsection")) {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing subsection" 
        Invoke-PSDRule $section["Subsection"]
      }

      # Process properties
      if (-not $skipProperties) {	
        $section.Keys | % {
          $sectionVar = $_
          $v = $global:variables | ? {$_.id -ieq $sectionVar}
          if ($v)
          {
		    if ((Get-Item tsenv:$v).Value -eq $section[$sectionVar])
			{
			  # Do nothing, value unchanged
			}
            if ((Get-Item tsenv:$v).Value -eq "" -or $v.overwrite -eq "true") {
              $Value = $((Get-Item tsenv:$($v.id)).Value)
              if($value -eq ''){$value = "EMPTY"}
              Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Changing PROPERTY $($v.id) to $($section[$sectionVar]), was $Value" 
              Set-Item tsenv:$($v.id) -Value $section[$sectionVar]
            }
            elseif ((Get-Item tsenv:$v).Value -ne "") {
              Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Ignoring new value for $($v.id)" 
            }
          }
          else
          {
            $trimVar = $sectionVar.TrimEnd("0","1","2","3","4","5","6","7","8","9")
            $v = $global:variables | ? {$_.id -ieq $trimVar}
            if ($v)
            {
              if ($v.type -eq "list") {
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Adding $($section[$sectionVar]) to $($v.id)" 
                $n = @((Get-Item tsenvlist:$($v.id)).Value)
                $n += [String] $section[$sectionVar]
                Set-Item tsenvlist:$($v.id) -Value $n
              }
            }
          }
        } 
      }

      if ($section.Contains("UserExit")) {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Process UserExit After" 
      }

    }
}
Function Get-IniContent{ 
    <# 
    .Synopsis 
        Gets the content of an INI file 
         
    .Description 
        Gets the content of an INI file and returns it as a hashtable 
         
    .Notes 
        Author		: Oliver Lipkau <oliver@lipkau.net> 
        Blog		: http://oliver.lipkau.net/blog/ 
	Source		: https://github.com/lipkau/PsIni
			  http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91
        Version		: 1.0 - 2010/03/12 - Initial release 
			  1.1 - 2014/12/11 - Typo (Thx SLDR)
                                         Typo (Thx Dave Stiff)
         
        #Requires -Version 2.0 
         
    .Inputs 
        System.String 
         
    .Outputs 
        System.Collections.Hashtable 
         
    .Parameter FilePath 
        Specifies the path to the input file. 
         
    .Example 
        $FileContent = Get-IniContent "C:\myinifile.ini" 
        ----------- 
        Description 
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent 
     
    .Example 
        $inifilepath | $FileContent = Get-IniContent 
        ----------- 
        Description 
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent 
     
    .Example 
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini" 
        C:\PS>$FileContent["Section"]["Key"] 
        ----------- 
        Description 
        Returns the key "Key" of the section "Section" from the C:\settings.ini file 
         
    .Link 
        Out-IniFile 
    #> 
     
    [CmdletBinding()] 
    Param
    ( 
        [ValidateNotNullOrEmpty()] 
        [ValidateScript({(Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini")})] 
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)] 
        [string]$FilePath 
    ) 
     
    Begin 
    {
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Function started"
    } 
         
    Process 
    { 
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing file: $Filepath"
             
        $ini = @{} 
        switch -regex -file $FilePath 
        { 
            "^\[(.+)\]$" # Section 
            { 
                $section = $matches[1] 
                $ini[$section] = @{} 
                $CommentCount = 0 
            } 
            "^(;.*)$" # Comment 
            { 
                if (!($section)) 
                { 
                    $section = "No-Section" 
                    $ini[$section] = @{} 
                } 
                $value = $matches[1] 
                $CommentCount = $CommentCount + 1 
                $name = "Comment" + $CommentCount 
                $ini[$section][$name] = $value 
            }  
            "(.+?)\s*=\s*(.*)" # Key 
            { 
                if (!($section)) 
                { 
                    $section = "No-Section" 
                    $ini[$section] = @{} 
                } 
                $name,$value = $matches[1..2] 
                $ini[$section][$name] = $value 
            } 
        } 
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Finished Processing file: $FilePath" 
        Return $ini 
    } 
         
    End 
    {
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Function ended" 
    } 
}
