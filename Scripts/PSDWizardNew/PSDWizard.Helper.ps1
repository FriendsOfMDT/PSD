<#
.SYNOPSIS
    PSDWizard Intializer File
.DESCRIPTION
    Script to initialize the new wizard content in PSD
.LINK
    PSDWizardNew.psm1
.NOTES
    FileName: PSDWizard.Helper.ps1
    Solution: PowerShell Deployment for MDT
    Purpose: Script to initialize the new wizard content in PSD
    Author: PSD Development Team
    Contact: Dick Tracy (@PowershellCrack)
    Primary: Dick Tracy (@PowershellCrack)
    Created: 2020-01-12
    Modified: 2024-05-10
    Version: 2.3.5

    SEE CHANGELOG.MD
#>
[CmdletBinding()]
param($Caller)

#region FUNCTION: Check if running in WinPE
Function Test-PSDWizardInPE{
    return Test-Path -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlset\Control\MiniNT
}
#endregion


#region FUNCTION: Test-PSDWizardInISE
Function Test-PSDWizardInISE {
    <#
    .SYNOPSIS
    Check if running in ISE
    #>
    # Set-StrictMode -Version latest
    try {
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}
#endregion

#region FUNCTION: Test-PSDWizardInVSC
Function Test-PSDWizardInVSC {
    <#
    .SYNOPSIS
        Check if running in Visual Studio Code
    #>
    if ($env:TERM_PROGRAM -eq 'vscode') {
        return $true;
    }
    Else {
        return $false;
    }
}
#endregion

#region FUNCTION: Get-PSDWizardScriptPath
Function Get-PSDWizardScriptPath {
    <#
    .SYNOPSIS
        Finds the current script path even in ISE or VSC
    .LINK
        Test-PSDWizardInVSC
        Test-PSDWizardInISE
    #>
    param(
        [switch]$Parent
    )

    Begin {}
    Process {
        Try {
            if ($PSScriptRoot -eq "") {
                if (Test-PSDWizardInISE) {
                    $ScriptPath = $psISE.CurrentFile.FullPath
                }
                elseif (Test-PSDWizardInVSC) {
                    $context = $psEditor.GetEditorContext()
                    $ScriptPath = $context.CurrentFile.Path
                }
                Else {
                    $ScriptPath = (Get-location).Path
                }
            }
            else {
                $ScriptPath = $PSCommandPath
            }
        }
        Catch {$script:PSDWizardPath
            $ScriptPath = '.'
        }
    }
    End {

        If ($Parent) {
            Split-Path $ScriptPath -Parent
        }
        Else {
            $ScriptPath
        }
    }

}
#endregion


##*========================================================================
##* VARIABLE DECLARATION
##*========================================================================
#region VARIABLES: Building paths & values
# Use function to get paths because Powershell ISE & other editors have differnt results
$ScriptPath = Get-PSDWizardScriptPath
[string]$script:PSDWizardPath = Split-Path -Path $ScriptPath -Parent
Try{
    [string]$script:PSDScriptRoot = Get-PSDContent -Content "Scripts"
    [string]$script:PSDContentPath = Get-PSDContent -Content "Control"

    If($PSDDeBug -ne $true){
        $PSDDeBug = $false
    }

    if ($PSDDeBug -eq $true) {
        Write-PSDLog -Message ("{0}: PSDWizard path is [{1}]" -f $MyInvocation.MyCommand, $script:PSDWizardPath) -LogLevel 1
        Write-PSDLog -Message ("{0}: ScriptRoot path is [{1}]" -f $MyInvocation.MyCommand, $script:PSDScriptRoot) -LogLevel 1
        Write-PSDLog -Message ("{0}: ContentRoot path is [{1}]" -f $MyInvocation.MyCommand, $script:PSDContentPath) -LogLevel 1
    }
    Write-Verbose ("{0}: PSDWizard path is [{1}]" -f $MyInvocation.MyCommand, $script:PSDWizardPath)
    Write-Verbose ("{0}: ScriptRoot path is [{1}]" -f $MyInvocation.MyCommand, $script:PSDScriptRoot)
    Write-Verbose ("{0}: ContentRoot path is [{1}]" -f $MyInvocation.MyCommand, $script:PSDContentPath)
}
Catch{
    If($Caller){
        Write-Error ("{0}: Unable to load PSD path; PSD Modules not loaded." -f $Caller)
    }Else{
        Write-Host ("{0}: Unable to load PSD path; PSD modules will load during [Invoke-PSDTestEnv]" -f $MyInvocation.MyCommand) -ForegroundColor Yellow
    }
}

Function Reset-PSDEnv{
    $MDTRegPath = "HKLM:\SOFTWARE\Microsoft\Deployment 4"
    $OrginalMDTPath = "C:\Program Files\Microsoft Deployment Toolkit\"
    Get-ItemProperty $MDTRegPath -Name Install_Dir -ErrorAction SilentlyContinue
    If((Get-ItemProperty $MDTRegPath -Name Install_Dir -ErrorAction SilentlyContinue).Install_Dir -ne $OrginalMDTPath)
    {
        Set-ItemProperty $MDTRegPath -Name "Install_Dir" -Value $OrginalMDTPath -Force
    }

    #Remove-PSDrive -Name TSEnv -ErrorAction SilentlyContinue
    #Remove-PSDrive -Name TSEnvList -ErrorAction SilentlyContinue
    Remove-PSDrive -Name DS001 -ErrorAction SilentlyContinue
    Remove-PSDrive -Name DeploymentShare -ErrorAction SilentlyContinue

    Remove-Item -Path "$global:psuDataPath\variables.dat" -Recurse -ErrorAction SilentlyContinue -Force
    Remove-Item -Path "$global:psuDataPath\Cache" -Recurse -ErrorAction SilentlyContinue -Force
    Remove-Item -Path "$PSDLocalDataPath\Cache" -Recurse -ErrorAction SilentlyContinue -Force

    Get-Module PSD* -ListAvailable | Remove-Module -Force -ErrorAction SilentlyContinue
}

Function Invoke-PSDTestEnv{
    <#
    .SYNOPSIS
        Function to test the PSD environment

    .DESCRIPTION
        Function to test the PSD environment

    .EXAMPLE
        Invoke-PSDTestEnv
    
    .EXAMPLE
        Invoke-PSDTestEnv -DeploymentShare "\\10.30.3.10\dep-psddev$"

    .EXAMPLE
        Invoke-PSDTestEnv -SimulatorScript 'C:\MDTSimulator\Start-MDTSimulator.ps1'

    .EXAMPLE
        Invoke-PSDTestEnv -Passthru
    #>
    [CmdletBinding()]
    param(
        [string]$DeploymentShare,
        [string]$SimulatorScript,
        [string]$LocalPath = 'C:\MININT',
        [string]$Theme = 'Classic',
        [switch]$NoWizard,
        [switch]$CleanUpFirst,
        [switch]$Passthru
    )

    If($DeploymentShare){
        $commands = @(
            
            "`$Global:deployRoot = `"$DeploymentShare`""
        )
    }Else{
        $commands = @(
            "`$Global:deployRoot = `"$($PSScriptRoot.Replace('\Scripts\PSDWizardNew', '').TrimEnd('\'))`""
        )
    }

    If($CleanUpFirst){
        $commands += @(
            "Reset-PSDEnv"
        )
    }

    $commands += @(
        "New-Item -Path `"$LocalPath\SMSOSD`" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null"
        "New-Item -Path `"$LocalPath\SMSOSD\OSDLOGS`" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null"
        "`$ModuleList = `$env:PSModulePath -split ';'"
        "`$ModuleList += `"`$deployRoot\Tools\Modules`""
        "`$env:PSModulePath = (`$ModuleList | Select -Unique) -join ';'"
    )
    
    If($VerbosePreference){
        $commands += @(
            "`$VerbosePreference = `$VerbosePreference"
            "`$env:PSModulePath"
        )
    }

    If(Test-Path $SimulatorScript){
        $commands += @(
            "`$MDTModule = `"C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1`""
            "Import-Module `$MDTModule -Verbose -Force"
            "`$SimulatorPath = (Split-Path `$SimulatorScript -Parent)"
            ". `"$SimulatorScript`" -MDTSimulatorPath `"`$SimulatorPath`" -DeploymentShare `"`$Global:deployRoot`" -Mode PSD -Environment VSCode"
            "If(-Not(Get-PSDrive DS001 -ErrorAction SilentlyContinue)){`$Null = New-PSDrive -Name DS001 -PSProvider MDTProvider -Root `$Global:deployRoot -Scope Global -ErrorAction Stop}"
            "If(-Not(Get-PSDrive DeploymentShare -ErrorAction SilentlyContinue)){`$Null = New-PSDrive -Name DeploymentShare -PSProvider MDTProvider -Root `$Global:deployRoot -Scope Global -ErrorAction Stop}"
            "`$global:tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment"
            "Import-Module `"`$Global:deployRoot\Tools\Modules\Microsoft.BDD.TaskSequenceModule\Microsoft.BDD.TaskSequenceModule.psd1`" -Force"
        )
    }Else{
        $commands += @("Write-Host 'Simulator script not found. Download it here: https://github.com/PowerShellCrack/MDTTSSimulator' -ForegroundColor Red")
    }

    $commands += @(
        "Import-Module PSDUtility -Force"
        "Import-Module Storage -Global -Force"
        "Import-Module PSDDeploymentShare -ErrorAction Stop -Force"
        "Import-Module PSDGather -ErrorAction Stop -Force"
        "Get-PSDLocalInfo"
        "`$mappingFile = `"`$Global:deployRoot\Tools\Modules\PSDGather\ZTIGather.xml`""
        "`$global:psddsDeployRoot = `$Global:deployRoot"
    )

    If(!$SimulatorScript){
        $commands += @(
            "`$global:psuDataPath = '`$CachePath'"
            "`$PSDLocalDataPath = Get-PSDLocalDataPath"
            "Get-PSDConnection -deployRoot `$tsenv:DeployRoot -username `"`$(`$tsenv:UserDomain)\`$(`$tsenv:UserID)`" -password `$tsenv:UserPassword"
            "`$tsEngine = Get-PSDContent `"Tools\x64`""
            "`$scripts = Get-PSDContent -Content `"Scripts`""
            "`$modules = Get-PSDContent -Content `"Tools\Modules`""
            "`$env:PSModulePath = `$env:PSModulePath + `";`$modules`""
            #"Invoke-PSDRules -FilePath `"`$Global:deployRoot\Control\Bootstrap.ini`" -MappingFile `$mappingFile"
        )
    }

    $commands += @(       
        "Invoke-PSDRules -FilePath `"`$Global:deployRoot\Control\CustomSettings.ini`" -MappingFile `$mappingFile"
        "`$Control = Get-PSDContent -content 'Control'"
    )

    If($VerbosePreference){
        $commands += @(
            "Get-PSDrive -PSProvider MDTProvider"
            "Get-PSDrive -PSProvider MDTTSEnv*"
            "Get-Item tsenv:*"
        )
    }

    If(Test-PSDWizardInPE){
        $commands += @(
            "Get-Command -Module (Get-childItem -Path `$modules -Recurse | Get-Module).name | Sort Source"
        )
    }Else{
        $commands += @(
            "`$CachePath = `"$LocalPath\Cache`""
            "Import-Module PSDWizardNew -ErrorAction Stop -Force"
            "New-Item -Path `$CachePath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null"
            "New-Item -Path `$CachePath\Scripts -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null"
            "Copy-Item `"`$Global:deployRoot\Scripts\PSDListOfLanguages.xml`" `$CachePath\Scripts"
            "Copy-Item `"`$Global:deployRoot\Scripts\PSDListOfTimeZoneIndex.xml`" `$CachePath\Scripts"
            #"Reset-PSDEnv"
            #"Clear-PSDInformation"
            #"Remove-Item -Path `"`$global:psuDataPath\variables.dat`" -Recurse -ErrorAction SilentlyContinue -Force"
            #"Remove-Item -Path `"`$global:psuDataPath\Cache`" -Recurse -ErrorAction SilentlyContinue -Force"
            #"Remove-Item -Path `"`$PSDLocalDataPath\Cache`" -Recurse -ErrorAction SilentlyContinue -Force"
            
        )
    }

    If(-Not $NoWizard){
        
        $commands += @(
            "Import-Module `"`$Global:deployRoot\Tools\Modules\PSDWizardNew\PSDWizardNew.psm1`" -Global -Force"
            "`$result = Show-PSDWizard -ResourcePath `"`$Global:deployRoot\Scripts\PSDWizardNew`" -AsAsyncJob:`$False -NoSplashScreen -Passthru -Debug:`$true -Theme $Theme"
            #"`$result = Show-PSDWizard -ResourcePath `"`$Global:deployRoot\Scripts\PSDWizardNew`" -AsAsyncJob:`$True -NoSplashScreen -Passthru -Debug:`$true -Theme $Theme"
            "`$result"
        )

    }Else{
        
        $commands += @(
            "`$LangDefinition  = (Get-Content `"`$Global:deployRoot\Scripts\PSDWizardNew\PSDWizard_Definitions_en-US.xml`")"
            "`$ThemeDefinition = (Get-Content `"`$Global:deployRoot\Scripts\PSDWizardNew\Themes\$Theme`_Theme_Definitions_en-US.xml`")"
            "`$Xaml = Format-PSDWizard -Path `"`$Global:deployRoot\Scripts\PSDWizardNew`" -LangDefinition `$LangDefinition -ThemeDefinition `$ThemeDefinition"
            "`$Xaml.OuterXml | Out-File `"$LocalPath\SMSOSD\OSDLOGS\PSDWizardNew_$Theme`_en-US.xaml`" -Force"
        )
        
    }

    If($Passthru){
        $commands
    }Else{
        Write-Verbose -Message ("{0}: Running commands" -f $MyInvocation.MyCommand)
        $commands | ForEach-Object {
            Write-Host ("{0}: Executing [{1}]" -f $MyInvocation.MyCommand, $_)
            Try{
                Invoke-Expression $_
            }Catch{
                Write-Host ("{0}: Unable to execute [{1}]" -f $MyInvocation.MyCommand, $_) -ForegroundColor Red
            }
        }
    }
}

<#
#initialize the wizard module
. .\Scripts\PSDWizardNew\PSDWizard.Helper.ps1
Invoke-PSDTestEnv -SimulatorScript 'C:\MDTSimulator\Start-MDTSimulator.ps1' -NoWizard
#>

