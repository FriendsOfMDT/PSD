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
    $script:Xaml.SelectNodes("//*[@Name]") | %{Set-Variable -Name ($_.Name) -Value $script:Wizard.FindName($_.Name)}

    # Attach event handlers
    $wizFinishButton.Add_Click({$script:Wizard.Close()})

    # Initialize panes
    Populate-Tree -objectPath "DeploymentShare:\Task Sequences" -parent $tsTree

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

    $wizard = Get-PSDWizard $xamlPath
    Set-PSDWizardDefault
    $null = $wizard.ShowDialog()
    Save-PSDWizardResult
}

function Populate-Tree
{
    param(
        $parent, 
        $objectPath
    )

    $parent.Items.Clear
    Get-ChildItem -Path $objectPath | % {
        $t = New-Object System.Windows.Controls.TreeViewItem
        $t.Header = $_.FullName
        $t.Tag = $_
        $t.Items.Add("*")
    }
}

Export-ModuleMember -function Show-PSDWizard

