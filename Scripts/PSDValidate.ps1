# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDTemplate.ps1
# // 
# // Purpose:   Apply the specified operating system.
# // 
# // 
# // ***************************************************************************

param (

)

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility
Import-Module PSDDeploymentShare

$verbosePreference = "Continue"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $($tsenv:DeployRoot)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:ImageSize $($tsenv:ImageSize)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:ImageProcessorSpeed $($tsenv:ImageProcessorSpeed)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:ImageMemory $($tsenv:ImageMemory)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:VerifyOS $($tsenv:VerifyOS)"

<#
    '//----------------------------------------------------------------------------
    '//  Abort if this is a server OS
    '//----------------------------------------------------------------------------
#>

If($TSEnv:DeploymentType -eq "REFRESH")
{
	If ($TSEnv:VerifyOS -eq "CLIENT")
    {
		If($TSEnv:IsServerOS -eq "TRUE")
        {
            $Message = "ERROR - Attempting to deploy a client operating system to a machine running a server operating system."
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $Message" -LogLevel 3
            Show-PSDInfo -Message $Message  -Severity Error
            Start-Process PowerShell -Wait
            Break
        }
    }

	If ($TSEnv:VerifyOS -eq "SERVER")
    {
		If($TSEnv:IsServerOS -eq "FALSE")
        {
            $Message = "ERROR - Attempting to deploy a server operating system to a machine running a client operating system."
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $Message" -LogLevel 3
            Show-PSDInfo -Message $Message  -Severity Error
            Start-Process PowerShell -Wait
            Break
        }
    }
}

<#
	'//----------------------------------------------------------------------------
	'//  Abort if "OSInstall" flag is set to something other than Y or YES
	'//----------------------------------------------------------------------------
#>

    If($TSEnv:OSInstall -eq "Y" -or "YES")
    {
        $Message = "OSInstall flag is $TSEnv:OSInstall , install is allowed."
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $Message" -LogLevel 1
    }
    else
    {
        $Message = "OSInstall flag is NOT set to Y or YES, abort."
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $Message" -LogLevel 3
        Show-PSDInfo -Message $Message -Severity Error
        Start-Process PowerShell -Wait
        Break
    }


Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Save-PSDVariables
