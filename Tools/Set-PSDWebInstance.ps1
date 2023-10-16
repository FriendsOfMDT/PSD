<#
.Synopsis
    This script is designed to work with the PSD Toolkit to install and configure IIS as needed for the solution to deploy Windows over the internet. 
    This script will install the IIS feature set and the components required for WEBDav

.Description
    This script was written by Jordan Benzing @JordanTheITGuy in partnership with TrueSec and 2Pint. This script is for the friends of MDT deployment tools 
    and is responsible for making the required IIS components work for PSD


.LINK
    https://github.com/FriendsOfMDT/PSD

.NOTES
    FileName:   New-PSDIISInstance.PS1
    Author:     Jordan Benzing
    Contact:    @JordanTheITGuy, @jarwidmark
    Created:    2019-04-15
    Updated:    2022-09-29

    Version 0.0.0 (2019-04-15) Wrote out framework for code base imported standard helper functions
	Version 0.1.0 (2019-04-15)- Created a functional version of the script installs IIS, installs WebDav - reboots server to complete setup and then starts WEbDave Services
	Version 0.1.1 (2019-04-17) - Created switches for "install" v.s. Configure
				  			   - Created New function that does the configuration so that we can add all configuration changes in one place
				  			   - Created a switch for reboot
				  			   - Blocked the behaviour so that someone cannot call Install AND configure - without a reboot
	Version 0.2.0 (2019-04-18) - Updated the Logic for the configure step so it can be modified seperately from the installation step
							   - Implemented a check that prevents you from running the script if the script is targeting the local server (Can't handle reboot)
	Version 0.3.1 (2019-04-18) - Use a variable LIST of all features that need to be installed now for IIS
							   - Wrote out a function for confiugre
							   - crossed off numerous TODO functioanlity checks
							   - Some Code optimization from repeat sections
	Version 0.3.2 (2019-04-19) - Increased the functionality of the reboot handler
							   - Now ALLOW you to reboot the local computer but only if Configure wasn't requested
							   - Now prompts to confirm the reboot 
	Version 0.3.3 (2019-04-19) - Now retrieves network information about the client starting the install and the target machine and logs it.
							   - May include a "debug" option in the WRite-PSD log function in the future.. 
	Version 0.3.4 (2019-04-19) - Updated from PSD to PSD - on all the function
							   - Moved the start-log function back to the begin block to make it work properly. 
	Version 0.3.5 (2019-04-22) - Corrected the process currently for the installtion/configuration steps. Validation of final testing steps Now needs to occur.
	Version 0.4.0 (2019-04-23) - Removed the TODO: Block from the script header. All to do's will now be finalized trough GITHUB project workflow. 
							   - Re-organized the code layout/structure for readabiltiy with regions in process block
							   - Refactored the install code to use a list install instead of feature by feature
							   - NOTE - commented out the old code did not remove - want to save as an "Advanced" installer methd for troubleshooting which feature fails in the future
							   - Introduced time tracking on the script to log the duration of the install or configuration.
	Version 0.4.1 (2019-04-23) - Confirmed Install Command works - Still no complete resolution on Logging function not erroring out while the script is running. 
							   - Confirmed Configure Works - Now need to enhance functionality
							   - Resolved Issue Tracked on Github #1
	Version 0.4.2 (2019-04-24) - Resolved The following Github Issues
							   - #3 Install Script Doesn't Check if Already Run 
							   - #10 New-PSDWebinstance.ps1 cannot run -configure multiple times 
							   - #9 Variable names and check for folder
							   - #8 Uppercase N in New
							   - #7 MIME type being set a second time causes terminating error -> Interealated to Numbers #3 and #10
	Version 0.4.3 (2019-04-24) - Updated the psDeploymentShare parameter to meet the criteria of being called psDeploymentFolder per Bug #9
	Version 0.4.4 (2019-04-24) - Updated the {} structure to follow the styling that Niehaus is using. Per Bug #6
							   - Validated Code works in Version - Dev Test SignOff
							   - Added parameter information to the powerShell Get-Help block.
							   - Added functional examples to the PowerShell Get-Help Block
	Version 0.4.5 (2019-04-25) - Discovered a Microsoft Bug with IIS PowerShell Cmdlets developed a way around it by implementing an older command style to first populate the needed
							   - Attributes and then move on. This related to Bug #12
	Version 0.4.6 (2019-05-01) - Configured same settings on the Default Web Site related to WebDav 
							   - Logging an issue with not being able to hide the AppCMD output will update an issue tracking number tomorrow
	Version 0.4.7 (2020-06-30) - Script separated into two diffrent scripts, this script will Configure WebDav.
                               - The script only works when running locally on the server.
    	Version 0.4.8 (2022-09-29) - Added support for special characters in folder names (allow double escaping)

						

.EXAMPLE
	.\New-PSDWebInstance.Ps1 -PSvirtualDirectory "PSDExample01" -psDeploymentFolder "C:\MDT\MyDeploymentShare"
	This will configure the needed webDAV components for the local server.

#>

#Requires -RunAsAdministrator
[CmdletBinding()]
param(
	[Parameter(HelpMessage = "Use this flag to specify the MDT Share Path - Note if you do not provide one the script WILL Error OUT.",Mandatory=$True)]
    [ValidateScript({Test-Path -Path $_})]
	[string]$psDeploymentFolder,

	[parameter(HelpMessage = "Use this flag to specifiy the NAME of the PSD - NOTE - if you do not provide one the defualt value will be used.",Mandatory=$True)]
	[string]$psVirtualDirectory,
    [switch]$StartedFromHydration
)
begin
{

############################################
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
                write-PSDInstallLog -Message "The role $($RoleName) is NOT installed on the machine" -LogLevel 2
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

############################################
#region ConfigurationFunctions
function invoke-IISConfiguration{
	[CmdletBinding()]
	param(
		[parameter()]
		[string]$psDeploymentFolder,
		[parameter()]
		[string]$psVirtualDirectory
	)
	begin
	{
	if(!(Test-PSDRoleInstalled -RoleName "WEB-Server") -or !(Test-PSDRoleInstalled -RoleName "WebDav-Redirector"))
		{
			Write-PSDInstallLog -Message "The configuration attempt failed because a role was missing review the log for details" -LogLevel 3
			break
		}
	if(!(Test-Path -Path $psDeploymentFolder))
	{
		Write-PSDInstallLog -Message "The deployment share doesn't exist re-run the script with a share that exists" -LogLevel 3
		break
	}
	}
	process
	{
		# Confirm the Services are present and the start up configuration is properly configured
		write-PSDInstallLog -Message "Confirming the WebDav services are configured properly on $($ComputerName)"
		try
		{
			$Count = 0
			Do
			{
				$Count++
				Write-PSDInstallLog -Message "Attempt number $($Count) at connecting and starting the service"
				$MRxDavserviceState = Get-Service -Name MRxDAV -ErrorAction SilentlyContinue
				$WebClientServiceState = Get-Service -Name WebClient -ErrorAction SilentlyContinue
				if(($MRxDavserviceState) -and $MRxDavserviceState.Status -ne "Running")
				{
					Write-PSDInstallLog -Message "We found $($MRxDAVServiceState.DisplayName) and are now attempting to set it to a running state"
					Set-Service -StartupType Automatic -ErrorAction Stop -Status Running -Name $MRxDavserviceState.Name
				}
				if(($WebClientServiceState) -and $WebClientServiceState.Status -ne "Running")
				{
					Write-PSDInstallLog -Message "We found $($WebClientServiceState.DisplayName) and are now attempting to set it to a running state"
					Set-Service -StartupType Automatic -ErrorAction Stop -Status Running -Name $WebClientServiceState.Name
				}
				elseif (!($MRxDavserviceState) -and !($WebClientServiceState)) {
					Write-PSDInstallLog -Message "Neither service was found waiting 15 seconds" -LogLevel 2
					Start-Sleep -Seconds 15
				}
			}
			until((($MRxDavserviceState) -and ($WebClientServiceState)) -or ($Count -ge 5))
			if(!($MRxDavserviceState) -or !($WebClientServiceState))
			{
				Write-PSDInstallLog -Message "Something went wrong with the installation, and the services are not appearing."
				break
			}
			Write-PSDInstallLog -Message "Succesfully Completed starting the required services."
		}
		Catch
		{
				Write-PSDInstallLog -Message "Something went wrong with setting or starting the services refer to the log to validate." -LogLevel 3
		}
			#Create the virtual directory
		try
		{
			write-PSDInstallLog -Message "Now creating the Virtual Directory"
			if(Test-Path -Path $psDeploymentFolder)
			{
				$DuplicateCheck = Get-WebVirtualDirectory -Name $psVirtualDirectory
				if($DuplicateCheck)
				{
					Write-PSDInstallLog -Message "The website $($psVirtualDirectory) already exits" -LogLevel 3
					break
				}
				$VirtualDirectoryResults = New-WebVirtualDirectory -Site "Default Web Site" -Name "$($psVirtualDirectory)" -PhysicalPath $psDeploymentFolder
				if($VirtualDirectoryResults)
				{
					Write-PSDInstallLog -Message "Succesfully created the Virtual Directory $($VirtualDirectoryResults.Name) this drive maps to $($VirtualDirectoryResults.PhysicalPath)"
				}
				Write-PSDInstallLog -Message "Now enabling WebDav"
				$Result = Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/" -filter "system.webServer/webdav/authoring" -name "enabled" -value "True"
				$HERE = @"
				set config "Default Web Site/$($psVirtualDirectory)" /section:system.webServer/webdav/authoringRules /+[users='*',path='*',access='Read,Source'] /commit:apphost
"@
                $Result = Start-Process C:\Windows\System32\inetsrv\AppCMD.EXE -ArgumentList $HERE -NoNewWindow -RedirectStandardOutput "$env:TEMP\silentfile.txt"
				Start-Sleep -Seconds 5
				if(!((Get-WebConfigurationProperty -PSPath "IIS:\Sites\Default Web Site\$($psVirtualDirectory)" -Filter "system.webServer/staticContent" -Name ".").Collection | Where-Object {$_.fileExtension -eq ".*"}))
				{
					Write-PSDInstallLog -Message "The Mime Type has not yet been added for virtual directories now adding..."
					$MimeREsults = Add-WebConfigurationProperty -PSPath "IIS:\Sites\Default Web Site\$($psVirtualDirectory)" -Filter "system.webServer/staticContent" -Name "." -Value @{ fileExtension='.*'; mimeType='Text/Plain'}
					if($MimeREsults)
					{
						Write-PSDInstallLog -Message "Succesfully created the Mime Type"
					}
				}
				Write-PSDInstallLog -Message "Enabling the Directory browsing"
				set-WebConfigurationProperty -filter /system.webServer/directoryBrowse -name enabled -PSPath "IIS:\Sites\Default Web Site\$($psVirtualDirectory)" -Value $true
				Write-PSDInstallLog -Message "Directory browsing has been enabled for the $($psVirtualDirectory)"
				Write-PSDInstallLog -Message "Now configuring security settings for authentication"

				# Enable Double Escaping to support special characters in folder names
				Write-PSDInstallLog -Message "Enabling Double Escaping"
				Set-WebConfigurationProperty -filter /system.webServer/Security/requestFiltering -name allowDoubleEscaping -PSPath "IIS:\Sites\Default Web Site\$($psVirtualDirectory)" -value $true 

				#Written using ScriptGenerator from IIS
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/security/authentication/anonymousAuthentication" -name "enabled" -value "False"

				#Written Using Script Generator from IIS
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/security/authentication/windowsAuthentication" -name "enabled" -value "True"

				#Written using ScriptGenerator from IIS
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site" -filter "system.webServer/security/authentication/anonymousAuthentication" -name "enabled" -value "False"

				#Written Using Script Generator from IIS
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site" -filter "system.webServer/security/authentication/windowsAuthentication" -name "enabled" -value "True"

				#Setting WebDav Settings
				Write-PSDInstallLog -Message "Setting WEBDavSettings"
				Write-PSDInstallLog -Message "Setting the Authoring rules for Default MimeType"
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/" -filter "system.webServer/webdav/authoringRules" -name "defaultMimeType" -value "text/xml"
				Write-PSDInstallLog -Message "Setting the Infinite Depth rules for the virtual directory"
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/webdav/authoring/properties" -name "allowInfinitePropfindDepth" -value "True"
				Write-PSDInstallLog -Message "Setting the the Infinite Depth rules for the Default Web Site"
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site" -filter "system.webServer/webdav/authoring/properties" -name "allowInfinitePropfindDepth" -value "True"
				Write-PSDInstallLog -Message "Turning off the apply to WebDav setting for File Extensions - Allows it to be configured or altered as needed"
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/security/requestFiltering/fileExtensions" -name "applyToWebDAV" -value "false"
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/" -filter "system.webServer/security/requestFiltering/fileExtensions" -name "applyToWebDAV" -value "false"
				Write-PSDInstallLog -Message "Turning off the Request filtering for Verbs on WebDav"
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/security/requestFiltering/verbs" -name "applyToWebDav" -value "False"
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/" -filter "system.webServer/security/requestFiltering/verbs" -name "applyToWebDav" -value "False"
				$hiddenSegments = Get-IISConfigSection -SectionPath 'system.webServer/security/requestFiltering' | Get-IISConfigElement -ChildElementName 'hiddenSegments'
				Set-IISConfigAttributeValue -ConfigElement $hiddenSegments -AttributeName 'applyToWebDAV' -AttributeValue $false
			}
			if(!(Test-Path -Path $psDeploymentFolder))
			{
				invoke-IISConfiguration
			}
		}
		Catch
		{
			Write-PSDInstallLog -Message "Something went wrong" -LogLevel 3
		}
	}
}

#Endregion ConfigurationFunctions
############################################
}

process
{

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
	Write-PSDInstallLog -Message "The Script was executed with commands: $($MyInvocation.Line)"
	Write-PSDInstallLog -Message "The Current running computer is: $($ENV:COMPUTERNAME.ToUpper())"
	Write-PSDInstallLog -Message "The Current user is $($ENV:USERNAME) and is an administrator"

	#endregion GatherActions
	############################################

	############################################
	#region ConfigureActions

	Write-PSDInstallLog -Message "Now configuring the WebDAV and IIS for the MDT share at $($psDeploymentFolder) with $($PSWebsite)"
	invoke-IISConfiguration -psDeploymentFolder $psDeploymentFolder -psVirtualDirectory $psVirtualDirectory	

	#endregion ConfigureActions
	############################################

    Remove-Item -Path "$env:TEMP\silentfile.txt"

	############################################
	#region ShutdownChecks
	$EndTime = Get-Date
	$Duration = New-TimeSpan -Start $StartTime -End $EndTime
	Write-PSDInstallLog -Message "The script has completed running and took $($Duration.Hours) Hours and $($Duration.Minutes) Minutes and $($Duration.Seconds) seconds"
	#endregion ShutdownChecks
	############################################

    Write-Verbose -Verbose -Message "The script has completed"
}

