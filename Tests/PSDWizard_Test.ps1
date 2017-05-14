$xamlPath = "..\Scripts\PSDWizard.xaml"
 
# Load the XAML
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml] $script:Xaml = Get-Content $xamlPath
 
# Process XAML
$reader=(New-Object System.Xml.XmlNodeReader $script:Xaml) 
$script:wizard = [Windows.Markup.XamlReader]::Load($reader)

# Return the form to the caller
return $script:Wizard
