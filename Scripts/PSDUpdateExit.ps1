<#
.Synopsis
    This script runs when a deployment share is updated, and the completely generate boot image option is selected.
    
.Description
    This script was written by Johan Arwidmark @jarwidmark. This script is for adding features and tools to the boot image WIM and/or ISO.

.LINK
    https://github.com/FriendsOfMDT/PSD

.NOTES
          FileName: PSDUpdateExit.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark
          Primary: @jarwidmark 
          Created: 2019-05-09
          Modified: 2020-07-03

          Version - 0.0.0 - () - Finalized functional version 1.

.EXAMPLE
	.\PSD-UpdateExit.ps1
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
Param(
)

function Start-PSDLog{
	[CmdletBinding()]
    param (
    #[ValidateScript({ Split-Path $_ -Parent | Test-Path })]
	[string]$FilePath
 	)
    try
    	{
			if(!(Split-Path $FilePath -Parent | Test-Path))
			{
				New-Item (Split-Path $FilePath -Parent) -Type Directory | Out-Null
			}
			#Confirm the provided destination for logging exists if it doesn't then create it.
			if (!(Test-Path $FilePath)){
	    			## Create the log file destination if it doesn't exist.
                    New-Item $FilePath -Type File | Out-Null
			}
				## Set the global variable to be used as the FilePath for all subsequent write-PSDInstallLog
				## calls in this session
				$global:ScriptLogFilePath = $FilePath
    	}
    catch
    {
		#In event of an error write an exception
        Write-Error $_.Exception.Message
    }
}
function Write-PSDInstallLog{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [Parameter()]
    [ValidateSet(1, 2, 3)]
	[string]$LogLevel=1,
	[Parameter(Mandatory = $false)]
    [bool]$writetoscreen = $true   
   )
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
	$Line = $Line -f $LineFormat
	[system.GC]::Collect()
    Add-Content -Value $Line -Path $global:ScriptLogFilePath
	if($writetoscreen)
	{
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
            Default {
            }
        }
    }
	if($writetolistbox -eq $true)
	{
        $result1.Items.Add("$Message")
    }
}
function set-PSDDefaultLogPath{
	#Function to set the default log path if something is put in the field then it is sent somewhere else. 
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $false)]
		[bool]$defaultLogLocation = $true,
		[parameter(Mandatory = $false)]
		[string]$LogLocation
	)
	if($defaultLogLocation)
	{
		$LogPath = Split-Path $script:MyInvocation.MyCommand.Path
		$LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
		Start-PSDLog -FilePath $($LogPath + "\" + $LogFile)
	}
	else 
	{
		$LogPath = $LogLocation
		$LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
		Start-PSDLog -FilePath $($LogPath + "\" + $LogFile)
	}
}

function Get-PSDIniValue {
    <#
    .SYNOPSIS
        Reads the last active value for an INI setting.
    .DESCRIPTION
        Returns the final non-commented key/value match in an INI file. This
        supports the simple keyboard settings needed while servicing a boot WIM.
    .PARAMETER Path
        Path to the INI file.
    .PARAMETER Name
        Name of the setting to retrieve.
    .OUTPUTS
        The setting value, or $null when no active value is present.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $match = Get-Content -Path $Path | Where-Object {
        $_ -notmatch '^\s*[;#]' -and $_ -match "^\s*$([regex]::Escape($Name))\s*=\s*(.+?)\s*$"
    } | Select-Object -Last 1

    if ($match) {
        return ($match -split '=', 2)[1].Trim()
    }
}

function Get-PSDWinPEInputLocale {
    <#
    .SYNOPSIS
        Resolves the WinPE input locale configured for a deployment share.
    .DESCRIPTION
        Prioritizes KeyboardLocalePE over KeyboardLocale and Bootstrap.ini over
        CustomSettings.ini. Culture values such as fr-FR are mapped to a DISM
        input-locale value using PSDListOfLanguages.xml.
    .PARAMETER DeployRoot
        Root path of the deployment share being updated.
    .OUTPUTS
        A DISM-compatible locale such as 040c:0000040c, or $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeployRoot
    )

    $bootstrapPath = Join-Path $DeployRoot 'Control\Bootstrap.ini'
    $customSettingsPath = Join-Path $DeployRoot 'Control\CustomSettings.ini'
    $inputLocale = Get-PSDIniValue -Path $bootstrapPath -Name 'KeyboardLocalePE'

    if ([string]::IsNullOrWhiteSpace($inputLocale)) {
        $inputLocale = Get-PSDIniValue -Path $customSettingsPath -Name 'KeyboardLocalePE'
    }

    if ([string]::IsNullOrWhiteSpace($inputLocale)) {
        $inputLocale = Get-PSDIniValue -Path $bootstrapPath -Name 'KeyboardLocale'
    }

    if ([string]::IsNullOrWhiteSpace($inputLocale)) {
        $inputLocale = Get-PSDIniValue -Path $customSettingsPath -Name 'KeyboardLocale'
    }

    if ([string]::IsNullOrWhiteSpace($inputLocale)) {
        return $null
    }

    if ($inputLocale -match '^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{8}$') {
        return $inputLocale
    }

    $languageFile = Join-Path $DeployRoot 'Scripts\PSDListOfLanguages.xml'
    if (Test-Path $languageFile) {
        [xml]$languages = Get-Content -Path $languageFile
        $locale = $languages.Locales.Locale | Where-Object { $_.Culture -eq $inputLocale } | Select-Object -First 1
        if ($locale) {
            return $locale.KeyboardLayout
        }
    }

    Write-PSDInstallLog -Message "Unable to resolve KeyboardLocale '$inputLocale' to an input locale." -LogLevel 2
    return $null
}

# Start logging
set-PSDDefaultLogPath -defaultLogLocation $false -LogLocation "$Env:DEPLOYROOT"

# List some variables
Write-PSDInstallLog -Message "Write out each of the passed-in environment variable values"
Write-PSDInstallLog -Message "INSTALLDIR = $Env:INSTALLDIR"
Write-PSDInstallLog -Message "DEPLOYROOT = $Env:DEPLOYROOT"
Write-PSDInstallLog -Message "PLATFORM = $Env:PLATFORM"
Write-PSDInstallLog -Message "ARCHITECTURE = $Env:ARCHITECTURE"
Write-PSDInstallLog -Message "TEMPLATE = $Env:TEMPLATE"

# Do any desired WIM customizations (right before the WIM changes are committed)
If ($Env:STAGE -eq "WIM") {
    # CONTENT environment variable contains the path to the mounted WIM
    Write-PSDInstallLog -Message "Entering the $Env:STAGE phase"
    Write-PSDInstallLog -Message "CONTENT = $Env:CONTENT"

    $inputLocale = Get-PSDWinPEInputLocale -DeployRoot $Env:DEPLOYROOT
    if ($inputLocale -and $inputLocale -ne '0409:00000409') {
        $DismArgs = @(
            ('/Image:"{0}"' -f $Env:CONTENT)
            "/Set-InputLocale:$inputLocale"
        )
        Write-PSDInstallLog -Message "Setting WinPE input locale to $inputLocale"
        $dism = Start-Process -FilePath dism.exe -ArgumentList $DismArgs -Wait -PassThru -NoNewWindow

        if ($dism.ExitCode -eq 0) {
            Write-PSDInstallLog -Message "WinPE input locale set to $inputLocale"
        }
        else {
            Write-PSDInstallLog -Message "Failed to set WinPE input locale to $inputLocale. DISM exit code: $($dism.ExitCode)" -LogLevel 3
        }
    }
    else {
        Write-PSDInstallLog -Message "WinPE input locale remains the default US layout."
    }
}

# Do any desired customizations (right after the WIM changes are committed)
If ($Env:STAGE -eq "POSTWIM") {
    Write-PSDInstallLog -Message "Entering the $Env:STAGE phase"
    Write-PSDInstallLog -Message "CONTENT = $Env:CONTENT"

    # Added for the OSD Toolkit Plugin
    Write-PSDInstallLog -Message "Adding the OSD Toolkit by running Set-PSDBootImage2PintEnabled.ps1 from the PSDResources\Plugins\OSDToolKit folder"
    $PSDArgument = "$Env:DEPLOYROOT\PSDResources\Plugins\OSDToolKit\Set-PSDBootImage2PintEnabled.ps1"
    $PSDProcess = Start-Process PowerShell -ArgumentList $PSDArgument  -NoNewWindow -PassThru -Wait

    Write-PSDInstallLog -Message "Wait a while for MDT to catch up"
    Start-sleep -Seconds 10
}

# Do any desired ISO customizations (right before a new ISO is captured, assuming deployment share is configured to create an ISO)
If ($Env:STAGE -eq "ISO") {
	# CONTENT environment variable contains the path to the directory that will be used to create the ISO.
    Write-PSDInstallLog -Message "Entering the $Env:STAGE phase"
    Write-PSDInstallLog -Message "CONTENT = $Env:CONTENT"
    Write-PSDInstallLog -Message "Wait a while for MDT to catch up"
    Start-sleep -Seconds 10
} 

# Do any steps needed after the ISO has been generated
If ($Env:STAGE -eq "POSTISO") {
	# CONTENT environment variable is empty at this stage
    Write-PSDInstallLog -Message "Entering the $Env:STAGE phase"
} 

