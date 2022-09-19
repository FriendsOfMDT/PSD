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
        Created: 2020-01-12
        Modified: 2022-09-18-13
        Version: 2.2.4b

        SEE CHANGELOG.MD

        Changed Write-PSDlog to confirm with standard

        TODO:
            - Add deployment readiness checks
            - Add refresh event handler
            - build network configuration screen
            - Validate task sequence before showing
            - Show Applications tab if application step in Task seqeunce


.Example
#>

#region FUNCTION: Retrieve definition file sections
Function Get-PSDWizardDefinitions {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        [xml]$xml,

        [parameter(Mandatory = $false)]
        [ValidateSet('Global', 'WelcomeWizard', 'Pane')]
        $Section = 'Global'
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Try {
        [Xml.XmlElement]$WizardElement = $xml.Wizard
    }
    Catch {
        Write-PSDLog -Message ("{0}: Unable to parse xml content definition file: {1} " -f ${CmdletName}, $_.Exception.Message) -LogLevel 3
        Return
    }

    switch ($Section) {
        'Global' { $DefinitionObject = $WizardElement.Global }
        'WelcomeWizard' { $DefinitionObject = $WizardElement.WelcomeWizard }
        'Pane' { $DefinitionObject = $WizardElement.Pane }
        default {}
    }

    Return $DefinitionObject
}
#endregion


#region FUNCTION: Retrieve theme definition file sections
Function Get-PSDWizardThemeDefinitions {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        [xml]$xml,

        [parameter(Mandatory = $false)]
        [ValidateSet('ThemeTemplate', 'PanesTemplate', 'WelcomeWizard', 'Pane')]
        $Section
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Try {
        [Xml.XmlElement]$ThemeElement = $xml.Theme
    }
    Catch {
        Write-PSDLog -Message ("{0}: Unable to parse xml content definition file: {1} " -f ${CmdletName}, $_.Exception.Message) -LogLevel 3
        Return
    }

    switch ($Section) {
        'ThemeTemplate' { $DefinitionObject = $ThemeElement.Global.TemplateReference }
        'WelcomeWizard' { $DefinitionObject = $ThemeElement.Global.WelcomeWizardReference }
        'PanesTemplate' { $DefinitionObject = $ThemeElement.PaneDefinitions.PanesTemplate.'#cdata-section'.Trim() }
        'Pane' { $DefinitionObject = $ThemeElement.PaneDefinitions.Pane }
        default { $DefinitionObject = $ThemeElement }
    }

    If ($AsObject) {
        $DefinitionObject | % {
            $

        }

    }
    Else {
        Return $DefinitionObject
    }

}
#endregion

#region FUNCTION: Retrieve XSL condition statement from definition file
Function Get-PSDWizardCondition {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        [string]$Condition,

        [PSCustomObject]$TSEnvSettings,

        [switch]$Passthru
    )

    #convert each TSEnvSettings object into variables
    #ForEach ($item in $TSEnvSettings | ?{$_.Name -eq 'IsUEFI'}) {
    ForEach ($item in $TSEnvSettings) {
        $Name = $item.Name
        If ($Name -match "^_") {
            $Name = $Name -replace '^_', ''
        }

        #determine if value is boolean
        Try {
            $Value = [boolean]::Parse($item.value)
        }
        Catch {
            $Value = $item.value
        }
        Finally {
            Try {
                Set-Variable -Name $Name -Value $Value | Out-Null
            }
            Catch {}
        }
    }

    #Load functions from external file
    #. "$($global:psddsDeployRoot)\scripts\PSDWizard\PSDWizard.Initialize.ps1"

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
    $Condition = $Condition -replace '<>', ' -ne ' -replace '==', ' -eq ' -replace '=', ' -eq ' -replace '<=', ' -le ' -replace '=>', ' -ge ' -replace '<', '-lt ' -replace '>', ' -gt'

    #Remove quotes from all items in parentheses
    $Condition = $Condition -replace "\([`"|']", '(' -replace "[`"|']\)", ")"
    #remove the UCASE and Property string to make variable
    #$Condition = $Condition -replace "Property\(`"",'$' -replace "`"\)","" -replace 'UCASE\(','' -replace '\)',' '
    #remove the UCASE and Property string to make variable
    If ($Condition -match 'Property') {
        $Condition = $Condition -replace "Property\(", '$' -replace "\)", ""
    }

    #find the properties match and tie them together
    If ($Condition -match 'Properties') {
        #$Matches
        #look for more than one properties
        $PropertiesSearch = $Condition -split ' ' | Where { $_ -match 'Properties\("' }
        #loop through each
        Foreach ($Properties in $PropertiesSearch) {
            #get list name
            $ArrayName = ($Properties -split 'Properties\("')[1] -replace "\(\*\)", ""
            $Values = @()
            #get list values
            $TSEnvSettings | Where { $_.Name -match "$ArrayName\d\d\d" } | ForEach-Object {
                $Values += $_.Value
            }
            #Build array variable
            Remove-Variable -Name "$($ArrayName)List" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Variable -Name "$($ArrayName)List" -Value $Values
            #replace array in string
            $Condition = $Condition.replace("$Properties", "`$$ArrayName`List") -replace "`"\)", ""
        }
        #change operators to powershell operators
        $Condition = $Condition -replace '\bin\b', ' -in '
    }

    If ($Condition -match 'UCASE') {
        $Condition = $Condition -replace 'UCASE\(', '' -replace '\)', ' '
    }

    $Condition = $Condition -replace "`"\)", ""
    #determine if there is multiple condition in one statement, if so, encapsulated each one in parenthesis
    #replace [and] and [or] with proper operators
    If ($Condition -match '\s+or\s+|\s+and\s+') {
        $Condition = '(' + ($Condition -replace '\bor\b', ') -or (' -replace '\band\b', ') -and (') + ')'
    }
    #Change True/false to boolean
    $Condition = $Condition -replace '"True"', '$True' -replace '"False"', '$False'

    #remove any additional spacing
    $Condition = ($Condition -replace '\s+', ' ').Trim()

    #convert condition string into a script
    $scriptblock = [scriptblock]::Create($Condition)
    If ($Passthru) {
        $result = $scriptblock
    }
    Else {
        #evaluate the condition
        $result = Invoke-command $scriptblock
    }

    return $result
}
#endregion


#region FUNCTION: Build the XAML dynamically from definition file
Function Format-PSDWizard {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        [string]$Path,

        [parameter(Mandatory = $true)]
        [Xml.XmlDocument]$LangDefinitions,

        [parameter(Mandatory = $true)]
        [Xml.XmlDocument]$ThemeDefinitions,

        [switch]$Passthru,

        [switch]$Test
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #determine if path is has a file in path or is just a container
    #Make the path the working path
    If (Test-Path -Path $Path -PathType Container) {
        $WorkingPath = $Path -replace '\\$', ''
    }
    Else {
        # we don't need the fie; just the path
        $WorkingPath = Split-Path $Path -Parent
    }

    #Load functions from external file
    #. "$WorkingPath\PSDWizard.Initialize.ps1"

    #TESTS $WorkingPath = "D:\DeploymentShares\PSDRestartUIv2\Scripts\PSDWizardNew\"
    #[string]$PSDWizardPath = (Join-Path -Path $WorkingPath -ChildPath 'PSDWizard')
    [string]$ResourcePath = (Join-Path -Path $WorkingPath -ChildPath 'Resources')
    [string]$TemplatePath = (Join-Path -Path $WorkingPath -ChildPath 'Themes')

    #grab needed elements from Lang definition file
    <#
    TESTS
    $LangDefinitions = Get-content "D:\DeploymentShares\PSDRestartUIv2\Scripts\PSDWizardNew\PSDWizard_Definitions_en-US.xml"
    $ThemeDefinitions = Get-content "D:\DeploymentShares\PSDRestartUIv2\Scripts\PSDWizardNew\Themes\Classic_Theme_Definitions_en-US.xml"
    $ThemeDefinitions = Get-content "D:\DeploymentShares\PSDRestartUIv2\Scripts\PSDWizardNew\Themes\Modern_Theme_Definitions_en-US.xml"
    #>
    #[PSCustomObject]$GlobalElement = Get-PSDWizardDefinitions -Xml $LangDefinitions -Section Global
    [PSCustomObject]$WelcomeElement = Get-PSDWizardDefinitions -Xml $LangDefinitions -Section WelcomeWizard
    [PSCustomObject]$PaneElements = Get-PSDWizardDefinitions -Xml $LangDefinitions -Section Pane

    #build paths to Welcome Wizard start
    $WelcomeWizardFile = Get-PSDWizardThemeDefinitions -xml $ThemeDefinitions -Section WelcomeWizard
    $ThemeTemplateFile = Get-PSDWizardThemeDefinitions -xml $ThemeDefinitions -Section ThemeTemplate

    [string]$XamlWizardTemplatePath = Join-Path -Path $TemplatePath -ChildPath $ThemeTemplateFile
    [string]$StartPagePath = Join-Path -Path $TemplatePath -ChildPath $WelcomeWizardFile

    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Generating PSD Wizard from template file [{1}]" -f ${CmdletName}, (Split-Path $XamlWizardTemplatePath -leaf)) }

    #grab the primary template
    $PSDWizardXAML = (Get-Content $XamlWizardTemplatePath -ReadCount 0) -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'

    If ($Test) {
        $OrgName = "Test ORG Name"
        $SkipSettings = @{SkipWizard = 'NO' }
    }
    Else {
        #grab the SMSTSOrgName from settings
        $OrgName = Get-PSDWizardTSItem 'SMSTSOrgName' -wildcard -ValueOnly
        #fill in the main title and sub title

        #grab all variables that contain skip
        $SkipSettings = Get-PSDWizardTSItem 'Skip' -wildcard
    }

    #determine if welcome wizard is not skipped
    If (Get-PSDWizardCondition -Condition $WelcomeElement.Condition.'#cdata-section' -TSEnvSettings $SkipSettings) {
        If (Test-Path $StartPagePath) {
            #grab the start page content
            $StartPageContent = (Get-Content $StartPagePath -ReadCount 0)
            #insert main and sub title
            $MainTitle = ($WelcomeElement.MainTitle.'#cdata-section' -replace '"', '').Trim()
            $SubTitle = ($WelcomeElement.SubTitle.'#cdata-section' -replace '"', '').Trim()
            $StartPageContent = ($StartPageContent -replace '@MainTitle', $MainTitle).Trim()
            $StartPageContent = ($StartPageContent -replace '@SubTitle', $SubTitle).Trim()
            If ($OrgName) {
                $StartPageContent = ($StartPageContent -replace '@ORG', $OrgName)
            }
            Else {
                $StartPageContent = ($StartPageContent -replace '@ORG', 'PSD')
            }
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Start page was imported [{1}]" -f ${CmdletName}, $StartPagePath) }
        }
        Else {
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: No start page was found [{1}]" -f ${CmdletName}, $StartPagePath) }
            $StartPageContent = ''
        }
    }
    Else {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Conditions states not to load start page" -f ${CmdletName}) }
        $StartPageContent = ''
    }

    #populate the template with start page
    $PSDWizardXAML = $PSDWizardXAML.replace("@StartPage", $StartPageContent)

    #convert XAML to XML just to grab info using xml dot sourcing (Not used to process form)
    [xml]$PSDWizardXML = $PSDWizardXAML

    #grab the list of merged dictionaries in XML, replace the path with Powershell
    $MergedDictionaries = $PSDWizardXML.Window.'Window.Resources'.ResourceDictionary.'ResourceDictionary.MergedDictionaries'.ResourceDictionary.Source

    #grab all resource files
    $Resources = Get-ChildItem $ResourcePath -Filter *.xaml

    # replace the resource path
    foreach ($Source in $MergedDictionaries) {
        $FileName = Split-Path $Source -Leaf
        $SourcePath = $Resources | Where { $_.Name -match $FileName } | Select -ExpandProperty FullName
        #Replace whats in the string version (Not XML version)
        $PSDWizardXAML = $PSDWizardXAML.replace($Source, $SourcePath) #  ($SourcePath -replace "\\","/")
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Updating resource file path [{1}] with new path [{2}]" -f ${CmdletName}, $Source, $SourcePath) }
    }

    #Tab template used to build form
    #Consist of logos, title, subtitle and buttons
    # @content is controlled by definition reference file for pane (aka: Tab)
    $TabsContentTemplate = Get-PSDWizardThemeDefinitions -Xml $ThemeDefinitions -Section PanesTemplate
    #$TabsContentTemplate = $PanesTemplateElements

    If ($Test) {
        $TSEnvSettings = @{}
    }
    Else {
        $TSEnvSettings = (Get-PSDWizardTSItem * -wildcard)
    }

    #Replace Tabcontrol section with tab template
    $tabitems = $null
    #grab all tabs
    $i = 0
    #loop through each page
    #TEST $Tab = $PaneElements[0]
    #TEST $Tab = $PaneElements[6]
    #TEST $Tab = $PaneElements[8]
    ForEach ($Tab in $PaneElements) {
        #$Result = $True
        #loop through each condition to find if ts value matches
        Foreach ($condition in ($Tab.condition.'#cdata-section').Trim()) {
            $Result = Get-PSDWizardCondition -Condition $condition -TSEnvSettings $TSEnvSettings
            If ($Result -eq $false) { Break } #stop this condition loop if false
        }

        #Go to next iteration in loop if ANY condition is false
        If ($Result -eq $false) {
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Condition [{1}] for [{2}] tab is false, Skipping generation of this tab" -f ${CmdletName}, $condition, $Tab.title) }
            Continue
        }

        # GET PAGE CONTENT
        $PageContent = $null
        #If there is an reference file, grab the contents to inject into the @Content section
        $TabDefinitions = (Get-PSDWizardThemeDefinitions -Xml $ThemeDefinitions -Section Pane | Where id -eq $Tab.id)
        $PageContentPath = Join-Path -Path $TemplatePath -ChildPath $TabDefinitions.reference

        If (Test-Path $PageContentPath -PathType Leaf) {
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Generating [{1}] tab from reference file [{2}]" -f ${CmdletName}, $Tab.title, (Split-Path $PageContentPath -leaf)) }
            $PageContent = (Get-Content $PageContentPath -ReadCount 0)
        }
        Else {
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Unable to Generate [{1}] tab from reference file [{2}]. File not found, Skipping..." -f ${CmdletName}, $Tab.title, (Split-Path $PageContentPath -leaf)) }
            Continue #Go to next iteration in loop
        }
        # PROCESS TAB

        #increment tab count
        $i++

        $TabTitle = $Tab.title

        #Replace @ORG with ORGName
        $MainTitle = ($Tab.MainTitle.'#cdata-section' -replace '@ORG', $OrgName -replace '"', '').Trim()
        $SubTitle = ($Tab.SubTitle.'#cdata-section' -replace '@ORG', $OrgName -replace '"', '').Trim()
        $Context = ($Tab.Context.'#cdata-section' -replace '"', '').Trim()
        $Help = ($Tab.Help.'#cdata-section' -replace '"', '').Trim()

        #merge tab template to page content
        $PageContent = $TabsContentTemplate -replace '@TabItemContent', $PageContent

        #replace the @ values with content (if exists)
        <#
        #Collect Tab details from Definition
        $TabId = ("{0:D2}" -f $i)   # make all tabs are double digits

        $PageContent = $PageContent -replace 'tab01',('tab' + $TabId) `
                                    -replace '@TabTitle',$TabTitle `
                                    -replace '@MainTitle',$MainTitle `
                                    -replace '@SubTitle',$SubTitle `
                                    -replace '@Help',$Help `
                                    -replace '@Content',$PageContent
        #>
        $PageContent = $PageContent -replace '@TabTitle', $TabTitle `
            -replace '@MainTitle', $MainTitle `
            -replace '@SubTitle', $SubTitle `
            -replace '@Context', $Context `
            -replace '@Help', $Help `
            -replace '@Content', $PageContent

        #Iterate through CURRENT page content and find any @values
        #If value matches a property in definition, replace it
        $r = [regex]'@\w+'
        $allmatches = $r.matches($PageContent)
        #TEST $Item = $allmatches[1]
        Foreach ($Item in $allmatches) {
            $Property = $Item.Value.TrimStart('@')
            $ReplaceWithValue = $TabDefinitions.$Property

            If ($ReplaceWithValue) {
                if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Replaced [{1}] with [{2}]" -f ${CmdletName}, $Item, $ReplaceWithValue) }
                $PageContent = $PageContent -replace $Item, $ReplaceWithValue
            }
        }

        <#if margin is in definition, update tab
        If($TabDefinitions.margin){
            $r = [regex]'(?i)margin=\"(.*)\"'
            $match = $r.match($PageContent)
            $margin = $match.groups[1].value
            $PageContent = $PageContent -replace $margin, $TabDefinitions.margin
        }
        #>

        #this joins as a string. The format is still xml, but display is wrapped
        $tabitems += $PageContent -join "`n"  | Out-String

        #TODO Do a check of xaml first?
        If ($Test) {
            Try {
                Write-PSDLog -Message ("{0}: Testing Tabitem [{1}] and content against proper format: {2}" -f ${CmdletName}, $Tab.id, $PageContentPath)
                [xml]$PSDWizardTest = $PSDWizardXAML -replace '@TabItems', $tabitems -replace "x:N", 'N' -replace '^<Win.*', '<Window' -replace 'Click=".*', '/>' -replace 'x:Class=".*', ''
                Return $PSDWizardTest.OuterXml
            }
            Catch {
                Write-PSDLog -Message ("{0}: Tabitem [{1}] test failed: {2}" -f ${CmdletName}, $PageContentPath, $_.exception.message) -LogLevel 3
                If ($Passthru) { Return $PSDWizardXAML }
            }
        }
    } #end tab loop

    #determine if tab is horizontal (uses tabpanel property)
    #adjust the tabs width to fit on screen
    If ($PSDWizardXAML -contains 'tabpanel') {
        $TabWidth = [Math]::Floor([decimal](($PSDWizardXML.Window.Width - 20) / $PaneElements.Count)) #Round down to fill tabs based on UI width (with 10 margin)
        If ($TabWidth -gt 50) { $PSDWizardXAML = $PSDWizardXAML -replace 'Width="150"', "Width=""$TabWidth""" }
    }

    #convert XAML to XML
    Try {
        [xml]$PSDWizardUI = $PSDWizardXAML -replace '@TabItems', $tabitems -replace "x:N", 'N' -replace '^<Win.*', '<Window' -replace 'Click=".*', '/>' -replace 'x:Class=".*', ''
    }
    Catch {
        Write-PSDLog -Message ("{0}: Unable to Generate PSD Wizard: {1}" -f ${CmdletName}, $_.exception.message) -LogLevel 3

    }

    If ($Passthru) {
        Return $PSDWizardUI.OuterXml
    }
    Else {
        Return $PSDWizardUI
    }

}
#endregion

#region FUNCTION: Export all results from PSDwizard
function Export-PSDWizardResult {
    [CmdletBinding()]
    Param(
        $XMLContent,
        $VariablePrefix,
        $Form
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #search through XML for matching VariablePrefix
    #Test
    $XMLContent.SelectNodes("//*[@Name]") | ? { $_.Name -match "^$VariablePrefix" } | % {
        Try {
            $control = $Form.FindName($_.Name)
            #get name without prefix
            $name = $_.Name.Substring($VariablePrefix.Length)

            if ($name -match 'Password') {
                $value = $control.Password
                #Set-Item -Path tsenv:$name -Value $value
                If ($value) { Set-PSDWizardTSItem $name -Value $value }
            }
            elseif ($name -eq 'ComputerName') {
                $value = $control.Text
                If ($value) { Set-PSDWizardTSItem 'OSDComputerName' -Value $value }
            }
            elseif ($name -eq 'Applications') {
                $apps = Get-PSDWizardTSItem $name -WildCard
                $AppGuids = Set-PSDWizardSelectedApplications -InputObject $apps -FieldObject $_appTabList -Passthru
                $value = $AppGuids
                #Set-PSDWizardTSItem $name -Value $value
            }
            elseif ($name -eq 'Summary') {
                # Do nothing
            }
            else {
                $value = $control.Text
                If ($value) { Set-PSDWizardTSItem $name -Value $value }
            }
            Write-PSDLog -Message ("{0}: Property {1} is now = {2}" -f ${CmdletName}, $name, $value)

            if ($name -eq "TaskSequenceID") {
                Write-PSDLog -Message ("{0}: Checking TaskSequenceID for a value" -f ${CmdletName})
                if ($null -eq (Get-PSDWizardTSItem $name -ValueOnly)) {
                    Write-PSDLog -Message ("{0}: TaskSequenceID is empty!!!" -f ${CmdletName})
                    Write-PSDLog -Message ("{0}: Re-Running Wizard, TaskSequenceID must not be empty..." -f ${CmdletName})
                    Show-PSDSimpleNotify -Message ("{0}: No Task Sequence selected, restarting wizard..." -f ${CmdletName})
                    Show-PSDWizard
                }
                Else {
                    Write-PSDLog -Message ("{0}: TaskSequenceID is now: {1}" -f ${CmdletName}, $value)
                }
            }
        }
        Catch {}
    }
}
#endregion

#region FUNCTION: Sets all variables for PSD wizard
function Set-PSDWizardDefault {
    [CmdletBinding()]
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
        Try {
            $control = $Form.FindName($_.Name)
            #get name and associated TS value
            $name = $_.Name.Substring($VariablePrefix.Length)
            $value = Get-PSDWizardTSItem $name -ValueOnly
            #Password fields use different property
            if ($name -match 'Password') {
                #$control.Password = (Get-Item tsenv:$name).Value
                $control.Password = $value
            }
            elseif ($name -eq 'ComputerName') {
                $control.Text = $value
                #Set the OSDComputerName to match ComputerName
                Set-PSDWizardTSItem 'OSDComputerName' -Value $value
            }
            elseif ($name -eq 'Applications') {
                $apps = Get-PSDWizardTSItem $name -WildCard
                $AppGuids = Get-PSDWizardSelectedApplications -InputObject $apps -FieldObject $_appTabList -Identifier "Name" -Passthru
                $value = $AppGuids
            }
            elseif ($name -eq 'Summary') {
                # Do nothing
            }
            else {
                $control.Text = $value
            }
            if ($PSDDeBug -eq $true -and $value) { Write-PSDLog -Message ("{0}: [{1}] is set to [{2}]" -f ${CmdletName}, $control.Name, $value) -LogLevel 1 }
            If ($Passthru) { (Get-PSDWizardTSItem $name) }
        }
        Catch {}
    }
}
#endregion

#region FUNCTION: initialize PSDwizard and it functionality
Function Invoke-PSDWizard {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        $XamlContent,
        [string]$ScriptPath,
        [string]$Version,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #Load assembies to display UI
    [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework') #required for WPF

    #Load XAML to reader (single threaded)
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$XamlContent)
    try {
        $script:Wizard = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-PSDLog -Message ("{0}: {1}" -f ${CmdletName}, $ErrorMessage) -LogLevel 3
        Throw $ErrorMessage
    }

    # Store xaml objects as PowerShell variables and add them to a gloabl array to use
    $global:PSDWizardUIElements = @()
    $XamlContent.SelectNodes("//*[@Name]") | % {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Creating wizard variable: {1}" -f ${CmdletName}, $_.Name) }
        $global:PSDWizardUIElements += Set-Variable -Name ($_.Name) -Value $script:Wizard.FindName($_.Name) -Scope Global -PassThru
    }

    #add title to window and version label
    $script:Wizard.Title = "PSD Wizard " + $Version
    $_wizVersion.Content = $Version


    If ($LogoPath = Get-PSDWizardTSItem 'PSDWizardLogo' -ValueOnly) {
        If (Test-Path $LogoPath) {
            $_wizMainLogo.Source = $LogoPath
            $_wizBeginLogo.Source = $LogoPath
        }
    }

    #Allow UI to be dragged around screen
    If ($script:Wizard.WindowStyle -eq 'None') {
        $script:Wizard.Add_MouseLeftButtonDown( {
                $script:Wizard.DragMove()
            })
    }

    #hide the back button on startup
    $_wizBack.Visibility = 'hidden'
    #endregion

    #region For Device Readiness Tab objects
    # ---------------------------------------------
    If ($_depTabProfiles) {
        $WizardSelectionProfile = Get-PSDWizardTSItem 'WizardSelectionProfile' -ValueOnly
        $Profiles = Add-PSDWizardSelectionProfile -ListObject $_depSelectionProfilesList -Passthru
        If ($WizardSelectionProfile -in $Profiles) {
            Get-PSDWizardUIElement -Name "_depSelectionProfilesList" | Set-PSDWizardUIElement -Enable:$True
        }
    }
    #endregion

    #region For Task Sequence Tab objects
    # ---------------------------------------------
    #Build Task Sequence Tree
    If ($_tsTabTree) {
        #update ID to what in customsettings.ini
        $TS_TaskSequenceID.Text = Get-PSDWizardTSItem 'TaskSequenceID' -ValueOnly

        # start by disabling search
        $_tsTabSearchEnter.IsEnabled = $False
        $_tsTabSearchClear.IsEnabled = $False
        If ($_tsTabTree.GetType().Name -eq 'TreeView') {
            Add-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID'
        }
        If ($_tsTabTree.GetType().Name -eq 'ListBox') {
            Add-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID' -PreSelect $TS_TaskSequenceID.Text
        }


        #get all available task seqeunces
        $Global:TaskSequencesList = Get-PSDWizardTSChildItem -path "DeploymentShare:\Task Sequences" -Recurse -Passthru
    }
    #endregion

    #region For Device tab objects



    # ---------------------------------------------
    #hide device details is specified
    #if skipcomputername is YES, hide input unless value is invalid
    If ( ((Get-PSDWizardTSItem 'SkipComputerName' -ValueOnly).ToUpper() -eq 'YES') -and ($results -ne $False)) {
        Get-PSDWizardUIElement -Name "_grdDeviceDetails" | Set-PSDWizardUIElement -Visible:$False
    }

    $NetworkSelectionAvailable = $True
    #if the check comes back false; show name
    If ((Get-PSDWizardTSItem 'SkipDomainMembership' -ValueOnly).ToUpper() -eq 'YES') {
        If ($_JoinDomainRadio.GetType().Name -eq 'RadioButton') {
            $NetworkSelectionAvailable = $false
            Get-PSDWizardUIElement -Name "_grdNetworkDetails" | Set-PSDWizardUIElement -Visible:$False
        }

        If ($_JoinDomainRadio.GetType().Name -eq 'CheckBox') {
            $NetworkSelectionAvailable = $false
            Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Visible:$False
            Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Visible:$False
        }

    }

    <#TODO: Need PSDDomainJoin.ps1 to enable feature
    If('PSDDomainJoin.ps1' -notin (Get-PSDContent -Content "Scripts" -Passthru)){
        $NetworkSelectionAvailable = $false
        Get-PSDWizardUIElement -Name "JoinDomain" -Wildcard | Set-PSDWizardUIElement -Visible:$False
    }
    #>
    #Check the furrent Workgroup/domain values and sets UI appropiately
    If ( -not[string]::IsNullOrEmpty((Get-PSDWizardTSItem 'JoinWorkgroup' -ValueOnly)) ) {
        #SET WORKGROUP UP
        Get-PSDWizardUIElement -Name "_JoinWorkgroupRadio" | Set-PSDWizardUIElement -Checked:$True
        Get-PSDWizardUIElement -Name "_JoinDomainRadio" | Set-PSDWizardUIElement -Checked:$False
        Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Visible:$True

        If ($_JoinDomainRadio.GetType().Name -eq 'CheckBox') {
            Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Visible:$False
        }
        Else {
            Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Enable:$False
        }
    }

    If ( -not[string]::IsNullOrEmpty((Get-PSDWizardTSItem 'JoinDomain' -ValueOnly)) ) {
        #SET DOMAIN UP
        Get-PSDWizardUIElement -Name "_JoinWorkgroupRadio" | Set-PSDWizardUIElement -Checked:$False
        Get-PSDWizardUIElement -Name "_JoinDomainRadio" | Set-PSDWizardUIElement -Checked:$True
        Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Visible:$True

        If ($_JoinDomainRadio.GetType().Name -eq 'CheckBox') {
            Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Visible:$False
        }
        Else {
            Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Enable:$False
        }
    }
    #endregion

    #region For Locale Tab objects
    # ---------------------------------------------
    #The display name is different than the actual variable value. (eg. English (United States) --> en-US)
    # first get the current value and convert it to a format the list will compare
    # second populate full list, and preselect the current value

    #Show the text box values if in debugmode, otherwise hide them


    #$LocaleProperties = @('UILanguage','SystemLocale','UserLocale','TimeZoneName')
    #Get current values from CustomSettigns.ini
    $CSUILanguage = Get-PSDWizardTSItem 'UILanguage' -ValueOnly
    $CSSystemLocale = Get-PSDWizardTSItem 'SystemLocale' -ValueOnly
    $CSKeyboardLocale = Get-PSDWizardTSItem 'KeyboardLocale' -ValueOnly
    $CSTimeZoneName = Get-PSDWizardTSItem 'TimeZoneName' -ValueOnly

    #Grab all Timezones and languages
    $Global:PSDWizardLocales = Get-PSDWizardLocale -Path $ScriptPath -FileName 'PSDListOfLanguages.xml'
    $Global:PSDWizardTimeZoneIndex = Get-PSDWizardTimeZoneIndex -Path $ScriptPath -FileName 'PSDListOfTimeZoneIndex.xml'


    If ($TS_UILanguage) {
        #Show hidden TS_ value element is debug
        If ($PSDDeBug -eq $true) { Get-PSDWizardUIElement -Name "TS_UILanguage" | Set-PSDWizardUIElement -Visible:$True }
        Else { Get-PSDWizardUIElement -Name "TS_UILanguage" | Set-PSDWizardUIElement -Visible:$False }

        #get mapped data of current UILanguage from CustomSettings.ini
        $UILanguage = $Global:PSDWizardLocales | Where { $_.Culture -eq $CSUILanguage }
        #add the entire list of UILangauge and preselect the one from CustomSettings.ini (if exists)
        Add-PSDWizardComboList -InputObject $Global:PSDWizardLocales -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $UILanguage.Name
    }

    If ($TS_SystemLocale) {
        #Show hidden TS_ value element is debug
        If ($PSDDeBug -eq $true) {
            Get-PSDWizardUIElement -Name "TS_SystemLocale" -Wildcard | Set-PSDWizardUIElement -Visible:$True
            Get-PSDWizardUIElement -Name "TS_UserLocale" | Set-PSDWizardUIElement -Visible:$True
        }
        Else {
            Get-PSDWizardUIElement -Name "TS_SystemLocale" | Set-PSDWizardUIElement -Visible:$False
            Get-PSDWizardUIElement -Name "TS_UserLocale" | Set-PSDWizardUIElement -Visible:$False
        }

        #get mapped data of current SystemLocale from CustomSettings.ini
        $SystemLocale = $Global:PSDWizardLocales | Where { $_.Culture -eq $CSSystemLocale }
        #add the entire list of Systemlocale and preselect the one from CustomSettings.ini (if exists)
        If ($_locTabSystemLocale.GetType().Name -eq 'ComboBox') {
            Add-PSDWizardComboList -InputObject $Global:PSDWizardLocales -ListObject $_locTabSystemLocale -Identifier 'Name' -PreSelect $SystemLocale.Name
        }
        If ($_locTabSystemLocale.GetType().Name -eq 'ListBox') {
            Add-PSDWizardList -InputObject $Global:PSDWizardLocales -ListObject $_locTabSystemLocale -Identifier 'Name' -PreSelect $SystemLocale.Name
        }
    }

    If ($TS_KeyboardLocale) {
        #Show hidden TS_ value element is debug
        If ($PSDDeBug -eq $true) { Get-PSDWizardUIElement -Name "TS_KeyboardLocale" | Set-PSDWizardUIElement -Visible:$True }
        Else { Get-PSDWizardUIElement -Name "TS_KeyboardLocale" | Set-PSDWizardUIElement -Visible:$False }

        #get mapped data of current keyboard layout from CustomSettings.ini
        $KeyboardLocale = $Global:PSDWizardLocales | Where { $_.KeyboardLayout -eq $CSKeyboardLocale }
        #add the entire list of keyboard options and preselect the one from CustomSettings.ini (if exists)
        Add-PSDWizardComboList -InputObject $Global:PSDWizardLocales -ListObject $_locTabKeyboardLocale -Identifier 'Name' -PreSelect $KeyboardLocale.Name
    }

    If ($TS_TimeZoneName) {
        #Show hidden TS_ value element is debug
        If ( $PSDDeBug -eq $true ) {
            Get-PSDWizardUIElement -Name "TS_TimeZoneName" | Set-PSDWizardUIElement -Visible:$True
            Get-PSDWizardUIElement -Name "TS_TimeZone" | Set-PSDWizardUIElement -Visible:$True
        }
        Else {
            Get-PSDWizardUIElement -Name "TS_TimeZoneName" | Set-PSDWizardUIElement -Visible:$False
            Get-PSDWizardUIElement -Name "TS_TimeZone" | Set-PSDWizardUIElement -Visible:$False
        }

        #get mapped data of current timezone from CustomSettings.ini
        $TimeZoneName = $Global:PSDWizardTimeZoneIndex | Where { $_.DisplayName -eq $CSTimeZoneName }
        #add the entire list of timezone options and preselect the one from CustomSettings.ini (if exists)
        If ($_locTabTimeZoneName.GetType().Name -eq 'ComboBox') {
            Add-PSDWizardComboList -InputObject $Global:PSDWizardTimeZoneIndex -ListObject $_locTabTimeZoneName -Identifier 'TimeZone' -PreSelect $TimeZoneName.TimeZone
        }
        If ($_locTabTimeZoneName.GetType().Name -eq 'ListBox') {
            Add-PSDWizardList -InputObject $Global:PSDWizardTimeZoneIndex -ListObject $_locTabTimeZoneName -Identifier 'TimeZone' -PreSelect $TimeZoneName.TimeZone
        }
    }
    #endregion

    #region For Application Tab objects
    # ---------------------------------------------
    If ($_appBundlesCmb) {
        $Bundles = Add-PSDWizardBundle -ListObject $_appBundlesCmb -Passthru
        If ($null -eq $Bundles) {
            Get-PSDWizardUIElement -Name "_appBundlesCmb" | Set-PSDWizardUIElement -Enable:$False
        }
    }

    If ($_appTabList) {
        # start by disabling search
        $_appTabSearchEnter.IsEnabled = $False
        $_appTabSearchClear.IsEnabled = $False
        Add-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Identifier "Name" -Exclude "Bundles"
    }

    #Build Trees
    If ($_appTabTree) {
        Add-PSDWizardTree -SourcePath "DeploymentShare:\Applications" -TreeObject $_appTabTree -Identifier "Name" -Exclude "Bundles"
    }

    #Hide all items that are named Validation
    Get-PSDWizardUIElement -Name "TabValidation" -Wildcard | Set-PSDWizardUIElement -Visible:$False

    #endregion
    #====================================
    # EVENTS HANDLERS ON PAGE CHANGE
    #====================================
    #Update list when changed
    $_wizTabControl.Add_SelectionChanged( {
            Switch ($_wizTabControl.SelectedItem.Name) {
                '_wizReadiness' {
                    #currently for version 2.2.2b+ hide the ability to select or use selection profiles
                    Get-PSDWizardUIElement -Name "depSelectionProfiles" -Wildcard | Set-PSDWizardUIElement -Visible:$False
                }


                '_wizTaskSequence' {
                    #PROCESS ON PAGE LOAD
                    #region For Task Sequence Tab event handlers
                    # -------------------------------------------
                    #Grab the text value when cursor leaves (AFTER Typed)
                    $_tsTabSearch.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::GotFocusEvent,
                        [System.Windows.RoutedEventHandler] {
                            #set a variable if there is text in field BEFORE the new name is typed
                            If ($_tsTabSearch.Text) {
                                $script:SearchText = $_tsTabSearch.Text
                            }
                            $_tsTabSearchEnter.IsEnabled = $True
                            $_tsTabSearchClear.IsEnabled = $True
                        }
                    )

                    $_tsTabSearch.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::LostFocusEvent,
                        [System.Windows.RoutedEventHandler] {
                            #because there is a example text field in the box by default, check for that
                            If ($_tsTabSearch.Text -eq 'Search...') {
                                $script:SearchText = $_tsTabSearch.Text
                                $_tsTabSearchEnter.IsEnabled = $False
                                $_tsTabSearchClear.IsEnabled = $False
                            }
                            ElseIf ([string]::IsNullOrEmpty($_tsTabSearch.Text)) {
                                $_tsTabSearchEnter.IsEnabled = $False
                                $_tsTabSearchClear.IsEnabled = $False
                            }
                            Else {
                                $_tsTabSearchEnter.IsEnabled = $True
                                $_tsTabSearchClear.IsEnabled = $True
                            }
                        }
                    )

                    #Textbox placeholder remove default text when textbox is being used
                    $_tsTabSearch.Add_GotFocus( {
                            #if it has an example
                            if ($_tsTabSearch.Text -eq 'Search...') {
                                #clear value and make it black bold ready for input
                                $_tsTabSearch.Text = ''
                                $_tsTabSearch.Foreground = 'Black'
                                #should be black while typing....
                            }
                            #if it does not have an example
                            Else {
                                #ensure test is black and medium
                                $_tsTabSearch.Foreground = 'Black'
                            }
                        })

                    #Textbox placeholder grayed out text when textbox empty and not in being used
                    $_tsTabSearch.Add_LostFocus( {
                            #if text is null (after it has been clicked on which cleared by the Gotfocus event)
                            if ($_tsTabSearch.Text -eq '') {
                                #add example back in light gray font
                                $_tsTabSearch.Foreground = 'Gray'
                                $_tsTabSearch.Text = 'Search...'
                            }
                        })

                    If ($_tsTabTree.GetType().Name -eq 'TreeView') {
                        #make sure task sequence is selected
                        $_tsTabTree.add_SelectedItemChanged( {
                                $TS_TaskSequenceID.Text = $this.SelectedItem.Tag[2]
                                If ($TS_TaskSequenceID.Text -in $Global:TaskSequencesList.ID) {
                                    $_wizNext.IsEnabled = $True
                                }
                                Else {
                                    $_wizNext.IsEnabled = $False
                                }
                            })
                    }

                    If ($_tsTabTree.GetType().Name -eq 'ListBox') {
                        $_tsTabTree.add_SelectionChanged( {
                                $TS_TaskSequenceID.Text = $this.SelectedItem
                                If ($TS_TaskSequenceID.Text -in $Global:TaskSequencesList.ID) {
                                    $_wizNext.IsEnabled = $True
                                }
                                Else {
                                    $_wizNext.IsEnabled = $False
                                }
                            })
                    }


                    #check if preselect tasksequence is within list
                    If ($TS_TaskSequenceID.Text -in $Global:TaskSequencesList.ID) {
                        Get-PSDWizardUIElement -Name "_wizNext" | Set-PSDWizardUIElement -Enable:$True
                    }
                    Else {
                        Get-PSDWizardUIElement -Name "_wizNext" | Set-PSDWizardUIElement -Enable:$False
                    }

                    #LIVE SEARCH
                    $_tsTabSearch.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            If (-not([string]::IsNullOrEmpty($_tsTabSearch.Text))) {
                                If ($_tsTabTree.GetType().Name -eq 'TreeView') {
                                    Search-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID' -Filter $_tsTabSearch.Text
                                }
                                If ($_tsTabTree.GetType().Name -eq 'ListBox') {
                                    Search-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID' -Filter $_tsTabSearch.Text
                                }
                            }

                        }
                    )

                    # BUTTON EVENTS
                    # ---------------------------
                    $_tsTabSearchEnter.Add_Click( {
                            If (-not([string]::IsNullOrEmpty($_tsTabSearch.Text))) {
                                If ($_tsTabTree.GetType().Name -eq 'TreeView') {
                                    Search-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID' -Filter $_tsTabSearch.Text
                                }
                                If ($_tsTabTree.GetType().Name -eq 'ListBox') {
                                    Search-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID' -Filter $_tsTabSearch.Text
                                }
                            }
                        })

                    $_tsTabSearchClear.Add_Click( {
                            $_tsTabSearch.Text = $null
                            $_tsTabSearchEnter.IsEnabled = $False
                            If ($_tsTabTree.GetType().Name -eq 'TreeView') {
                                Add-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID'
                            }
                            If ($_tsTabTree.GetType().Name -eq 'ListBox') {
                                Add-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID' -PreSelect $TS_TaskSequenceID.Text
                            }

                            $_tsTabSearchClear.IsEnabled = $False
                        })

                    If ($_tsTabTree.GetType().Name -eq 'TreeView') {
                        $_tsTabExpand.Add_Click( {
                                $i = 0
                                Foreach ($item in $_tsTabTree.Items) {
                                    If ($_tsTabTree.Items[$i].IsExpanded -ne $true) {
                                        $_tsTabTree.Items[$i].ExpandSubtree()
                                    }
                                    $i++
                                }

                            })

                        $_tsTabCollapse.Add_Click( {
                                $i = 0
                                Foreach ($item in $_tsTabTree.Items) {
                                    If ($_tsTabTree.Items[$i].IsExpanded -ne $False) {
                                        $_tsTabTree.Items[$i].IsExpanded = $false;
                                    }
                                    $i++
                                }
                            })
                    }
                    #endregion

                    #Hide the text box if not in debugmode
                    If ( $PSDDeBug -eq $true ) {
                        Get-PSDWizardUIElement -Name "TS_TaskSequenceID" | Set-PSDWizardUIElement -Visible:$True
                    }
                    Else {
                        Get-PSDWizardUIElement -Name "TS_TaskSequenceID" | Set-PSDWizardUIElement -Visible:$False
                    }

                } #end Tasksequence switch value

                '_wizComputerName' {
                    #RUN EVENTS ON PAGE LOAD
                    #Check what value is provided by computer name and rebuild it based on supported variables
                    # Any variables declared in CustoSettings.ini are supported + variables with %SERIAL% or %RAND%
                    If ( $CompName = Get-PSDWizardTSItem 'ComputerName' -ValueOnly ) {
                        $TS_OSDComputerName.Text = (Get-PSDWizardComputerName $CompName)
                    }
                    If ( $CompName = Get-PSDWizardTSItem 'OSDComputerName' -ValueOnly ) {
                        $TS_OSDComputerName.Text = (Get-PSDWizardComputerName $CompName)
                    }

                    $_wizNext.IsEnabled = (Confirm-PSDWizardComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru)

                    $TS_OSDComputerName.Add_GotFocus( {
                            #Check initial name
                            $_wizNext.IsEnabled = (Confirm-PSDWizardComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru)
                            #CHECK VALUE AS TYPED
                            $TS_OSDComputerName.AddHandler(
                                [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                                [System.Windows.RoutedEventHandler] {
                                    $_wizNext.IsEnabled = (Confirm-PSDWizardComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru)
                                }
                            )
                        })

                }

                '_wizDomainSettings' {

                    #when page loads, check current status
                    If (($_JoinDomainRadio.IsChecked -eq $False) -and ([string]::IsNullOrEmpty($TS_JoinDomain.text)) ) {
                        #DO WORKGROUP ACTIONS
                        Get-PSDWizardUIElement -Name "Domain" -Wildcard | Set-PSDWizardUIElement -BorderColor '#FFABADB3'
                        Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Visible:$True
                        Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Visible:$False

                        If ([string]::IsNullOrEmpty($TS_JoinWorkgroup.Text)) {
                            Get-PSDWizardUIElement -Name "_wizNext" | Set-PSDWizardUIElement -Enable:$False
                        }
                        Else {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
                        }
                    }
                    Else {
                        #DO DOMAIN ACTIONS
                        Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Visible:$False
                        Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Visible:$True
                        Get-PSDWizardUIElement -Name "Workgroup" -Wildcard | Set-PSDWizardUIElement -BorderColor '#FFABADB3'

                        $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_JoinDomain -OutputObject $_detTabValidation2 -Passthru)
                        $_wizNext.IsEnabled = (Confirm-PSDWizardUserName -UserNameObject $TS_DomainAdmin -OutputObject $_detTabValidation2 -Passthru)
                        $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_DomainAdminDomain -OutputObject $_detTabValidation2 -Passthru)

                        If ( [string]::IsNullOrEmpty($TS_DomainAdminPassword.Password)) {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_DomainAdminPassword -ConfirmedPasswordObject $_DomainAdminConfirmPassword -OutputObject $_detTabValidation2 -Passthru)
                        }
                        Else {
                            $_DomainAdminConfirmPassword.Password = $TS_DomainAdminPassword.Password
                        }

                    }

                    #RUN EVENTS ON CHECK CHANGE
                    [System.Windows.RoutedEventHandler]$Script:CheckedEventHandler = {
                        Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Visible:$False
                        Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Visible:$True
                        Get-PSDWizardUIElement -Name "Workgroup" -Wildcard | Set-PSDWizardUIElement -BorderColor '#FFABADB3'

                        $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_JoinDomain -OutputObject $_detTabValidation2 -Passthru)
                        $_wizNext.IsEnabled = (Confirm-PSDWizardUserName -UserNameObject $TS_DomainAdmin -OutputObject $_detTabValidation2 -Passthru)
                        $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_DomainAdminDomain -OutputObject $_detTabValidation2 -Passthru)

                        If ( [string]::IsNullOrEmpty($TS_DomainAdminPassword.Password)) {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_DomainAdminPassword -ConfirmedPasswordObject $_DomainAdminConfirmPassword -OutputObject $_detTabValidation2 -Passthru)
                        }
                        Else {
                            $_DomainAdminConfirmPassword.Password = $TS_DomainAdminPassword.Password
                        }
                    }
                    #Do DOMAIN actions when checked
                    $_JoinDomainRadio.AddHandler([System.Windows.Controls.CheckBox]::CheckedEvent, $CheckedEventHandler)


                    [System.Windows.RoutedEventHandler]$Script:UnCheckedEventHandler = {
                        Get-PSDWizardUIElement -Name "Domain" -Wildcard | Set-PSDWizardUIElement -BorderColor '#FFABADB3'
                        Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Visible:$True
                        Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Visible:$False

                        If ([string]::IsNullOrEmpty($TS_JoinWorkgroup.Text)) {
                            Get-PSDWizardUIElement -Name "_wizNext" | Set-PSDWizardUIElement -Enable:$False
                        }
                        Else {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
                        }
                    }
                    #Do WORKGROUP action when unchecked
                    $_JoinDomainRadio.AddHandler([System.Windows.Controls.CheckBox]::UncheckedEvent, $UnCheckedEventHandler)

                    $TS_JoinWorkgroup.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                    $TS_DomainAdminPassword.AddHandler(
                        [System.Windows.Controls.PasswordBox]::PasswordChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_DomainAdminPassword -ConfirmedPasswordObject $_DomainAdminConfirmPassword -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                    $_DomainAdminConfirmPassword.AddHandler(
                        [System.Windows.Controls.PasswordBox]::PasswordChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_DomainAdminPassword -ConfirmedPasswordObject $_DomainAdminConfirmPassword -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                    $TS_JoinDomain.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_JoinDomain -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                    $TS_DomainAdminDomain.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_DomainAdminDomain -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                    $TS_DomainAdmin.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardUserName -UserNameObject $TS_DomainAdmin -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                } #end device switch value

                '_wizDeviceDetails' {


                    $_wizNext.IsEnabled = (Confirm-PSDWizardComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru)

                    $TS_OSDComputerName.Add_GotFocus( {
                            #Check initial name
                            $_wizNext.IsEnabled = (Confirm-PSDWizardComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru)
                            #CHECK VALUE AS TYPED
                            $TS_OSDComputerName.AddHandler(
                                [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                                [System.Windows.RoutedEventHandler] {
                                    $_wizNext.IsEnabled = (Confirm-PSDWizardComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru)
                                }
                            )
                        })

                    #disable Next if neither radio is select....however if options are not available, don't disable
                    If ( ($_JoinWorkgroupRadio.IsChecked -eq $False) -and ($_JoinDomainRadio.IsChecked -eq $False) -and $NetworkSelectionAvailable) {
                        Get-PSDWizardUIElement -Name "_wizNext" | Set-PSDWizardUIElement -Enable:$False
                    }
                    ElseIf ($_JoinDomainRadio.IsChecked -eq $True) {
                        Get-PSDWizardUIElement -Name "Workgroup" -Wildcard | Set-PSDWizardUIElement -BorderColor '#FFABADB3'
                        Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Enable:$True
                        Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Enable:$False

                        $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_JoinDomain -OutputObject $_detTabValidation2 -Passthru)
                        $_wizNext.IsEnabled = (Confirm-PSDWizardUserName -UserNameObject $TS_DomainAdmin -OutputObject $_detTabValidation2 -Passthru)
                        $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_DomainAdminDomain -OutputObject $_detTabValidation2 -Passthru)

                        If ( [string]::IsNullOrEmpty($TS_DomainAdminPassword.Password)) {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_DomainAdminPassword -ConfirmedPasswordObject $_DomainAdminConfirmPassword -OutputObject $_detTabValidation2 -Passthru)
                        }
                        Else {
                            $_DomainAdminConfirmPassword.Password = $TS_DomainAdminPassword.Password
                        }
                    }
                    ElseIf ($_JoinWorkgroupRadio.IsChecked -eq $True) {
                        Get-PSDWizardUIElement -Name "Domain" -Wildcard | Set-PSDWizardUIElement -BorderColor '#FFABADB3'
                        Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Enable:$False
                        Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Enable:$True

                        If ([string]::IsNullOrEmpty($TS_JoinWorkgroup.Text)) {
                            Get-PSDWizardUIElement -Name "_wizNext" | Set-PSDWizardUIElement -Enable:$False
                        }
                        Else {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
                        }
                    }

                    #RUN EVENTS ON SELECTION CHANGE
                    #Disables other option when either Domain or workgroup selected
                    $_detTabLayout.AddHandler(
                        [System.Windows.Controls.RadioButton]::CheckedEvent,
                        [System.Windows.RoutedEventHandler] {
                            If ($_.source.name -eq '_JoinDomainRadio') {
                                Get-PSDWizardUIElement -Name "Workgroup" -Wildcard | Set-PSDWizardUIElement -BorderColor '#FFABADB3'
                                Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Enable:$True
                                Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Enable:$False

                                $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_JoinDomain -OutputObject $_detTabValidation2 -Passthru)
                                $_wizNext.IsEnabled = (Confirm-PSDWizardUserName -UserNameObject $TS_DomainAdmin -OutputObject $_detTabValidation2 -Passthru)
                                $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_DomainAdminDomain -OutputObject $_detTabValidation2 -Passthru)

                                if ([string]::IsNullOrEmpty($TS_DomainAdminPassword.Password)) {
                                    $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_DomainAdminPassword -ConfirmedPasswordObject $_DomainAdminConfirmPassword -OutputObject $_detTabValidation2 -Passthru)
                                }
                                Else {
                                    $_DomainAdminConfirmPassword.Password = (Get-PSDWizardTSItem 'DomainAdminPassword' -ValueOnly)
                                }
                            }

                            If ($_.source.name -eq '_JoinWorkgroupRadio') {
                                Get-PSDWizardUIElement -Name "Domain" -Wildcard | Set-PSDWizardUIElement -BorderColor '#FFABADB3'
                                Get-PSDWizardUIElement -Name "_grdJoinDomain" | Set-PSDWizardUIElement -Enable:$False
                                Get-PSDWizardUIElement -Name "_grdJoinWorkgroup" | Set-PSDWizardUIElement -Enable:$True

                                $TS_JoinWorkgroup.AddHandler(
                                    [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                                    [System.Windows.RoutedEventHandler] {
                                        $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
                                    }
                                )

                                If ([string]::IsNullOrEmpty($TS_JoinWorkgroup.Text)) {
                                    Get-PSDWizardUIElement -Name "_wizNext" | Set-PSDWizardUIElement -Enable:$False
                                }
                                Else {
                                    $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
                                }
                            }
                        }
                    )



                    $TS_DomainAdminPassword.AddHandler(
                        [System.Windows.Controls.PasswordBox]::PasswordChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_DomainAdminPassword -ConfirmedPasswordObject $_DomainAdminConfirmPassword -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                    $_DomainAdminConfirmPassword.AddHandler(
                        [System.Windows.Controls.PasswordBox]::PasswordChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_DomainAdminPassword -ConfirmedPasswordObject $_DomainAdminConfirmPassword -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                    $TS_JoinDomain.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_JoinDomain -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                    $TS_DomainAdminDomain.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_DomainAdminDomain -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                    $TS_DomainAdmin.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardUserName -UserNameObject $TS_DomainAdmin -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                    $TS_JoinWorkgroup.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
                        }
                    )

                } #end device switch value

                '_wizAdminAccount' {
                    #currently for version 2.2.2b+ hide the ability to add additional local admin accounts
                    Get-PSDWizardUIElement -Name "OSDAddAdmin" -wildcard | Set-PSDWizardUIElement -Visible:$False

                    #PROCESS ON PAGE LOAD
                    If ( -Not[string]::IsNullOrEmpty($TS_AdminPassword.Password)) {
                        $_ConfirmAdminPassword.Password = $TS_AdminPassword.Password
                    }
                    $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_AdminPassword -ConfirmedPasswordObject $_ConfirmAdminPassword -OutputObject $_admTabValidation -Passthru)

                    #CHECK VALUE AS TYPED
                    $TS_AdminPassword.AddHandler(
                        [System.Windows.Controls.PasswordBox]::PasswordChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_AdminPassword -ConfirmedPasswordObject $_ConfirmAdminPassword -OutputObject $_admTabValidation -Passthru)
                        }
                    )

                    $_ConfirmAdminPassword.AddHandler(
                        [System.Windows.Controls.PasswordBox]::PasswordChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_AdminPassword -ConfirmedPasswordObject $_ConfirmAdminPassword -OutputObject $_admTabValidation -Passthru)
                        }
                    )

                } #end Admin creds switch value

                '_wizLocaleTime' {
                    $DefaultLocale = 'en-US'
                    $DefaultTimeZone = 'Pacific Standard Time'
                    #Grab all Timezones and languages
                    #$Global:PSDWizardTimeZoneIndex = Get-PSDWizardTimeZoneIndex
                    #$Global:PSDWizardLocales = Get-PSDWizardLocale
                    #PROCESS ON PAGE LOAD
                    #region For Locale Tab event handlers
                    # -----------------------------------------
                    #Change OSD variables based on selection (format to OSD format)
                    #$PSDLocaleData = Get-Content "$ScriptPath\PSDListOfLanguages.xml"
                    <#TEST
                    $_locTabLanguage = "" | Select SelectedItem
                    $_locTabLanguage.SelectedItem = 'English (United States)'
                #>
                    $_locTabLanguage.Add_SelectionChanged( {
                            #$TS_UILanguage.Text = ($Global:PSDWizardLocales | Where {$_.Name -eq $_locTabLanguage.SelectedItem}).Culture
                            #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
                            $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $_locTabLanguage.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $DefaultLocale)
                        })

                    $_locTabSystemLocale.Add_SelectionChanged( {
                            #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
                            $MappedLocale = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $_locTabSystemLocale.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $DefaultLocale)
                            $TS_SystemLocale.Text = $MappedLocale
                            $TS_UserLocale.Text = $MappedLocale
                        })

                    $_locTabKeyboardLocale.Add_SelectionChanged( {
                            #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
                            $TS_KeyboardLocale.Text = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $_locTabKeyboardLocale.SelectedItem -MappedProperty 'Name' -SelectedProperty 'KeyboardLayout')

                            If ([string]::IsNullOrEmpty($TS_KeyboardLocale.Text) ) {
                                $TS_KeyboardLocale.Text = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $_locTabKeyboardLocale.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $DefaultLocale)
                            }

                            If ($TS_InputLocale -and [string]::IsNullOrEmpty($TS_KeyboardLocale.Text) ) {
                                $TS_InputLocale.Text = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $_locTabKeyboardLocale.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $DefaultLocale)
                                $TS_KeyboardLocale.Text = $TS_InputLocale.Text
                            }
                        })

                    $_locTabTimeZoneName.Add_SelectionChanged( {
                            $MappedTimeZone = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardTimeZoneIndex -InputValue $_locTabTimeZoneName.SelectedItem -MappedProperty 'TimeZone' -DefaultValueOnNull $DefaultTimeZone)
                            $TS_TimeZoneName.Text = $MappedTimeZone.DisplayName
                            #$TS_TimeZone.Text = ('{0:d3}' -f [int]$MappedTimeZone.id).ToString()

                        })
                    #endregion

                } #end locale and time switch value

                '_wizLanguage' {
                    $DefaultLocale = 'en-US'
                    $_locTabSystemLocale.Add_SelectionChanged( {
                            If ($_locTabSystemLocale.GetType().Name -eq 'ListBox' ) {

                                $SelectedLocale = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $_locTabSystemLocale.SelectedItem -MappedProperty 'Name' -DefaultValueOnNull $DefaultLocale)
                                $TS_UILanguage.Text = $SelectedLocale.Culture
                                $TS_SystemLocale.Text = $SelectedLocale.Culture
                                $TS_UserLocale.Text = $SelectedLocale.Culture
                                $TS_KeyboardLocale.Text = $SelectedLocale.KeyboardLayout
                                $_locTabSystemLocale.SelectedIndex
                                $_locTabSystemLocale.SelectedItem
                            }
                        })
                } #end locale switch value


                '_wizTimeZone' {
                    $DefaultTimeZone = 'Pacific Standard Time'
                    $_locTabTimeZoneName.Add_SelectionChanged( {
                            $MappedTimeZone = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardTimeZoneIndex -InputValue $_locTabTimeZoneName.SelectedItem -MappedProperty 'TimeZone' -DefaultValueOnNull $DefaultTimeZone)
                            $TS_TimeZoneName.Text = $MappedTimeZone.DisplayName
                            #$TS_TimeZone.Text = ('{0:d3}' -f [int]$MappedTimeZone.id).ToString()
                        })
                    #endregion
                } #end timezone switch value

                '_wizApplications' {
                    #currently for version 2.2.2b+ hide the ability to select applications using bundles
                    Get-PSDWizardUIElement -Name "appBundles" -wildcard | Set-PSDWizardUIElement -Visible:$False

                    #PROCESS ON PAGE LOAD
                    #region For Application Tab event handlers
                    # -----------------------------------------
                    #Grab the text value when cursor leaves (AFTER Typed)
                    $_appTabSearch.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::GotFocusEvent,
                        [System.Windows.RoutedEventHandler] {
                            #set a variable if there is text in field BEFORE the new name is typed
                            If ($_appTabSearch.Text) {
                                $script:SearchText = $_appTabSearch.Text
                            }
                            $_appTabSearchEnter.IsEnabled = $True
                            $_appTabSearchClear.IsEnabled = $True
                        }
                    )

                    $_appTabSearch.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::LostFocusEvent,
                        [System.Windows.RoutedEventHandler] {
                            #because there is a example text field in the box by default, check for that
                            If ($_appTabSearch.Text -eq 'Search...') {
                                $script:SearchText = $_appTabSearch.Text
                                $_appTabSearchEnter.IsEnabled = $False
                                $_appTabSearchClear.IsEnabled = $False
                            }
                            ElseIf ([string]::IsNullOrEmpty($_appTabSearch.Text)) {
                                $_appTabSearchEnter.IsEnabled = $False
                                $_appTabSearchClear.IsEnabled = $False
                            }
                            Else {
                                $_appTabSearchEnter.IsEnabled = $True
                                $_appTabSearchClear.IsEnabled = $True
                            }
                        }
                    )

                    #Textbox placeholder remove default text when textbox is being used
                    $_appTabSearch.Add_GotFocus( {
                            #if it has an example
                            if ($_appTabSearch.Text -eq 'Search...') {
                                #clear value and make it black bold ready for input
                                $_appTabSearch.Text = ''
                                $_appTabSearch.Foreground = 'Black'
                                #should be black while typing....
                            }
                            #if it does not have an example
                            Else {
                                #ensure test is black and medium
                                $_appTabSearch.Foreground = 'Black'
                            }
                        })

                    #Textbox placeholder grayed out text when textbox empty and not in being used
                    $_appTabSearch.Add_LostFocus( {
                            #if text is null (after it has been clicked on which cleared by the Gotfocus event)
                            if ($_appTabSearch.Text -eq '') {
                                #add example back in light gray font
                                $_appTabSearch.Foreground = 'Gray'
                                $_appTabSearch.Text = 'Search...'
                            }
                        })

                    $_appTabList.Add_SelectionChanged( {
                            $_appTabList.items

                        })


                    #LIVE SEARCH
                    $_appTabSearch.AddHandler(
                        [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                        [System.Windows.RoutedEventHandler] {
                            If (-not([string]::IsNullOrEmpty($_appTabSearch.Text))) {
                                Search-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Identifier "Name" -Filter $_appTabSearch.Text
                            }
                        }
                    )

                    # BUTTON EVENTS
                    # -------------------------

                    $_appTabSearchEnter.Add_Click( {
                            If (-not([string]::IsNullOrEmpty($_appTabSearch.Text))) {
                                Search-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Identifier "Name" -Filter $_appTabSearch.Text
                            }
                        })

                    $_appTabSearchClear.Add_Click( {
                            $_appTabSearch.Text = $null
                            $_appTabSearchEnter.IsEnabled = $False
                            Add-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Identifier "Name" -Exclude "Bundles"
                            $_appTabSearchClear.IsEnabled = $False
                        })

                    $_appTabSelectAll.Add_Click( {
                            If ($_appTabList -and ($_appTabList.items.Count -gt 0)) {
                                $_appTabList.SelectAll();
                            }
                        })

                    $_appTabSelectNone.Add_Click( {
                            $_appTabList.SelectedItems.Clear()
                        })

                    # Grab all selected apps a output as a list  like string (viewable by wizard summary)
                    # We don't need to process each one with its own variables (eg. Application001, Applications002, etc),
                    # the Export-PSDWizardResult cmdlet does that
                    $TS_Applications.text = $_appTabList.SelectedItems -join "`n"
                    #endregion

                } #end Application switch

                '_wizReady' {
                    #Collect all TS_* variables and their values
                    $NewTSVars = Get-PSDWizardUIElement -Name "TS_" -Wildcard | Select-Object -Property @{Name = 'Name'; Expression = { $_.Name.replace('TS_', '') } }, @{Name = 'Value'; Expression = { $_.Text } }
                    #Add list to output screen
                    Add-PSDWizardListView -UIObject $_summary -ItemData $NewTSVars
                } #end Summary switch

            } #end all tabs switch
        }) #end change event



    #region For Main Wizard Template event handlers
    # ---------------------------------------------
    #Change nack and next button display based on tabs
    $_wizTabControl.Add_SelectionChanged( {
            $Tabcount = $_wizTabControl.items.count
            #show the back button if next on first page is displayed
            If ($_wizTabControl.SelectedIndex -eq 0) {
                $_wizBack.Visibility = 'hidden'
            }
            Else {
                $_wizBack.Visibility = 'Visible'
            }

            #change the button text to display begin on the last tab
            If ($_wizTabControl.SelectedIndex -eq ($Tabcount - 1)) {
                $_wizNext.Content = 'Begin'

                $script:Wizard.Add_KeyDown( {
                        if ($_.Key -match 'Return') {
                            #need to set a result back to true when Begin is clicked
                            $Global:WizardDialogResult = $true
                            $script:Wizard.Add_Closing( { $_.Cancel = $false })
                            $script:Wizard.Close()
                        }
                    })

            }
            Else {
                $_wizNext.Content = 'Next'

                #Use tab on keyboard to navigate mentu forward (only works until last page)
                $script:Wizard.Add_KeyDown( {
                        if ( ($_.Key -match 'Tab') -and ($_wizNext.IsEnabled -eq $True) ) {
                            Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -increment 1
                        }
                    })
            }

            #Enable tab click functionality as wizard progress
            Get-PSDWizardUIElement -Name ("_wizTab{0:d2}" -f $_wizTabControl.SelectedIndex) | Set-PSDWizardUIElement -Enable:$true -ErrorAction SilentlyContinue

        })
    #endregion
    #====================================
    # BUTTON EVENTS
    #====================================

    #region For Start page
    # --------------------
    #Start page may not be rendered if SkipWelcome is set to YES, so attempt to bind buttons
    Try {
        #if the start button is clicked, hide the start page
        $_Start.Add_Click( {
                $_startPage.Visibility = 'hidden'
            })

        $_startPageOpenPS.Add_Click( {
            If(Test-InWinPE){
                Start-Process 'powershell.exe' -WorkingDirectory 'X:\'
            }Else{
                Start-Process 'powershell.exe' -WorkingDirectory $env:windir
            }
        })
    }
    Catch {}
    #endregion

    #region For Main Wizard Template
    # ------------------------------
    $_wizNext.Add_Click( {
            $Tabcount = $_wizTabControl.items.count
            #if wizard is at the last tab
            If ($_wizTabControl.SelectedIndex -eq ($Tabcount - 1)) {
                #need to set a result back to true when Begin is clicked
                $Global:WizardDialogResult = $true
                $script:Wizard.Add_Closing( { $_.Cancel = $false })
                $script:Wizard.Close()
            }
            Else {
                Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -increment 1
            }
        })

    $_wizBack.Add_Click( {
            Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -increment -1
            #if next is diabled; re-enable it
            $_wizNext.IsEnabled = $true
        })

    #close wizard with cancel button
    $_wizCancel.Add_Click( {
            $script:Wizard.Add_Closing( { $_.Cancel = $false })
            $script:Wizard.Close() | Out-Null
        })
    #endregion

    #====================================
    # KEYBOARD EVENTS
    #====================================
    #allow window in front if ESC is hit
    $script:Wizard.Add_KeyDown( { if ($_.Key -match 'Esc') { $script:Wizard.Topmost = $false } })

    #Allow space to hide start wizard
    $script:Wizard.Add_KeyDown( {
        if ($_.Key -match 'Space') {
            Get-PSDWizardUIElement -Name "_startPage" | Set-PSDWizardUIElement -Visible:$false
        }
    })

    #Use shift+tab on keyboard to navigate mentu backward (only works when after first tab)
    $shiftTabPressed = {
        [System.Windows.Input.KeyEventArgs]$Alt = $args[0]
        if ( ($Alt.Key -eq 'Shift') -or ($Alt.Key -eq 'Tab') ) {
            If ($_wizTabControl.SelectedIndex -ne 0) {
                Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -increment -1
            }
        }
    }
    Try {
        $null = $script:Wizard.add_KeyDown([System.Windows.Input.KeyEventHandler]::new($shiftTabPressed))
    }
    Catch {}


    #Allow space to hide start wizard
    $script:Wizard.Add_KeyDown( {
        if ($_.Key -match 'F5') {
            #Grab all Timezones and languages
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Refreshing wizard content"
            Try {
                If ($_tsTabTree.GetType().Name -eq 'TreeView') {
                    Add-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID'
                }
                If ($_tsTabTree.GetType().Name -eq 'ListBox') {
                    Add-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID'
                }
                Add-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Identifier "Name" -Exclude "Bundles"
            }
            Catch {}
        }

        if ($_.Key -match 'F9') {
            If($script:Wizard.WindowState -eq 'Normal'){
                $syncHash.Window.ShowInTaskbar = $true
                $script:Wizard.WindowState = 'Minimized'
            }
        }
    })


    If ($Passthru) {
        # Return the results to the caller
        return $script:Wizard
    }
}

#region FUNCTION: Start the wizard
Function Show-PSDWizard {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('XamlPath')]
        [string]$ResourcePath,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('en-US')]
        [string]$Language = 'en-US',

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateSet('Classic', 'Refresh', 'Tabular', 'Modern')]
        [string]$Theme,

        [Parameter(Mandatory = $false)]
        [switch]$AsAsyncJob,

        [Parameter(Mandatory = $false)]
        [switch]$Passthru
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $ResourcePath = $ResourcePath.TrimEnd('\')

    #Default to false
    $Global:WizardDialogResult = $false
    #Load functions from external file
    Write-PSDLog -Message ("{0}: Loading PSD Wizard helper script [{1}\PSDWizard.Initialize.ps1]" -f ${CmdletName}, $ResourcePath)
    . "$ResourcePath\PSDWizard.Initialize.ps1"

    #parse changelog for version for a more accurate version
    $ChangeLogPath = Join-Path $ResourcePath 'CHANGELOG.MD'
    If (Test-Path $ChangeLogPath) {
        $ChangeLog = Get-Content $ChangeLogPath
        $Changedetails = (($ChangeLog -match '##')[0].TrimStart('##') -split '-').Trim()
        [string]$MenuVersion = [string]$Changedetails[0]
        [string]$MenuDate = $Changedetails[1]
        $VersionTitle = "v$MenuVersion [$MenuDate]"
    }
    Else {
        $VersionTitle = "v2"
    }

    If ( (Get-PSDWizardTSItem -Name 'PSDDeBug' -ValueOnly) -eq 'YES') {
        $PSDDeBug = $true
    }

    #Set theme in 1 of 3 ways: Parameter, CustomeSettings.ini, Default
    If ($Theme) {
        If ( $PSDDeBug -eq $true ) { Write-PSDLog -Message ("{0}: Show-PSDWizard cmdlet was called with Theme parameter, will attempt to use the theme [{1}]" -f ${CmdletName}, $Theme) }
        $SelectedTheme = $Theme
    }
    ElseIf ($ThemeFromCS = Get-PSDWizardTSItem -Name 'WizardTheme' -ValueOnly) {
        If ( $PSDDeBug -eq $true ) { Write-PSDLog -Message ("{0}: [WizardTheme] setting found in CustomSetting.ini; will attempt to use the theme [{1}]" -f ${CmdletName}, $ThemeFromCS) }
        $SelectedTheme = $ThemeFromCS
    }
    Else {
        $SelectedTheme = 'Classic'
        If ( $PSDDeBug -eq $true ) { Write-PSDLog -Message ("{0}: No theme control was found; defaulting to theme [{1}]" -f ${CmdletName}, $Theme) }
    }

    #Build Path to definition files; if file not found, default to en-US version
    [string]$LangDefinitionsXml = Join-Path -Path $ResourcePath -ChildPath ('PSDWizard_Definitions_' + $Language + '.xml')
    [string]$ThemeDefinitionsXml = Join-Path -Path "$ResourcePath\Themes" -ChildPath ($SelectedTheme + '_Theme_Definitions_' + $Language + '.xml')

    If ( (Test-Path $LangDefinitionsXml) -and (Test-Path $ThemeDefinitionsXml) ) {
        [string]$XmlLangDefinitionFile = ('PSDWizard_Definitions_' + $Language + '.xml')
        [string]$XmlThemeDefinitionFile = ($SelectedTheme + '_Theme_Definitions_' + $Language + '.xml')
    }
    Else {
        Write-PSDLog -Message ("{0}: language definition file [{1}] or theme definitions file [{2}] missing; reverting to defaults" -f ${CmdletName}, ('PSDWizard_Definitions_' + $Language + '.xml'), ($SelectedTheme + '_Theme_Definitions_' + $Language + '.xml')) -LogLevel 2
        [string]$XmlLangDefinitionFile = 'PSDWizard_Definitions_en-US.xml'
        [string]$XmlThemeDefinitionFile = 'Classic_Theme_Definitions_en-US.xml'
    }

    #Rebuild Build path to language and theme definition (if paths aren't found)
    [string]$LangDefinitionsXml = Join-Path -Path $ResourcePath -ChildPath $XmlLangDefinitionFile
    [string]$ThemeDefinitionsXml = Join-Path -Path "$ResourcePath\Themes" -ChildPath $XmlThemeDefinitionFile


    #Check again (Incase definition defaulted to en-US and ARE still missing)
    If ( (Test-Path $LangDefinitionsXml) -and (Test-Path $ThemeDefinitionsXml) ) {
        #Get content of Defintion file
        [Xml.XmlDocument]$LangDefinitionXmlDoc = (Get-Content $LangDefinitionsXml)
        [Xml.XmlDocument]$ThemeDefinitionXmlDoc = (Get-Content $ThemeDefinitionsXml)
    }
    Else {
        Write-PSDLog -Message ("{0}: language definition file [{1}] or theme definitions file [{2}] not found" -f ${CmdletName}, $LangDefinitionsXml, $ThemeDefinitionsXml) -LogLevel 3
        Break
    }

    #Build the XAML file based on definitions
    Write-PSDLog -Message ("{0}: Running [Format-PSDWizard -Path {1} -LangDefinitions (xml:{2}) -ThemeDefinitions (xml:{3})]" -f ${CmdletName}, $ResourcePath, $XmlLangDefinitionFile, $XmlThemeDefinitionFile)
    $script:Xaml = Format-PSDWizard -Path $ResourcePath -LangDefinitions $LangDefinitionXmlDoc -ThemeDefinitions $ThemeDefinitionXmlDoc
    If ( $PSDDeBug -eq $true ) {
        $Logpath = Split-Path $Global:PSDLogPath -Parent
        $script:Xaml.OuterXml | Out-File "$Logpath\PSDWizardNew_$($SelectedTheme)_$($Language).xaml" -Force
    }

    #load wizard
    $ScriptPath = Split-Path $ResourcePath -Parent
    Write-PSDLog -Message ("{0}: Running [Invoke-PSDWizard -ScriptPath $ScriptPath -XamlContent `$script:Xaml -Version `"{1}`" -Passthru]" -f ${CmdletName}, $VersionTitle)
    $script:Wizard = Invoke-PSDWizard -ScriptPath $ScriptPath -XamlContent $script:Xaml -Version "$VersionTitle" -Passthru

    #Get Defintions prefix
    [PSCustomObject]$GlobalElement = Get-PSDWizardDefinitions -Xml $LangDefinitionXmlDoc -Section Global

    Write-PSDLog -Message ("{0}: Running [Set-PSDWizardDefault -XMLContent `$script:Xaml -VariablePrefix {1} -Form `$script:Wizard]" -f ${CmdletName}, $GlobalElement.TSVariableFieldPrefix)
    Set-PSDWizardDefault -XMLContent $script:Xaml -VariablePrefix $GlobalElement.TSVariableFieldPrefix -Form $script:Wizard

    Write-PSDLog -Message ("{0}: Launching PSDWizard using locale [{1}] and with [{2}] theme " -f ${CmdletName}, $Language, $SelectedTheme)

    #Optimize UI when running in Windows
    If ($AsAsyncJob) {
        $script:Wizard.Add_Closing( {
                #$_.Cancel = $true
                [System.Windows.Forms.Application]::Exit()
                Write-PSDLog -Message ("{0}: Closing PSD Wizard" -f ${CmdletName})
            })

        $async = $script:Wizard.Dispatcher.InvokeAsync( {

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
    Else {
        #make sure window is on top
        $script:Wizard.Topmost = $true
        #disable x button
        $script:Wizard.Add_Closing( { $_.Cancel = $true })
        #Slower method to present form for modal (no popups)
        $script:Wizard.ShowDialog() | Out-Null
    }

    #NOTE: Function will not continue until wizard is closed

    #Save all entered results back
    Write-PSDLog -Message ("{0}: Running [Export-PSDWizardDefault -XMLContent `$script:Xaml -VariablePrefix {1} -Form `$script:Wizard]" -f ${CmdletName}, $GlobalElement.TSVariableFieldPrefix)
    Export-PSDWizardResult -XMLContent $script:Xaml -VariablePrefix $GlobalElement.TSVariableFieldPrefix -Form $script:Wizard

    If ($Passthru) {
        # Return the form results to the caller
        return $Global:WizardDialogResult
    }
}

Export-ModuleMember -Function Show-PSDWizard, Format-PSDWizard, Invoke-PSDWizard, Set-PSDWizardDefault, Export-PSDWizardResult
#Export-ModuleMember -Function Show-PSDWizard