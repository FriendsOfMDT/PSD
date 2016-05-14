$verbosePreference = "Continue"

# Load core modules

Import-Module DISM
$deployRoot = Split-Path -Path "$PSScriptRoot"
Write-Verbose "Using deploy root $deployRoot, based on $PSScriptRoot"
Import-Module "$deployRoot\Scripts\PSDUtility.psm1" -Force
Import-Module "$deployRoot\Scripts\PSDProvider.psm1" -Force


# Load the unattend.xml

[xml] $unattend = Get-Content "$deployRoot\Control\$($tsenv:TaskSequenceID)\unattend.xml"
$namespaces = @{unattend='urn:schemas-microsoft-com:unattend'}
$changed = $false
$unattendXml = "$($tsenv:OSVolume):\Windows\Panther\Unattend.xml"
Initialize-PSDFolder "$($tsenv:OSVolume):\Windows\Panther"


# Substitute the values in the unattend.xml

[xml] $config = Get-Content "$deployRoot\Scripts\ZTIConfigure.xml"
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


# Reboot

Exit 3010
