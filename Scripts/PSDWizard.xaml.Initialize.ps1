#
# PSDWizard.xaml.ps1
#

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
    Write-Verbose $t.Tag.PSPath 
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
        Write-Verbose $path
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
    }
})
