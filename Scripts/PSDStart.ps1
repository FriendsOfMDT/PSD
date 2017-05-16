# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDStart.ps1
# // 
# // Purpose:   Start or continue a PSD task sequence.
# // 
# // ***************************************************************************

param (
    [switch] $start
)

# Set the module path based on the current script path
$deployRoot = Split-Path -Path "$PSScriptRoot"
$env:PSModulePath = $env:PSModulePath + ";$deployRoot\Tools\Modules"

# Load core module
Import-Module PSDUtility
Import-Module PSDDeploymentShare
Import-Module PSDGather
Import-Module PSDWizard
$verbosePreference = "Continue"

# If running from RunOnce, create a startup folder item and then exit
if ($start)
{
    Write-Verbose "Creating a link to re-run $PSCommandPath from the all users Startup folder"

    # Create a shortcut to run this script
    $allUsersStartup = [Environment]::GetFolderPath('CommonStartup')
    $linkPath = "$allUsersStartup\PSDStartup.lnk"
    $wshShell = New-Object -comObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($linkPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-noprofile -executionpolicy bypass -file $PSCommandPath"
    $shortcut.Save()

    exit 0
}

# Gather local info to make sure key variables are set (e.g. Architecture)
Get-PSDLocalInfo

# Check for an in-progress task sequence
$tsInProgress = $false
get-volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\_SMSTaskSequence\TSEnv.dat"} | % {

    # Found it, save the location
    Write-Verbose "In-progress task sequence found at $($_.DriveLetter):\_SMSTaskSequence."
    $tsInProgress = $true
    $tsDrive = $_.DriveLetter

    # Restore the task sequence variables
    $variablesPath = Restore-PSDVariables
    Write-Verbose "Restored variables from $variablesPath."

    # Reconnect to the deployment share
    Write-Verbose "Reconnecting to the deployment share at $($tsenv:DeployRoot)."
    if ($tsenv:UserDomain -ne "")
    {
        Get-PSDConnection -deployRoot $tsenv:DeployRoot -username "$($tsenv:UserDomain)\$($tsenv:UserID)" -password $tsenv:UserPassword
    }
    else
    {
        Get-PSDConnection -deployRoot $tsenv:DeployRoot -username $tsenv:UserID -password $tsenv:UserPassword
    }

}

# If a task sequence is in progress, resume it.  Otherwise, start a new one
[Environment]::CurrentDirectory = "$($env:WINDIR)\System32"
if ($tsInProgress)
{
    # Find the task sequence engine
    if (Test-Path -Path "X:\Deploy\Tools\$($tsenv:Architecture)\tsmbootstrap.exe")
    {
        $tsEngine = "X:\Deploy\Tools\$($tsenv:Architecture)"
    }
    else
    {
        $tsEngine = Get-PSDContent "Tools\$($tsenv:Architecture)"
    }
    Write-Verbose "Task sequence engine located at $tsEngine."

    # Get full scripts location
    $scripts = Get-PSDContent -Content "Scripts"
    $env:ScriptRoot = $scripts

    # Set the PSModulePath
    $modules = Get-PSDContent -Content "Tools\Modules"
    $env:PSModulePath = $env:PSModulePath + ";$modules"

    # Resume task sequence
    Stop-PSDLogging
    $result = Start-Process -FilePath "$tsEngine\TSMBootstrap.exe" -ArgumentList "/env:SAContinue" -Wait -Passthru
}
else
{
    Write-Verbose "No task sequence is in progress."

    # Process bootstrap
    Write-Verbose "Processing Bootstrap.ini"
    if ($env:SYSTEMDRIVE -eq "X:")
    {
        $mappingFile = "X:\Deploy\Tools\Modules\PSDGather\ZTIGather.xml"
        Invoke-PSDRules -FilePath "X:\Deploy\Scripts\Bootstrap.ini" -MappingFile $mappingFile
    }
    else
    {
        $mappingFile = "$deployRoot\Scripts\ZTIGather.xml"
        Invoke-PSDRules -FilePath "$deployRoot\Control\Bootstrap.ini" -MappingFile $mappingFile
    }
    $deployRoot = $tsenv:DeployRoot
    Write-Verbose "New deploy root is $deployRoot."
    Get-PSDConnection -DeployRoot $tsenv:DeployRoot -Username "$tsenv:UserDomain\$tsenv:UserID" -Password $tsenv:UserPassword

    # Process CustomSettings.ini
    $control = Get-PSDContent -Content "Control"
    Write-Verbose "Processing CustomSettings.ini"
    Invoke-PSDRules -FilePath "$control\CustomSettings.ini" -MappingFile $mappingFile

    # Get full scripts location
    $scripts = Get-PSDContent -Content "Scripts"
    $env:ScriptRoot = $scripts

    # Set the PSModulePath
    $modules = Get-PSDContent -Content "Tools\Modules"
    $env:PSModulePath = $env:PSModulePath + ";$modules"

    # Process wizard
    if ($tsenv:SkipWizard -ine "YES")
    {
        $result = Show-PSDWizard "$scripts\PSDWizard.xaml"
        if ($result -eq $false)
        {
            Write-Verbose "Cancelling."
            Stop-PSDLogging
            Clear-PSDInformation
            exit 0
        }
    }
    if ($tsenv:OSDComputerName -eq "") {
        $tsenv:OSDComputerName = $env:COMPUTERNAME
    }

    # Find the task sequence engine
    if (Test-Path -Path "X:\Deploy\Tools\$($tsenv:Architecture)\tsmbootstrap.exe")
    {
        $tsEngine = "X:\Deploy\Tools\$($tsenv:Architecture)"
    }
    else
    {
        $tsEngine = Get-PSDContent "Tools\$($tsenv:Architecture)"
    }
    Write-Verbose "Task sequence engine located at $tsEngine."

    # Start task sequence
    $variablesPath = Save-PSDVariables
    Copy-Item -Path $variablesPath -Destination $tsEngine -Force
    Copy-Item -Path "$control\$($tsenv:TaskSequenceID)\ts.xml" -Destination $tsEngine -Force

    Stop-PSDLogging
    $result = Start-Process -FilePath "$tsEngine\TSMBootstrap.exe" -ArgumentList "/env:SAStart" -Wait -Passthru
}

# Make sure variables.dat is in the current local directory
if (Test-Path "$(Get-PSDLocalDataPath)\Variables.dat")
{
    Write-Verbose "Variables.dat found in the correct location, $(Get-PSDLocalDataPath)\Variables.dat, no need to copy."
}
else
{
    Write-Verbose "Copying Variables.dat to the current location, $(Get-PSDLocalDataPath)\Variables.dat."
    Copy-Item $variablesPath "$(Get-PSDLocalDataPath)\"
}

# Process the exit code from the task sequence
Start-PSDLogging
Switch ($result.ExitCode)
{
    0 {
        Write-Verbose "SUCCESS!"
        Stop-PSDLogging
        Clear-PSDInformation
        exit 0
    }
    -2147021886 {
        Write-Verbose "REBOOT!"
        Stop-PSDLogging
        if ($env:SYSTEMDRIVE -eq "X:")
        {
            # Exit with a zero return code and let Windows PE reboot
            exit 0
        }
        else
        {
            # In full OS, need to initiate a reboot
            Restart-Computer -Force
            Start-Sleep -Seconds 120
        }
    }
    default {
        # Exit with a non-zero return code
        Write-Verbose "Task sequence failed, rc = $($result.ExitCode)"
        Stop-PSDLogging
        Clear-PSDInformation
        exit $result.ExitCode
    }
}
