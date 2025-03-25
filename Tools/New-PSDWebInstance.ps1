<#
	.SYNOPSIS
		This script installs the IIS roles and features needed for PSD to work.

	.DESCRIPTION
		This script installs the IIS roles and features needed for PSD to work.

	.PARAMETER StartedFromHydration
		This parameter is used to determine if the script is being run from a hydration script. If it is then the script will not prompt for a reboot.

	.EXAMPLE
		.\New-PSDWebInstance.Ps1
		This will install the IIS roles and features needed for PSD to work.

	.LINK
		https://github.com/FriendsOfMDT/PSD

	.NOTES
		FileName:   New-PSDWebInstance.ps1
		Author:     Jordan Benzing
		Contact:    @JordanTheITGuy
		Created:    2019-04-15
		Updated:    2025-01-19

		Version 0.0.0 (2019-04-15) Wrote out framework for code base imported standard helper functions
		Version 0.1.0 (2019-04-15)- Created a functional version of the script installs IIS, installs WebDav - reboots server to complete setup and then starts WEbDave Services
		Version 0.1.1 (2019-04-17) - Created switches for "install" v.s. Configure
								- Created New function that does the configuration so that we can add all configuration changes in one place
								- Created a switch for reboot
								- Blocked the behavior so that someone cannot call Install AND configure - without a reboot
		Version 0.2.0 (2019-04-18) - Updated the Logic for the configure step so it can be modified separately from the installation step
								- Implemented a check that prevents you from running the script if the script is targeting the local server (Can't handle reboot)
		Version 0.3.1 (2019-04-18) - Use a variable LIST of all features that need to be installed now for IIS
								- Wrote out a function for configure
								- crossed off numerous TODO functionality checks
								- Some Code optimization from repeat sections
		Version 0.3.2 (2019-04-19) - Increased the functionality of the reboot handler
								- Now ALLOW you to reboot the local computer but only if Configure wasn't requested
								- Now prompts to confirm the reboot 
		Version 0.3.3 (2019-04-19) - Now retrieves network information about the client starting the install and the target machine and logs it.
								- May include a "debug" option in the WRite-PSD log function in the future.. 
		Version 0.3.4 (2019-04-19) - Updated from PSD to PSD - on all the function
								- Moved the start-log function back to the begin block to make it work properly. 
		Version 0.3.5 (2019-04-22) - Corrected the process currently for the installation/configuration steps. Validation of final testing steps Now needs to occur.
		Version 0.4.0 (2019-04-23) - Removed the TODO: Block from the script header. All to do's will now be finalized trough GITHUB project workflow. 
								- Re-organized the code layout/structure for readability with regions in process block
								- Refactored the install code to use a list install instead of feature by feature
								- NOTE - commented out the old code did not remove - want to save as an "Advanced" installer method for troubleshooting which feature fails in the future
								- Introduced time tracking on the script to log the duration of the install or configuration.
		Version 0.4.1 (2019-04-23) - Confirmed Install Command works - Still no complete resolution on Logging function not erroring out while the script is running. 
								- Confirmed Configure Works - Now need to enhance functionality
								- Resolved Issue Tracked on Github #1
		Version 0.4.2 (2019-04-24) - Resolved The following Github Issues
								- #3 Install Script Doesn't Check if Already Run 
								- #10 New-PSDWebinstance.ps1 cannot run -configure multiple times 
								- #9 Variable names and check for folder
								- #8 Uppercase N in New
								- #7 MIME type being set a second time causes terminating error -> Interrelated to Numbers #3 and #10
		Version 0.4.3 (2019-04-24) - Updated the psDeploymentShare parameter to meet the criteria of being called psDeploymentFolder per Bug #9
		Version 0.4.4 (2019-04-24) - Updated the {} structure to follow the styling that Niehaus is using. Per Bug #6
								- Validated Code works in Version - Dev Test SignOff
								- Added parameter information to the powerShell Get-Help block.
								- Added functional examples to the PowerShell Get-Help Block
		Version 0.4.5 (2019-04-25) - Discovered a Microsoft Bug with IIS PowerShell Cmdlets developed a way around it by implementing an older command style to first populate the needed
								- Attributes and then move on. This related to Bug #12
		Version 0.4.6 (2019-05-01) - Configured same settings on the Default Web Site related to WebDav 
									- Logging an issue with not being able to hide the AppCMD output will update an issue tracking number tomorrow
		Version 0.4.7 (2020-06-30) - Script separated into two different scripts, this script will install the roles needed.
									- The script only works when running locally on the server.
		Version 0.4.8 - (@PowerShellCrack) - Cleaned up Synopsis. Fixed missed spelled words and added blocks for cleaner code.
#>

#Requires -RunAsAdministrator

##=========================================================================================
## PARAMETER DECLARATION
##=========================================================================================
[CmdletBinding(DefaultParameterSetName='None')]
param(
    [switch]$StartedFromHydration
)

##=========================================================================================
## FUNCTION HELPERS
##=========================================================================================
#region HelperFunctions

function Test-PSDRoleInstalled{
        [CmdletBinding()]
        param
        (
            [parameter(Mandatory = $true)]
            [string]$RoleName
        )
        Try
        {
            write-PSDInstallLog -Message "Now confirming if the role is installed on the machine"
            $FeatureInfo = Get-WindowsFeature -Name $RoleName -Verbose:$false
            if($FeatureInfo.InstallState -eq $true)
            {
                write-PSDInstallLog -Message "The role is installed on the machine"
                return $true
            }
            else
            {
                write-PSDInstallLog -Message "The role $($RoleName) is NOT installed on the machine" 
                return $false
            }
        }
        Catch
        {
            throw [System.IO.DriveNotFoundException] "An Error occured with detecting the roles installation state"
        }
}
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
			if (!(Test-Path $FilePath))
				{
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

#endregion HelperFunctions
############################################


##=========================================================================================
## MAIN LOGIC
##=========================================================================================

# Set VerboseForegroundColor
$host.PrivateData.VerboseForegroundColor = 'Cyan'

############################################

#region StartUpChecks
set-PSDDefaultLogPath

#Start Time Calculation
$StartTime = Get-Date

#endregion StartUpChecks
############################################

############################################
#region GatherActions
Write-PSDInstallLog -Message "The Script is currently running on $($ENV:COMPUTERNAME)"
Write-PSDInstallLog -Message "Upon completion several roles will be installed upon $($env:ComputerName)"
Write-PSDInstallLog -Message "The Script was executed with commands: $($MyInvocation.Line)"
Write-PSDInstallLog -Message "The Current user is $($ENV:USERNAME) and is an administrator"
# endregion GatherActions

# region InstallActions
if(Test-PSDRoleInstalled -RoleName "WEB-Server")
{
	Write-PSDInstallLog -Message "The installation failed because IIS was already installed, and we don't want to break an existing installation" -LogLevel 3
	break
}

write-PSDInstallLog -Message "The server is available and does NOT have IIS installed. Now preparing to install IIS" 
try
{
	$IISResults = Install-WindowsFeature -Name Web-Server -Verbose:$false
	if($IISResults.Success)
	{
		write-PSDInstallLog -Message "Successfully installed the IIS install with Exit Code $($IISResults.ExitCode) and Value $($IISResults.ExitCode.Value__)"
	}

	$BITSSResults = Install-WindowsFeature -Name BITS-IIS-Ext -Verbose:$false
	if($BITSSResults.Success)
	{
		write-PSDInstallLog -Message "Successfully installed the BITS install with Exit Code $($BITSSResults.ExitCode) and Value $($BITSSResults.ExitCode.Value__)"
	}

	Write-PSDInstallLog -Message "Now attempting to install other required IIS Features"
	#ToDO make this a proper hash table/list to explain info next to it at the end and evaluate or to allow install ALL sub features
	$Featurelist = @("Web-Custom-Logging","Web-Log-Libraries","Web-Request-Monitor","Web-Http-Tracing","Web-Security","Web-Filtering","Web-Basic-Auth","Web-Digest-Auth","Web-Url-Auth","Web-Windows-Auth","Web-Mgmt-Console","Web-Metabase","Web-Common-Http","Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-Static-Content","Web-Http-Redirect","Web-DAV-Publishing")
	$FeatureResults = Install-WindowsFeature -Name $Featurelist
	write-PSDInstallLog -Message "Installed the Common HTTP Features with Exit Code $($FeatureResults.ExitCode) and Value $($FeatureResults.ExitCode.Value__)"

	$WEBDAVResults = Install-WindowsFeature -Name "WebDav-Redirector" -Verbose:$false -WarningAction SilentlyContinue
	if($WEBDAVResults.Success)
	{
		write-PSDInstallLog -Message "Completed the installation of the WEBDAV-Feature on $($env:ComputerName) and Value $($WEBDAVResults.ExitCode.Value__)"
		if($WEBDAVResults.ExitCode.Value__ -eq "3010"){
			If ($StartedFromHydration -eq $false){
				write-PSDInstallLog -Message "The server $($env:ComputerName) requires a reboot to finalize the WebDav installation" -LogLevel 2
			}
		}
	}
}
catch
{
	write-PSDInstallLog -Message "Something went wrong on line $($_.Exception.InvocationInfo.ScriptLineNumber) the error message was: $($_.Exception.Message)" -LogLevel 3
}

#endregion InstallActions
############################################

############################################
#region ShutdownChecks
$EndTime = Get-Date
$Duration = New-TimeSpan -Start $StartTime -End $EndTime

If ($StartedFromHydration -eq $false){
	Write-PSDInstallLog -Message "The New-PSDWebInstance.ps1 script has completed running and took $($Duration.Hours) Hours and $($Duration.Minutes) Minutes and $($Duration.Seconds) seconds"
}
#endregion ShutdownChecks
############################################

Write-Verbose -Verbose -Message "The script has completed"
