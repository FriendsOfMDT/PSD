<#
.Synopsis
    This script runs when a deployment share is updated, and the completely generate boot image option is selected.
    
.Description
    This script was written by Johan Arwidmark @jarwidmark. This script is for adding features and tools to the boot image WIM and/or ISO.

.LINK
    https://github.com/FriendsOfMDT/PSD

.NOTES
          FileName: New-UpdateExit.ps1
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
            else{
                Remove-Item -Path $FilePath -Force
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

# Start logging
set-PSDDefaultLogPath

# TODO, figure out log overwrite logic due to deployment workbench running this script four times for every deployment share update

# List some variables
Write-PSDInstallLog -Message "Write out each of the passed-in environment variable values"
Write-PSDInstallLog -Message "INSTALLDIR = $Env:INSTALLDIR"
Write-PSDInstallLog -Message "DEPLOYROOT = $Env:DEPLOYROOT"
Write-PSDInstallLog -Message "PLATFORM = $Env:PLATFORM"
Write-PSDInstallLog -Message "ARCHITECTURE = $Env:ARCHITECTURE"
Write-PSDInstallLog -Message "TEMPLATE = $Env:TEMPLATE"
Write-PSDInstallLog -Message "STAGE = $Env:STAGE"
Write-PSDInstallLog -Message "CONTENT = $Env:CONTENT"

# Do any desired WIM customizations (right before the WIM changes are committed)
If ($Env:STAGE -eq "WIM") {
    # CONTENT environment variable contains the path to the mounted WIM
    Write-PSDInstallLog -Message "Entering the WIM phase"
    Write-PSDInstallLog -Message "CONTENT = $Env:CONTENT"
}

# Do any desired customizations (right after the WIM changes are committed)
If ($Env:STAGE -eq "POSTWIM") {
    Write-PSDInstallLog -Message "Entering the POSTWIM phase"
    Write-PSDInstallLog -Message "CONTENT = $Env:CONTENT"
}

# Do any desired ISO customizations (right before a new ISO is captured, assuming deployment share is configured to create an ISO)
If ($Env:STAGE -eq "ISO") {
	# CONTENT environment variable contains the path to the directory that will be used to create the ISO.
    Write-PSDInstallLog -Message "Entering the ISO phase"
    Write-PSDInstallLog -Message "CONTENT = $Env:CONTENT"
} 

# Do any steps needed after the ISO has been generated
If ($Env:STAGE -eq "POSTISO") {
	# CONTENT environment variable contains the path to the locally-captured ISO file (after it has been copied to the network).
    Write-PSDInstallLog -Message "Entering the POSTISO phase"
    Write-PSDInstallLog -Message "CONTENT = $Env:CONTENT"
} 

