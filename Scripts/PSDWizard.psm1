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
        Contact: @PowershellCrack
        Primary: @PowershellCrack
        Created:
        Modified: 2021-01-26

        Version - 2.0.0b - () - Finalized functional version 2.
        Version - 2.1.1b - (PC) - Cleaned up logging and added script source; moved all variables in messages to format tag
        Version - 2.1.2b - (PC) - Fixed UI issues with invalid TS selection unable to continue if navigate back


        TODO:
            - Themes
            - Logos/Branding
            - Add deployment readiness checks
            - Add refresh event handler
            - build network configuration screen
            - Generate XAML based on customsettings - SEE CHANGELOG 11/22/2020
            - Search Task Sequence - SEE CHANGELOG 11/28/2020
            - Tab events - SEE CHANGELOG 11/28/2020
            - Populate multilevel treeview for task sequence - SEE CHANGELOG 11/27/2020
            - Search Applications - SEE CHANGELOG 11/28/2020
            - SkipWizard Control - SEE CHANGELOG 11/28/2020
.Example
#>

#region FUNCTION: Convert XML file into PS object
Function ConvertFrom-XML {
    Param (
        $XML
    )
    $Return = New-Object -TypeName PSCustomObject
    $xml |Get-Member -MemberType Property |Where-Object {$_.MemberType -EQ "Property"} |ForEach {
        IF ($_.Definition -Match "^\bstring\b.*$") {
            $Return | Add-Member -MemberType NoteProperty -Name $($_.Name) -Value $($XML.($_.Name))
        } ElseIf ($_.Definition -Match "^\System.Xml.XmlElement\b.*$") {
            $Return | Add-Member -MemberType NoteProperty -Name $($_.Name) -Value $(ConvertFrom-XML -XML $($XML.($_.Name)))
        } Else {
            Write-Verbose ("Unrecognized Type: {0}='{1}'" -f $_.Name,$_.Definition)
        }
    }
    $Return
}
#endregion

#region FUNCTION: Retrieve definition file sections
Function Get-PSDWizardDefinitions {
    Param(
        [parameter(Mandatory=$true)]
        [xml]$xml,

        [parameter(Mandatory=$false)]
        [ValidateSet('Global','WelcomeWizard','Pane')]
        $Section = 'Global'
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Try{
        [Xml.XmlElement]$WizardElement = $xml.Wizard
    }
    Catch{
        Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Unable to parse xml content definition file: {0} " -f $_.Exception.Message) -LogLevel 3
        Return
    }

    switch($Section){
        'Global'        {$DefinitionObject = ConvertFrom-XML $WizardElement.Global}
        'WelcomeWizard' {$DefinitionObject = ConvertFrom-XML $WizardElement.WelcomeWizard}
        'Pane'          {$DefinitionObject = $WizardElement.Pane}
        default         {}
    }

    Return $DefinitionObject
}
#endregion


#region FUNCTION: Retrieve XSL condition statement from definition file
Function Get-PSDWizardCondition {
    Param(
        [parameter(Mandatory=$true)]
        [string]$Condition,

        [PSCustomObject]$TSEnvSettings,

        [switch]$Passthru
    )

    #convert each TSEnvSettings object into variables
    #ForEach ($item in $TSEnvSettings | ?{$_.Name -eq 'IsUEFI'}) {
    ForEach ($item in $TSEnvSettings) {
        $Name = $item.Name
        If($Name -match "^_"){
            $Name = $Name -replace '^_',''
        }

        #determine if value is boolean
        Try{
            $Value = [boolean]::Parse($item.value)
        }
        Catch{
            $Value = $item.value
        }
        Finally{
            #('Set-Variable -Name ' + $Name + ' -Value ' + $Value)
            Set-Variable -Name $Name -Value $Value | Out-Null
        }
    }

    #Load functions from external file
    #. "$DeployRoot\scripts\PSDWizard\PSDWizard.Initialize.ps1"

    <#test
    $Condition = 'UCASE(Property("SkipWizard")) <> "YES"'
    $Condition = 'UCase(Property("SkipDomainMembership"))<>"YES" or UCase(Property("SkipComputerName"))<>"YES"'
    $Condition = 'Property("Model") in Properties("SupportedModels(*)")'
    $Condition = 'Property("IPADDRESS") in Properties("IPADDRESS(*)") -and Property("Model") in Properties("SupportedList(*)")'
    $Condition = 'Property(IsUEFI) == "True"'
    $Condition = 'Property("Model")'
    $Condition = 'Property("DeploymentType") <> "REPLACE" and Property("DeploymentType") <> "CUSTOM" and Property("DeploymentType") <> "StateRestore" and Property("DeploymentType") <> "UPGRADE"'
    $Condition = 'Property("DeploymentType") <> "NEWCOMPUTER" and Property("DeploymentType") <> "CUSTOM"'
    #>
    #change operators to powershell operators
    $Condition = $Condition -replace '<>',' -ne ' -replace '==',' -eq ' -replace '=',' -eq ' -replace '<=',' -le ' -replace '=>',' -ge ' -replace '<', '-lt ' -replace '>',' -gt'

    #Remove quotes from all items in parentheses
    $Condition = $Condition -replace "\([`"|']",'(' -replace "[`"|']\)",")"
    #remove the UCASE and Property string to make variable
    #$Condition = $Condition -replace "Property\(`"",'$' -replace "`"\)","" -replace 'UCASE\(','' -replace '\)',' '
    #remove the UCASE and Property string to make variable
    If($Condition -match 'Property'){
        $Condition = $Condition -replace "Property\(",'$' -replace "\)",""
    }

    #find the properties match and tie them together
    If($Condition -match 'Properties'){#$Matches
        #look for more than one properties
        $PropertiesSearch = $Condition -split ' ' | Where {$_ -match 'Properties\("'}
        #loop through each
        Foreach($Properties in $PropertiesSearch){
            #get list name
            $ArrayName = ($Properties -split 'Properties\("')[1] -replace "\(\*\)",""
            $Values = @()
            #get list values
            $TSEnvSettings | Where {$_.Name -match "$ArrayName\d\d\d"} | ForEach-Object {
                $Values += $_.Value
            }
            #Build array variable
            Remove-Variable -Name "$($ArrayName)List" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Variable -Name "$($ArrayName)List" -Value $Values
            #replace array in string
            $Condition = $Condition.replace("$Properties","`$$ArrayName`List") -replace "`"\)",""
        }
        #change operators to powershell operators
        $Condition = $Condition -replace '\bin\b',' -in '
    }

    If($Condition -match 'UCASE'){
        $Condition = $Condition -replace 'UCASE\(','' -replace '\)',' '
    }

    $Condition = $Condition -replace "`"\)",""
    #determine if there is multiple condition in one statement, if so, encapsulated each one in parenthesis
    #replace [and] and [or] with proper operators
    If($Condition -match '\s+or\s+|\s+and\s+'){
        $Condition = '(' + ($Condition -replace '\bor\b',') -or (' -replace '\band\b',') -and (') + ')'
    }
    #Change True/false to boolean
    $Condition = $Condition -replace '"True"','$True' -replace '"False"','$False'

    #remove any additional spacing
    $Condition = ($Condition -replace '\s+',' ').Trim()

    #convert condition string into a script
    $scriptblock = [scriptblock]::Create($Condition)
    If($Passthru){
        $result = $scriptblock
    }
    Else{
        #evaluate the condition
        $result = Invoke-command $scriptblock
    }

    return $result
}
#endregion


#region FUNCTION: Build the XAML dynamically from definition file
Function Format-PSDWizard{
    Param(
        [parameter(Mandatory=$false)]
        [string]$Path = "$DeployRoot\scripts\PSDWizard",

        [parameter(Mandatory=$true)]
        $DefinitionFile,

        [switch]$Passthru
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #determine if path is has a file in path or is just a container
    #Make the path the working path
    If(Test-Path -Path $Path -PathType Container){
        $WorkingPath = $Path -replace '\\$',''
    }Else{
        # we don't need the fie; just the path
        $WorkingPath = Split-Path $Path -Parent
    }

    #Load functions from external file
    #. "$WorkingPath\PSDWizard.Initialize.ps1"

    #[string]$PSDWizardPath = (Join-Path -Path $WorkingPath -ChildPath 'PSDWizard')
    [string]$ResourcePath = (Join-Path -Path $WorkingPath -ChildPath 'Resources')
    [string]$TemplatePath = (Join-Path -Path $WorkingPath -ChildPath 'Themes')

    #grab definition path and its contents
    #[string]$DefinitionsXml = Join-Path -Path $WorkingPath -ChildPath $DefinitionFile
    [string]$DefinitionsXml = Join-Path -Path $WorkingPath -ChildPath $DefinitionFile
    [Xml.XmlDocument]$DefinitionXmlDoc = Get-Content $DefinitionsXml

    #grab all elements from definition file
    [PSCustomObject]$GlobalElement = Get-PSDWizardDefinitions -Xml $DefinitionXmlDoc -Section Global
    [PSCustomObject]$WelcomeElement = Get-PSDWizardDefinitions -Xml $DefinitionXmlDoc -Section WelcomeWizard
    [PSCustomObject]$PaneElements = Get-PSDWizardDefinitions -Xml $DefinitionXmlDoc -Section Pane

    #build paths to Welcome Wizard start
    [string]$XamlWizardTemplatePath = Join-Path -Path $TemplatePath -ChildPath $GlobalElement.TemplateReference
    [string]$StartPagePath = Join-Path -Path $TemplatePath -ChildPath $WelcomeElement.reference

    if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Generating PSD Wizard from template file: {0}" -f (Split-Path $XamlWizardTemplatePath -leaf))}

    #grab the primary template
    $PSDWizardXAML = (Get-Content $XamlWizardTemplatePath -ReadCount 0) -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'

    #grab the SMSTSOrgName from settings
    $OrgName = Get-TSItem SMSTSOrgName -wildcard -ValueOnly
    #fill in the main title and sub title

    #grab all variables that contain skip
    $SkipSettings = Get-TSItem Skip -wildcard

    #determine if welcome wizard is not skipped
    If(Get-PSDWizardCondition -Condition $WelcomeElement.Condition.'#cdata-section' -TSEnvSettings $SkipSettings)
    {
        #grab the start page content
        $StartPageContent = (Get-Content $StartPagePath -ReadCount 0)
        #insert main and sub title
        $MainTitle = ($WelcomeElement.MainTitle.'#cdata-section' -replace '"','').Trim()
        $SubTitle = ($WelcomeElement.SubTitle.'#cdata-section' -replace '"','').Trim()
        $StartPageContent = ($StartPageContent -replace '@MainTitle',$MainTitle).Trim()
        $StartPageContent = ($StartPageContent -replace '@SubTitle',$SubTitle).Trim()
        If($OrgName){
            $StartPageContent = ($StartPageContent -replace '@ORG',$OrgName)
        }Else{
            $StartPageContent = ($StartPageContent -replace '@ORG','you')
        }
    }
    Else{
        $StartPageContent = ''
    }
    #populate the template with start page
    $PSDWizardXAML = $PSDWizardXAML.replace("@StartPage",$StartPageContent)

    #convert XAML to XML just to grab info using xml dot sourcing (Not used to process form)
    [xml]$PSDWizardXML = $PSDWizardXAML

    #grab the list of merged dictionaries in XML, replace the path with Powershell
    $MergedDictionaries = $PSDWizardXML.Window.'Window.Resources'.ResourceDictionary.'ResourceDictionary.MergedDictionaries'.ResourceDictionary.Source

    #grab all resource files
    $Resources = Get-ChildItem $ResourcePath -Filter *.xaml

    # replace the resource path
    foreach ($Source in $MergedDictionaries)
    {
        $FileName = Split-Path $Source -Leaf
        $SourcePath = $Resources | Where {$_.Name -match $FileName} | Select -ExpandProperty FullName
        $PSDWizardXAML = $PSDWizardXAML -replace $Source,$SourcePath #  ($SourcePath -replace "\\","/")
    }

    #Tab template used to build form
    #Consist of logos, title, subtitle and buttons
    # @content is controlled by definition reference file for pane (aka: Tab)
    $TabsContentTemplate = ($GlobalElement.PanesTemplate.'#cdata-section'.Trim())

    
    #Replace Tabcontrol section with tab template
    #$PSDWizardXAML = $PSDWizardXAML -replace '@TabItem',$TabsContentTemplate

    $tabitems = $null
    #grab all tabs
    $i=0
    #loop through each page
    #ForEach ($Tab in $PaneElements){break}
    $TSEnvSettings = (Get-TSItem * -wildcard)
    ForEach ($Tab in $PaneElements)
    {
        #loop through each condition to find if ts value matches
        Foreach($condition in ($Tab.condition.'#cdata-section').Trim()){
            $Result = Get-PSDWizardCondition -Condition $condition -TSEnvSettings $TSEnvSettings
            If($Result -eq $false){Break} #stop this condition loop if false
        }

        #Go to next iteration in loop if ANY condition is false
        If($Result -eq $false){
            if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Condition [{0}] for [{1}] tab is false, Skipping generation of this tab" -f $condition,$Tab.title)}
            Continue
        }

        # GET PAGE CONTENT
        $PageContent = $null
          #If there is an reference file, grab the contents to inject into the @Content section
        $PageContentPath = Join-Path -Path $TemplatePath -ChildPath $tab.reference
        If(Test-Path $PageContentPath -ErrorAction SilentlyContinue){
            if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Generating [{0}] tab from reference file [{1}]" -f $Tab.title,(Split-Path $PageContentPath -leaf))}
            $PageContent = (Get-Content $PageContentPath -ReadCount 0)
        }
        Else{
            if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Unable to Generate [{0}] tab from reference file [{1}]. File not found, Skipping..." -f $Tab.title,(Split-Path $PageContentPath -leaf))}
            Continue #Go to next iteration in loop
        }
        # PROCESS TAB

        #increment tab count
        $i++

        #Collect Tab details from Definition
        $TabId = ("{0:D2}" -f $i)   # make all tabs are double digits
        $TabTitle = $Tab.title
        #Replace @ORG with ORGName
        $MainTitle = ($Tab.MainTitle.'#cdata-section' -replace '@ORG',$OrgName -replace '"','').Trim()
        $SubTitle = ($Tab.SubTitle.'#cdata-section' -replace '@ORG',$OrgName -replace '"','').Trim()
        $Help = ($Tab.Help.'#cdata-section' -replace '"','').Trim()

        #set the button label appropriately for first and last tabs
        If($i -eq $PaneElements.Count){$NextButtonLabel="Begin"}Else{$NextButtonLabel="Next"}
        If($i -eq 1){
            $BackButtonVisibility="Hidden"
        }
        Else{
            $BackButtonVisibility="Visible"
        }

        #merge tab template to page content
        $PageContent = $TabsContentTemplate -replace '@TabItemContent',$PageContent

        #if margin is in definition, update tab
        If($Tab.tabmargin){
            $r = [regex]'(?i)margin=\"(.*)\"'
            $match = $r.match($PageContent)
            $margin = $match.groups[1].value
            $PageContent = $PageContent -replace $margin, $Tab.tabmargin
        }

        #replace the @ values with content (if exists)
        $PageContent = $PageContent -replace 'tab01',('tab' + $TabId) -replace '@TabTitle',$TabTitle `
                                    -replace '@MainTitle',$MainTitle -replace '@SubTitle',$SubTitle `
                                    -replace '@Backbtn','Back' -replace '@Nextbtn',$NextButtonLabel `
                                    -replace '@Help',$Help `
                                    -replace '@BtnBackVisibility',$BackButtonVisibility `
                                    -replace '@Content',$PageContent

        #replace background color on tabs content
        ## FUTURE: THIS NEEDS TO BE REPLACED BY THEMES CONTROL
        If($BackgroundColor){$PageContent = $PageContent -replace 'Background="#004275"', "Background=`"$BackgroundColor`""}

        #join each tab to a new line
        <#
        # create new XML document with <Packages> root node
        $PSDWizardXML = New-Object Xml
        $PSDWizardXML.AppendChild($PSDWizardXML.CreateElement('TabItem')) | Out-Null

        # load package XML from file and import it into $PSDWizardXML
        $tabitem = New-Object Xml
        $tabitem.Load($StartPageContent)
        $imported = $xml.ImportNode($tabitem.DocumentElement, $true)
        $PSDWizardXML.DocumentElement.AppendChild($imported) | Out-Null

        $PSDWizardXML.Save([Console]::Out)

        #>
        #this joins as a string. The format is still xml, but display is wrapped
        $tabitems += $PageContent -join "`n"  | Out-String
    }
    #determine if tab is horizontal (uses tabpanel property)
    #adjust the tabs width to fit on screen
    If($PSDWizardXAML -contains 'tabpanel'){
        $TabWidth = [Math]::Floor([decimal](($PSDWizardXML.Window.Width - 20) / $PaneElements.Count)) #Round down to fill tabs based on UI width (with 10 margin)
        If($TabWidth -gt 50){$PSDWizardXAML = $PSDWizardXAML -replace 'Width="150"',"Width=""$TabWidth"""}
    }
    #convert XAML to XML
    If($Passthru){
        $PSDWizardUI = $PSDWizardXAML -replace '@TabItems',$tabitems -replace "x:N",'N' -replace '^<Win.*', '<Window' -replace 'Click=".*','/>' -replace 'x:Class=".*',''
    }Else{
        [xml]$PSDWizardUI = $PSDWizardXAML -replace '@TabItems',$tabitems -replace "x:N",'N' -replace '^<Win.*', '<Window' -replace 'Click=".*','/>' -replace 'x:Class=".*',''
    }
    Return $PSDWizardUI
}
#endregion

#region FUNCTION: Export all results
function Export-PSDWizardResult{
    Param(
        $XMLContent,
        $VariablePrefix,
        $Form
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #search through XML for matching VariablePrefix
    $XMLContent.SelectNodes("//*[@Name]") | ? { $_.Name -match "^$VariablePrefix" } | % {
        $control = $Form.FindName($_.Name)
        #get name without prefix
        $name = $_.Name.Substring($VariablePrefix.Length)

        if($name -match 'Password'){
            $value = $control.Password
            #Set-Item -Path tsenv:$name -Value $value
            If($value){Set-TSItem $name -Value $value}
        }
        elseif($name -eq 'ComputerName'){
            $value = $control.Text
            If($value){Set-TSItem OSDComputerName -Value $value}
        }
        elseif($name -eq 'Applications'){
            $apps = Get-TSItem $name -WildCard
            $AppGuids = Set-SelectedApplications -InputObject $apps -FieldObject $_appTabList -Passthru
            $value = $AppGuids
            #Set-TSItem $name -Value $value
        }
        else{
            $value = $control.Text
            If($value){Set-TSItem $name -Value $value}
        }
        Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): {0} is now: {1}" -f $name,$value)

        if($name -eq "TaskSequenceID"){
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking TaskSequenceID for a value..."
            if ($null -eq (Get-TSItem $name -ValueOnly)){
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): TaskSequenceID is empty!!!"
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Re-Running Wizard, TaskSequenceID must not be empty..."
                Show-PSDSimpleNotify -Message "No Task Sequence selected, restarting wizard..."
                Show-PSDWizard
            }Else{
                Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): TaskSequenceID is now: {0}" -f $value)
            }
        }
    }
}
#endregion

#region FUNCTION: Sets all variables
function Set-PSDWizardDefault{
    Param(
        $XMLContent,
        $VariablePrefix,
        $Form,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #search through XML for matching VariablePrefix
    #TEST: $XMLContent=$script:Xaml;$VariablePrefix='TS_';$Form=$script:Wizard
    $XMLContent.SelectNodes("//*[@Name]") | ? { $_.Name -match "^$VariablePrefix" } | % {

        $control = $Form.FindName($_.Name)
        #get name and associated TS value
        $name = $_.Name.Substring($VariablePrefix.Length)
        $value = Get-TSItem $name -ValueOnly
        #Password fields use different property
        if($name -match 'Password'){
            #$control.Password = (Get-Item tsenv:$name).Value
            $control.Password = $value
        }
        elseif($name -eq 'ComputerName'){
            $control.Text = $value
            #Set the OSDComputerName to match ComputerName
            Set-TSItem OSDComputerName -Value $value
        }
        elseif($name -eq 'Applications'){
            $apps = Get-TSItem $name -WildCard
            $AppGuids = Get-SelectedApplications -InputObject $apps -FieldObject $_appTabList -Identifier "Name" -Passthru
            $value = $AppGuids
        }
        else{
            $control.Text = $value
        }
        if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): {0} is set to: {1}" -f $control.Name,$value) -LogLevel 1}
        If($Passthru){(Get-TSItem $name)}
    }
}
#endregion


Function Invoke-PSDWizard{
    Param(
        [parameter(Mandatory=$true)]
        $XamlContent,
        [string]$Title,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

     #[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')       | out-null #creating Windows-based applications
    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows')             | out-null #Encapsulates a Windows Presentation Foundation application.
    [System.Reflection.Assembly]::LoadWithPartialName('System.ComponentModel')      | out-null #systems components and controls and convertors (eg. iNotifyPropertyChanged interface)
    #[System.Reflection.Assembly]::LoadWithPartialName('System.Data')                | out-null #represent the ADO.NET architecture; allows multiple data sources
    [System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration')    | out-null # Call the EnableModelessKeyboardInterop; allows a Windows Forms control on a WPF page.
    [System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')      | out-null #required for WPF
    [System.Reflection.Assembly]::LoadWithPartialName('PresentationCore')           | out-null #required for WPF

    #Load XAML to reader (single threaded)
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$XamlContent)
    try{
        $script:Wizard=[Windows.Markup.XamlReader]::Load($reader)
    }
    catch{
        $ErrorMessage = $_.Exception.Message
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $ErrorMessage" -LogLevel 3
        Throw $ErrorMessage
    }

    # Store objects in PowerShell variables
    $XamlContent.SelectNodes("//*[@Name]") | % {
        if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Creating wizard variable: {0}" -f $_.Name)}
        Set-Variable -Name ($_.Name) -Value $script:Wizard.FindName($_.Name) -Scope Global
    }
    #add title to window
    $script:Wizard.Title = $Title

    #hide the back button on startup
    $_wizBack.Visibility = 'hidden'
    #endregion

    #prepoulate locale (reduce UI lock up)
    #$LocaleList = Get-LocaleInfo
    #region For Task Sequence Tab objects
    # ---------------------------------------------
    #update ID to what in customsettings.ini
    $TS_TaskSequenceID.Text = Get-TSItem TaskSequenceID -ValueOnly
    # start by disabling search
    $_tsTabSearchEnter.IsEnabled = $False
    $_tsTabSearchClear.IsEnabled = $False
    Add-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID'
    #get all available task seqeunces
    $Global:TaskSequencesList = Get-PSDChildItem -path "DeploymentShare:\Task Sequences" -Recurse -Passthru
    
    #endregion
    #region For Task Sequence Tab objects
    # ---------------------------------------------

    #Build Task Sequence Tree
    If($_tsTabTree)
    {
        #update ID to what in customsettings.ini
        $TS_TaskSequenceID.Text = Get-TSItem TaskSequenceID -ValueOnly
        # start by disabling search
        $_tsTabSearchEnter.IsEnabled = $False
        $_tsTabSearchClear.IsEnabled = $False
        Add-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID'
        #get all available task seqeunces
        $Global:TaskSequencesList = Get-PSDChildItem -path "DeploymentShare:\Task Sequences" -Recurse -Passthru
    }
    #endregion

    #region For Device tab objects
    # ---------------------------------------------
    #hide device details is specified

    #OSDComputerName overwrites ComputerName
    If($null -ne $TS_ComputerName.Text){
        $TS_OSDComputerName.Text = (Set-ComputerName $TS_ComputerName.Text)
    }

    #if skipcomputername is YES, hide input unless value is invalid
    If( ((Get-TSItem SkipComputerName -ValueOnly).ToUpper() -eq 'YES') -and ($results -ne $False)){
        Get-FormVariable -Name "_grdDeviceDetails" -Wildcard | Set-UIFieldElement -Visible:$False
    }

    $NetworkSelectionAvailable = $True
    #if the check comes back false; show name
    If((Get-TSItem SkipDomainMembership -ValueOnly).ToUpper() -eq 'YES'){
        $NetworkSelectionAvailable = $false
        Get-FormVariable -Name "_grdNetworkDetails" -Wildcard | Set-UIFieldElement -Visible:$False
    }

    #TODO: Need PSDDomainJoin.ps1 to enable feature
    If('PSDDomainJoin.ps1' -notin (Get-PSDContent -Content "Scripts" -Passthru)){
        $NetworkSelectionAvailable = $false
        Get-FormVariable -Name "JoinDomain" -Wildcard | Set-UIFieldElement -Visible:$False
    }
    #endregion

    #region For Locale Tab objects
    # ---------------------------------------------
    #The display name is different than the actual variable value. (eg. English (United States) --> en-US)
    # first get the current value and convert it to a format the list will compare
    # second populate full list, and preselect the current value
    #$LocaleProperties = @('UILanguage','SystemLocale','UserLocale','TimeZoneName')

    If($TS_UILanguage)
    {
        $CSUILanguage = ConvertFrom-TSVar -HashTable $UILanguageTable -TSVariable 'UILanguage' -Passthru
        Add-PSDWizardComboList -List $UILanguageTable.Keys -ListObject $_locTabLanguage -PreSelect $CSUILanguage
    }

    If($TS_SystemLocale)
    {
        $CSSystemLocale = ConvertFrom-TSVar -HashTable $SystemLocaleTable -TSVariable 'SystemLocale' -Passthru
        Add-PSDWizardComboList -List $SystemLocaleTable.Keys -ListObject $_locTabSystemLocale -PreSelect $CSSystemLocale
    }

    If($TS_KeyboardLocale)
    {
        $KeyboardList = Get-KeyboardLayouts
        $KeyboardLocale = ConvertFrom-TSVar -InputObject $KeyboardList -TSVariable 'KeyboardLocale' -Property 'KeyboardLayout' -Passthru
        Add-PSDWizardComboList -InputObject $KeyboardList -ListObject $_locTabKeyboardLocale -Identifier 'Name' -PreSelect $KeyboardLocale.Name
    }

    If($TS_TimeZoneName)
    {
        $CSTimeZoneName = ConvertFrom-TSVar -HashTable $TimeZoneNameTable -TSVariable 'TimeZoneName' -Passthru
        Add-PSDWizardComboList -List $TimeZoneNameTable.Keys -ListObject $_locTabTimeZoneName -PreSelect $CSTimeZoneName
    }
    #>
    #endregion

    #region For Application Tab objects
    # ---------------------------------------------
    If($_appTabBundles)
    {
        Add-PSDWizardProfiles -SourcePath "DeploymentShare:\Selection Profiles" -ListObject $_appTabBundles
        Add-PSDWizardBundles -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabBundles
    }

    If($_appTabList)
    {
        # start by disabling search
        $_appTabSearchEnter.IsEnabled = $False
        $_appTabSearchClear.IsEnabled = $False
        Add-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Identifier "Name" -Exclude "Bundles"
    }

    #Build Trees
    If($_appTabTree)
    {
        Add-PSDWizardTree -SourcePath "DeploymentShare:\Applications" -TreeObject $_appTabTree -Identifier "Name" -Exclude "Bundles"
    }
    #endregion
    #====================================
    # EVENTS HANDLERS
    #====================================
    #Update list when changed
    $_wizTabControl.Add_SelectionChanged({
        Switch($_wizTabControl.SelectedItem.Header)
        {
            'Deployment Readiness'   {

                                    }

            'Task Sequence'  {
                                #check if preselect tasksequence is within list
                                If($TS_TaskSequenceID.Text -in $Global:TaskSequencesList.ID){
                                    Get-FormVariable -Name "_wizNext" | Set-UIFieldElement -Enable:$True
                                }Else{
                                    Get-FormVariable -Name "_wizNext" | Set-UIFieldElement -Enable:$False
                                }
            }

            'Device Details' {
                                $TS_OSDComputerName.Text = (Set-ComputerName $TS_OSDComputerName.Text)
                                $results = Confirm-ComputerName -ComputerNameObject $TS_OSDComputerName `
                                                                        -OutputObject $_detTabValidation -Passthru
                                $_wizNext.IsEnabled = $results

                                #disable Next if neither radio is select....however if options are not available, don't disable
                                If( ($_JoinWorkgroupRadio.IsChecked -eq $False) -and ($_JoinDomainRadio.IsChecked -eq $False) -and $NetworkSelectionAvailable){
                                    Get-FormVariable -Name "_wizNext" | Set-UIFieldElement -Enable:$False
                                }
            }

            'Administrator Credentials' {
                                            If( -Not[string]::IsNullOrEmpty($TS_AdminPassword.Password)){
                                                $_ConfirmAdminPassword.Password = $TS_AdminPassword.Password
                                            }
                                            $_wizNext.IsEnabled = Confirm-Passwords -PasswordObject $TS_AdminPassword `
                                                                        -ConfirmedPasswordObject $_ConfirmAdminPassword `
                                                                        -OutputObject $_admTabValidation -Passthru
            }

            'Locale and Time' {}

            'Applications' {}
        }
    })

    #region For Task Sequence Tab event handlers
    # -------------------------------------------
    #Grab the text value when cursor leaves (AFTER Typed)
    $_tsTabSearch.AddHandler(
        [System.Windows.Controls.Primitives.TextBoxBase]::GotFocusEvent,
        [System.Windows.RoutedEventHandler]{
            #set a variable if there is text in field BEFORE the new name is typed
            If($_tsTabSearch.Text){
                $script:SearchText = $_tsTabSearch.Text
            }
            $_tsTabSearchEnter.IsEnabled = $True
            $_tsTabSearchClear.IsEnabled = $True
        }
    )

    $_tsTabSearch.AddHandler(
        [System.Windows.Controls.Primitives.TextBoxBase]::LostFocusEvent,
        [System.Windows.RoutedEventHandler]{
            #because there is a example text field in the box by default, check for that
            If($_tsTabSearch.Text -eq 'Search...'){
                $script:SearchText = $_tsTabSearch.Text
                $_tsTabSearchEnter.IsEnabled = $False
                $_tsTabSearchClear.IsEnabled = $False
            }
            ElseIf([string]::IsNullOrEmpty($_tsTabSearch.Text)){
                $_tsTabSearchEnter.IsEnabled = $False
                $_tsTabSearchClear.IsEnabled = $False
            }
            Else{
                $_tsTabSearchEnter.IsEnabled = $True
                $_tsTabSearchClear.IsEnabled = $True
            }
        }
    )

    #Textbox placeholder remove default text when textbox is being used
    $_tsTabSearch.Add_GotFocus({
        #if it has an example
        if ($_tsTabSearch.Text -eq 'Search...') {
            #clear value and make it black bold ready for input
            $_tsTabSearch.Text = ''
            $_tsTabSearch.Foreground = 'Black'
            #should be black while typing....
        }
        #if it does not have an example
        Else{
            #ensure test is black and medium
            $_tsTabSearch.Foreground = 'Black'
        }
    })

    #Textbox placeholder grayed out text when textbox empty and not in being used
    $_tsTabSearch.Add_LostFocus({
        #if text is null (after it has been clicked on which cleared by the Gotfocus event)
        if ($_tsTabSearch.Text -eq '') {
            #add example back in light gray font
            $_tsTabSearch.Foreground = 'Gray'
            $_tsTabSearch.Text = 'Search...'
        }
    })

    #make sure task sequence is selected
    $_tsTabTree.add_SelectedItemChanged({
        $TS_TaskSequenceID.Text = $this.SelectedItem.Tag[2]
        If($TS_TaskSequenceID.Text -in $Global:TaskSequencesList.ID){
            $_wizNext.IsEnabled = $True
        }Else{
            $_wizNext.IsEnabled = $False
        }
    })

    #endregion

    #region For Admin Credentials Tab event handlers
    # -----------------------------------------
    #Grab the text value if cursor is in field
    $TS_AdminPassword.AddHandler(
        [System.Windows.Controls.Primitives.TextBoxBase]::GotFocusEvent,
        [System.Windows.RoutedEventHandler]{
            $_wizNext.IsEnabled = Confirm-Passwords -PasswordObject $TS_AdminPassword -ConfirmedPasswordObject $_ConfirmAdminPassword -OutputObject $_admTabValidation -Passthru
        }
    )

    #Grab the text value when cursor leaves (AFTER Typed)
    $TS_AdminPassword.AddHandler(
        [System.Windows.Controls.Primitives.TextBoxBase]::LostFocusEvent,
        [System.Windows.RoutedEventHandler]{
            $_wizNext.IsEnabled = Confirm-Passwords -PasswordObject $TS_AdminPassword -ConfirmedPasswordObject $_ConfirmAdminPassword -OutputObject $_admTabValidation -Passthru
        }
    )
    #endregion

    #region For Details Tab event handlers
    # -----------------------------------------
    #Grab the text value if cursor is in field
    $TS_OSDComputerName.AddHandler(
        [System.Windows.Controls.Primitives.TextBoxBase]::GotFocusEvent,
        [System.Windows.RoutedEventHandler]{
            $_wizNext.IsEnabled = Confirm-ComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru
        }
    )

    #Grab the text value when cursor leaves (AFTER Typed)
    $TS_OSDComputerName.AddHandler(
        [System.Windows.Controls.Primitives.TextBoxBase]::LostFocusEvent,
        [System.Windows.RoutedEventHandler]{
            $_wizNext.IsEnabled = Confirm-ComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru
        }
    )


    #Disables other option when either Domain or workgroup selected
    [System.Windows.RoutedEventHandler]$Script:CheckedEventHandler = {
        If($_.source.name -eq '_JoinDomainRadio')
        {
            Get-FormVariable -Name "_grdJoinDomain" | Set-UIFieldElement -Enable:$True
            Get-FormVariable -Name "_grdJoinWorkgroup" | Set-UIFieldElement -Enable:$False
            Get-FormVariable -Name "_wizNext" | Set-UIFieldElement -Enable:$True

            if([string]::IsNullOrEmpty($TS_DomainAdminPassword.Password)){
                #$_DomainAdminConfirmPassword.IsEnabled = $True
            }Else{
                $_DomainAdminConfirmPassword.Password = (Get-TSItem DomainAdminPassword -ValueOnly)
                #$_DomainAdminConfirmPassword.IsEnabled = $False
            }
        }

        If($_.source.name -eq '_JoinWorkgroupRadio')
        {
            Get-FormVariable -Name "_grdJoinDomain" | Set-UIFieldElement -Enable:$False
            Get-FormVariable -Name "_grdJoinWorkgroup" | Set-UIFieldElement -Enable:$True
            Get-FormVariable -Name "_wizNext" | Set-UIFieldElement -Enable:$True
        }
    }
    $_detTabLayout.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $CheckedEventHandler)
    #endregion

    #region For Locale Tab event handlers
    # -----------------------------------------
    #Change OSD variables based on selection (format to OSD format)
    $_locTabLanguage.Add_SelectionChanged({
        $TS_UILanguage.Text = ConvertTo-TSVar -HashTable $UILanguageTable -InputValue $_locTabLanguage.SelectedItem
    })

    $_locTabSystemLocale.Add_SelectionChanged({
        $TS_SystemLocale.Text = ConvertTo-TSVar -HashTable $SystemLocaleTable -InputValue $_locTabSystemLocale.SelectedItem
        $TS_UserLocale.Text = $TS_SystemLocale.Text
    })

    $_locTabKeyboardLocale.Add_SelectionChanged({
        $TS_KeyboardLocale.Text = (Get-KeyboardLayouts | Where {$_.Name -eq $_locTabKeyboardLocale.SelectedItem}).KeyboardLayout
    })

    $_locTabTimeZoneName.Add_SelectionChanged({
        $TS_TimeZoneName.Text = ConvertTo-TSVar -HashTable $TimeZoneNameTable -InputValue $_locTabTimeZoneName.SelectedItem
        $TS_TimeZone.Text = Get-TimeZoneIndex -TimeZone ($_locTabTimeZoneName.SelectedItem)
    })
    #endregion

    #region For Application Tab event handlers
    # -----------------------------------------
    #Grab the text value when cursor leaves (AFTER Typed)
    $_appTabSearch.AddHandler(
        [System.Windows.Controls.Primitives.TextBoxBase]::GotFocusEvent,
        [System.Windows.RoutedEventHandler]{
            #set a variable if there is text in field BEFORE the new name is typed
            If($_appTabSearch.Text){
                $script:SearchText = $_appTabSearch.Text
            }
            $_appTabSearchEnter.IsEnabled = $True
            $_appTabSearchClear.IsEnabled = $True
        }
    )

    $_appTabSearch.AddHandler(
        [System.Windows.Controls.Primitives.TextBoxBase]::LostFocusEvent,
        [System.Windows.RoutedEventHandler]{
            #because there is a example text field in the box by default, check for that
            If($_appTabSearch.Text -eq 'Search...'){
                $script:SearchText = $_appTabSearch.Text
                $_appTabSearchEnter.IsEnabled = $False
                $_appTabSearchClear.IsEnabled = $False
            }
            ElseIf([string]::IsNullOrEmpty($_appTabSearch.Text)){
                $_appTabSearchEnter.IsEnabled = $False
                $_appTabSearchClear.IsEnabled = $False
            }
            Else{
                $_appTabSearchEnter.IsEnabled = $True
                $_appTabSearchClear.IsEnabled = $True
            }
        }
    )

    #Textbox placeholder remove default text when textbox is being used
    $_appTabSearch.Add_GotFocus({
        #if it has an example
        if ($_appTabSearch.Text -eq 'Search...') {
            #clear value and make it black bold ready for input
            $_appTabSearch.Text = ''
            $_appTabSearch.Foreground = 'Black'
            #should be black while typing....
        }
        #if it does not have an example
        Else{
            #ensure test is black and medium
            $_appTabSearch.Foreground = 'Black'
        }
    })

    #Textbox placeholder grayed out text when textbox empty and not in being used
    $_appTabSearch.Add_LostFocus({
        #if text is null (after it has been clicked on which cleared by the Gotfocus event)
        if ($_appTabSearch.Text -eq '') {
            #add example back in light gray font
            $_appTabSearch.Foreground = 'Gray'
            $_appTabSearch.Text = 'Search...'
        }
    })

    $_appTabList.Add_SelectionChanged({
        $_appTabList.items
    })

    #endregion

    #region For Main Wizard Template event handlers
    # ---------------------------------------------
    #Change nack and next button display based on tabs
    $_wizTabControl.Add_SelectionChanged({
        $Tabcount = $_wizTabControl.items.count
        #show the back button if next on first page is displayed
        If($_wizTabControl.SelectedIndex -eq 0){
            $_wizBack.Visibility = 'hidden'
        }Else{
            $_wizBack.Visibility = 'Visible'
        }

        #change the button text to display begin on the last tab
        If($_wizTabControl.SelectedIndex -eq ($Tabcount -1)){
            $_wizNext.Content = 'Begin'
        }Else{
            $_wizNext.Content = 'Next'
        }

        #Enable tab click functionality as wizard progresses
        Get-UIFieldElement -Name ("_wizTab{0:d2}" -f $_wizTabControl.SelectedIndex) | Set-UIFieldElement -Enable:$true

    })
    #endregion
    #====================================
    # BUTTON EVENTS
    #====================================

    #region For Start page
    # --------------------
    #if the star button is clicked, hide the start page
    $_Start.Add_Click({
        $_startPage.Visibility = 'hidden'
    })
    #endregion

    #region For Task sequence Tab
    # ---------------------------
    $_tsTabSearchEnter.Add_Click({
        If(-not([string]::IsNullOrEmpty($_tsTabSearch.Text))){
            Search-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID' -Filter $_tsTabSearch.Text
        }
    })

    $_tsTabSearchClear.Add_Click({
        $_tsTabSearch.Text = $null
        $_tsTabSearchEnter.IsEnabled = $False
        Add-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID'
        $_tsTabSearchClear.IsEnabled = $False
    })

    $_tsTabExpand.Add_Click({
        $i=0
        Foreach($item in $_tsTabTree.Items)
        {
            If($_tsTabTree.Items[$i].IsExpanded -ne $true){
                $_tsTabTree.Items[$i].ExpandSubtree()
            }
            $i++
        }

    })

    $_tsTabCollapse.Add_Click({
        $i=0
        Foreach($item in $_tsTabTree.Items)
        {
            If($_tsTabTree.Items[$i].IsExpanded -ne $False){
                $_tsTabTree.Items[$i].IsExpanded = $false;
            }
            $i++
        }
    })
    #endregion

    #region For Application Tab
    # -------------------------

    $_appTabSearchEnter.Add_Click({
        If(-not([string]::IsNullOrEmpty($_appTabSearch.Text))){
            Search-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Filter $_appTabSearch.Text
        }
    })

    $_appTabSearchClear.Add_Click({
        $_appTabSearch.Text = $null
        $_appTabSearchEnter.IsEnabled = $False
        Add-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList
        $_appTabSearchClear.IsEnabled = $False
    })

    $_appTabSelectAll.Add_Click({
        If($_appTabList -and ($_appTabList.items.Count -gt 0)){
            $_appTabList.SelectAll();
        }
    })

    $_appTabSelectNone.Add_Click({
        $_appTabList.SelectedItems.Clear()
    })
    #endregion

    #region For Main Wizard Template
    # ------------------------------
    $_wizNext.Add_Click({
        $Tabcount = $_wizTabControl.items.count
        #if wizard is at the last tab
        If($_wizTabControl.SelectedIndex -eq ($Tabcount -1))
        {
            #need to set a result back
            $Global:WizardDialogResult = $true
            $script:Wizard.Add_Closing({$_.Cancel = $false})
            $script:Wizard.Close()
        }
        Else{
            Switch-TabItem -TabControlObject $_wizTabControl -increment 1
        }
    })

    $_wizBack.Add_Click({
        Switch-TabItem -TabControlObject $_wizTabControl -increment -1
        #if next is diabled; re-enable it
        $_wizNext.IsEnabled = $true
    })

    #close wizard with cancel button
    $_wizCancel.Add_Click({
        $script:Wizard.Add_Closing({$_.Cancel = $false})
        $script:Wizard.Close() | Out-Null
    })
    #endregion

    If($Passthru){
        # Return the results to the caller
        return $script:Wizard
    }
}

#region FUNCTION: Start the wizard
Function Show-PSDWizard{
    Param(
        [Parameter(Mandatory = $false, Position=0)]
        [Alias('XamlPath')]
        [string]$ResourcePath = "$DeployRoot\scripts\PSDWizard",

        [Parameter(Mandatory = $false, Position=1)]
        [string]$XmlDefinitionFile = 'PSDWizard_Definitions_en-US.xml',

        [Parameter(Mandatory = $false)]
        [switch]$AsAsyncJob,

        [Parameter(Mandatory = $false)]
        [switch]$Passthru
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If(Test-Path -Path $ResourcePath -PathType Container)
    {
        $WorkingPath = $ResourcePath -replace '\\$',''
    }
    Else{
        # we don't need the fie; just the path
        $WorkingPath = Split-Path $ResourcePath -Parent
    }
    #Default to false
    $Global:WizardDialogResult = $false
    #Load functions from external file
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Loading PSD Wizard helper script [$WorkingPath\PSDWizard.Initialize.ps1]"
    . "$WorkingPath\PSDWizard.Initialize.ps1"

    #parse changelog for version for a more accurate version
    $ChangeLogPath = Join-Path $ResourcePath 'CHANGELOG.MD'
    If(Test-Path $ChangeLogPath){
        $ChangeLog = Get-Content $ChangeLogPath
        $Changedetails = (($ChangeLog -match '##')[0].TrimStart('##') -split '-').Trim()
        [string]$MenuVersion = [string]$Changedetails[0]
        [string]$MenuDate = $Changedetails[1]
        $Title = "PSD Wizard v$MenuVersion [$MenuDate]"
    }Else{
        $Title = "PSD Wizard v2"
    }

    #Build the XAML file based on definitions
    Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Running [Format-PSDWizard -Path {0} -DefinitionFile {1}]" -f $WorkingPath,$XmlDefinitionFile)
    $script:Xaml = Format-PSDWizard -Path $WorkingPath -DefinitionFile $XmlDefinitionFile

    #load wizard
    Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Running [Invoke-PSDWizard -XamlContent `$script:Xaml -Title `"{0}`" -Passthru]" -f $Title)
    $script:Wizard = Invoke-PSDWizard -XamlContent $script:Xaml -Title "$Title" -Passthru

    #Get Defintions prefix
    [string]$DefinitionsXml = Join-Path -Path $WorkingPath -ChildPath $XMLDefinitionFile
    [Xml.XmlDocument]$DefinitionXmlDoc = Get-Content $DefinitionsXml
    [PSCustomObject]$GlobalElement = Get-PSDWizardDefinitions -Xml $DefinitionXmlDoc -Section Global

    Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Running [Set-PSDWizardDefault -XMLContent `$script:Xaml -VariablePrefix {0} -Form `$script:Wizard]" -f $GlobalElement.TSVariableFieldPrefix)
    Set-PSDWizardDefault -XMLContent $script:Xaml -VariablePrefix $GlobalElement.TSVariableFieldPrefix -Form $script:Wizard

    Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Launching PSD Wizard using definition file: {0}" -f $XmlDefinitionFile)

    if($PSDDeBug -eq $false){
        # Make PowerShell Disappear
        $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
        $asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
        $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
    }

    If($AsAsyncJob){
        $script:Wizard.Add_Closing({
            #$_.Cancel = $true
            [System.Windows.Forms.Application]::Exit()
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Closing PSD Wizard"
        })

        $async = $script:Wizard.Dispatcher.InvokeAsync({

            # Enables a Window to receive keyboard messages correctly when it is opened modelessly from Windows Forms.
            [Void][System.Windows.Forms.Integration.ElementHost]::EnableModelessKeyboardInterop($script:Wizard)

            #make sure this display on top of every window
            $script:Wizard.Topmost = $true
            # https://blog.netnerds.net/2016/01/showdialog-sucks-use-applicationcontexts-instead/
            # ShowDialog shows the form as a modal window.
            # Modal meaning the form cannot lose focus until it's closed and the user can not click on other windows within the same application
            # With Show, the code proceeds to the line after the Show statement by spawning a new thread
            # With ShowDialog, it single threaded and does not continue until closed.
            # Running this without $appContext & ::Run would actually cause a really poor response.
            # https://docs.microsoft.com/en-us/dotnet/desktop/wpf/app-development/how-to-return-a-dialog-box-result?view=netframeworkdesktop-4.8

            $script:Wizard.Show() | Out-Null
            # This makes the form pop up
            $script:Wizard.Activate() | Out-Null
        })
        #Wait for the async is complete before continuing
        $async.Wait() | Out-Null

        ## Force garbage collection to start the wizard with lower RAM usage.
        [System.GC]::Collect() | Out-Null
        [System.GC]::WaitForPendingFinalizers() | Out-Null

        # Create an application context for it to all run within.
        # This helps with responsiveness, especially when exiting.
        $appContext = New-Object System.Windows.Forms.ApplicationContext
        [void][System.Windows.Forms.Application]::Run($appContext)
    }
    Else{
        #make sure window is on top
        $script:Wizard.Topmost = $true
        #disable x button
        $script:Wizard.Add_Closing({$_.Cancel = $true})
        #Slower method to present form for modal (no popups)
        $script:Wizard.ShowDialog() | Out-Null
    }

    #NOTE: Function will not continue until wizard is closed

    #Save all entered results back
    Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Running [Export-PSDWizardDefault -XMLContent `$script:Xaml -VariablePrefix {0} -Form `$script:Wizard]" -f $GlobalElement.TSVariableFieldPrefix)
    Export-PSDWizardResult -XMLContent $script:Xaml -VariablePrefix $GlobalElement.TSVariableFieldPrefix -Form $script:Wizard

    If($Passthru){
        # Return the form results to the caller
        return $Global:WizardDialogResult
    }
}

#Export-ModuleMember -Function Show-PSDWizard,Format-PSDWizard,Invoke-PSDWizard,Set-PSDWizardDefault,Export-PSDWizardResult
Export-ModuleMember -Function Show-PSDWizard