#
# PSDApplications.ps1
#

# Load core modules

$deployRoot = Split-Path -Path "$PSScriptRoot"
Write-Verbose "Using deploy root $deployRoot, based on $PSScriptRoot"
Import-Module "$deployRoot\Scripts\PSDUtility.psm1" -Force
Import-Module "$deployRoot\Scripts\PSDProvider.psm1" -Force
$verbosePreference = "Continue"


function Install-PSDApplication
{
    param(
	  [parameter(Mandatory=$true, ValueFromPipeline=$true)]
      [string] $id
    )

	# Get the app
	$app = Get-Item DeploymentShare:\Applications\$id

	# Process dependencies (recursive)
	$app.Dependency | Install-PSDApplication

	# Check if the app has been installed already
	$alreadyInstalled = @()
	$alreadyInstalled = $tsenvlist:InstalledApplications
	$found = $false
	$alreadyInstalled | ? {$_ -eq $id} | % {$found = $true}
	if ($found)
	{
		Write-Verbose "Application $($app.Name) is already installed, skipping."
		return
	} 

	# TODO: Check supported platforms

	# TODO: Check for uninstall string

	# Set the working directory

	if ($app.WorkingDirectory -ne "" -and $app.WorkingDirectory -ne ".")
	{
        if ($app.WorkingDirectory -like ".\*")
		{
		    $workingDir = "$($tsenv:DeployRoot)\$($app.WorkingDirectory.Substring(2))"
		}
		else
		{
		    $workingDir = $app.WorkingDirectory
		}
		# TODO: Substitute
		# TODO: Validate connection
		[Environment]::CurrentDirectory = $workingDir
	}

	# Install the app

	if ($app.CommandLine -eq "")
	{
		Write-Verbose "No command line specified (bundle)."
	}
	elseif ($app.CommandLine -icontains ".appx" -or $app.CommandLine -icontains ".appxbundle")
	{
		# TODO: Process modern app
	}
	else
	{
	    $cmd = $app.CommandLine
		# TODO: Substitute
		Write-Verbose "About to run: $cmd"
        $result = Start-Process -FilePath "$toolRoot\bddrun.exe" -ArgumentList $cmd -Wait -Passthru
		
		# TODO: Check return codes
		Write-Verbose "Application $app.Name return code = $($result.ExitCode)"
	}

	# Update list of installed apps

	$alreadyInstalled += $id
	$tsenvlist:InstalledApplications = $alreadyInstalled


	# Reboot if specified

	if ($app.Reboot -ieq "TRUE")
	{
        return 3010
	}
	else
	{
	    return 0
	}

}


# Get tools

$toolRoot = Get-PSDContent "Tools"

# Process applications

$tsenv:MandatoryApplications | Install-PSDApplication
$tsenv:Applications | Install-PSDApplication

