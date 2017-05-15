$xamlPath = "..\Scripts\PSDWizard.xaml"
 
# Load the XAML
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml] $xaml = Get-Content $xamlPath
 
# Process XAML
$reader=(New-Object System.Xml.XmlNodeReader $xaml) 
$wizard = [Windows.Markup.XamlReader]::Load($reader)

# Show the dialog
$wizard.ShowDialog()