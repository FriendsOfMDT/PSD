<#
.SYNOPSIS
    Module for the PSD Wizard
.DESCRIPTION
    Module for the PSD Wizard
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDWizard.psm1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2019-05-09

          Version - 0.0.0 - () - Finalized functional version 1.

          TODO:

.Example
#>

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true){
    $verbosePreference = "Continue"
}


$script:Wizard = $null
$script:Xaml = $null

function Get-PSDWizard{
    Param( 
        $xamlPath
    ) 

    # Load the XAML
    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    [xml] $script:Xaml = Get-Content $xamlPath
 
    # Process XAML
    $reader=(New-Object System.Xml.XmlNodeReader $script:Xaml) 
    $script:wizard = [Windows.Markup.XamlReader]::Load($reader)

    # Store objects in PowerShell variables
    $script:Xaml.SelectNodes("//*[@Name]") | % {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating variable $($_.Name)"
        Set-Variable -Name ($_.Name) -Value $script:Wizard.FindName($_.Name) -Scope Global
    }

    # Attach event handlers
    $wizFinishButton.Add_Click({
        $script:Wizard.DialogResult = $true
        $script:Wizard.Close()
    })

    # Attach event handlers
    $wizCancelButton.Add_Click({
        $script:Wizard.DialogResult = $false
        $script:Wizard.Close()
    })

    # Load wizard script and execute it
    Invoke-Expression "$($xamlPath).Initialize.ps1" | Out-Null

    # Return the form to the caller
    return $script:Wizard
}
function Save-PSDWizardResult{
    $script:Xaml.SelectNodes("//*[@Name]") | ? { $_.Name -like "TS_*" } | % {
        $name = $_.Name.Substring(3)
        $control = $script:Wizard.FindName($_.Name)
        if($_.Name -eq "TS_DomainAdminPassword" -or $_.Name -eq "TS_AdminPassword"){
            $value = $control.Password
            Set-Item -Path tsenv:$name -Value $value 
        }
        else{
            $value = $control.Text
            Set-Item -Path tsenv:$name -Value $value 
        }
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Set variable $name using form value $value"
        if($name -eq "TaskSequenceID"){
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking TaskSequenceID value"
            if ($value -eq ""){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TaskSequenceID is empty!!!"
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Re-Running Wizard, TaskSequenceID must not be empty..."
                Show-PSDSimpleNotify -Message "No Task Sequence selected, restarting wizard..."
                Show-PSDWizard "$scripts\PSDWizard.xaml"
            }
        }
    }
}
function Set-PSDWizardDefault{
    $script:Xaml.SelectNodes("//*[@Name]") | ? { $_.Name -like "TS_*" } | % {
        $name = $_.Name.Substring(3)
        $control = $script:Wizard.FindName($_.Name)
        if($_.Name -eq "TS_DomainAdminPassword" -or $_.Name -eq "TS_AdminPassword"){
            $value = $control.Password
            $control.Password = (Get-Item tsenv:$name).Value
        }
        else{
            $value = $control.Text
            $control.Text = (Get-Item tsenv:$name).Value
        }
    }
}
function Show-PSDWizard{
    Param( 
        $xamlPath
    ) 
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing wizard from $xamlPath"
    $wizard = Get-PSDWizard $xamlPath
    Set-PSDWizardDefault
    $result = $wizard.ShowDialog()
    Save-PSDWizardResult
    Return $wizard
}

Export-ModuleMember -function Show-PSDWizard

