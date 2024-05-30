<#
.SYNOPSIS

.DESCRIPTION

.LINK

.NOTES
          FileName: PSDGather.psm1
          Solution: PowerShell Deployment for MDT
          Purpose: Module the various utility functions used in PSD
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus, @PowershellCrack, @Soupman98
          Primary: @Mikael_Nystrom
          Created:
          Modified: 2022-09-18

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.0.1 - () - Added support forParallels Virtual Platform,Standard PC (Q35 + ICH9, 2009 and Standard PC (i440FX + PIIX, 1996)
          Version - 0.0.2 - () - Fixed ISServerCore, ISServerOS, DefaultGateway, ISOnBattery
          Version - 0.0.3 - () - Improved logic for make and model detection
		  Version - 0.0.4 - (PC) - Collect localinfo first before adding to TS var; useful to collect data before TS runs
		  Version - 0.0.5 - (PC) - Output from PSDLocalInfo, minor change
		  Version - 0.0.6 - (PC) - Removed loging to show "TODO", no point in showing things that does not work yet
		  Version - 0.0.7 - (MN) - Added rule to VMware modelalias section, all VMware modelalias will now be "WMware"
		  Version - 0.0.8 - (MN) - Added rule to VMware modelalias section, replacing the "," with "_", replace " " with "_"

          TODO:

.Example
#>

# Check for debug in PowerShell and TSEnv
if ($TSEnv:PSDDebug -eq "YES") {
	$Global:PSDDebug = $true
}
if ($PSDDebug -eq $true) {
	$verbosePreference = "Continue"
}

Function Test-PSDTSENV{
	<#
		.SYNOPSIS
			Test environmetn to see if Microsoft.SMS.TSEnvironment COM Object exists

	#>
	try{
		Get-ChildItem -Path tsenv: -ErrorAction Stop | Out-Null
		# Create an object to access the task sequence environment
		#$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
		#grab the progress UI
		#$TSProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI
		return $true
	}
	catch{
		#set variable to null
		return $false
	}
}

Function Get-PSDLocalInfo {
	[CmdletBinding()]
	Param(
		[switch]$IncludeNull,
		[switch]$Passthru
	)

	Begin {
		$verbosePreference = 'SilentlyContinue'

		#Build a hashtable for local info
		$LocalInfo = @{}
	}
	Process {
        $LocalInfo['IsServerCoreOS'] = "False"
		$LocalInfo['IsServerOS'] = "False"

		# Look up OS details
		Get-CimInstance -ClassName Win32_OperatingSystem | ForEach-Object { $LocalInfo['OSCurrentVersion'] = $_.Version; $LocalInfo['OSCurrentBuild'] = $_.BuildNumber }
		if (Test-Path HKLM:System\CurrentControlSet\Control\MiniNT) {
			$LocalInfo['OSVersion'] = "WinPE"
		}
		else {
			$LocalInfo['OSVersion'] = "Other"
			if (!(Test-Path -Path "$env:WINDIR\Explorer.exe")) {
				$LocalInfo['IsServerCoreOS'] = "True"
			}
			if (Test-Path -Path HKLM:\System\CurrentControlSet\Control\ProductOptions) {
				$productType = (Get-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\ProductOptions).ProductType
				if ($productType -eq "ServerNT" -or $productType -eq "LanmanNT") {
					$LocalInfo['IsServerOS'] = "True"
				}
			}
		}

		# Look up network details
		$ipList = @()
		$macList = @()
		$gwList = @()
		Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1" | ForEach-Object {
			$_.IPAddress | ForEach-Object { $ipList += $_ }
			$_.MacAddress | ForEach-Object { $macList += $_ }
			if ($_.DefaultIPGateway) {
				$_.DefaultIPGateway | ForEach-Object { $gwList += $_ }
			}
		}
		$LocalInfo['IPAddress'] = $ipList
		$LocalInfo['MacAddress'] = $macList
		$LocalInfo['DefaultGateway'] = $gwList

		# Look up asset information
		$LocalInfo['IsDesktop'] = "False"
		$LocalInfo['IsLaptop'] = "False"
		$LocalInfo['IsServer'] = "False"
		$LocalInfo['IsSFF'] = "False"
		$LocalInfo['IsTablet'] = "False"
		Get-CimInstance -ClassName Win32_SystemEnclosure | ForEach-Object {
			$LocalInfo['AssetTag'] = $_.SMBIOSAssetTag.Trim()
			if ($_.ChassisTypes[0] -in "8", "9", "10", "11", "12", "14", "18", "21") { $LocalInfo['IsLaptop'] = "True"; $LocalInfo['Chassis'] = "Laptop"}
			if ($_.ChassisTypes[0] -in "3", "4", "5", "6", "7", "15", "16") { $LocalInfo['IsDesktop'] = "True"; $LocalInfo['Chassis'] = "Desktop"}
			if ($_.ChassisTypes[0] -in "23") { $LocalInfo['IsServer'] = "True"; $LocalInfo['Chassis'] = "Server"}
			if ($_.ChassisTypes[0] -in "34", "35", "36") { $LocalInfo['IsSFF'] = "True"; $LocalInfo['Chassis'] = "Small Form Factor"}
			if ($_.ChassisTypes[0] -in "13", "31", "32", "30") {$LocalInfo['IsTablet'] = "True"; $LocalInfo['Chassis'] = "Tablet"}
		}

		Get-CimInstance -ClassName Win32_BIOS | ForEach-Object {
			$LocalInfo['SerialNumber'] = $_.SerialNumber.Trim()
		}

		if ($env:PROCESSOR_ARCHITEW6432) {
			if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
				$LocalInfo['Architecture'] = "x64"
			}
			else {
				$LocalInfo['Architecture'] = $env:PROCESSOR_ARCHITEW6432.ToUpper()
			}
		}
		else {
			if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
				$LocalInfo['Architecture'] = "x64"
			}
			else {
				$LocalInfo['Architecture'] = $env:PROCESSOR_ARCHITECTURE.ToUpper()
			}
		}

		Get-CimInstance -ClassName Win32_Processor | ForEach-Object {
			$LocalInfo['ProcessorSpeed'] = $_.MaxClockSpeed
			$LocalInfo['SupportsSLAT'] = $_.SecondLevelAddressTranslationExtensions
		}

		# TODO: Capable architecture

		Get-CimInstance -ClassName Win32_ComputerSystem | ForEach-Object {
			$LocalInfo['Manufacturer'] = $_.Manufacturer.Trim()
			$LocalInfo['Make'] = $_.Manufacturer.Trim()
			$LocalInfo['Model'] = $_.Model.Trim()
			$LocalInfo['Memory'] = [int] ($_.TotalPhysicalMemory / 1024 / 1024)
		}

		if ($LocalInfo['Make'] -eq "") {
			$Make = (Get-CimInstance -ClassName "Win32_BaseBoard" | Select-Object -ExpandProperty Manufacturer).Trim()
			$LocalInfo['Make'] = $Make
			$LocalInfo['Manufacturer'] = $Make
		}

		if ($LocalInfo['Model'] -eq "") {
			$LocalInfo['Model'] = (Get-CimInstance -ClassName "Win32_BaseBoard" | Select-Object -ExpandProperty Product).Trim()
		}

		Get-CimInstance -ClassName Win32_ComputerSystemProduct | ForEach-Object {
			$LocalInfo['UUID'] = $_.UUID.Trim()
			$LocalInfo['CSPVersion'] = $_.Version.Trim()
		}

		Get-CimInstance -ClassName MS_SystemInformation -Namespace root\WMI | ForEach-Object {
			$LocalInfo['BaseBoardProduct'] = $_.BaseBoardProduct.Trim()
			$LocalInfo['SystemSku'] = $_.SystemSku.Trim()
		}

		Get-CimInstance -ClassName Win32_BaseBoard | ForEach-Object {
			$LocalInfo['Product'] = $_.Product.Trim()
		}

		# UEFI
		try {
			Get-SecureBootUEFI -Name SetupMode | Out-Null
			$LocalInfo['IsUEFI'] = "True"
			$LocalInfo['SetupMode'] = "UEFI"
		}
		catch {
			$LocalInfo['IsUEFI'] = "False"
			$LocalInfo['SetupMode'] = "BIOS"
		}

		# TEST: Battery
		$bFoundAC = $false
		$bOnBattery = $false
		$bFoundBattery = $false
		foreach ($Battery in (Get-CimInstance -ClassName Win32_Battery)) {
			$bFoundBattery = $true
			if ($Battery.BatteryStatus -eq "2") {
				$bFoundAC = $true
			}
		}
		If ($bFoundBattery -and !$bFoundAC) {
			$LocalInfo['IsOnBattery'] = $true
		}

		#https://docs.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getproductinfo
		$sku = (Get-CimInstance -ClassName win32_operatingsystem).OperatingSystemSKU
		switch ($sku)
		{
			0       {$LocalInfo['OSSku']="Undefined";break}
			1       {$LocalInfo['OSSku']="Ultimate Edition";break}
			2       {$LocalInfo['OSSku']="Home Basic Edition";break}
			3       {$LocalInfo['OSSku']="Home Basic Premium Edition";break}
			4       {$LocalInfo['OSSku']="Enterprise Edition";break}
			5       {$LocalInfo['OSSku']="Home Basic N Edition";break}
			6       {$LocalInfo['OSSku']="Business Edition";break}
			7       {$LocalInfo['OSSku']="Standard Server Edition";break}
			8       {$LocalInfo['OSSku']="Datacenter Server Edition";break}
			9       {$LocalInfo['OSSku']="Small Business Server Edition";break}
			10      {$LocalInfo['OSSku']="Enterprise Server Edition";break}
			11      {$LocalInfo['OSSku']="Web Server";break}
			12      {$LocalInfo['OSSku']="Datacenter Server Core Edition";break}
			13      {$LocalInfo['OSSku']="Standard Server Core Edition";break}
			14      {$LocalInfo['OSSku']="Enterprise Server Core Edition";break}
			15      {$LocalInfo['OSSku']="Storage Server Standard";break}
			16      {$LocalInfo['OSSku']="Storage Server Workgroup";break}
			17      {$LocalInfo['OSSku']="Storage Server Enterprise";break}
			18      {$LocalInfo['OSSku']="Windows Essential Server Solutions";break}
			19      {$LocalInfo['OSSku']="Small Business Server Premium";break}
			20      {$LocalInfo['OSSku']="Storage Express Server Edition";break}
			21      {$LocalInfo['OSSku']="Server Foundation";break}
			22      {$LocalInfo['OSSku']="Storage Workgroup Server Edition";break}
			23      {$LocalInfo['OSSku']="Windows Essential Server Solutions";break}
			24      {$LocalInfo['OSSku']="Server For Small Business Edition";break}
			25      {$LocalInfo['OSSku']="Small Business Server Premium Edition";break}
			30      {$LocalInfo['OSSku']="Pro Edition";break}
			40      {$LocalInfo['OSSku']="Server Hyper Core V";break}
			48		{$LocalInfo['OSSku']="Enterprise Edition";break}
			50      {$LocalInfo['OSSku']="Datacenter Server Edition";break}
			54      {$LocalInfo['OSSku']="Enterpise N Edition";break}
			62      {$LocalInfo['OSSku']="Home N Edition";break}
			65      {$LocalInfo['OSSku']="Home Edition";break}
			68      {$LocalInfo['OSSku']="Mobile Edition";break}
			79		{$LocalInfo['OSSku']="Education Edition";break}
			81		{$LocalInfo['OSSku']="Enterprise 2015 LTSB";break}
			82		{$LocalInfo['OSSku']="Enterprise 2015 N LTSB";break}
			85		{$LocalInfo['OSSku']="Mobile Enterprise";break}
			default {$LocalInfo['OSSku']="Not Supported";break}
		}

		# TODO: GetCurrentOSInfo

		# TODO: BitLocker

		# Generate ModelAlias, MakeAlias and SystemAlias
		$LocalInfo['IsVM'] = "False"
		Switch -Wildcard ($LocalInfo['Make']) {
			"*Microsoft*" {
				$LocalInfo['MakeAlias'] = "Microsoft"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$LocalInfo['SystemAlias'] = Get-CimInstance -Namespace "root\wmi" -ClassName "MS_SystemInformation" | Select-Object -ExpandProperty SystemSKU
				# Logic for Hyper-V Testing
				If ($LocalInfo['ModelAlias'] -eq "Virtual Machine") {
					$LocalInfo['SystemAlias'] = Get-CimInstance -Namespace "root\wmi" -ClassName "MS_SystemInformation" | Select-Object -ExpandProperty SystemVersion
					$LocalInfo['IsVM'] = "True"
				}
			}
			"*HP*" {
				$LocalInfo['MakeAlias'] = "HP"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName "MS_SystemInformation" -Namespace "root\WMI").BaseBoardProduct.Trim()
			}
			"*VMWare*" {
				$LocalInfo['MakeAlias'] = "VMWare"
                # $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim() # Default, sets alias to same as model
                # $LocalInfo['ModelAlias'] = ((Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()).replace(",","_") # Remove the "," and replace with "_"
                $LocalInfo['ModelAlias'] = ((Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()).replace(" ","_").replace(",","_") # Remove the "," and replace with "_", Remove the " " and replace with "_"

				$LocalInfo['SystemAlias'] = Get-CimInstance -Namespace "root\wmi" -ClassName "MS_SystemInformation" | Select-Object -ExpandProperty SystemSKU
				$LocalInfo['IsVM'] = "True"
			}
			"*QEMU*" {
				$LocalInfo['MakeAlias'] = "QEMU"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$LocalInfo['SystemAlias'] = Get-CimInstance -Namespace "root\wmi" -ClassName "MS_SystemInformation" | Select-Object -ExpandProperty SystemSKU
				$LocalInfo['IsVM'] = "True"
			}
			"*Innotek*" {
				$LocalInfo['MakeAlias'] = "Innotek"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$LocalInfo['SystemAlias'] = Get-CimInstance -Namespace "root\wmi" -ClassName "MS_SystemInformation" | Select-Object -ExpandProperty SystemSKU
				$LocalInfo['IsVM'] = "True"
			}
			"*Hewlett-Packard*" {
				$LocalInfo['MakeAlias'] = "HP"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName "MS_SystemInformation" -Namespace "root\WMI").BaseBoardProduct.Trim()
			}
			"*Dell*" {
				$LocalInfo['MakeAlias'] = "Dell"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName "MS_SystemInformation" -Namespace "root\WMI" ).SystemSku.Trim()
			}
			"*Lenovo*" {
				$LocalInfo['MakeAlias'] = "Lenovo"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystemProduct" | Select-Object -ExpandProperty Version).Trim()
				$LocalInfo['SystemAlias'] = ((Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).SubString(0, 4)).Trim()
			}
			"*Intel(R) Client Systems*" {
				$LocalInfo['MakeAlias'] = "Intel(R) Client Systems"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystemProduct" | Select-Object -ExpandProperty Version).Trim()
				$LocalInfo['SystemAlias'] = ((Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim())
				$LocalInfo['SystemAlias'] = $LocalInfo['SystemAlias'].SubString(0, $LocalInfo['SystemAlias'].IndexOf("i")).Trim()
			}
			"*Panasonic*" {
				$LocalInfo['MakeAlias'] = "Panasonic Corporation"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName "MS_SystemInformation" -Namespace "root\WMI" ).BaseBoardProduct.Trim()
			}
			"*Viglen*" {
				$LocalInfo['MakeAlias'] = "Viglen"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName "Win32_BaseBoard" | Select-Object -ExpandProperty SKU).Trim()
			}
			"*AZW*" {
				$LocalInfo['MakeAlias'] = "AZW"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName "MS_SystemInformation" -Namespace "root\WMI" ).BaseBoardProduct.Trim()
			}
			"*Fujitsu*" {
				$LocalInfo['MakeAlias'] = "Fujitsu"
				$LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName "Win32_BaseBoard" | Select-Object -ExpandProperty SKU).Trim()
			}
			Default {
				$LocalInfo['MakeAlias'] = "NA"
				$LocalInfo['ModelAlias'] = "NA"
				$LocalInfo['SystemAlias'] = "NA"
			}
			# Closing for switch block
		}
	}
	End{
		If(Test-PSDTSENV)
		{
			# Dump all items in hastable as TS VARs
			Foreach($i in $LocalInfo.GetEnumerator())
			{
				#if value is null, skip and continue to next
				If([string]::IsNullOrEmpty($i.Value)){
					Continue
				}
				#detemine is value is an array
				#if it is add to $tenvlist instead
				If($i.Value -is [array])
				{
					Set-Item -Path tsenvlist:$($i.name) -Value $i.Value
					#for each value in array, pad variable with incemental 3 digit
					$num = 1
					Foreach($l in $i.Value){
						#buld new name with padded digits
						$NumName =  $i.Name + ($num.ToString().PadLeft(3, '0'))
						If(-Not[string]::IsNullOrEmpty($l) -and -Not[string]::IsNullOrWhiteSpace($l) )
						{
							Set-Item -Path tsenv:$NumName -Value $l
						}
						Write-PSDLog -Message ("{0}: Property {1} is now = {2}" -f $MyInvocation.MyCommand.Name,$NumName,$l)
						$num++
					}
				}
				Else{
					Set-Item -Path tsenv:$($i.name) -Value $i.Value
					Write-PSDLog -Message ("{0}: Property {1} is now = {2}" -f $MyInvocation.MyCommand.Name,$i.Name,$i.Value)
				}
			}
		}

		If($Passthru){
			$LocalInfo
		}
	}
}

Function Invoke-PSDRules {
	[CmdletBinding()]
	Param(
		[ValidateNotNullOrEmpty()]
		[Parameter(ValueFromPipeline = $True, Mandatory = $True)]
		[string]$FilePath,
		[ValidateNotNullOrEmpty()]
		[Parameter(ValueFromPipeline = $True, Mandatory = $True)]
		[string]$MappingFile
	)
	Begin {
		$global:iniFile = Get-IniContent $FilePath
		[xml]$global:variableFile = Get-Content $MappingFile

		# Process custom properties
		if ($global:iniFile["Settings"]["Properties"]) {
			$global:iniFile["Settings"]["Properties"].Split(",").Trim() | ForEach-Object {
				$newVar = $global:variableFile.properties.property[0].Clone()
				if ($_.EndsWith("(*)")) {
					$newVar.id = $_.Replace("(*)", "")
					$newVar.type = "list"
				}
				else {
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
	Process {
		$global:iniFile["Settings"]["Priority"].Split(",").Trim() | Invoke-PSDRule
	}
}

Function Invoke-PSDRule {
	[CmdletBinding()]
	Param(
		[ValidateNotNullOrEmpty()]
		[Parameter(ValueFromPipeline = $True, Mandatory = $True)]
		[string]$RuleName
	)
	Begin {

	}
	Process {
		Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing rule $RuleName"

		$v = $global:variables | Where-Object { $_.id -ieq $RuleName }
		if ($RuleName.ToUpper() -eq "DEFAULTGATEWAY") {
			# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DEFAULTGATEWAY is not yet implemented"
		}

		# Evaluate Serialnumber if exists
		$v = $global:variables | Where-Object { $_.id -ieq $RuleName }
		if ($RuleName.ToUpper() -eq "SERIALNUMBER") {
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing values of $tsenv:SERIALNUMBER"
			Invoke-PSDRule -RuleName $tsenv:SERIALNUMBER
		}

		elseif ($v) {
			if ($v.type -eq "list") {
				Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing values of $RuleName"
				(Get-Item tsenvlist:$($v.id)).Value | Invoke-PSDRule
			}
			else {
				$s = (Get-Item tsenv:$($v.id)).Value
				if ($s -ne "") {
					Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing value of $RuleName"
					Invoke-PSDRule $s
				}
				else {
					Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Skipping rule $RuleName, value is blank"
				}
			}
		}
		else {
			Get-PSDSettings $global:iniFile[$RuleName]
		}
	}
}

Function Get-PSDSettings {
	[CmdletBinding()]
	Param(
		$section
	)
	Begin {

	}
	Process {
		$skipProperties = $false

		# Exit if the section doesn't exist
		if (-not $section) {
			return
		}

		# Process special sections and exits
		if ($section.Contains("UserExit")) {
			# TODO: Process UserExit Before"
			# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property UserExit is not yet implemented"
		}

		if ($section.Contains("SQLServer")) {
			$skipProperties = $true
			# TODO: Database"
		}

		if ($section.Contains("WebService")) {
			$skipProperties = $true
			# TODO: WebService"
		}

		if ($section.Contains("Subsection")) {
			Invoke-PSDRule $section["Subsection"]
		}

		# Process properties
		if (-not $skipProperties) {
			$section.Keys | ForEach-Object {
				$sectionVar = $_
				$v = $global:variables | Where-Object { $_.id -ieq $sectionVar }
				if ($v) {
					if ((Get-Item tsenv:$v).Value -eq $section[$sectionVar]) {
						# Do nothing, value unchanged
					}
					if ((Get-Item tsenv:$v).Value -eq "" -or $v.overwrite -eq "true") {
						$Value = $((Get-Item tsenv:$($v.id)).Value)
						if ($value -eq '') { $value = "Empty" }
						Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Changing property $($v.id) to $($section[$sectionVar]), was $Value"
						Set-Item tsenv:$($v.id) -Value $section[$sectionVar]
					}
					elseif ((Get-Item tsenv:$v).Value -ne "") {
						Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Ignoring new value for $($v.id)"
					}
				}
				else {
					$trimVar = $sectionVar.TrimEnd("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
					$v = $global:variables | Where-Object { $_.id -ieq $trimVar }
					if ($v) {
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
			# TODO: Process UserExit After"
			# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property UserExit is not yet implemented"
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
	Param
	(
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { (Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini") })]
		[Parameter(ValueFromPipeline = $True, Mandatory = $True)]
		[string]$FilePath
	)

	Begin {
		# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Function started"
	}

	Process {
		# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing file: $Filepath"

		$ini = @{}
		switch -regex -file $FilePath {
			"^\[(.+)\]$" {
				# Section
				$section = $matches[1]
				$ini[$section] = @{}
				$CommentCount = 0
			}
			"^(;.*)$" {
				# Comment
				if (!($section)) {
					$section = "No-Section"
					$ini[$section] = @{}
				}
				$value = $matches[1]
				$CommentCount = $CommentCount + 1
				$name = "Comment" + $CommentCount
				$ini[$section][$name] = $value
			}
			"(.+?)\s*=\s*(.*)" {
				# Key
				if (!($section)) {
					$section = "No-Section"
					$ini[$section] = @{}
				}
				$name, $value = $matches[1..2]
				$ini[$section][$name] = $value
			}
		}
		# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Finished Processing file: $FilePath"
		Return $ini
	}

	End {
		# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Function ended"
	}
}