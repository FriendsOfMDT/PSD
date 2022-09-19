<#
.SYNOPSIS
    Validate
.DESCRIPTION
    Validate
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDValidate.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2022-01-12
          Version:0.0.1 - () - Finalized functional version 1.
          TODO:

.Example
#>

[CmdletBinding()]
param (

)

# Set scriptversion for logging
$ScriptVersion = "0.0.1"

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global -Verbose:$true
Import-Module PSDUtility -Verbose:$true
Import-Module PSDDeploymentShare -Verbose:$true

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true)
{
    $verbosePreference = "Continue"
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Starting: $($MyInvocation.MyCommand.Name) - Version $ScriptVersion"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): The task sequencer log is located at $("$tsenv:_SMSTSLogPath\SMSTS.LOG"). For task sequence failures, please consult this log."
Write-PSDEvent -MessageID 41000 -severity 1 -Message "Starting: $($MyInvocation.MyCommand.Name)"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property ImageSize is $($tsenv:ImageSize)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property ImageProcessorSpeed is $($tsenv:ImageProcessorSpeed)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property ImageMemory is $($tsenv:ImageMemory)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property VerifyOS is $($tsenv:VerifyOS)"

<#
    '//----------------------------------------------------------------------------
    '//  Abort if this is a server OS
    '//----------------------------------------------------------------------------
#>

# TODO: The logic is only used when running in Windows, the logic needs to change from using DeploymentType to detect we are running inside Windows or not
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
