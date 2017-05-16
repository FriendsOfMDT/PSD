#
# PSDWizard.psm1
#

$verbosePreference = "Continue"
$script:Wizard = $null
$script:Xaml = $null

function Get-PSDWizard
{
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
        Write-Verbose "Creating variable $($_.Name)"
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

function Save-PSDWizardResult
{
    $script:Xaml.SelectNodes("//*[@Name]") | ? { $_.Name -like "TS_*" } | % {
        $name = $_.Name.Substring(3)
        $control = $script:Wizard.FindName($_.Name)
        $value = $control.Text
        Set-Item -Path tsenv:$name -Value $value 
        Write-Verbose "Set variable $name using form value $value"
    }
}

function Set-PSDWizardDefault
{
    $script:Xaml.SelectNodes("//*[@Name]") | ? { $_.Name -like "TS_*" } | % {
        $name = $_.Name.Substring(3)
        $control = $script:Wizard.FindName($_.Name)
        $value = $control.Text
        $control.Text = (Get-Item tsenv:$name).Value
    }
}

function Show-PSDWizard
{
    Param( 
        $xamlPath
    ) 

    Write-Verbose "Processing wizard from $xamlPath"
    $wizard = Get-PSDWizard $xamlPath
    Set-PSDWizardDefault
    $result = $wizard.ShowDialog()
    Save-PSDWizardResult
}

Export-ModuleMember -function Show-PSDWizard

