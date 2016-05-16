# Load core module

$deployRoot = Split-Path -Path "$PSScriptRoot"
Write-Verbose "Using deploy root $deployRoot, based on $PSScriptRoot"
Import-Module "$deployRoot\Scripts\PSDUtility.psm1" -Force
Import-Module "$deployRoot\Scripts\PSDGather.psm1" -Force
$verbosePreference = "Continue"


# Gather local info to make sure key variables are set (e.g. Architecture)

Get-PSDLocalInfo


# Check for an in-progress task sequence

$tsInProgress = $false
get-volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\_SMSTaskSequence\TSEnv.dat"} | % {
    Write-Verbose "In-progress task sequence found at $($_.DriveLetter):\_SMSTaskSequence."
    $tsInProgress = $true
    $tsDrive = $_.DriveLetter

    $variablesPath = Restore-PSDVariables
    Write-Verbose "Restored variables from $variablesPath."
}


# If a task sequence is in progress, resume it.  Otherwise, start a new one

[Environment]::CurrentDirectory = "$($env:WINDIR)\System32"
if ($tsInProgress)
{
    # Find the task sequence engine

    $tsEngine = Get-PSDContent "TaskSequencer"
    Write-Verbose "Task sequence engine located at $tsEngine."


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

	# Find the task sequence engine

    $tsEngine = Get-PSDContent "TaskSequencer"
    Write-Verbose "Task sequence engine located at $tsEngine."


    # Start task sequence

    $variablesPath = Save-PSDVariables
    Copy-Item -Path $variablesPath -Destination $tsEngine -Force
    Copy-Item -Path "$deployroot\Control\$($tsenv:TaskSequenceID)\ts.xml" -Destination $tsEngine -Force

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
