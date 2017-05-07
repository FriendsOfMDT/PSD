# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDGather.psm1
# // 
# // Purpose:   Module for gathering information about the OS and environment
# //            (mostly from WMI), and for processing rules (Bootstrap.ini, 
# //            CustomSettings.ini).  All the resulting information is saved
# //            into task sequence variables.
# // 
# // ***************************************************************************

Function Get-PSDLocalInfo {
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
    Get-WmiObject Win32_SystemEnclosure | % {
      $tsenv:AssetTag = $_.SMBIOSAssetTag.Trim()
      if ($_.ChassisTypes[0] -in "8", "9", "10", "11", "12", "14", "18", "21") { $tsenv:IsLaptop = "True" }
      if ($_.ChassisTypes[0] -in "3", "4", "5", "6", "7", "15", "16") { $tsenv:IsDesktop = "True" }
      if ($_.ChassisTypes[0] -in "23") { $tsenv:IsServer = "True" }
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

    Get-WmiObject Win32_ComputerSystem | % {
      $tsenv:Manufacturer = $_.Manufacturer
      $tsenv:Model = $_.Model
      $tsenv:Memory = [int] ($m.TotalPhysicalMemory / 1024 / 1024)
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

    # TODO: Battery

    # TODO: GetDP
    # TODO: GetWDS
    # TODO: GetHostName
    # TODO: GetOSSKU
    # TODO: GetCurrentOSInfo
    # TODO: Virtualization
    # TODO: BitLocker
  }
}

Function Invoke-PSDRules {
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
            Write-Verbose "Adding custom property $($newVar.id)"
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

Function Invoke-PSDRule
{
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
        Write-Verbose "Processing rule $RuleName"
        $v = $global:variables | ? {$_.id -ieq $RuleName}
        if ($RuleName.ToUpper() -eq "DEFAULTGATEWAY") {
            Write-Host "TODO: Process default gateway"
        }
        elseif ($v) {
            if ($v.type -eq "list") {
              Write-Verbose "Processing values of $RuleName" 
              (get-item tsenvlist:$($v.id)).Value | Invoke-PSDRule
            }
            else
            {
              $s = (Get-Item tsenv:$($v.id)).Value
              if ($s -ne "")
              {
                Write-Verbose "Processing value of $RuleName"
                Invoke-PSDRule $s
              }
              else
              {
                Write-Verbose "Skipping rule $RuleName, value is blank"
              }
            }
        }
        else
        {
            Get-PSDSettings $global:iniFile[$RuleName]
        }
    }
}

Function Get-PSDSettings
{
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
      if ($section.Contains("UserExit")) {
        Write-Host "TODO: Process UserExit Before"
      }

      if ($section.Contains("SQLServer")) {
        $skipProperties = $true
        Write-Host "TODO: Database"
      }

      if ($section.Contains("WebService")) {
        $skipProperties = $true
        Write-Host "TODO: WebService"
      }

      if ($section.Contains("Subsection")) {
        Write-Verbose "Processing subsection"
        Invoke-PSDRule $section["Subsection"]
      }

      # Process properties
      if (-not $skipProperties) {	
        $section.Keys | % {
          $sectionVar = $_
          $v = $global:variables | ? {$_.id -ieq $sectionVar}
          if ($v)
          {
		    if ((get-item tsenv:$v).Value -eq $section[$sectionVar])
			{
			  # Do nothing, value unchanged
			}
            if ((get-item tsenv:$v).Value -eq "" -or $v.overwrite -eq "true") {
              Write-Verbose "Changing $($v.id) to $($section[$sectionVar]), was $((Get-Item tsenv:$($v.id)).Value)"
              Set-Item tsenv:$($v.id) -Value $section[$sectionVar]
            }
            elseif ((get-item tsenv:$v).Value -ne "") {
              Write-Verbose "Ignoring new value for $($v.id)"
            }
          }
          else
          {
            $trimVar = $sectionVar.TrimEnd("0","1","2","3","4","5","6","7","8","9")
            $v = $global:variables | ? {$_.id -ieq $trimVar}
            if ($v)
            {
              if ($v.type -eq "list") {
                Write-Verbose "Adding $($section[$sectionVar]) to $($v.id)"
                $n = @((Get-Item tsenvlist:$($v.id)).Value)
                $n += [String] $section[$sectionVar]
                Set-Item tsenvlist:$($v.id) -Value $n
              }
            }
          }
        } 
      }

      if ($section.Contains("UserExit")) {
        Write-Host "TODO: Process UserExit After"
      }

    }
}

Function Get-IniContent { 
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
    Param( 
        [ValidateNotNullOrEmpty()] 
        [ValidateScript({(Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini")})] 
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)] 
        [string]$FilePath 
    ) 
     
    Begin 
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"} 
         
    Process 
    { 
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath" 
             
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
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath" 
        Return $ini 
    } 
         
    End 
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"} 
}
