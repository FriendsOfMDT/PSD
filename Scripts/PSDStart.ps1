$verbosePreference = "Continue"


# Load core module

$deployRoot = Split-Path -Path "$PSScriptRoot"
Write-Verbose "Using deploy root $deployRoot, based on $PSScriptRoot"
Import-Module "$deployRoot\Scripts\PSDUtility.psm1" -Force
Import-Module "$deployRoot\Scripts\PSDGather.psm1" -Force


# Check for an in-progress task sequence

$tsInProgress = $false
get-volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\_SMSTaskSequence\TSEnv.dat"} | % {
    Write-Verbose "In-progress task sequence found at $($_.DriveLetter):\_SMSTaskSequence."
    $tsInProgress = $true
    $tsDrive = $_.DriveLetter
}


# Find the task sequence engine

$tsEngine = Get-PSDContent "Tools"
Write-Verbose "Task sequence engine located at $tsEngine."


# If a task sequence is in progress, resume it.  Otherwise, start a new one

[Environment]::CurrentDirectory = "$($env:WINDIR)\System32"
if ($tsInProgress)
{
    # Resume task sequence

    Get-PSDVariables
    Stop-PSDLogging
    $result = Start-Process -FilePath "$tsEngine\TSMBootstrap.exe" -ArgumentList "/env:SAContinue" -Wait -Passthru
}
else
{
    Write-Verbose "No task sequence is in progress."


    # Process bootstrap

    Get-PSDLocalInfo
    Write-Verbose "Processing Bootstrap.ini"
    if ($env:SYSTEMDRIVE -eq "X:")
    {
        Invoke-PSDRules "X:\Deploy\Scripts\Bootstrap.ini"
        Get-PSDConnection -UncPath $tsenv:DeployRoot -Username "$tsenv:UserDomain\$tsenv:UserID" -Password $tsenv:UserPassword
        $deployRoot = $tsenv:DeployRoot
    }
    else
    {
        Invoke-PSDRules "$deployRoot\Control\Bootstrap.ini"
        $deployRoot = $tsenv:DeployRoot
    }
    Write-Verbose "New deploy root is $deployRoot."


    # Process CustomSettings.ini

    Write-Verbose "Processing CustomSettings.ini"
    Invoke-PSDRules "$deployRoot\Control\CustomSettings.ini"
    if ($tsenv:OSDComputerName -eq "") {
        $tsenv:OSDComputerName = $env:COMPUTERNAME
    }


    # TODO: Process wizard


    # Start task sequence

    $variablesPath = Save-PSDVariables
    Write-verbose "$variablesPath $tsEngine"
    Copy-Item -Path $variablesPath -Destination $tsEngine -Force
    Copy-Item -Path "$deployroot\Control\$($tsenv:TaskSequenceID)\ts.xml" -Destination $tsEngine -Force

    Stop-PSDLogging
    $result = Start-Process -FilePath "$tsEngine\TSMBootstrap.exe" -ArgumentList "/env:SAStart" -Wait -Passthru
}


# Process the exit code from the task sequence

Start-PSDLogging
Switch ($result.ExitCode)
{
    0 {
        Write-Verbose "SUCCESS!"
    }
    -2147021886 {
        Write-Verbose "REBOOT!"
    }
    default {
        Write-Verbose "Task sequence failed, rc = $($result.ExitCode)"
    }
}
Stop-PSDLogging
