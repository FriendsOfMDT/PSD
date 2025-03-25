<#
    .SYNOPSIS
        This script creates a self-signed web certificate for PSD
        
    .DESCRIPTION
        This script creates a self-signed web certificate for PSD

    .PARAMETER DNSName
        The DNS name for the certificate.

    .PARAMETER FriendlyName
        The friendly name for the certificate.

    .PARAMETER ValidityPeriod
        The validity period for the certificate.

    .PARAMETER RootCACertFriendlyName
        The friendly name of the root CA certificate.

    .EXAMPLE
        .\New-PSDServerCert.ps1 -DNSName psddev.network.local -FriendlyName psddev.network.local -ValidityPeriod 15 -RootCACertFriendlyName PSDRootCA

    .EXAMPLE
        .\New-PSDServerCert.ps1 -DNSName psddev.network.local -FriendlyName psddev.network.local -RootCACertFriendlyName PSDRootCA

    .LINK
        https://github.com/FriendsOfMDT/PSD

    .NOTES
            FileName: New-PSDSelfSignedCert.ps1
            Solution: PowerShell Deployment for MDT
            Author: PSD Development Team
            Created: 2019-05-09
            Modified: 2025-01-19

            Version - 0.0.0 - () - Finalized functional version 1.
            Version - 0.0.1 - (@PowerShellCrack) - Cleaned up Synopsis and made parameters mandatory instead of N/A checks. Fixed missed spelled words and added blocks for cleaner code.

    #>

#Requires -RunAsAdministrator

## =========================================================================================
## PARAMETER DECLARATION
## =========================================================================================
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,HelpMessage = "REQUIRED: Specify the DNS name for the certificate")]
    [string]$DNSName,

    [Parameter(Mandatory=$True,HelpMessage = "REQUIRED: Specify the Friendly name for the certificate")]
    [string]$FriendlyName,

    [Parameter(Mandatory=$False,HelpMessage = "OPTIONAL: Specify the validity period for the certificate. default is 10 years")]
    [int]$ValidityPeriod = 10,

    [Parameter(Mandatory=$True,HelpMessage = "REQUIRED: Specify the friendly name of the root CA certificate. Run New-PSDRootCACert.ps1 first to create a root CA certificate")]
    [string]$RootCACertFriendlyName
)

## =========================================================================================
## FUNCTION HELPERS
## =========================================================================================
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

## =========================================================================================
## MAIN LOGIC
## =========================================================================================
# Set VerboseForegroundColor
$host.PrivateData.VerboseForegroundColor = 'Cyan'

# Start logging
Set-PSDDefaultLogPath

# Get the PSD root CA Certificate
$PSDRootCACert = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.FriendlyName -eq $RootCACertFriendlyName}

# Create self-signed certificate
Write-PSDInstallLog -Message "Creating Self-signed Certificate"
Write-PSDInstallLog -Message "Certificate FriendlyName: $FriendlyName"
Write-PSDInstallLog -Message "Certificate DNSName: $DNSName"
Write-PSDInstallLog -Message "Certificate Path: Cert:Localmachine\My"
Write-PSDInstallLog -Message "Certificate valid until: $ValidityPeriodDate
"
Write-PSDInstallLog -Message "Using $RootCACertFriendlyName as signing cert"

$params = @{
  DnsName = $DNSName
  Signer = $PSDRootCACert
  KeyLength = 2048
  KeyAlgorithm = 'RSA'
  HashAlgorithm = 'SHA256'
  KeyExportPolicy = 'Exportable'
  NotAfter = (Get-Date).AddYears($ValidityPeriod)
  CertStoreLocation = 'Cert:\LocalMachine\My'
  FriendlyName = $FriendlyName
}

$cert = New-SelfSignedCertificate @params

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
# Write-PSDInstallLog -Message "Export Self-signed Certificate"
# Write-PSDInstallLog -Message "Export path: $psDeploymentFolder\PSDResources\Certificates\PSDCert.cer"
# Export-Certificate -Cert $cert -FilePath "$psDeploymentFolder\PSDResources\Certificates\PSDCert.cer" | Out-Null
$CurrentLocation | Set-Location

Write-Verbose -Verbose -Message "The script has completed"