<#
.SYNOPSIS
    Configure the unattend.xml to be used with the new OS.
.DESCRIPTION
    Configure the unattend.xml to be used with the new OS.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDConfigure.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2019-05-17

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.1.1 - () - Removed $tsenv:SMSTSRebootRequested = "true" in the end, if not the script will force TS to reboot

          TODO:

.Example
#>

[CmdletBinding()]
param (

)

# Set scriptversion for logging
$ScriptVersion = "0.1.1"

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility
Import-Module DISM
Import-Module PSDDeploymentShare

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true){
    $verbosePreference = "Continue"
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Starting: $($MyInvocation.MyCommand.Name) - Version $ScriptVersion"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): The task sequencer log is located at $("$tsenv:_SMSTSLogPath\SMSTS.LOG"). For task sequence failures, please consult this log."
Write-PSDEvent -MessageID 41000 -severity 1 -Message "Starting: $($MyInvocation.MyCommand.Name)"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"

# Fix issue if Domainjoin value is blank as well as joinworkgroup
if ([string]::IsNullOrEmpty($tsenv:JoinDomain) -and
    [string]::IsNullOrEmpty($tsenv:DomainAdmin) -and
    [string]::IsNullOrEmpty($tsenv:DomainAdminDomain) -and
    [string]::IsNullOrEmpty($tsenv:DomainAdminPassword)) {
    # If $tsenv:JoinWorkGroup is not null or empty, set it to WORKGROUP
    if ([string]::IsNullOrEmpty($tsenv:JoinWorkGroup)) {
        $tsenv:JoinWorkGroup = "WORKGROUP"
    }
}

# Load the unattend.xml
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load the unattend.xml"
$tsInfo = Get-PSDContent "Control\$($tsenv:TaskSequenceID)"
[xml] $unattend = Get-Content "$tsInfo\unattend.xml"
$namespaces = @{unattend='urn:schemas-microsoft-com:unattend'}
$changed = $false
$unattendXml = "$($tsenv:OSVolume):\Windows\Panther\Unattend.xml"
Initialize-PSDFolder "$($tsenv:OSVolume):\Windows\Panther"

# Substitute the values in the unattend.xml
Show-PSDActionProgress -Message "Updating the local unattend.xml" -Step "1" -MaxStep "2"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Substitute the values in the unattend.xml"
$scripts = Get-PSDContent "Scripts"
[xml] $config = Get-Content "$scripts\ZTIConfigure.xml"
$config | Select-Xml "//mapping[@type='xml']" | % {

    # Process each substitution rule from ZTIConfigure.xml
    $variable = $_.Node.id
    $value = (Get-Item tsenv:$variable).Value
    $removes = $_ | Select-Xml "remove"
    $_ | Select-Xml "xpath" | % {

        # Process each XPath query
        $xpath = $_.Node.'#cdata-section'
        $removeIfBlank = $_.Node.removeIfBlank
        $unattend | Select-Xml -XPath $xpath -Namespace $namespaces | % {

            # Process found entry in the unattend.xml
            $prev = $_.Node.InnerText
            if ($value -eq "" -and $prev -eq "" -and $removeIfBlank -eq "Self")
            {
                # Remove the node
                $_.Node.parentNode.removeChild($_.Node) | Out-Null
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Removed $xpath from unattend.xml because the value was blank."
                $changed = $true
            }
            elseif ($value -eq "" -and $prev -eq "" -and $removeIfBlank -eq "Parent")
            {
                # Remove the node
                $_.Node.parentNode.parentNode.removeChild($_.Node.parentNode) | Out-Null
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Removed parent of $xpath from unattend.xml because the value was blank."
                $changed = $true
            }
            elseif ($value -ne "")
            {
                # Set the new value
                $_.Node.InnerText = $value
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Updated unattend.xml with $variable = $value (value was $prev)."
                $changed = $true

                # See if this has a parallel "PlainText" entry, and if it does, set it to true
                $_.Node.parentNode | Select-Xml -XPath "unattend:PlainText" -Namespace $namespaces | % {
                    $_.Node.InnerText = "true"
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Updated PlainText entry to true."
                }

                # Remove any contradictory entries
                $removes | % {
                    $removeXpath = $_.Node.'#cdata-section'
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): *** $removeXpath"
                    $unattend | Select-Xml -XPath $removeXpath -Namespace $namespaces | % {
                        $_.Node.parentNode.removeChild($_.Node) | Out-Null
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Removed $removeXpath entry from unattend.xml."
                    }
                }
            }
            else
            {
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No value found for $variable."
            }
        }
    }
}

# Save the file
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the file"
$unattend.Save($unattendXml)
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Saved $unattendXml."

# TODO: Copy patches
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TODO: Copy patches"

# Apply the unattend.xml
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Apply the unattend.xml"
$scratchPath = "$(Get-PSDLocalDataPath)\Scratch"
Initialize-PSDFolder $scratchPath
Show-PSDActionProgress -Message "Applying local unattend.xml to the OS volume" -Step "2" -MaxStep "2"
Use-WindowsUnattend -UnattendPath $unattendXml -Path "$($tsenv:OSVolume):\" -ScratchDirectory $scratchPath -NoRestart

# The following section has been moved to PSDStart.ps1
# Copy needed script and module files
# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy needed script and module files"

# Initialize-PSDFolder "$($tsenv:OSVolume):\MININT\Scripts"
# Copy-Item "$scripts\PSDStart.ps1" "$($tsenv:OSVolume):\MININT\Scripts"

# $modules = Get-PSDContent "Tools\Modules"
# Copy-PSDFolder "$modules" "$($tsenv:OSVolume):\MININT\Tools\Modules"

# Save all the current variables for later use
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Save-PSDVariables

# Request a reboot
#$tsenv:SMSTSRebootRequested = "true"