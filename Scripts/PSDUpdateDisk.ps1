<#
.SYNOPSIS
    Apply the specified operating system.
.DESCRIPTION
    Apply the specified operating system.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDUpdateDisk.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2022-09-18

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.1.0 - (2019-05-09) - Check access to image file

.Example
#>

[CmdLetBinding()]
param(
)

if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
    $VerbosePreference = "Continue"
}
Write-Verbose "Verbose is on"

# Set scriptversion for logging
$ScriptVersion = "0.1.0"

# Load core modules
Import-Module PSDUtility

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

# Request temporary files for RedirectStandardOutput and RedirectStandardError
$RedirectStandardOutput = [System.IO.Path]::GetTempFileName()
$RedirectStandardError = [System.IO.Path]::GetTempFileName() 

# Wait 5 seconds
Start-Sleep -Seconds 5

# Start bcdedit.exe to refresh BCD entries (needed on some hardware)
$Executable = "bcdedit.exe"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run $Executable $Arguments"
$Result = Start-Process -FilePath $Executable -NoNewWindow -Wait -PassThru -RedirectStandardOutput $RedirectStandardOutput -RedirectStandardError $RedirectStandardError

# Log the Standard Output, skip any empty lines
If ((Get-Item $RedirectStandardOutput).length -gt 0){
    Write-PSDLog -Message "----------- $Executable Begin Standard Output -----------"
    $CleanedRedirectStandardOutput = Get-Content $RedirectStandardOutput | Where-Object {$_.trim() -ne "" } 
    foreach ($row in $CleanedRedirectStandardOutput){
         Write-PSDLog -Message $row
    }
    Write-PSDLog -Message "----------- $Executable End Standard Output -----------"
}

# Log the $Executable Standard Error, skip any empty lines
If ((Get-Item $RedirectStandardError).length -gt 0){
    Write-PSDLog -Message "----------- $Executable Begin Standard Error -----------"
    $CleanedRedirectStandardError = Get-Content $RedirectStandardError | Where-Object {$_.trim() -ne "" } 
    foreach ($row in $CleanedRedirectStandardError){
         Write-PSDLog -Message $row
    }
    Write-PSDLog -Message "----------- $Executable End Standard Error -----------"
}

# Error handling
if ($Result.ExitCode -eq 0) {
	Write-PSDLog -Message  "Boot Entry has been updated successfully"
} elseif ($Result.ExitCode -gt 0) {
	return Write-PSDLog "Exit code is $($Result.ExitCode)"
} else {
	return Write-PSDLog "An unknown error occurred."
}

# Wait 5 seconds
Start-Sleep -Seconds 5
