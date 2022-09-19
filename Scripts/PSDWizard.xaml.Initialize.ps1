<#
.SYNOPSIS

.DESCRIPTION

.LINK

.NOTES
          FileName: PSDWizard.xaml.ps1
          Solution: PowerShell Deployment for MDT
          Purpose: Script to initialize the wizard content in PSD
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2019-05-09

          Version - 0.0.0 - () - Finalized functional version 1.

          TODO:

.Example
#>

function Validate-Wizard
{
    # TODO: Make sure selection has been made
    # TODO: Set hidden variables
}

# Populate the top-level tree items
Get-ChildItem -Path "DeploymentShare:\Task Sequences" | % {
    $t = New-Object System.Windows.Controls.TreeViewItem
    $t.Header = $_.Name
    $t.Tag = $_
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $($t.Tag.PSPath)"
    if ($_.PSIsContainer) {
        $t.Items.Add("*")
    }
    $tsTree.Items.Add($t)
}

# Create the Expand event handler
[System.Windows.RoutedEventHandler]$expandEvent = {

    if ($_.OriginalSource -is [System.Windows.Controls.TreeViewItem])
    {
        # Populate the next level of objects
        $current = $_.OriginalSource
        $current.Items.clear()
        $pos = $current.Tag.PSPath.IndexOf("::") + 2
        $path = $current.Tag.PSPath.Substring($pos)
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $path"

        Get-ChildItem -Path $path | % {
            $t = New-Object System.Windows.Controls.TreeViewItem
            $t.Header = $_.Name
            $t.Tag = $_
            if ($_.PSIsContainer) {
                $t.Items.Add("*")
            }
            $current.Items.Add($t)
        }
    }
}
$tsTree.AddHandler([System.Windows.Controls.TreeViewItem]::ExpandedEvent,$expandEvent)

# Create the SelectionChanged event handler
$tsTree.add_SelectedItemChanged({
    if ($this.SelectedItem.Tag.PSIsContainer -ne $true)
    {
        $TS_TaskSequenceID.Text = $this.SelectedItem.Tag.ID
        #$TS_TaskSequenceName = $TS_TaskSequenceID.Text
    }
})
