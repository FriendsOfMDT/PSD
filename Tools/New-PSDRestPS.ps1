<#
    .SYNOPSIS
        This script will install RestPS as a service

    .DESCRIPTION
        This script will install RestPS as a service

    .PARAMETER RestPSRootPath
        The path to the RestPS root folder

    .PARAMETER PathtoNSSMexe
        The path to the NSSM.exe

    .PARAMETER RestPSListenerPort
        The port that RestPS will listen on. default is 8080

    .PARAMETER SecretKey
        The secret key for RestPS

    .PARAMETER CertificateFriendlyName
        The friendly name of the certificate

    .PARAMETER Test
        Test the RestPS service

    .EXAMPLE
        .\New-PSDRestPS.ps1 -RestPSRootPath "C:\RestPS" -PathtoNSSMexe "C:\NSSM\nssm.exe" -RestPSListenerPort 8080 -SecretKey "SuperSecret" -CertificateFriendlyName "RestPS"

    .EXAMPLE
        .\New-PSDRestPS.ps1 -RestPSRootPath "C:\RestPS" -PathtoNSSMexe "C:\NSSM\nssm.exe" -RestPSListenerPort 8080 -SecretKey "SuperSecret" -CertificateFriendlyName "RestPS" -Test

    .LINK
        https://github.com/FriendsOfMDT/PSD

    .NOTES
        FileName: New-PSDRestPS.ps1
        Solution: PowerShell Deployment for MDT
        Author: PSD Development Team
        Contact: @Mikael_Nystrom , @jarwidmark
        Primary: @jarwidmark 
        Created: 2019-05-09
        Modified: 2025-01-19

        Version - 0.0.0 - () - Finalized functional version 1.
        Version - 0.0.1 - (@PowerShellCrack) - Cleaned up Synopsys and made parameters mandatory instead of checks. Fixed missed spelled words and added blocks for cleaner code.

#>

#Requires -RunAsAdministrator

## =========================================================================================
## PARAMETER DECLARATION
## =========================================================================================

[CmdLetBinding(DefaultParameterSetName='PreloadedCert')]
Param(
    [Parameter(Mandatory=$true,HelpMessage = "REQUIRED: Specify the path to the RestPS root folder")]
    $RestPSRootPath,
        
    [Parameter(Mandatory=$true,HelpMessage = "REQUIRED: Specify the path to the NSSM.exe")]
    $PathtoNSSMexe,

    [Parameter(Mandatory=$false,HelpMessage = "OPTIONAL: Specify the port that RestPS will listen on. default is 8080")]
    [int]$RestPSListenerPort = '8080',

    [Parameter(ParameterSetName='PreAuth',Mandatory=$true,HelpMessage = "REQUIRED: Specify the secret key for RestPS")]
    $SecretKey,

    [Parameter(ParameterSetName='PreloadedCert',Mandatory=$true,HelpMessage = "REQUIRED: Specify the friendly name of the server certificate")]
    $ServerCertFriendlyName,

    [Parameter(ParameterSetName='PreloadedCert',Mandatory=$true,HelpMessage = "REQUIRED: Specify the friendly name of the client certificate")]
    $ClientCertFriendlyName,

    [Parameter(ParameterSetName='GenSelfSignedCert',Mandatory=$false,HelpMessage = "OPTIONAL: Generate a self-signed certificate")]
    [switch]$GenSelfSignedCert,

    [Parameter(ParameterSetName='GenSelfSignedCert',Mandatory=$true,HelpMessage = "OPTIONAL: Test the RestPS service")]
    $psDeploymentFolder,

    [Parameter(Mandatory=$false,HelpMessage = "OPTIONAL: Test the RestPS service")]
    [Switch]$Test
)

## =========================================================================================
## FUNCTION HELPERS
## =========================================================================================
Function Test-PSDModule{
    [CmdLetBinding()]
    Param(
        $Name
    )
    If((Get-Module -ListAvailable $Name).count -eq 1){
        Return $true
    }
    else{
        Return $false
    }
}

Function Set-PSDRestPS{
    [CmdLetBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $RestPSRootPath,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $PathtoNSSMexe,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $RestPSListenerPort,

        $CertificateFriendlyName
    )

    $RestPSRootPath = $RestPSRootPath.TrimEnd("\")

    if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
        $VerbosePreference = "Continue"
    }
    Write-Verbose "Verbose is on"

    #check if RestPS module is installed, if not install it
    If((Test-PSDModule -Name RestPS ) -eq $false){
        Write-Warning "The RestPS module is not installed, installing it now..."
        Install-Module RestPS -Force
    }

    $Folder = ($RestPSRootPath | Split-Path)
    if((Test-Path -Path $Folder) -ne $true){
        Write-Warning "Unable to access $Folder. Make sure the folder exists"
        Write-Warning "Will exit"
        Return
    }

    if((Test-Path -Path $PathtoNSSMexe) -ne $true){
        Write-Warning "Unable to access NSSM.exe. Download it from https://nssm.cc/download"
        Write-Warning "Will exit"
        Return
    }

    # Import Module
    Import-Module RestPS -Force

    # Initual Configuration
    Invoke-DeployRestPS -LocalDir $RestPSRootPath

    # Fix the routes
    $RestPSRootPathW = $RestPSRootPath.Replace("\","/")
    (Get-Content -Path "$RestPSRootPath\endpoints\RestPSRoutes.json").Replace("c:/RestPS","$RestPSRootPathW") | Out-File -FilePath "$RestPSRootPath\endpoints\RestPSRoutes.json" -Encoding ascii

    # New Service ConfigFolder
    New-Item -Path "$RestPSRootPath\Service" -ItemType Directory -Force

    #create a guid for the app
    $AppGuid = [guid]::NewGuid().ToString()
    #$AppGuid = '12345678-db90-4b66-8b01-88f7af2e36ca'

    # Create Service script
    $ScriptPath = "$RestPSRootPath\Service\StartRestPS.ps1"
    Set-Content -Path $ScriptPath -Value "Start-Transcript -Path $RestPSRootPath\Service\Start.log"
    Add-Content -Path $ScriptPath -Value "`$ServerCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {`$_.FriendlyName -eq `"$CertificateFriendlyName`"}"
    Add-Content -Path $ScriptPath -Value "Write-Output `"Certificate Thumbprint: `$(`$ServerCert.Thumbprint)`""
    Add-Content -Path $ScriptPath -Value "Import-Module RestPS -Force"
    Add-Content -Path $ScriptPath -Value "`$ServerParams = @{"
    Add-Content -Path $ScriptPath -Value "  RoutesFilePath = `"$RestPSRootPath\endpoints\RestPSRoutes.json`""
    Add-Content -Path $ScriptPath -Value "  Port = `"$RestPSListenerPort`""
    Add-Content -Path $ScriptPath -Value "  SSLThumbprint = `"`$(`$ServerCert.Thumbprint)`""
    Add-Content -Path $ScriptPath -Value "  AppGuid = '$AppGuid'"
    Add-Content -Path $ScriptPath -Value "  VerificationType = 'VerifyRootCA'"
    Add-Content -Path $ScriptPath -Value "  Logfile = `"$RestPSRootPath\Service\RestPS.log`""
    Add-Content -Path $ScriptPath -Value "  LogLevel = `"ALL`""
    Add-Content -Path $ScriptPath -Value "  RestPSLocalRoot = `"$RestPSRootPath`""
    Add-Content -Path $ScriptPath -Value "}"
    Add-Content -Path $ScriptPath -Value "Start-RestPSListener @ServerParams"
    Add-Content -Path $ScriptPath -Value "Stop-Transcript"

    # Make RestPS a Service
    $PoShPath = (Get-Command powershell).Source

    $NewServiceName = "RestPS"
    $PoShScriptPath = "$RestPSRootPath\Service\StartRestPS.ps1"
    $Arguments = '-ExecutionPolicy Bypass -NoProfile -File "{0}"' -f $PoShScriptPath

    & $PathtoNSSMexe install $NewServiceName $PoShPath $Arguments
    & $PathtoNSSMexe status $NewServiceName
    & $PathtoNSSMexe dump $NewServiceName
    
    # Change the name of the Services
    & $PathtoNSSMexe set $NewServiceName description "RestFul API Services"

    # Start the Services
    Get-Service -Name RestPS | Start-Service
}

Function Test-PSDRestPS{
    Param(
        $ClientCert,
        $RestPSListenerPort
    )
    If($ClientCert){
        Disable-SSLValidation
        $result = Invoke-RestMethod -Uri "https://localhost:$RestPSListenerPort/process?name=powershell" -Method Get -UseBasicParsing -Certificate $ClientCert
    }
    else{
        $result = Invoke-RestMethod -Uri "http://localhost:$RestPSListenerPort/process?name=powershell" -Method Get -UseBasicParsing
    }
    
    if(($result.ProcessName) -eq "powershell"){
        Return $true
    }
    else{
        Return $false
    }
}
Function New-PSDAuthList{
    Param(
        $Path,
        $SecretKey
    )

    $UserAuth = @{
        UserData = @(
                @{
                    UserName         = 'PSDClient'
                    SystemAuthString = "$SecretKey"
                }
            )
        }
    $UserAuth | Export-Clixml -Path $Path -Force
}

Function New-PSDGetRestUserAuthFile{
    Param(
        $RestPSPath
    )
    
    $RestPSPath = $RestPSPath.TrimEnd("\")

    $Path = "$RestPSPath\Bin\Get-RestUserAuth.ps1"
    
    Set-Content -Path $path -Value "function Get-RestUserAuth {"
    Add-Content -Path $path -Value "    `$UserAuth = Import-Clixml -Path $RestPSPath\Service\Auth.usr"
    Add-Content -Path $path -Value "    `$UserAuth"
    Add-Content -Path $path -Value "}"
}

## =========================================================================================
## MAIN LOGIC
## ========================================================================================
If($GenSelfSignedCert){
    #Create the root Certificate
    $rootCAparams = @{
        DnsName = 'RestPS.Root.local'
        KeyLength = 2048
        KeyAlgorithm = 'RSA'
        HashAlgorithm = 'SHA256'
        KeyExportPolicy = 'Exportable'
        NotAfter = (Get-Date).AddYears(5)
        CertStoreLocation = 'Cert:\LocalMachine\My'
        KeyUsage = 'CertSign','CRLSign' #fixes invalid certificate error
    }
    $rootCA = New-SelfSignedCertificate @rootCAparams

    #Add/Import the new RootCA to the ‘Root’ Certificate Store
    $CertStore = New-Object -TypeName `
    System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::Root,
    'LocalMachine')
    $CertStore.open('MaxAllowed')
    $CertStore.add($rootCA)
    $CertStore.close()


    #Creating the Server certificate:
    $params = @{
        FriendlyName = 'RestPS Server Cert'
        DnsName = 'Server.RestPS.local'
        Signer = $rootCA # &amp;amp;amp;amp;amp;lt;------ Notice the Signer is the newly created RootCA
        KeyLength = 2048
        KeyAlgorithm = 'RSA'
        HashAlgorithm = 'SHA256'
        KeyExportPolicy = 'Exportable'
        NotAfter = (Get-Date).AddYears(2)
        CertStoreLocation = 'Cert:\LocalMachine\My'
    }
    $ServerCert = New-SelfSignedCertificate @params

    #Creating the Client Certificate:
    $params = @{
        FriendlyName = 'RestPS Client Cert'
        DnsName = 'Client.RestPS.local'
        Signer = $rootCA # &amp;amp;amp;amp;lt;------ Notice the Signer is the newly created RootCA
        KeyLength = 2048
        KeyAlgorithm = 'RSA'
        HashAlgorithm = 'SHA256'
        KeyExportPolicy = 'Exportable'
        NotAfter = (Get-Date).AddYears(2)
        CertStoreLocation = 'Cert:\LocalMachine\My'
    }
    $ClientCert = New-SelfSignedCertificate @params

    Get-item Cert:\LocalMachine\My\$($rootCA.Thumbprint) | Export-Certificate -Type CERT -FilePath $
    #remove cert from my store
    Get-item Cert:\LocalMachine\My\$($rootCA.Thumbprint) | Remove-Item -Force

    #Build the RestPS start script
    Set-PSDRestPS -RestPSRootPath $RestPSRootPath -PathtoNSSMexe $PathtoNSSMexe -RestPSListenerPort $RestPSListenerPort -CertificateFriendlyName "RestPS Server Cert"

}Else{
    #Build the RestPS start script
    Set-PSDRestPS -RestPSRootPath $RestPSRootPath -PathtoNSSMexe $PathtoNSSMexe -RestPSListenerPort $RestPSListenerPort -CertificateFriendlyName $ServerCertFriendlyName
}



if($Test){
    If($GenSelfSignedCert){
        $ClientCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.FriendlyName -eq "RestPS Client Cert"}
    }
    else{
        $ClientCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.FriendlyName -eq $ClientCertFriendlyName}
    }
    $result = Test-PSDRestPS -RestPSListenerPort $RestPSListenerPort -ClientCert $ClientCert

    switch ($result)
    {
        'True' {
            Write-Output "RestPS seems to be working"
        }
        'False' {
            Write-Output "RestPS does not work"
        }
        Default {
            Write-Output "RestPS does not work"
        }
    }
}
