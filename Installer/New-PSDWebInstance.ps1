<#
.Synopsis
    This script is designed to work with the PSD Toolkit to install and configure IIS as needed for the solution to deploy Windows over the internet. 
    This script will install the IIS feature set and the components required for WebDAV

.Description
    This script was written by Jordan Benzing @JordanTheITGuy in partnership with TrueSec and 2Pint. This script is for the friends of MDT deployment tools 
    and is responsible for making the required IIS components work for PSD


.LINK
    https://github.com/FriendsOfMDT/PSD

.NOTES
    FileName:   New-PSDIISInstance.PS1
    Author:     Jordan Benzing
    Contact:    @JordanTheITGuy
    Created:    2019-04-15
    Updated:    2019-04-18

    Version 0.0.0 (2019-04-15) - Wrote out framework for code base imported standard helper functions
	Version 0.1.0 (2019-04-15) - Created a functional version of the script installs IIS, installs WebDav - reboots server to complete setup and then starts WEbDave Services
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
						

.PARAMETER Install
	This parameter will run the installation for all of the features that are required for the PowerShell install. Currently this parameter will NOT run if IIS is already installed.
	Additional development time has been requested to allow it to add the features that are MISSING if IIS is already installed on the server. 

.PARAMETER Configure
	This parameter will run the configuration steps for the virtual directories. This parameter can be used multiple times to configure multiple directories for PSD.

.PARAMETER psDeploymentFolder
	This parameter is mandatory if the configure parameter has been specified. This parameter is the path to the directory that is used by the virtual directory. Currently this has only been tested locally and not
	with a UNC Path. 

.PARAMETER psVirtualDirectory
	This parameter is mandatory if the configure parameter has been specified. This parameter is the virtual directories name that will be listed under "Default Web Site". Currently we only support installing a
	virtual directory under the default website. No plans have been made to support anything else. 

.PARAMETER ComputerName
	This parameter specifies the target server the above options should run against. Currently ComputerName is only supported for the INSTALL command and not the configure command. This is planned to be added in 
	Revision 2.0. 

.EXAMPLE
	.\New-PSDWebInstance.ps1 -install 
	This will install the IIS and WebDAV features on the local server

.EXAMPLE
	.\New-PSDWebInstance.Ps1 -Configure -PSvirtualDirectory "PSDExample01" -psDeploymentFolder "C:\MDT\MyDeploymentShare"
	This will configure the needed webDAV components for the local server.

#>

[CmdletBinding(DefaultParameterSetName='None')]
param(
	[Parameter(HelpMessage="Please enter the server name you would like to install the IIS/WEBDAV Role on. If no option is selected it will assume a local install.")]
	[string]$ComputerName = $ENV:COMPUTERNAME,
	[Parameter(HelpMessage = "Use this flag to reboot the server - Note: To complete the installation of WebDAV, a reboot is required.")]
	[switch]$AllowReboot,
	[Parameter(HelpMessage = "Use this flag to run the installer.")]
	[switch]$Install,
	[Parameter(HelpMessage = "Use this flag to run the post install configuration - Note: This flag should only be run if the install has already been run for IIS/WEBDAV",ParameterSetName ='Config',Mandatory=$false)]
	[switch]$Configure,
	[Parameter(HelpMessage = "Use this flag to specify the MDT share path - Note: If you do not provide one the script WILL error out.",ParameterSetName ='Config',Mandatory=$True)]
	[string]$psDeploymentFolder,
	[parameter(HelpMessage = "Use this flag to specifiy the NAME of the PSD - Note: If you do not provide one the defualt value will be used.",ParameterSetName ='Config',Mandatory=$True)]
	[string]$psVirtualDirectory
)
begin
{

############################################
#region RequirementCheck
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(!($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))
{
	Write-Error -Message "You must run this script as an administrator with admin permissions."
}
#endregion RequirementCheck
############################################

############################################
#region HelperFunctions
function Test-PSDConnectivity
#Test Connection function. All network tests should be added to this for a full connection test. Returns true or false.
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[string]$ComputerName
	)
	Try
	#Try each connection test. If there is a connection test that you do not want to use remove it by commenting out the line.
	{
		Test-PSDPing -ComputerName $ComputerName -ErrorAction Stop
		Test-PSDAdminShare -ComputerName $ComputerName -ErrorAction Stop
		Test-PSDWinRM -ComputerName $ComputerName -ErrorAction Stop
		write-PSDInstallLog -Message "$ComputerName has passed all connection tests."
		return $true
	}
	Catch
	{
		write-PSDInstallLog -Message "$ComputerName failed a connection test."
		return $false
	}
}

function Test-PSDPing
#Test ping for computer.
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[string]$ComputerName
	)
	$PingTest = Test-Connection -ComputerName $ComputerName -BufferSize 8 -Count 1 -Quiet
	If ($PingTest)
	{
		write-PSDInstallLog -Message "The Ping test for $ComputerName has PASSED."
	}
	Else
	{
		write-PSDInstallLog -Message "$ComputerName failed ping test."
		throw [System.Net.NetworkInformation.PingException] "$ComputerName failed ping test."
	}
}

function Test-PSDAdminShare
#Test Conection to admin C$ share.
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[string]$ComputerName
	)
	$AdminShare = "\\" + $ComputerName + "\C$"
	$AdminAccess = Test-Path -Path $AdminShare -ErrorAction Stop
	if ($AdminAccess)
	{
		write-PSDInstallLog -Message "The admin share connection test $ComputerName has PASSED."
	}
	Else
	{
		write-PSDInstallLog -Message "$ComputerName admin share not found."
		throw [System.IO.FileNotFoundException] "$ComputerName admin share not found."
		
	}
}

function Test-PSDWinRM
#Test WinRM.
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[string]$ComputerName
	)
	Try
	{
		Test-WSMan -computername $ComputerName -ErrorAction Stop
		write-PSDInstallLog -Message "The WINRM check for $ComputerName has PASSED."
	}
	Catch
	{
		throw [System.IO.DriveNotFoundException] "$ComputerName cannot be connected to via WINRM."
	}
}

function Test-PSDRoleInstalled
#Tests to see if a particular Windows feature/role is installed
{
        [CmdletBinding()]
        param
        (
            [parameter(Mandatory = $true)]
            [string]$RoleName,
            [parameter()]
            [string]$ComputerName = $ENV:COMPUTERNAME
        )
        Try
        {
            write-PSDInstallLog -Message "Now confirming if the role is installed on the machine."
            $FeatureInfo = Get-WindowsFeature -Name $RoleName -ComputerName $ComputerName -Verbose:$false
            if($FeatureInfo.InstallState -eq $true)
            {
                write-PSDInstallLog -Message "The role is installed on the machine."
                return $true
            }
            else
            {
                write-PSDInstallLog -Message "The role $($RoleName) is NOT installed on the machine." -LogLevel 2
                return $false
            }
        }
        Catch
        {
            throw [System.IO.DriveNotFoundException] "An error occured with detecting the role's installation state."
        }
}

Function Start-PSDLog
#Set global variable for the write-PSDInstallLog function in this session or script.
{
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
			#Confirm the provided destination for logging exists. if it doesn't then create it.
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

Function Write-PSDInstallLog
#Write the log file if the global variable is set
{
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

function set-PSDDefaultLogPath
{
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

function get-PSDNetworkConfiguration
{
    [CmdletBinding()]
    param()
    $Information = Get-NetIPConfiguration | Select-Object InterfaceAlias,IPv4Address,IPv6Address,NetProfile,DNSServer
    $NetworkInfo = @()
	ForEach($Interface in $Information)
	{
        $Hash = @{
            InterfaceName = $Interface.InterfaceAlias
            IPv4Address = $Interface.IPv4Address.IPAddress
            IPv6Address = $Interface.IPv6Address.IPAddress
            NetProfile = $Interface.NetProfile.Name
            DNSServer = $Interface.DNSServer.ServerAddresses
        }
        $Item = New-Object -TypeName psobject -Property $Hash
        $NetworkInfo += $Item
    }
    return $NetworkInfo
}

#endregion HelperFunctions
############################################

############################################
#region ConfigurationFunctions
function invoke-IISConfiguration
{
	[CmdletBinding()]
	param(
		[parameter()]
		[string]$psDeploymentFolder,
		[parameter()]
		[string]$psVirtualDirectory
	)
	begin
	{
		if(!($TargetEqualsLocal))
		{
			if(!(Test-PSDConnectivity -ComputerName $ComputerName))
			{
				Write-PSDInstallLog -Message "A connection test failed to validate which connnection test failed in the LogFile and remediate. Nothing was attempted to install at this time." -LogLevel 3
				break
			}
		}
		if(!(Test-PSDRoleInstalled -RoleName "WEB-Server" -ComputerName $ComputerName) -or !(Test-PSDRoleInstalled -RoleName "WebDav-Redirector" -ComputerName $ComputerName))
			{
				Write-PSDInstallLog -Message "The configuration attempt failed because a role was missing. Review the log for details." -LogLevel 3
				break
			}
		if(!(Test-Path -Path $psDeploymentFolder))
		{
			Write-PSDInstallLog -Message "The deployment share doesn't exist. Re-run the script with a share that exists." -LogLevel 3
			break
		}
	}
	process
	{
		# Confirm the Services are present and the start up configuration is properly configured
		write-PSDInstallLog -Message "Confirming the WebDAV services are configured properly on: $($ComputerName)"
		try
		{
			$Count = 0
			Do
			{
				$Count++
				Write-PSDInstallLog -Message "Attempt number: $($Count) at connecting and starting the service."
				$MRxDavserviceState = Get-Service -ComputerName $ComputerName -Name MRxDAV -ErrorAction SilentlyContinue
				$WebClientServiceState = Get-Service -ComputerName $ComputerName -Name WebClient -ErrorAction SilentlyContinue
				if(($MRxDavserviceState) -and $MRxDavserviceState.Status -ne "Running")
				{
					Write-PSDInstallLog -Message "We found $($MRxDAVServiceState.DisplayName) and are now attempting to set it to a running state."
					Set-Service -ComputerName $ComputerName -StartupType Automatic -ErrorAction Stop -Status Running -Name $MRxDavserviceState.Name
				}
				if(($WebClientServiceState) -and $WebClientServiceState.Status -ne "Running")
				{
					Write-PSDInstallLog -Message "We found $($WebClientServiceState.DisplayName) and are now attempting to set it to a running state."
					Set-Service -ComputerName $ComputerName -StartupType Automatic -ErrorAction Stop -Status Running -Name $WebClientServiceState.Name
				}
				elseif (!($MRxDavserviceState) -and !($WebClientServiceState)) {
					Write-PSDInstallLog -Message "Neither service was found. Waiting 15 seconds..." -LogLevel 2
					Start-Sleep -Seconds 15
				}
			}
			until((($MRxDavserviceState) -and ($WebClientServiceState)) -or ($Count -ge 5))
			if(!($MRxDavserviceState) -or !($WebClientServiceState))
			{
				Write-PSDInstallLog -Message "Something went wrong with the installation, and the services are not appearing. Now breaking."
				break
			}
			Write-PSDInstallLog -Message "Successfully Completed starting the required services."
		}
		Catch
		{
				Write-PSDInstallLog -Message "Something went wrong with setting or starting the services. Refer to the log to validate." -LogLevel 3
		}
			#Create the virtual directory
		try
		{
			write-PSDInstallLog -Message "Now creating the Virtual Directory."
			if(Test-Path -Path $psDeploymentFolder)
			{
				$DuplicateCheck = Get-WebVirtualDirectory -Name $psVirtualDirectory
				if($DuplicateCheck)
				{
					Write-PSDInstallLog -Message "The website $($psVirtualDirectory) already exists." -LogLevel 3
					break
				}
				$VirtualDirectoryResults = New-WebVirtualDirectory -Site "Default Web Site" -Name "$($psVirtualDirectory)" -PhysicalPath $psDeploymentFolder
				if($VirtualDirectoryResults)
				{
					Write-PSDInstallLog -Message "Succesfully created the virtual directory $($VirtualDirectoryResults.Name). This drive maps to: $($VirtualDirectoryResults.PhysicalPath)"
				}
				Write-PSDInstallLog -Message "Now enabling WebDAV"
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/" -filter "system.webServer/webdav/authoring" -name "enabled" -value "True"
				$HERE = @"
				set config "Default Web Site/$($psVirtualDirectory)" /section:system.webServer/webdav/authoringRules /+[users='*',path='*',access='Read,Source'] /commit:apphost
"@
				$Results = start-process C:\Windows\System32\inetsrv\AppCMD.EXE -ArgumentList $HERE -NoNewWindow -PassThru | Out-Null
				Start-Sleep -Seconds 5
				if(!((Get-WebConfigurationProperty -PSPath "IIS:\Sites\Default Web Site\$($psVirtualDirectory)" -Filter "system.webServer/staticContent" -Name ".").Collection | Where-Object {$_.fileExtension -eq ".*"}))
				{
					Write-PSDInstallLog -Message "The Mime Type has not yet been added for virtual directories. Now adding..."
					$MimeREsults = Add-WebConfigurationProperty -PSPath "IIS:\Sites\Default Web Site\$($psVirtualDirectory)" -Filter "system.webServer/staticContent" -Name "." -Value @{ fileExtension='.*'; mimeType='Text/Plain'}
					if($MimeREsults)
					{
						Write-PSDInstallLog -Message "Successfully created the Mime Type."
					}
				}
				Write-PSDInstallLog -Message "Enabling directory browsing."
				set-WebConfigurationProperty -filter /system.webServer/directoryBrowse -name enabled -PSPath "IIS:\Sites\Default Web Site\$($psVirtualDirectory)" -Value $true
				Write-PSDInstallLog -Message "Directory browsing has been enabled for: $($psVirtualDirectory)"
				<#if(!((Get-WebConfigurationProperty -Filter '/system.webServer/webdav/authoringRules' -Location "IIS:\Default Web Site\$($psVirtualDirectory)" -Name '.').Collection | Where-Object {$_.users -eq "*" -and $_.Path -eq "*" -and $_.access -eq "Read,Source"}))
				{
					Write-PSDInstallLog -Message "Enabling WebDav Authoring Rules"
					$accessRule = @{
					users  = '*'
					path   = '*'
					access = 'Read,Source'
					}
					$WebDavAuthoring = Add-WebConfigurationProperty -Filter '/system.webServer/webdav/authoringRules' -Location "IIS:\Default Web Site\$($psVirtualDirectory)" -Name '.' -Value $accessRule
					if($WebDavAuthoring)
					{
						Write-PSDInstallLog -Message "Configured WebDav Rules"
					}
				}#>
				Write-PSDInstallLog -Message "Now configuring security settings for authentication."
				#Written using ScriptGenerator from IIS
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/security/authentication/anonymousAuthentication" -name "enabled" -value "False"
				#Written Using Script Generator from IIS
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/security/authentication/windowsAuthentication" -name "enabled" -value "True"
				#Setting WebDav Settings
				Write-PSDInstallLog -Message "Setting WEBDAVSettings."
				Write-PSDInstallLog -Message "Setting the authoring rules for default MimType."
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/" -filter "system.webServer/webdav/authoringRules" -name "defaultMimeType" -value "text/xml"
				Write-PSDInstallLog -Message "Setting the Infinite Depth rules for the virtual directory."
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/webdav/authoring/properties" -name "allowInfinitePropfindDepth" -value "True"
				Write-PSDInstallLog -Message "Setting the Infinite Depth rules for the default Web Site."
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site" -filter "system.webServer/webdav/authoring/properties" -name "allowInfinitePropfindDepth" -value "True"
				Write-PSDInstallLog -Message "Turning off the apply to WebDAV setting for File Extensions - This allows it to be configured or altered as needed."
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/security/requestFiltering/fileExtensions" -name "applyToWebDAV" -value "false"
				Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/" -filter "system.webServer/security/requestFiltering/fileExtensions" -name "applyToWebDAV" -value "false"
				Write-PSDInstallLog -Message "Turning off the Request Filtering for Verbs on WebDAV."
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
			Write-PSDInstallLog -Message "Something went wrong." -LogLevel 3
		}
	}
}
#Endregion ConfigurationFunctions
############################################


}

process
{
	############################################
	#region StartUpChecks
	set-PSDDefaultLogPath
	#Block any unallowed action
	if(($Install -and $Configure) -and !($Allowreboot))
	{
		Write-PSDInstallLog -Message "Error - you cannot run the installation and configuration commands together without allowing a reboot" -LogLevel 3
		break
	}

	if($ENV:COMPUTERNAME -eq $ComputerName)
	{
		$TargetEqualsLocal = $True
	}

	#Start Time Calculation
	$StartTime = Get-Date

	#endregion StartUpChecks
	############################################

	############################################
	#region GatherActions
	Write-PSDInstallLog -Message "The script is currently running on $($ENV:COMPUTERNAME) and was targeted to run against $($ComputerName)."
	Write-PSDInstallLog -Message "Upon completion, several roles will be installed upon $($ComputerName)."
	Write-PSDInstallLog -Message "Completed initilization of all pre-written functions. Now documenting running environment."
	Write-PSDInstallLog -Message "The script was executed with commands: $($MyInvocation.Line)"
	Write-PSDInstallLog -Message "The current running computer is: $($ENV:COMPUTERNAME.ToUpper())"
	Write-PSDInstallLog -Message "The current user is $($ENV:USERNAME) and is an administrator."
	$NetworkSettings = get-PSDNetworkConfiguration
	Write-PSDInstallLog -Message "The EXECUTING SERVER $($ENV:COMPUTERNAME.ToUpper())'s network information is:"
	foreach($Setting in $NetworkSettings)
	{
		Write-PSDInstallLog -Message "$($ENV:COMPUTERNAME.ToUpper()) - Profile: $($Setting.NetProfile)"
		Write-PSDInstallLog -Message "$($ENV:COMPUTERNAME.ToUpper()) - IPv4 Address: $($Setting.IPv4Address)"
		Write-PSDInstallLog -Message "$($ENV:COMPUTERNAME.ToUpper()) - IPv6 Address: $($Setting.IPv6Address)"
		Write-PSDInstallLog -Message "$($ENV:COMPUTERNAME.ToUpper()) - DNS Server: $($Setting.DNSServer)"
	}
	##check if the target computer is remote if it IS remote then and only then check the connection
	if(!($TargetEqualsLocal))
	{
		Write-PSDInstallLog -Message "Now validating that we can connect to the target server: $($ComputerName)"
		if(!(Test-PSDConnectivity -ComputerName $ComputerName))
		{
			Write-PSDInstallLog -Message "Cannot reach the target computer: $($ComputerName). Now breaking." -LogLevel 3
			break
		}
		$TargetServerNetworkSettings = (Invoke-Command -HideComputerName -ComputerName $ComputerName -ScriptBlock ${Function:get-PSDNetworkConfiguration})
		Write-PSDInstallLog -Message "The TARGET SERVER $($COMPUTERNAME.ToUpper())'s network information is:"
		foreach($Setting in $TargetServerNetworkSettings)
		{
			Write-PSDInstallLog -Message "$($COMPUTERNAME.ToUpper()) - Profile: $($Setting.NetProfile)"
			Write-PSDInstallLog -Message "$($COMPUTERNAME.ToUpper()) - IPv4 Address: $($Setting.IPv4Address)"
			Write-PSDInstallLog -Message "$($COMPUTERNAME.ToUpper()) - IPv6 Address: $($Setting.IPv6Address)"
			Write-PSDInstallLog -Message "$($COMPUTERNAME.ToUpper()) - DNS Server: $($Setting.DNSServer)"
		}
	}
	#endregion GatherActions
	############################################

	############################################
	#region InstallActions
	if($Install)
	{
		if(!($TargetEqualsLocal))
		{
			if(!(Test-PSDConnectivity -ComputerName $ComputerName) -or (Test-PSDRoleInstalled -RoleName "WEB-Server" -ComputerName $ComputerName))
			{
				Write-PSDInstallLog -Message "A connection test failed validate which connnection test failed in the Logfile and remediate. Nothing was attempted to install at this time." -LogLevel 3
				if(Test-PSDRoleInstalled -RoleName "WEB-Server" -ComputerName $ComputerName)
				{
					Write-PSDInstallLog -Message "The installation failed because IIS was already installed and we don't want to break an existing installation. Now breaking." -LogLevel 3
				}
				break
			}
		}
		if($TargetEqualsLocal)
		{
			if(Test-PSDRoleInstalled -RoleName "WEB-Server" -ComputerName $ComputerName)
			{
				Write-PSDInstallLog -Message "The installation failed because IIS was already installed and we don't want to break an existing installation. Now breaking" -LogLevel 3
				break
			}
		}
		write-PSDInstallLog -Message "The server is available and does NOT have IIS installed. Now preparing to install IIS." 
		try
		{
			$IISResults = Install-WindowsFeature -Name Web-Server -ComputerName $ComputerName -Verbose:$false
			if($IISResults.Success)
			{
				write-PSDInstallLog -Message "Succesfully installed the IIS install with Exit Code: $($IISResults.ExitCode) and Value: $($IISResults.ExitCode.Value__)"
			}
			Write-PSDInstallLog -Message "Now attempting to install other required IIS features."
			#ToDO make this a proper hash table/list to explain info next to it at the end and evaluate or to allow install ALL sub features
			$Featurelist = @("Web-Custom-Logging","Web-Log-Libraries","Web-Request-Monitor","Web-Http-Tracing","Web-Security","Web-Filtering","Web-Basic-Auth","Web-Digest-Auth","Web-Url-Auth","Web-Windows-Auth","Web-Mgmt-Console","Web-Metabase","Web-Common-Http","Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-Static-Content","Web-Http-Redirect","Web-DAV-Publishing")
			$FeatureResults = Install-WindowsFeature -Name $Featurelist -ComputerName $ComputerName
			write-PSDInstallLog -Message "Installed the Common HTTP features with Exit Code: $($FeatureResults.ExitCode) and Value: $($FeatureResults.ExitCode.Value__)"
			<#
			This section has been blocked out. It is INCREDIBLY time consuming to install each feature one at a time however may add this back in as an  option later on as an "advanced" install option 
			for people who want to have each step logged and are willing to wait the extra time when figuring out if a specific feature install is causing an issue. 
			foreach($Feature in $Featurelist){
				Write-PSDInstallLog -Message "Now attempting to install $($Feature)"
				$FeatureResults = $null
				$FeatureResults = Install-WindowsFeature -Name $Feature -ComputerName $ComputerName -Verbose:$false
				write-PSDInstallLog -Message "Installed the $Feature with Exit Code $($FeatureResults.ExitCode) and Value $($FeatureResults.ExitCode.Value__)"
			}
			#>
			$WEBDAVResults = Install-WindowsFeature -Name "WebDav-Redirector" -ComputerName $ComputerName -Verbose:$false
			if($WEBDAVResults.Success)
			{
				write-PSDInstallLog -Message "Completed the installation of the WebDAV-Feature on: $($ComputerName) and Value: $($WEBDAVResults.ExitCode.Value__)"
				if($WEBDAVResults.ExitCode.Value__ -eq "3010"){
					write-PSDInstallLog -Message "The server: $($ComputerName) requires a reboot to finalize the WebDAV installation."
					if($Allowreboot)
					{
						Write-PSDInstallLog -Message "A reboot for $ComputerName was approved via -AllowReboot switch at script runtime."
						if($TargetEqualsLocal)
						{
							Write-PSDInstallLog -Message "Validated that the computer running the script: $($ENV:COMPUTERNAME) IS the same as the target computer: $($ComputerName)" -LogLevel 2
							Restart-Computer -ComputerName $ComputerName -Force
						}
						if($ENV:COMPUTERNAME -ne $ComputerName)
						{
							Write-PSDInstallLog -Message "Validated that the computer running the script: $($ENV:COMPUTERNAME) is NOT the same as the target computer: $($ComputerName)" -LogLevel 2
							Restart-Computer -ComputerName $ComputerName -Wait -Force
							if($Configure){
								$ConfigureResults = (Invoke-Command -HideComputerName -ComputerName $ComputerName -ScriptBlock ${Function:invoke-IISConfiguration})
								Write-PSDInstallLog -Message "Completed the process for all selected flags. Now breaking."
								break
							}
						}
					}
					elseif (!($AllowReboot))
					{
						Write-PSDInstallLog -Message "The server: $($Computername) was NOT allowed to reboot. You must reboot the server and re-run the script with the -Configure flag." -LogLevel 2
					}   
				}
			}
		}
		catch
		{
			write-PSDInstallLog -Message "Something went wrong on line: $($_.Exception.InvocationInfo.ScriptLineNumber). The error message was: $($_.Exception.Message)" -LogLevel 3
		}
	}

	#endregion InstallActions
	############################################

	############################################
	#region ConfigureActions

	if($Configure)
	{
		if($ComputerName -ne $ENV:COMPUTERNAME)
		{
			$ConfigureResults = (Invoke-Command -HideComputerName -ComputerName $ComputerName -ScriptBlock ${Function:invoke-IISConfiguration})
			Write-PSDInstallLog -Message "Completed the process for all selected flags. Now breaking."
		}
		else
		{
			if(($psDeploymentFolder) -and !($psVirtualDirectory))
			{
				Write-PSDInstallLog -Message "Now configuring WebDAV and IIS for the MDT share at: $($psDeploymentFolder)"
				invoke-IISConfiguration -psDeploymentFolder $psDeploymentFolder
				Write-PSDInstallLog -Message "Completed the configuration."
			}
			elseif (($psDeploymentFolder) -and ($psVirtualDirectory))
			{
			Write-PSDInstallLog -Message "Now configuring  WebDAV and IIS for the MDT share at: $($psDeploymentFolder) with: $($PSWebsite)"
			invoke-IISConfiguration -psDeploymentFolder $psDeploymentFolder -psVirtualDirectory $psVirtualDirectory	
			}

		}
	}
	#endregion ConfigureActions
	############################################

	############################################
	#region ShutdownChecks
	$EndTime = Get-Date
	$Duration = New-TimeSpan -Start $StartTime -End $EndTime
	Write-PSDInstallLog -Message "The script has completed running and took: $($Duration.Hours) Hours, $($Duration.Minutes) Minutes, and $($Duration.Seconds) seconds."
	#endregion ShutdownChecks
	############################################
}
