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
    Contact:    @JordanTheITGuy
    Created:    2019-04-15
    Updated:    2019-04-18

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
							   - 

	TODO
	##Basic Functionality##
		[X] - Check if IIS is installed on TargetServer - Break if already installed if not Install
		[X] - Check if WEBDave is installed on Target Server - Break if already installed
		[ ] - Validate that Configuration is completely done - Can't be done UNTIL all PSD work stuff is known
		[ ] - Upgrade the reboot check to ONLY stop the script if its run against the LOCAL box AND the reboot is called
	##Things that Make PSD Work##
			[X] - Create New Virtual Directory that points to the PSD Deployment Share
			[ ] - Needs Bound to HTTP/HTTPS - Markus Blog Post? 
			[X] - Needs MIME type set or Added - Thinks it was XAML or XML (Maybe) 
			[X] - Possible Permission changes
			[X] - WebDav Authoring Rules 
	##Validation##
			[X] - MGMT Tools (IIS MGMG Console and IIS 6 Metabase Compat)
			[X] - AppDev -> Isapi Extensions
			[X] - Security -> request filtering, basic auth, digest auth, URL auth, Windows Auth
			[X] - Performance -> Static Content
			[X] - Health and Diag -> HTTP Logging, Logging Tools, Request Monitor Tracing
			[X] - Http Logging, Logging Tools, Request Monitor, Tracing
			[X] - Common Http -> All
			[X] - Should be 19/43 total features installed
			[X] - Management 2/7 
		[X] - Upgrade the reboot check to ONLY stop the script if its run against the LOCAL box AND the reboot is called
			- This was enhanced to ALWAYS allow the reboot if asked for EXCEPT in the case Install AND Configure are called at the same time on the local box. 
		[ ] - Validate that if a reboot is cancelled later in the script when prompted that it STOPS the script and does not try to run configure.
		[ ] - Validate that all of the flag controls perform the expected outputs.


.PARAMETER

.EXAMPLE

.EXAMPLE

#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Please enter the server name you would like to install the IIS/WEBDAV Role on if no option is selected it will assume a local install")]
	[string]$ComputerName = $ENV:COMPUTERNAME,
	[Parameter(HelpMessage = "To complete the installation of WebDav a reboot is required. If you woud like the script to perform the reboot then make this true.")]
	[switch]$AllowReboot,
	[Parameter(HelpMessage = "Use this flag to run the post install configuration. This flag should only be run if the install has already been run for IIS/WEBDAV")]
	[switch]$Configure,
	[Parameter(HelpMessage = "Use this flag to run the installer")]
	[switch]$Install
)
begin{

############################################
#region RequirementCheck
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(!($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))){
	Write-Error -Message "You must run this script as an administrator with admin permissions"
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
		write-PSDInstallLog -Message "$ComputerName has passed all connection tests"
		return $true
	}
	CATCH
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
		write-PSDInstallLog -Message "The Ping test for $ComputerName has PASSED"
	}
	Else
	{
		write-PSDInstallLog -Message "$ComputerName failed ping test"
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
		write-PSDInstallLog -Message "The admin share connection test $ComputerName has PASSED"
		$ConnectionStatus = $true
	}
	Else
	{
		write-PSDInstallLog -Message "$ComputerName admin share not found"
		throw [System.IO.FileNotFoundException] "$ComputerName admin share not found"
		
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
		write-PSDInstallLog -Message "The WINRM check for $ComputerName has PASSED"
	}
	Catch
	{
		throw [System.IO.DriveNotFoundException] "$ComputerName cannot be connected to via WINRM"
	}
}

function Test-PSDRoleInstalled
#Tests to see if a particular Windows feature/role is instaled
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
            write-PSDInstallLog -Message "Now confirming if the role is installed on the machine"
            $FeatureInfo = Get-WindowsFeature -Name $RoleName -ComputerName $ComputerName -Verbose:$false
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
    Add-Content -Value $Line -Path $ScriptLogFilePath
    if($writetoscreen){
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
    if($writetolistbox -eq $true){
        $result1.Items.Add("$Message")
    }
}

function set-PSDDefaultLogPath {
	#Function to set the default log path if something is put in the field then it is sent somewhere else. 
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $false)]
		[bool]$defaultLogLocation = $true,
		[parameter(Mandatory = $false)]
		[string]$LogLocation
	)
	if($defaultLogLocation){
		$LogPath = Split-Path $script:MyInvocation.MyCommand.Path
		$LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
		Start-PSDLog -FilePath $($LogPath + "\" + $LogFile)
	}
	else {
		$LogPath = $LogLocation
		$LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
		Start-PSDLog -FilePath $($LogPath + "\" + $LogFile)
	}
}

function get-PSDNetworkConfiguration{
    [CmdletBinding()]
    param()
    $Information = Get-NetIPConfiguration | Select-Object InterfaceAlias,IPv4Address,IPv6Address,NetProfile,DNSServer
    $NetworkInfo = @()
    ForEach($Interface in $Information){
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
function invoke-IISConfiguration{
	[CmdletBinding()]
	param(
		[parameter(Mandatory = $true)]
		[string]$MDTPath
	)
	if(!(Test-PSDConnectivity -ComputerName $ComputerName) -or !(Test-PSDRoleInstalled -RoleName "WEB-Server" -ComputerName $ComputerName) -or !(Test-PSDRoleInstalled -RoleName "WebDav-Redirector" -ComputerName $ComputerName)){
		Write-Error -Message "A connection test failed validate which connnection test failed in the LogFile and remediate nothing was attempted to install at this time."
		if(!(Test-PSDRoleInstalled -RoleName "WebDav-Redirector" -ComputerName $ComputerName)){
			Write-PSDInstallLog -Message "The configuration attempt failed because the WebDave role was missing" -LogLevel 3
		}
		break
	}
	write-PSDInstallLog -Message "Configuring the WebDav startup services on $($ComputerName)"
	try{
		$Count = 0
		Do{
			$Count++
			Write-PSDInstallLog -Message "Attempt number $($Count) at connecting and starting the service"
			$MRxDavserviceState = Get-Service -ComputerName $ComputerName -Name MRxDAV -ErrorAction SilentlyContinue
			$WebClientServiceState = Get-Service -ComputerName $ComputerName -Name WebClient -ErrorAction SilentlyContinue
			if(($MRxDavserviceState) -and $MRxDavserviceState.Status -ne "Running")
			{
				Write-PSDInstallLog -Message "We found $($MRxDAVServiceState.DisplayName) and are now attempting to set it to a running state"
				Set-Service -ComputerName $ComputerName -StartupType Automatic -ErrorAction Stop -Status Running -Name $MRxDavserviceState.Name
			}
			if(($WebClientServiceState) -and $WebClientServiceState.Status -ne "Running")
			{
				Write-PSDInstallLog -Message "We found $($WebClientServiceState.DisplayName) and are now attempting to set it to a running state"
				Set-Service -ComputerName $ComputerName -StartupType Automatic -ErrorAction Stop -Status Running -Name $WebClientServiceState.Name
			}
			elseif (!($MRxDavserviceState) -and !($WebClientServiceState)) {
				Write-PSDInstallLog -Message "Neither service was found waiting 15 seconds" -LogLevel 2
				Start-Sleep -Seconds 15
			}
		}
		until((($MRxDavserviceState) -and ($WebClientServiceState)) -or ($Count -ge 5))
		if(!($MRxDavserviceState) -or !($WebClientServiceState)){
			Write-PSDInstallLog -Message "Something went wrong with the installation, and the services are not appearing."
			break
		}
		Write-PSDInstallLog -Message "Succesfully Completed starting the required services."
		write-PSDInstallLog -Message "Now creating the Virtual Directory"
		if(Test-Path -Path $MDTPath){
			$VirtualDirectoryResults = New-WebVirtualDirectory -Site "Default Web Site" -Name "PSDWebSite" -PhysicalPath $MDTPath
			if($VirtualDirectoryResults){
				Write-PSDInstallLog -Message "Succesfully created the Virtual Directory $($VirtualDirectoryResults.Name) this drive maps to $($VirtualDirectoryResults.PhysicalPath)"
			}
			Write-PSDInstallLog -Message "Now enabling WebDav"
			Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site/PSDWebSite' -filter "system.webServer/webdav/authoring" -name "enabled" -value "True"
			Write-PSDInstallLog -Message "Now attempting to create the Mime Tops"
			$MimeREsults = Add-WebConfigurationProperty -PSPath 'IIS:\Sites\Default Web Site\PSDWebsite' -Filter "system.webServer/staticContent" -Name "." -Value @{ fileExtension='.*'; mimeType='Text/Plain'}
			if($MimeREsults){
				Write-PSDInstallLog -Message "Succesfully created the Mime Type"
			}
			Write-PSDInstallLog -Message "Enabling the Directory browsing"
			set-WebConfigurationProperty -filter /system.webServer/directoryBrowse -name enabled -PSPath 'IIS:\Sites\Default Web Site\PSDWebSite' -Value $true
			Write-PSDInstallLog -Message "Directory browsing has been enabled for the PSDWebsite"
			Write-PSDInstallLog -Message "Enabling WebDav Authoring Rules"
			$filter = '/system.webServer/webdav/authoringRules' 
			$location = 'IIS:\Default Web Site\PSDWebsite'
			#Cycle through and use this variable instead for locations in the future.
			$accessRule = @{
  			users  = '*'
  			path   = '*'
			access = 'Read,Source'
			}
			$WebDavAuthoring = Add-WebConfigurationProperty -Filter $filter -Location $location -Name '.' -Value $accessRule
			if($WebDavAuthoring){
				Write-PSDInstallLog -Message "Configured WebDav Rules"
			}
			Write-PSDInstallLog -Message "Now configuring security settings for authentication"
			#Written using ScriptGenerator from IIS
			Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site/PSDWebSite' -filter "system.webServer/security/authentication/anonymousAuthentication" -name "enabled" -value "False"
			#Written Using Script Generator from IIS
			Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site/PSDWebSite' -filter "system.webServer/security/authentication/windowsAuthentication" -name "enabled" -value "True"
			#Setting WebDav Settings
			Write-PSDInstallLog -Message "Setting WEBDavSettings"
			Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site/PSDWebSite' -filter "system.webServer/webdav/authoringRules" -name "defaultMimeType" -value "text/xml"
			Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site/PSDWebSite' -filter "system.webServer/webdav/authoring/properties" -name "allowInfinitePropfindDepth" -value "True"
			Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site'  -filter "system.webServer/security/requestFiltering/fileExtensions" -name "allowUnlisted" -value "False"
            Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site'  -filter "system.webServer/security/requestFiltering/verbs" -name "allowUnlisted" -value "False"
			$hiddenSegments = Get-IISConfigSection -CommitPath 'Default Web Site' -SectionPath 'system.webServer/security/requestFiltering' | Get-IISConfigElement -ChildElementName 'hiddenSegments'
			Set-IISConfigAttributeValue -ConfigElement $hiddenSegments -AttributeName 'applyToWebDAV' -AttributeValue $false
			


		}
		if(!(Test-Path -Path $MDTPath)){
			invoke-IISConfiguration
		}
		
	}
	Catch{
		Write-PSDInstallLog -Message "Something went wrong" -LogLevel 3
	}
#Endregion ConfigurationFunctions
############################################
}

}


process{
############################################
#region InstallActions
set-PSDDefaultLogPath
Write-PSDInstallLog -Message "The Script is currently running on $($ENV:COMPUTERNAME) and was targeted to run against $($ComputerName)"
Write-PSDInstallLog -Message "Upon completion several roles will be installed upon $($ComputerName)"
Write-PSDInstallLog -Message "Completed initilization of all pre-written functions. Now documenting running environment"
Write-PSDInstallLog -Message "The Script was executed with commands: $($MyInvocation.Line)"
Write-PSDInstallLog -Message "The Current running computer is: $($ENV:COMPUTERNAME.ToUpper())"
Write-PSDInstallLog -Message "The Current user is $($ENV:USERNAME)"
$NetworkSettings = get-PSDNetworkConfiguration
Write-PSDInstallLog -Message "The EXECUTING SERVER $($ENV:COMPUTERNAME.ToUpper()) Network information is:"
foreach($Setting in $NetworkSettings){
	Write-PSDInstallLog -Message "$($ENV:COMPUTERNAME.ToUpper()) - Profile - $($Setting.NetProfile)"
	Write-PSDInstallLog -Message "$($ENV:COMPUTERNAME.ToUpper()) - IPv4 Ad - $($Setting.IPv4Address)"
	Write-PSDInstallLog -Message "$($ENV:COMPUTERNAME.ToUpper()) - IPv6 AD - $($Setting.IPv6Address)"
	Write-PSDInstallLog -Message "$($ENV:COMPUTERNAME.ToUpper()) - DNS Ser - $($Setting.DNSServer)"
}
Write-PSDInstallLog -Message "Now validating that we can still connect to the target server $($ComputerName)"
if(!(Test-PSDConnectivity -ComputerName $ComputerName)){
	Write-PSDInstallLog -Message "Cannot reach the target computer $($ComputerName) now exiting" -LogLevel 3
	break
}
$TargetServerNetworkSettings = (Invoke-Command -HideComputerName -ComputerName $ComputerName -ScriptBlock ${Function:get-PSDNetworkConfiguration})
Write-PSDInstallLog -Message "The TARGET SERVER $($COMPUTERNAME.ToUpper()) Network information is:"
foreach($Setting in $TargetServerNetworkSettings){
	Write-PSDInstallLog -Message "$($COMPUTERNAME.ToUpper()) - Profile - $($Setting.NetProfile)"
	Write-PSDInstallLog -Message "$($COMPUTERNAME.ToUpper()) - IPv4 Ad - $($Setting.IPv4Address)"
	Write-PSDInstallLog -Message "$($COMPUTERNAME.ToUpper()) - IPv6 AD - $($Setting.IPv6Address)"
	Write-PSDInstallLog -Message "$($COMPUTERNAME.ToUpper()) - DNS Ser - $($Setting.DNSServer)"
}
#Block an unallowed action
if(($Install -and $Configure) -and !($Allowreboot))
{
	Write-PSDInstallLog -Message "Error - you canot run the install and configure command together without allowing a reboot" -LogLevel 3
	break
}



if($Install){
if(!(Test-PSDConnectivity -ComputerName $ComputerName) -or (Test-PSDRoleInstalled -RoleName "WEB-Server" -ComputerName $ComputerName)){
	Write-Error -Message "A connection test failed validate which connnection test failed in the LogFile and remediate nothing was attempted to install at this time."
	if(Test-PSDRoleInstalled -RoleName "WEB-Server" -ComputerName $ComputerName){
		Write-PSDInstallLog -Message "The installation failed because IIS was already installed and we don't want to break an existing installation" -LogLevel 3
	}
    break
}
write-PSDInstallLog -Message "The server is available and does NOT have IIS installed. Now preparing to install IIS" 
try{
    $IISResults = Install-WindowsFeature -Name Web-Server -ComputerName $ComputerName -Verbose:$false
    if($IISResults.Success){
        write-PSDInstallLog -Message "Succesfully installed the IIS install with Exit Code $($IISResults.ExitCode) and Value $($IISResults.ExitCode.Value__)"
	}
	Write-PSDInstallLog -Message "Now attempting to install other required IIS Features"
	#ToDO make this a proper hash table/list to explain info next to it at the end and evaluate or to allow install ALL sub features
	$Featurelist = @("Web-Custom-Logging","Web-Log-Libraries","Web-Request-Monitor","Web-Http-Tracing","Web-Security","Web-Filtering","Web-Basic-Auth","Web-Digest-Auth","Web-Url-Auth","Web-Windows-Auth","Web-Mgmt-Console","Web-Metabase")
	$FeatureResults = Install-WindowsFeature -Name "Web-Common-Http" -ComputerName $ComputerName -Verbose:$false -IncludeAllSubFeature
	write-PSDInstallLog -Message "Installed the Common HTTP Features with Exit Code $($IISHTTPCommon.ExitCode) and Value $($IISHTTPCommon.ExitCode.Value__)"
	foreach($Feature in $Featurelist){
		Write-PSDInstallLog -Message "Now attempting to install $($Feature)"
		$FeatureResults = $null
		$FeatureResults = Install-WindowsFeature -Name $Feature -ComputerName $ComputerName -Verbose:$false
		write-PSDInstallLog -Message "Installed the $Feature with Exit Code $($FeatureResults.ExitCode) and Value $($FeatureResults.ExitCode.Value__)"
	}
    $WEBDAVResults = Install-WindowsFeature -Name "WebDav-Redirector" -ComputerName $ComputerName -Verbose:$false
    if($WEBDAVResults.Success){
        write-PSDInstallLog -Message "Completed the installation of the WEBDAV-FEature on $($ComputerName) and Value $($WEBDAVResults.ExitCode.Value__)"
        if($WEBDAVResults.ExitCode.Value__ -eq "3010"){
			write-PSDInstallLog -Message "The  server $($ComputerName) requires a reboot to finalize the WebDav installation"
			if($Allowreboot){
				Write-PSDInstallLog -Message "A Reboot for $ComputerName was approved at the run of the scriptpt"
				if($ENV:COMPUTERNAME -eq $ComputerName){
					Write-PSDInstallLog -Message "Validated that the computer running the script $($ENV:COMPUTERNAME) IS the same as the target computer $($ComputerName)" -LogLevel 2
					Restart-Computer -ComputerName $ComputerName -Force -Confirm
				}
				if($ENV:COMPUTERNAME -ne $ComputerName){
					Write-PSDInstallLog -Message "Validated that the computer running the script $($ENV:COMPUTERNAME) is NOT the same as the target computer $($ComputerName)" -LogLevel 2
					Restart-Computer -ComputerName $ComputerName -Wait -Force -Confirm
					if($Configure){
						$ConfigureResults = (Invoke-Command -HideComputerName -ComputerName $ComputerName -ScriptBlock ${Function:invoke-IISConfiguration})
						Write-PSDInstallLog -Message "Completed the process for all selected flags now exiting"
						exit 0
					}
				}
			}
			elseif (!($AllowReboot)){
				Write-PSDInstallLog -Message "The server $($Comptuername) was NOT allowed to reboot. You must reboot the server and re-run the script with the -Configure Flag" -LogLevel 2
				break
			}   
        }
    }
}
catch{
    write-PSDInstallLog -Message "Something went wrong on line $($_.Exception.InvocationInfo.ScriptLineNumber) the error message was: $($_.Exception.Message)" -LogLevel 3
}
}

if($Configure){
	if($ComputerName -ne $ENV:COMPUTERNAME){
		$ConfigureResults = (Invoke-Command -HideComputerName -ComputerName $ComputerName -ScriptBlock ${Function:invoke-IISConfiguration})
		Write-PSDInstallLog -Message "Completed the process for all selected flags now exiting"
		exit 0
	}
	else{
		invoke-IISConfiguration
	}
}
#endregion InstallActions
############################################	
}



