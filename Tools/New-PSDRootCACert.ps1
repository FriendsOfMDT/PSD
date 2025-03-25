<#
    .SYNOPSIS
        This script creates a self-signed root certificate for PSD
        
    .DESCRIPTION
        This script creates a self-signed root certificate for PSD

    .EXAMPLE
        .\New-PSDRootCACert.ps1 -RootCAName PSDRootCA -ValidityPeriod 20 -psDeploymentFolder E:\PSDeploymentShare

    .LINK
        https://github.com/FriendsOfMDT/PSD

    .NOTES
        FileName: New-PSDSelfSignedCert.ps1
        Solution: PowerShell Deployment for MDT
        Author: PSD Development Team
        Contact: @Mikael_Nystrom , @jarwidmark
        Primary: @jarwidmark 
        Created: 2019-05-09
        Modified: 2025-01-19

        Version - 0.0.0 - () - Finalized functional version 1.
        Version - 0.0.1 - (@PowerShellCrack) -Added Synopsis and gave parameters help messages. Fixed missed spelled words and added blocks for cleaner code.
#>

#Requires -RunAsAdministrator

## =========================================================================================
## PARAMETER DECLARATION
## =========================================================================================

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,HelpMessage = "REQUIRED: Specify the name of the root CA certificate")]
    [string]$RootCAName,

    [Parameter(Mandatory=$False,HelpMessage = "OPTIONAL: Specify the validity period for the certificate. default is 20 years")]
    [int]$ValidityPeriod = 20,

    [Parameter(Mandatory=$True,HelpMessage = "REQUIRED: Specify the path to the deployment folder")]
    [string]$psDeploymentFolder
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

if((Test-Path -Path $psDeploymentFolder) -ne $true){
    Write-Warning "Unable to access $psDeploymentFolder"
    Write-Warning "Will exit"
    Return
}

$rootCAparams = @{
  DnsName = $RootCAName
  FriendlyName = $RootCAName
  KeyLength = 2048
  KeyAlgorithm = 'RSA'
  HashAlgorithm = 'SHA256'
  KeyExportPolicy = 'Exportable'
  NotAfter = (Get-Date).AddYears($ValidityPeriod)
  CertStoreLocation = 'Cert:\LocalMachine\My'
  KeyUsage = 'CertSign','CRLSign' #fixes invalid certificate error
}
$rootCA = New-SelfSignedCertificate @rootCAparams

$CertStore = New-Object -TypeName `
  System.Security.Cryptography.X509Certificates.X509Store(
  [System.Security.Cryptography.X509Certificates.StoreName]::Root,
  'LocalMachine')
$CertStore.open('MaxAllowed')
$CertStore.add($rootCA)
$CertStore.close()

# Export the Root certificate for WinPE
Write-PSDInstallLog -Message "Export Self-signed Certificate"
Write-PSDInstallLog -Message "Export path: $psDeploymentFolder\PSDResources\Certificates\PSDCert.cer"
$null = Export-Certificate -Cert $rootCA -FilePath "$psDeploymentFolder\PSDResources\Certificates\PSDCert.cer"

Write-Verbose -Verbose -Message "The script has completed"