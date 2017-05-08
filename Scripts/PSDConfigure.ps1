# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDConfigure.ps1
# // 
# // Purpose:   Configure the unattend.xml to be used with the new OS.
# // 
# // ***************************************************************************

# Load core modules

Import-Module DISM
Import-Module PSDUtility
Import-Module PSDDeploymentShare
$verbosePreference = "Continue"

# Load the unattend.xml
$tsInfo = Get-PSDContent "Control\$($tsenv:TaskSequenceID)"
[xml] $unattend = Get-Content "$tsInfo\unattend.xml"
$namespaces = @{unattend='urn:schemas-microsoft-com:unattend'}
$changed = $false
$unattendXml = "$($tsenv:OSVolume):\Windows\Panther\Unattend.xml"
Initialize-PSDFolder "$($tsenv:OSVolume):\Windows\Panther"


# Substitute the values in the unattend.xml

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
                Write-Verbose "Removed $xpath from unattend.xml because the value was blank."
                $changed = $true
            }
            elseif ($value -eq "" -and $prev -eq "" -and $removeIfBlank -eq "Parent")
            {
                # Remove the node
                $_.Node.parentNode.parentNode.removeChild($_.Node.parentNode) | Out-Null
                Write-Verbose "Removed parent of $xpath from unattend.xml because the value was blank."
                $changed = $true
            }
            elseif ($value -ne "")
            {
                # Set the new value
                $_.Node.InnerText = $value
                Write-Verbose "Updated unattend.xml with $variable = $value (value was $prev)."
                $changed = $true

                # See if this has a parallel "PlainText" entry, and if it does, set it to true
                $_.Node.parentNode | Select-Xml -XPath "unattend:PlainText" -Namespace $namespaces | % {
                    $_.Node.InnerText = "true"
                    Write-Verbose "Updated PlainText entry to true."
                }

                # Remove any contradictory entries
                $removes | % {
                    $removeXpath = $_.Node.'#cdata-section'
                    Write-Verbose "*** $removeXpath"
                    $unattend | Select-Xml -XPath $removeXpath -Namespace $namespaces | % {
                        $_.Node.parentNode.removeChild($_.Node) | Out-Null
                        Write-Verbose "Removed $removeXpath entry from unattend.xml."
                    }
                }
            }
            else
            {
                Write-Verbose "No value found for $variable."
            }
        }
    }
}

# Save the file
$unattend.Save($unattendXml)
Write-Verbose "Saved $unattendXml."

# TODO: Copy patches

# Apply the unattend.xml
Write-Verbose "Applying $unattendxml."
$scratchPath = "$(Get-PSDLocalDataPath)\Scratch"
Initialize-PSDFolder $scratchPath
Use-WindowsUnattend -UnattendPath $unattendXml -Path "$($tsenv:OSVolume):\" -ScratchDirectory $scratchPath -NoRestart

# Copy needed script and module files
Initialize-PSDFolder "$($tsenv:OSVolume):\MININT\Scripts"
$modules = Get-PSDContent "Tools\Modules"
Copy-Item "$scripts\PSDStart.ps1" "$($tsenv:OSVolume):\MININT\Scripts"
Copy-PSDFolder "$modules" "$($tsenv:OSVolume):\MININT\Tools\Modules" 

# Request a reboot
$tsenv:SMSTSRebootRequested = "true"
