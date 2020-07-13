<#
.Synopsis
    This script creates a self-signed certificate for PSD
    
.Description
    This script was written by Johan Arwidmark @jarwidmark and Mikael Nystrom @mikael_nystrom. This script is for the friends of MDT deployment tools 
    and is responsible for creating a self-signed certificate.

.LINK
    https://github.com/FriendsOfMDT/PSD

.NOTES
          FileName: New-PSDSelfSignedCert.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark
          Primary: @jarwidmark 
          Created: 2019-05-09
          Modified: 2020-07-03

          Version - 0.0.0 - () - Finalized functional version 1.

.EXAMPLE
	.\New-PSDSelfSignedCert.ps1 -DNSName mdt01.viamonstra.com -FriendlyName PSDCert -ValidityPeriod 5 -psDeploymentFolder E:\PSDProduction
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
Param(
    [string]$DNSName = "NA",
    [string]$FriendlyName = "NA",
    [int]$ValidityPeriod = "NA",
    [string]$psDeploymentFolder = "NA"
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
function Copy-PSDFolder{
    param (
        [Parameter(Mandatory=$True,Position=1)]
        [string] $source,
        [Parameter(Mandatory=$True,Position=2)]
        [string] $destination
    )

    $s = $source.TrimEnd("\")
    $d = $destination.TrimEnd("\")
    Write-Verbose "Copying folder $source to $destination using XCopy"
    & xcopy $s $d /s /e /v /y /i | Out-Null
}

# Set VerboseForegroundColor
$host.PrivateData.VerboseForegroundColor = 'Cyan'

# Start logging
set-PSDDefaultLogPath


if($DNSName -eq "NA"){
    Write-PSDInstallLog -Message "You need to specify a DNSName" -LogLevel 2
    $Fail = $True
}

if($FriendlyName -eq "NA"){
    Write-PSDInstallLog -Message "You need to specify a FriendlyName" -LogLevel 2
    $Fail = $True
}

if($ValidityPeriod -eq "NA"){
    Write-PSDInstallLog -Message "You need to specify a ValidityPeriod" -LogLevel 2
    $Fail = $True
}

if($psDeploymentFolder -eq "NA"){
    Write-PSDInstallLog -Message "You need to specify a psDeploymentFolder" -LogLevel 2
    $Fail = $True
}

if($Fail -eq $True){
    Write-PSDInstallLog -Message "Exiting" -LogLevel 2
    Exit
}

if((Test-Path -Path $psDeploymentFolder ) -eq $false){
    Write-PSDInstallLog -Message "Unable to access $psDeploymentFolder, exiting" -LogLevel 2
    Exit
}

# Create self-signed certificate
$Date = Get-Date
$ValidityPeriodDate = $Date.AddYears($ValidityPeriod)
Write-PSDInstallLog -Message "Creating Self-signed Certificate"
Write-PSDInstallLog -Message "Certificate FriendlyName: $FriendlyName"
Write-PSDInstallLog -Message "Certificate DNSName: $DNSName"
Write-PSDInstallLog -Message "Certificate Path: Cert:Localmachine\My"
Write-PSDInstallLog -Message "Certificate valid until: $ValidityPeriodDate"
$cert = New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation Cert:Localmachine\My -NotAfter $ValidityPeriodDate -FriendlyName $FriendlyName

# Create binding in IIS and add the certificate
Write-PSDInstallLog -Message "Create binding in IIS and add the certificate"
Write-PSDInstallLog -Message "Import-Module WebAdministration"
try{
    Import-Module WebAdministration -ErrorAction Stop
}
catch{
    Write-PSDInstallLog -Message "Unable to import module, exit"
    Exit
}

$CurrentLocation = Get-Location
Set-Location IIS:\SslBindings
Write-PSDInstallLog -Message "Enable https listener for IP 0.0.0.0"
try{
    New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https    
}
catch{
    Write-PSDInstallLog -Message "Unable to Enable https listener for IP 0.0.0.0" -LogLevel 2
    Write-PSDInstallLog -Message "Check if HTTPS with a SSL Certificate exist for the Default Web Site" -LogLevel 2
}

Write-PSDInstallLog -Message "Adding certificate to Default Web Site"
try{
    $Result = $cert | New-Item 0.0.0.0!443
}
catch{
    Write-PSDInstallLog -Message "Unable to Add certificate to Default Web Site" -LogLevel 2
    Write-PSDInstallLog -Message "Check if HTTPS with a SSL Certificate exist for the Default Web Site" -LogLevel 2
}

# Export the Root certificate for WinPE
Write-PSDInstallLog -Message "Export Self-signed Certificate"
Write-PSDInstallLog -Message "Export path: $psDeploymentFolder\PSDResources\Certificates\PSDCert.cer"
Export-Certificate -Cert $cert -FilePath "$psDeploymentFolder\PSDResources\Certificates\PSDCert.cer" | Out-Null
$CurrentLocation | Set-Location