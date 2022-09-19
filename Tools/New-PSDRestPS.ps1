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

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $SecretKey,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $CertificateFriendlyName,

    [Switch]$Test
)

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


    $Folder = ($RestPSRootPath | Split-Path)
    if((Test-Path -Path $Folder) -ne $true){
        Write-Warning "Unable to access $Folder"
        Write-Warning "Will exit"
        Return
    }

    if((Test-PSDModule -Name RESTPS) -ne $true){
        Write-Warning "The RESTPS Module is not installed, please install"
        Write-Warning "Will exit"
        Return
    }

    if((Test-Path -Path $PathtoNSSMexe) -ne $true){
        Write-Warning "Unable to access NSSM.exe"
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

    # Create Service script
    $ScriptPath = "$RestPSRootPath\Service\StartRestPS.ps1"
    Set-Content -Path $ScriptPath -Value "Start-Transcript -Path $RestPSRootPath\Service\Start.log"
    Add-Content -Path $ScriptPath -Value "`$ServerCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {`$_.FriendlyName -eq `"$CertificateFriendlyName`"}"
    Add-Content -Path $ScriptPath -Value "Import-Module RESTPS -Force"
    Add-Content -Path $ScriptPath -Value "`$ServerParams = @{"
    Add-Content -Path $ScriptPath -Value "RoutesFilePath = `"$RestPSRootPath\endpoints\RestPSRoutes.json`""
    Add-Content -Path $ScriptPath -Value "Port = `"$RestPSListenerPort`""
    Add-Content -Path $ScriptPath -Value "SSLThumbprint = `"`$(`$ServerCert.Thumbprint)`""
    Add-Content -Path $ScriptPath -Value "AppGuid = '12345678-db90-4b66-8b01-88f7af2e36ca'"
    Add-Content -Path $ScriptPath -Value "VerificationType = 'VerifyUserAuth'"
    Add-Content -Path $ScriptPath -Value "Logfile = `"$RestPSRootPath\Service\RestPS.log`""
    Add-Content -Path $ScriptPath -Value "LogLevel = `"ALL`""
    Add-Content -Path $ScriptPath -Value "RestPSLocalRoot = `"$RestPSRootPath`""
    Add-Content -Path $ScriptPath -Value "}"
    Add-Content -Path $ScriptPath -Value "Start-RestPSListener @ServerParams"
    Add-Content -Path $ScriptPath -Value "Stop-Transcript"

    # Make RestPS a Service
    $PoShPath = (Get-Command powershell).Source

    $NewServiceName = "RestPS"
    $PoShScriptPath = "$RestPSRootPath\Service\StartRestPS.ps1"
    $Arguments = ‘-ExecutionPolicy Bypass -NoProfile -File "{0}"‘ -f $PoShScriptPath

    & $PathtoNSSMexe install $NewServiceName $PoShPath $Arguments
    & $PathtoNSSMexe status $NewServiceName
    & $PathtoNSSMexe dump $NewServiceName
    
    # Change the name of the Services
    & $PathtoNSSMexe set $NewServiceName description “RestFul API Services”

    # Start the Services
    Get-Service -Name RestPS | Start-Service
}
Function Test-PSDRestPS{
    Param(
        $RestPSListenerPort
    )
    $result = Invoke-RestMethod -Uri http://localhost:$RestPSListenerPort/process?name=powershell -Method Get -UseBasicParsing
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


Set-PSDRestPS -RestPSRootPath $RestPSRootPath -PathtoNSSMexe $PathtoNSSMexe -RestPSListenerPort $RestPSListenerPort -CertificateFriendlyName $CertificateFriendlyName
if($Test){
    $result = Test-PSDRestPS -RestPSListenerPort $RestPSListenerPort

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
