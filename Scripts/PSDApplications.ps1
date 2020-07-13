<#
.SYNOPSIS
    Installs the apps specified in task sequence variables Applications and MandatoryApplications.
.DESCRIPTION
    Installs the apps specified in task sequence variables Applications and MandatoryApplications.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDApplications.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy, @AndHammarskjold
          Primary: @jarwidmark 
          Created: 
          Modified: 2019-05-17

          Version - 0.0.0 - () - Finalized functional version 1.

          TODO:

.Example
#>
param (

)

# Load core modules
Import-Module PSDUtility
Import-Module PSDDeploymentShare

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true)
{
    $verbosePreference = "Continue"
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"

# Internal functions

# Function to install a specified app
function Install-PSDApplication
{
    param(
      [parameter(Mandatory=$true, ValueFromPipeline=$true)]
      [string] $id
    )

    # Make sure we access to the application folder
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Make sure the app exists"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Make sure we access to the application folder"
    if ((Test-Path "DeploymentShare:\Applications") -ne $true)
    {
        
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): no access to DeploymentShare:\Applications , skipping."
        return 0
    }

    # Make sure the app exists
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Make sure the app exists"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Make sure the app exists DeploymentShare:\Applications\$id"
    if ((Test-Path "DeploymentShare:\Applications\$id") -ne $true)
    {
        
        #Write-Verbose "$($MyInvocation.MyCommand.Name): Unable to find application $id, skipping."
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to find application $id, skipping."
        return 0
    }

    # Get the app
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Get the app"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get the app"
    $app = Get-Item "DeploymentShare:\Applications\$id"

    #Write-Verbose "$($MyInvocation.MyCommand.Name): Processing $($app.Name)"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing :$($app.Name)"

    # Process dependencies (recursive)
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Process dependencies (recursive)"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Process dependencies (recursive)"
    if ($app.Dependency.Count -ne 0)
    {
        $app.Dependency | Install-PSDApplication
    }

    # Check if the app has been installed already
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Check if the app has been installed already"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Check if the app has been installed already"
    $alreadyInstalled = @()
    $alreadyInstalled = @((Get-Item tsenvlist:InstalledApplications).Value)
    $found = $false
    $alreadyInstalled | ? {$_ -eq $id} | % {$found = $true}
    if ($found)
    {
        #Write-Verbose "$($MyInvocation.MyCommand.Name): Application $($app.Name) is already installed, skipping."
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Application $($app.Name) is already installed, skipping."
        return
    } 

    # TODO: Check supported platforms
    #Write-Verbose "$($MyInvocation.MyCommand.Name): TODO: Check supported platforms"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Check supported platforms"

    # TODO: Check for uninstall string
    #Write-Verbose "$($MyInvocation.MyCommand.Name): TODO: Check for uninstall string"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Check for uninstall string"

    # Set the working directory
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Set the working directory"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Set the working directory"
    $workingDir = ""
    if ($app.WorkingDirectory -ne "" -and $app.WorkingDirectory -ne ".")
    {
        if ($app.WorkingDirectory -like ".\*")
        {
            # App content is on the deployment share, get it
            #Write-Verbose "$($MyInvocation.MyCommand.Name): App content is on the deployment share, get it"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): App content is on the deployment share, get it"
            $appContent = Get-PSDContent -Content "$($app.WorkingDirectory.Substring(2))"
            $workingDir = $appContent
        }
        else
        {
            $workingDir = $app.WorkingDirectory
        }
        # TODO: Substitute
        #Write-Verbose "$($MyInvocation.MyCommand.Name): TODO: Substitute"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Substitute"
        # TODO: Validate connection
        #Write-Verbose "$($MyInvocation.MyCommand.Name): TODO: Validate connection"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Validate connection"
    }

    # Install the app
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Install the app"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Install the app"

    if ($app.CommandLine -eq "")
    {
        #Write-Verbose "$($MyInvocation.MyCommand.Name): No command line specified (bundle)."
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No command line specified (bundle)."
    }
    elseif ($app.CommandLine -ilike "install-package *")
    {
        Invoke-Expression $($app.CommandLine)
    }
    elseif ($app.CommandLine -icontains ".appx" -or $app.CommandLine -icontains ".appxbundle")
    {
        # TODO: Process modern app
        #Write-Verbose "$($MyInvocation.MyCommand.Name): TODO: Process modern app"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Process modern app"
    }
    else
    {
        $cmd = $app.CommandLine
        # TODO: Substitute
        #Write-Verbose "$($MyInvocation.MyCommand.Name): TODO: Substitute"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Substitute"
        #Write-Verbose "$($MyInvocation.MyCommand.Name): About to run: $cmd"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run: $cmd"
        if ($workingDir -eq "")
        {
            $result = Start-Process -FilePath "$toolRoot\bddrun.exe" -ArgumentList $cmd -Wait -Passthru
        }
        else
        {
            #Write-Verbose "$($MyInvocation.MyCommand.Name): Setting working directory to $workingDir"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Setting working directory to $workingDir"
            $result = Start-Process -FilePath "$toolRoot\bddrun.exe" -ArgumentList $cmd -WorkingDirectory $workingDir -Wait -Passthru
        }
        # TODO: Check return codes
        #Write-Verbose "$($MyInvocation.MyCommand.Name): TODO: Check return codes"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Check return codes"
        #Write-Verbose "$($MyInvocation.MyCommand.Name): Application $($app.Name) return code = $($result.ExitCode)"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Application $($app.Name) return code = $($result.ExitCode)"
    }

    # Update list of installed apps
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Update list of installed apps"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Update list of installed apps"
    $alreadyInstalled += $id
    $tsenvlist:InstalledApplications = $alreadyInstalled

    # Reboot if specified
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Reboot if specified"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reboot if specified"
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
#Write-Verbose "$($MyInvocation.MyCommand.Name): Main code"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Main code"

# Get tools
#Write-Verbose "$($MyInvocation.MyCommand.Name): Get tools"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get tools"
$toolRoot = Get-PSDContent "Tools\$($tsenv:Architecture)"


# Single application install initiated by a Task Sequence action
# Note: The ApplicationGUID variable isn’t set globally. It’s set only within the scope of the Install Application action/step. One of the hidden mysteries of the task sequence engine :)

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking for single application install step"
If ($tsenv:ApplicationGUID -ne "") {
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Mandatory Single Application install indicated. Guid is $($tsenv:ApplicationGUID)"
    Install-PSDApplication $tsenv:ApplicationGUID
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Mandatory Single Application installed, exiting application step"
    Exit
}
else
{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No Single Application install found. Continue with checking for dynamic applications"
}
			

# Process applications
#Write-Verbose "$($MyInvocation.MyCommand.Name): Process applications"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Process applications"
if ($tsenvlist:MandatoryApplications.Count -ne 0)
{
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Processing $($tsenvlist:MandatoryApplications.Count) mandatory applications."
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing $($tsenvlist:MandatoryApplications.Count) mandatory applications."
    $tsenvlist:MandatoryApplications | Install-PSDApplication
}
else
{
    #Write-Verbose "$($MyInvocation.MyCommand.Name): No mandatory applications specified."
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No mandatory applications specified."
}

if ($tsenvlist:Applications.Count -ne 0)
{
    #Write-Verbose "$($MyInvocation.MyCommand.Name): Processing $($tsenvlist:Applications.Count) applications."
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing $($tsenvlist:Applications.Count) applications."
    $tsenvlist:Applications | % { Install-PSDApplication $_ }
}
else
{
    #Write-Verbose "$($MyInvocation.MyCommand.Name): No applications specified."
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No applications specified."
}
