<#
    .SYNOPSIS
        This script is responsible for configuring the IIS components for the PSD log files.

    .DESCRIPTION
        This script is responsible for configuring the IIS components for the PSD log files. This script will create a virtual directory in IIS and configure the security settings for the virtual directory.

    .PARAMETER psLogFolder
        The path to the folder where the logs will be stored.

    .PARAMETER psVirtualLogDirectory
        The name of the virtual directory that will be created in IIS.

    .EXAMPLE
        PS> .\Set-PSDLogInstance.ps1 -psLogFolder "E:\PSDProductionLogs" -psVirtualLogDirectory "PSDLogs"

    .LINK
        https://github.com/FriendsOfMDT/PSD

    .NOTES
        FileName:   Set-PSDLogInstance.ps1
        Author:     Jordan Benzing
        Contact:    @JordanTheITGuy
        Created:    2019-04-15
        Updated:    2025-01-19
        
        Version - 0.0.0 - () - Finalized functional version 1.
        Version - 0.0.1 - (@PowerShellCrack) - Cleaned up Synopsis and update help on parameters for more clarity. Fixed missed spelled words and added blocks for cleaner code.

        TODO: 
        Disable Anonymous
        Enable Windows Auth
        Enable Dir Browse

    #>

#Requires -RunAsAdministrator

## =========================================================================================
## PARAMETER DECLARATION
## =========================================================================================
[CmdletBinding()]
param(
	[Parameter(Mandatory=$True,HelpMessage = "REQUIRED: Specify the MDT Share Path. This is the path used in the IIS virtual directory")]
	[Alias("psDeploymentFolder")]
    [string]$psLogFolder,

	[parameter(Mandatory=$True,HelpMessage = "REQUIRED: Specify the NAME of the PSD. This will create a IIS virtual directory")]
	[Alias("psVirtualDirectory")]
    [string]$psVirtualLogDirectory
)


## =========================================================================================
## FUNCTION HELPERS
## =========================================================================================
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
            throw [System.IO.DriveNotFoundException] "An Error occurred with detecting the roles installation state"
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
function Set-PSDDefaultLogPath{
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
Function New-PSDLogWeb {
    Param(
        $Path,
        $Name
    )

    $null = Add-WindowsFeature BITS-IIS-Ext

    [system.reflection.assembly]::loadwithpartialname("System.DirectoryServices.dll")

    $null = New-Item -Path $Path -ItemType Directory -Force

    $VirtualDirectory = New-WebVirtualDirectory -Name "$Name" -Site "Default Web Site" -PhysicalPath "$Path"
    $Name = $VirtualDirectory.Name
    $ADSIVirtualDirectory = New-Object System.DirectoryServices.DirectoryEntry("IIS://localhost/W3SVC/1/root/$Name")

    $ADSIVirtualDirectory.EnableBitsUploads()

    $ADSIVirtualDirectory.BITSMaximumUploadSize = 250MB
    $ADSIVirtualDirectory.BITSSessionTimeout = $(12 * 3600)
    $ADSIVirtualDirectory.BITSAllowOverwrites = 1
    $ADSIVirtualDirectory.SetInfo()

}

#Endregion ConfigurationFunctions
############################################

##=========================================================================================
## MAIN LOGIC
##=========================================================================================

# Set VerboseForegroundColor
$host.PrivateData.VerboseForegroundColor = 'Cyan'

############################################
#region StartUpChecks
Set-PSDDefaultLogPath

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

$null = New-Item -Path $psLogFolder -ItemType Directory -Force

Write-PSDInstallLog -Message "Now configuring the IIS for the MDT Logs at $($psLogFolder) with $($PSWebsite)"
New-PSDLogWeb -Path $psLogFolder -Name $psVirtualLogDirectory


#Written using ScriptGenerator from IIS
Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/security/authentication/anonymousAuthentication" -name "enabled" -value "False"

#Written Using Script Generator from IIS
Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location "Default Web Site/$($psVirtualDirectory)" -filter "system.webServer/security/authentication/windowsAuthentication" -name "enabled" -value "True"


#endregion ConfigureActions
############################################

############################################
#region ShutdownChecks
$EndTime = Get-Date
$Duration = New-TimeSpan -Start $StartTime -End $EndTime
Write-PSDInstallLog -Message "The script has completed running and took $($Duration.Hours) Hours and $($Duration.Minutes) Minutes and $($Duration.Seconds) seconds"
#endregion ShutdownChecks
############################################

Write-Verbose -Verbose -Message "The script has completed"

