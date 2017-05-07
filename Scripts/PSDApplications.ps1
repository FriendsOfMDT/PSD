# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDApplications.ps1
# // 
# // Purpose:   Installs the apps specified in task sequence variables 
# //            Applications and MandatoryApplications.
# // 
# // ***************************************************************************

# Load core modules

Import-Module PSDUtility
Import-Module PSDDeploymentShare
$verbosePreference = "Continue"

# Internal functions

# Function to install a specified app
function Install-PSDApplication
{
    param(
      [parameter(Mandatory=$true, ValueFromPipeline=$true)]
      [string] $id
    )

    # Make sure the app exists
    if ((Test-Path DeploymentShare:\Applications\$id) -ne $true)
    {
        Write-Verbose "Unable to find application $id, skipping."
        return 0
    }

    # Get the app
    $app = Get-Item DeploymentShare:\Applications\$id
    Write-Verbose "Processing $($app.Name)"

    # Process dependencies (recursive)
    if ($app.Dependency.Count -ne 0)
    {
        $app.Dependency | Install-PSDApplication
    }

    # Check if the app has been installed already
    $alreadyInstalled = @()
    $alreadyInstalled = @((Get-Item tsenvlist:InstalledApplications).Value)
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
    $workingDir = ""
    if ($app.WorkingDirectory -ne "" -and $app.WorkingDirectory -ne ".")
    {
        if ($app.WorkingDirectory -like ".\*")
        {
            # App content is on the deployment share, get it
            $appContent = Get-PSDContent -Content "$($app.WorkingDirectory.Substring(2))"
            $workingDir = $appContent
        }
        else
        {
            $workingDir = $app.WorkingDirectory
        }
        # TODO: Substitute
        # TODO: Validate connection
    }

    # Install the app

    if ($app.CommandLine -eq "")
    {
        Write-Verbose "No command line specified (bundle)."
    }
    elseif ($app.CommandLine -ilike "install-package *")
    {
        Invoke-Expression $($app.CommandLine)
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
        if ($workingDir -eq "")
        {
            $result = Start-Process -FilePath "$toolRoot\bddrun.exe" -ArgumentList $cmd -Wait -Passthru
        }
        else
        {
            Write-Verbose "Setting working directory to $workingDir"
            $result = Start-Process -FilePath "$toolRoot\bddrun.exe" -ArgumentList $cmd -WorkingDirectory $workingDir -Wait -Passthru
        }
        # TODO: Check return codes
        Write-Verbose "Application $($app.Name) return code = $($result.ExitCode)"
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


# Main code

# Get tools
$toolRoot = Get-PSDContent "Tools\$($tsenv:Architecture)"

# Process applications
if ($tsenvlist:MandatoryApplications.Count -ne 0)
{
    Write-Verbose "Processing $($tsenvlist:MandatoryApplications.Count) mandatory applications."
    $tsenvlist:MandatoryApplications | Install-PSDApplication
}
else
{
    Write-Verbose "No mandatory applications specified."
}

if ($tsenvlist:Applications.Count -ne 0)
{
    Write-Verbose "Processing $($tsenvlist:Applications.Count) applications."
    $tsenvlist:Applications | % { Install-PSDApplication $_ }
}
else
{
    Write-Verbose "No applications specified."
}
