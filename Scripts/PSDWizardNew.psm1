<#
.SYNOPSIS
    Module for the PSD Wizard
.DESCRIPTION
    Module that generates a PSDWizard based on the definition files
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
    FileName: PSDWizardNew.psm1
    Solution: PowerShell Deployment for MDT
    Purpose: Module for the PSD Wizard
    Author: PSD Development Team
    Contact: Dick Tracy (@PowershellCrack)
    Primary: Dick Tracy (@PowershellCrack)
    Created: 2020-01-12
    Modified: 2024-12-29
    Version: 2.3.6

    SEE CHANGELOG.MD

    TODO:
        - Use runspace for multithreading, refresh capability, and faster response
        - Support application profiles
        - Support profile selections
        - Support Autopilot Tasksequence
        - Support additional languages
        - Additional themes
            - Windows 11 OOBE theme
            - Circular buttons theme (for touch screens)
#>

#region FUNCTION: Get-PSDWizardDefinitions
Function Get-PSDWizardDefinitions {
    <#
    .SYNOPSIS
    Retrieve definition file sections
    #>
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


#region FUNCTION: Get-PSDWizardThemeDefinition
Function Get-PSDWizardThemeDefinition {
    <#
    .SYNOPSIS
        Retrieve theme definition file sections
    #>
    Param(
        [parameter(Mandatory = $true)]
        [xml]$xml,

        [parameter(Mandatory = $false)]
        [ValidateSet('ThemeTemplate', 'PanesTemplate', 'WelcomeWizard', 'Pane', 'PaneStartingMargin')]
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
        'PaneStartingMargin' { $DefinitionObject = $ThemeElement.PaneDefinitions.PaneStartingMargin.'#cdata-section'.Trim() }
        'Pane' { $DefinitionObject = $ThemeElement.PaneDefinitions.Pane }
        default { $DefinitionObject = $ThemeElement }
    }

    If ($AsObject) {
        $DefinitionObject | ForEach-Object {
            $_
        }
    }
    Else {
        Return $DefinitionObject
    }

}
#endregion

#region FUNCTION: Get-PSDWizardCondition
Function Get-PSDWizardCondition {
    <#
    .SYNOPSIS
        Retrieve XSL condition statement from definition file

    .DESCRIPTION
        Retrieve XSL condition statement from definition file; and convert it into a powershell script

    .EXAMPLE
        $Condition = 'UCASE(Property("SkipBDDWizard")) <> "YES" or UCase(Property("SkipPSDWizard"))<>"YES"'
        $TSEnvSettings = Get-PSDWizardTSEnvProperty 'Skip' -wildcard
        Get-PSDWizardCondition -Condition $Condition -TSEnvSettings $TSEnvSettings

    .EXAMPLE
        $Condition = 'Property("Model") in Properties("SupportedModels(*)")'
        $TSEnvSettings = Get-PSDWizardTSEnvProperty *
        Get-PSDWizardCondition -Condition $Condition -TSEnvSettings $TSEnvSettings -Passthru

    .EXAMPLE
        $Condition = 'Property(IsUEFI) == "True"'
        $TSEnvSettings = Get-PSDWizardTSEnvProperty *
        Get-PSDWizardCondition -Condition $Condition -TSEnvSettings $TSEnvSettings

    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        [string]$Condition,

        [PSCustomObject]$TSEnvSettings,

        [switch]$Passthru
    )

    #convert each TSEnvSettings object into variables to be evaluated later
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

    #change operators to powershell operators
    $Condition = $Condition -replace '<>', ' -ne ' -replace '==', ' -eq ' -replace '=', ' -eq ' -replace '<=', ' -le ' -replace '=>', ' -ge ' -replace '<', '-lt ' -replace '>', ' -gt'

    #Remove quotes from all items in parentheses
    $Condition = $Condition -replace "\([`"|']", '(' -replace "[`"|']\)", ")"

    #remove the UCASE and Property string to make variable
    If ($Condition -match 'Property') {
        $Condition = $Condition -replace "Property\(", '$' -replace "\)", ""
    }

    #find the properties match and tie them together
    If ($Condition -match 'Properties') {
        #$Matches
        #look for more than one properties
        $PropertiesSearch = $Condition -split ' ' | Where-Object { $_ -match 'Properties\("' }
        #loop through each
        Foreach ($Properties in $PropertiesSearch) {
            #get list name
            $ArrayName = ($Properties -split 'Properties\("')[1] -replace "\(\*\)", ""
            $Values = @()
            #get list values
            $TSEnvSettings | Where-Object { $_.Name -match "$ArrayName\d\d\d" } | ForEach-Object {
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


#region FUNCTION: Format-PSDWizard
Function Format-PSDWizard {
    <#
    .SYNOPSIS
        Build the XAML dynamically from definition file

    .EXAMPLE
        $Path = 'D:\DeploymentShares\PSD\scripts\PSDWizardNew'
        $ThemeFile = 'Classic_Theme_Definitions_en-US.xml'
        [Xml.XmlDocument]$LangDefinition = (Get-Content "$Path\PSDWizard_Definitions_en-US.xml")
        [Xml.XmlDocument]$ThemeDefinition = (Get-Content "$Path\Themes\$ThemeFile")
        Format-PSDWizard -Path $Path -LangDefinition $LangDefinition -ThemeDefinition $ThemeDefinition -Test -Passthru

    .EXAMPLE
        $Path = 'D:\DeploymentShares\PSD\scripts\PSDWizardNew'
        $ThemeFile = 'Refresh_Theme_Definitions_en-US.xml'
        [Xml.XmlDocument]$LangDefinition = (Get-Content "$Path\PSDWizard_Definitions_en-US.xml")
        [Xml.XmlDocument]$ThemeDefinition = (Get-Content "$Path\Themes\$ThemeFile")
        Format-PSDWizard -Path $Path -LangDefinition $LangDefinition -ThemeDefinition $ThemeDefinition
    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        [string]$Path,

        [parameter(Mandatory = $true)]
        [Xml.XmlDocument]$LangDefinition,

        [parameter(Mandatory = $true)]
        [Xml.XmlDocument]$ThemeDefinition,

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
    #build paths to resources and templates
    [string]$ResourcePath = (Join-Path -Path $WorkingPath -ChildPath 'Resources')
    [string]$TemplatePath = (Join-Path -Path $WorkingPath -ChildPath 'Themes')

    #grab needed elements from Lang definition file
    #[PSCustomObject]$GlobalElement = Get-PSDWizardDefinitions -Xml $LangDefinition -Section Global
    [PSCustomObject]$WelcomeElement = Get-PSDWizardDefinitions -Xml $LangDefinition -Section WelcomeWizard
    [PSCustomObject]$PaneElements = Get-PSDWizardDefinitions -Xml $LangDefinition -Section Pane

    #build paths to Welcome Wizard start
    $WelcomeWizardFile = Get-PSDWizardThemeDefinition -xml $ThemeDefinition -Section WelcomeWizard
    $ThemeTemplateFile = Get-PSDWizardThemeDefinition -xml $ThemeDefinition -Section ThemeTemplate

    [string]$XamlWizardTemplatePath = Join-Path -Path $TemplatePath -ChildPath $ThemeTemplateFile
    [string]$StartPagePath = Join-Path -Path $TemplatePath -ChildPath $WelcomeWizardFile

    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Generating PSD Wizard from template file [{1}]" -f ${CmdletName}, (Split-Path $XamlWizardTemplatePath -leaf)) }

    #grab the primary template
    $PSDWizardXAML = (Get-Content $XamlWizardTemplatePath -ReadCount 0) -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'

    If ($Test) {
        $OrgName = "Test ORG Name"
        $SkipSettings = @{SkipBDDWizard = 'NO' }
    }
    Else {
        #grab the SMSTSOrgName from settings
        $OrgName = (Get-PSDWizardTSEnvProperty '_SMSTSOrgName' -ValueOnly)
        If(!$OrgName){
            $OrgName = (Get-PSDWizardTSEnvProperty 'OrgName' -ValueOnly)
        }
        #make sure no invalid characters exist
        $OrgName = (ConvertTo-PSDWizardHexaDecimal -String $OrgName)

        #grab all variables that contain skip
        $SkipSettings = Get-PSDWizardTSEnvProperty 'Skip' -wildcard
    }

    #get thecondition as a friendly output
    $WelcomeCondition = Get-PSDWizardCondition -Condition $WelcomeElement.Condition.'#cdata-section' -TSEnvSettings $SkipSettings -Passthru

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
            $StartPageContent = ($StartPageContent -replace '@ORG', $OrgName)

            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: [Welcome Start Page] is loaded [{1}]" -f ${CmdletName}, $StartPagePath) }
        }
        Else {
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: [Welcome Start Page] is not found [{1}]; unable to load page" -f ${CmdletName}, $StartPagePath) }
            $StartPageContent = ''
        }
    }
    Else {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Conditions [{1}] returned False; [Welcome Start Page] will not load" -f ${CmdletName},$WelcomeCondition) }
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
        $SourcePath = $Resources | Where-Object { $_.Name -match $FileName } | Select-Object -ExpandProperty FullName
        #Replace whats in the string version (Not XML version)
        $PSDWizardXAML = $PSDWizardXAML.replace($Source, $SourcePath) #  ($SourcePath -replace "\\","/")
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Updating resource file path [{1}] with new path [{2}]" -f ${CmdletName}, $Source, $SourcePath) }
    }

    #Tab template used to build form
    #Consist of logos, title, subtitle and buttons
    # @content is controlled by definition reference file for pane (aka: Tab)
    $TabsContentTemplate = Get-PSDWizardThemeDefinition -Xml $ThemeDefinition -Section PanesTemplate
    #$TabsContentTemplate = $PanesTemplateElements

    If ($Test) {
        $TSEnvSettings = @{}
    }
    Else {
        $TSEnvSettings = (Get-PSDWizardTSEnvProperty * -wildcard)
    }

    #Replace Tabcontrol section with tab template
    $tabitems = $null
    #grab all tabs
    $i = 0
    #loop through each page
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
        $TabDefinitions = (Get-PSDWizardThemeDefinition -Xml $ThemeDefinition -Section Pane | Where-Object { $_.id -eq $Tab.id })
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

        #Replace @ORG if value exists within other titles
        $MainTitle = ($Tab.MainTitle.'#cdata-section' -replace '@ORG', $OrgName -replace '"', '').Trim()
        $SubTitle = ($Tab.SubTitle.'#cdata-section' -replace '@ORG', $OrgName -replace '"', '').Trim()
        $Context = ($Tab.Context.'#cdata-section' -replace '"', '').Trim()
        $Help = ($Tab.Help.'#cdata-section' -replace '"', '').Trim()

        #merge tab template to page content
        $PageContent = $TabsContentTemplate -replace '@TabItemContent', $PageContent

        #replace the @ values with content (if exists)
        #Collect Tab details from Definition
        #$TabId = ("{0:D2}" -f $i)   # make all tabs are double digits

        $PageContent = $PageContent -replace '@TabTitle', $TabTitle `
            -replace '@MainTitle', $MainTitle `
            -replace '@SubTitle', $SubTitle `
            -replace '@Context', $Context `
            -replace '@Help', $Help `
            -replace '@Content', $PageContent

        #set the first tab's margin to default (ignoring the setting in the definition file)
        If($i -eq 1){
            $PaneStartingMargin = Get-PSDWizardThemeDefinition -Xml $ThemeDefinition -Section PaneStartingMargin
            $PageContent = $PageContent -replace '@margin', $PaneStartingMargin
        }

        #If value matches a property in definition, replace it
        $r = [regex]'@\w+'
        $allmatches = $r.matches($PageContent)
        #Iterate through CURRENT page content and find any @values
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
    If ($Test) {
        $PSDWizardXAML= $PSDWizardXAML -replace '@TabItems', $tabitems -replace "x:N", 'N' -replace '^<Win.*', '<Window' -replace 'Click=".*', '/>' -replace 'x:Class=".*', ''
        $PSDWizardXAML | Out-file $WorkingPath\psdwizard_test.xml -Force
    }Else{
        Try {
            [xml]$PSDWizardUI = $PSDWizardXAML -replace '@TabItems', $tabitems -replace "x:N", 'N' -replace '^<Win.*', '<Window' -replace 'Click=".*', '/>' -replace 'x:Class=".*', ''
        }
        Catch {
            Write-PSDLog -Message ("{0}: Unable to Generate PSD Wizard: {1}" -f ${CmdletName}, $_.exception.message) -LogLevel 3
        }
    }

    If ($Passthru) {
        Return $PSDWizardUI.OuterXml
    }
    Else {
        Return $PSDWizardUI
    }

}
#endregion

#region FUNCTION: Export-PSDWizardResult
function Export-PSDWizardResult {
    <#
    .SYNOPSIS
        Export all results from PSDwizard
    #>
    [CmdletBinding()]
    Param(
        $XMLContent,
        $VariablePrefix,
        $Form
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #search through XML for matching VariablePrefix
    $XMLContent.SelectNodes("//*[@Name]") | Where-Object { $_.Name -match "^$VariablePrefix" } | ForEach-Object {
        Try {
            $control = $Form.FindName($_.Name)
            #get name without prefix
            $name = $_.Name.Substring($VariablePrefix.Length)

            if ($name -match 'Password') {
                $value = $control.Password
                #Set-Item -Path tsenv:$name -Value $value
                If ($value) { Set-PSDWizardTSEnvProperty $name -Value $value }
            }
            elseif ($name -eq 'ComputerName') {
                $value = $control.Text
                If ($value) { Set-PSDWizardTSEnvProperty 'OSDComputerName' -Value $value }
            }
            elseif ($name -eq 'Applications') {
                #get apps listed in the tsenv
                $apps = Get-PSDWizardTSEnvProperty $name -WildCard
                #if no apps, generate a fake app object that contains name, guid

                $AppGuids = Set-PSDWizardSelectedApplications -InputObject $apps -FieldObject $_appTabList -Passthru
                $value = $AppGuids
                #Set-PSDWizardTSEnvProperty $name -Value $value
            }
            elseif ($name -eq 'Summary') {
                # Do nothing
            }
            else {
                $value = $control.Text
                If ($value) {
                    Set-PSDWizardTSEnvProperty $name -Value $value
                }Else{
                    Remove-PSDWizardTSEnvProperty $name
                }
            }
            Write-PSDLog -Message ("{0}: Property {1} is now = {2}" -f ${CmdletName}, $name, $value)

            if ($name -eq "TaskSequenceID") {
                Write-PSDLog -Message ("{0}: Checking TaskSequenceID for a value" -f ${CmdletName})
                if ($null -eq (Get-PSDWizardTSEnvProperty $name -ValueOnly)) {
                    Write-PSDLog -Message ("{0}: TaskSequenceID is empty!!!" -f ${CmdletName})
                    Write-PSDLog -Message ("{0}: Re-Running Wizard, TaskSequenceID must not be empty..." -f ${CmdletName})
                    Show-PSDSimpleNotify -Message ("{0}: No Task Sequence selected, restarting wizard..." -f ${CmdletName})
                    Show-PSDWizard -ResourcePath "$(Get-PSDContent -Content "scripts")\PSDWizardNew"
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

#region FUNCTION: Set-PSDWizardDefault
function Set-PSDWizardDefault {
    <#
    .SYNOPSIS
        Sets all variables for PSD wizard

    .EXAMPLE
        $Path = 'D:\DeploymentShares\PSD\scripts\PSDWizardNew\Scripts'
        $ResourcePath = 'D:\DeploymentShares\PSD\scripts\PSDWizardNew'
        [string]$LangDefinitionXml = Join-Path -Path $ResourcePath -ChildPath 'PSDWizard_Definitions_en-US.xml'
        [string]$ThemeDefinitionXml = Join-Path -Path "$ResourcePath\Themes" -ChildPath 'Classic_Theme_Definitions_en-US.xml'
        [Xml.XmlDocument]$LangDefinitionXmlDoc = (Get-Content $LangDefinitionXml)
        [Xml.XmlDocument]$ThemeDefinitionXmlDoc = (Get-Content $ThemeDefinitionXml)
        $XMLContent = Format-PSDWizard -Path $ResourcePath -LangDefinition $LangDefinitionXmlDoc -ThemeDefinition $ThemeDefinitionXmlDoc
        $Form = Invoke-PSDWizard -ScriptPath $Path -XamlContent $XMLContent -Version "2.0" -Passthru
        $VariablePrefix='TS_'
        Set-PSDWizardDefault -XMLContent $XMLContent -VariablePrefix $VariablePrefix -Form $Form
    #>
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
    $XMLContent.SelectNodes("//*[@Name]") | Where-Object { $_.Name -match "^$VariablePrefix" } | ForEach-Object {
        Try {
            $control = $Form.FindName($_.Name)
            #get name and associated TS value
            $name = $_.Name.Substring($VariablePrefix.Length)
            $value = Get-PSDWizardTSEnvProperty $name -ValueOnly
            #Password fields use different property
            if ($name -match 'Password') {
                #$control.Password = (Get-Item tsenv:$name).Value
                $control.Password = $value
            }
            elseif ($name -eq 'ComputerName') {
                $control.Text = $value
                #Set the OSDComputerName to match ComputerName
                Set-PSDWizardTSEnvProperty 'OSDComputerName' -Value $value
            }
            elseif ($name -eq 'Applications') {
                $apps = Get-PSDWizardTSEnvProperty $name -WildCard
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
            If ($Passthru) { (Get-PSDWizardTSEnvProperty $name) }
        }
        Catch {}
    }
}
#endregion


#region FUNCTION: Invoke-PSDWizard
Function Invoke-PSDWizardRS {
<#
    .SYNOPSIS
        Show the splash screen for the wizard

    .EXAMPLE
        Show-PSDWizardSplashScreen
    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        $XamlContent,
        [string]$ScriptPath = $script:PSDScriptRoot,
        [string]$Version,
        [string]$DefaultLocale = 'en-US',
        [string]$DefaultTimeZone = 'Pacific Standard Time',
        [switch]$LogDebug = $PSDDeBug,
        [switch]$Passthru
    )

    [string]${CmdletName} = $MyInvocation.MyCommand
    Write-PSDLog -Message ("{0}: PSDWizard started" -f ${CmdletName})

    # build a hash table with locale data to pass to runspace
    $PSDWizardHash = [hashtable]::Synchronized(@{})
    $PSDRunSpace =[runspacefactory]::CreateRunspace()
    $PSDWizardHash.Runspace = $PSDRunSpace
    $PSDWizardHash.xaml = $XamlContent
    $PSDWizardHash.scriptPath = $ScriptPath
    $PSDWizardHash.language = $DefaultLocale
    $PSDWizardHash.timeZone = $DefaultTimeZone
    $PSDWizardHash.version = $Version
    $PSDWizardHash.isLoaded = $False
    #build runspace
    $PSDRunSpace.ApartmentState = "STA"
    $PSDRunSpace.ThreadOptions = "ReuseThread"
    $PSDRunSpace.Open() | Out-Null
    $PSDRunSpace.SessionStateProxy.SetVariable("PSDWizardHash",$PSDWizardHash)
    $Script:Pwshell = [PowerShell]::Create().AddScript({
        
        [xml]$xaml = $PSDWizardHash.xaml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
        $PSDWizardHash.window = [Windows.Markup.XamlReader]::Load($reader)

        #===========================================================================
        # Store Form Objects In PowerShell
        #===========================================================================
        $xaml.SelectNodes("//*[@Name]") | %{ 
            $PSDWizardHash."$($_.Name)" = $PSDWizardHash.Window.FindName($_.Name)
            if ($PSDWizardHash.LogDebug -eq $true) { Write-PSDLog -Message ("{0}: Creating wizard variable: {1}" -f ${CmdletName}, $PSDWizardHash."$($_.Name)") }
        }
        
        $PSDWizardHash.Window.WindowState = $WindowState
        $PSDWizardHash.Window.Width = $Width
        $PSDWizardHash.Window.Background = $WindowBackground

        # INNER  FUNCTIONS
        #Closes UI objects and exits (within runspace)
        Function Close-PSDWizardRS
        {
            if ($PSDWizardHash.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
            #if runspace has not errored Dispose the UI
            if (!($PSDWizardHash.isClosing)) { $PSDWizardHash.Window.Close() | Out-Null }
        }

        $PSDWizardHash.TSEnv = Get-PSDWizardTSEnvProperty -Name *
        #add title to window and version label
        $PSDWizardHash.Window.Title = "PSD Wizard " + $Version
        $PSDWizardHash._wizVersion.Content = $Version

        #add logo if found
        If ($LogoPath = ($PSDWizardHash.TSEnv | Where Name -eq "PSDWizardLogo"))
        {
            If(Test-Path $LogoPath.Value){
                If($PSDWizardHash._wizMainLogo){$PSDWizardHash._wizMainLogo.Source = $LogoPath.Value}
                If($PSDWizardHash._wizBeginLogo){$PSDWizardHash._wizBeginLogo.Source = $LogoPath.Value}
            }
        }

        #Allow UI to be dragged around screen
        If ($PSDWizardHash.Window.WindowStyle -eq 'None')
        {
            $PSDWizardHash.Window.Add_MouseLeftButtonDown( {
                $PSDWizardHash.Window.DragMove()
            })
        }

        #hide the back button on startup
        $PSDWizardHash._wizBack.Visibility = 'hidden'
        
        #hide the debug button all times until ready
        $PSDWizardHash._wizDebugConsole.Visibility = 'hidden'
        
        #Add smooth closing for Window
        $PSDWizardHash.Window.Add_Loaded({ $PSDWizardHash.isLoaded = $True })
    	$PSDWizardHash.Window.Add_Closing({ $PSDWizardHash.isClosing = $True; Close-PSDWizardRS })
    	$PSDWizardHash.Window.Add_Closed({ $PSDWizardHash.isClosed = $True })

        #always force windows on bottom
        $PSDWizardHash.Window.Topmost = $False

        $PSDWizardHash.Window.ShowDialog()
        #$PSDRunspace.Close()
        #$PSDRunspace.Dispose()
        $PSDWizardHash.Error = $Error
    }) # end scriptblock

    #collect data from runspace
    $Data = $PSDWizardHash

    #invoke scriptblock in runspace
    $Script:Pwshell.Runspace = $PSDRunSpace
    $AsyncHandle = $Script:Pwshell.BeginInvoke()

    #cleanup registered object
    Register-ObjectEvent -InputObject $PSDWizardHash.Runspace `
            -EventName 'AvailabilityChanged' `
            -Action {

                    if($Sender.RunspaceAvailability -eq "Available")
                    {
                        $Sender.Closeasync()
                        $Sender.Dispose()
                        # Speed up resource release by calling the garbage collector explicitly.
                        # Note that this will pause *all* threads briefly.
                        [GC]::Collect()
                    }

                } | Out-Null

    If($Data.Error){Write-PSDLog -Message ("{0}: PSDWizard errored: {1}" -f ${CmdletName}, $Data.Error) -LogLevel 3}
    Else{Write-PSDLog -Message ("{0}: PSDWizard closed" -f ${CmdletName})}
    If($PassThru){Return $Data}
}

#region FUNCTION: Invoke-PSDWizard
Function Invoke-PSDWizard {
    <#
    .SYNOPSIS
        initialize PSDwizard and it functionality

    .EXAMPLE
        $XamlContent = $script:Xaml.OuterXml
        $ScriptPath = (Get-PSDContent scripts)
        $Version = 'v2'
        $Form = Invoke-PSDWizard -ScriptPath $ScriptPath -XamlContent $XMLContent -Version $Version -Passthru
    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        $XamlContent,
        [string]$ScriptPath = $script:PSDScriptRoot,
        [string]$Version,
        [string]$DefaultLocale = 'en-US',
        [string]$DefaultTimeZone = 'Pacific Standard Time',
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #Load assembies to display UI
    [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework') #required for WPF

    #Load XAML to reader (single threaded)
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$XamlContent)
    try {
        $script:UI = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-PSDLog -Message ("{0}: {1}" -f ${CmdletName}, $ErrorMessage) -LogLevel 3
        Throw $ErrorMessage
    }

    # Store xaml objects as PowerShell variables and add them to a gloabl array to use
    $Global:PSDWizardElements = @()
    $XamlContent.SelectNodes("//*[@Name]") | ForEach-Object {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Creating wizard variable: {1}" -f ${CmdletName}, $_.Name) }
        $Global:PSDWizardElements += Set-Variable -Name ($_.Name) -Value $script:UI.FindName($_.Name) -Scope Global -PassThru
    }

    #add title to window and version label
    $script:UI.Title = "PSD Wizard " + $Version
    $_wizVersion.Content = $Version

    #add logo if found
    If ($LogoPath = Get-PSDWizardTSEnvProperty 'PSDWizardLogo' -ValueOnly)
    {
        If(Test-Path $LogoPath){
            If($_wizMainLogo){$_wizMainLogo.Source = $LogoPath}
            If($_wizBeginLogo){$_wizBeginLogo.Source = $LogoPath}
        }
    }

    #Allow UI to be dragged around screen
    If ($script:UI.WindowStyle -eq 'None')
    {
        $script:UI.Add_MouseLeftButtonDown( {
            $script:UI.DragMove()
        })
    }

    #hide the back button on startup
    $_wizBack.Visibility = 'hidden'
    #endregion

    #hide the debug button all times until ready
    $_wizDebugConsole.Visibility = 'hidden'

    #region For Device Readiness Tab objects
    # ---------------------------------------------
    If ($_depTabProfiles)
    {
        $WizardSelectionProfile = Get-PSDWizardTSEnvProperty 'WizardSelectionProfile' -ValueOnly
        $Profiles = Add-PSDWizardSelectionProfile -ListObject $_depSelectionProfilesList -Passthru
        If ($WizardSelectionProfile -in $Profiles) {
            Get-PSDWizardElement -Name "_depSelectionProfilesList" | Set-PSDWizardElement -Enable:$True
        }
    }
    #endregion


    #region For Device tab objects
    # ---------------------------------------------
    #hide device details is specified
    #if skipcomputername is YES, hide input unless value is invalid
    If( ('_wizDeviceDetails' -in $_wizTabControl.items.Name) -or ('_wizComputerName' -in $_wizTabControl.items.Name) )
    {
        If( (Get-PSDWizardTSEnvProperty 'SkipComputerName' -ValueOnly).ToUpper() -eq 'YES' )
        {
            Get-PSDWizardElement -Name "_grdDeviceDetails" | Set-PSDWizardElement -Visible:$False
        }
    }

    If( ('_wizDeviceDetails' -in $_wizTabControl.items.Name) -or ('_wizDomainSettings' -in $_wizTabControl.items.Name) )
    {
        $NetworkSelectionAvailable = $True

        #if the check comes back false; show name
        If ((Get-PSDWizardTSEnvProperty 'SkipDomainMembership' -ValueOnly).ToUpper() -eq 'YES')
        {
            If ($_JoinDomainRadio.GetType().Name -eq 'RadioButton') {
                $NetworkSelectionAvailable = $false
                Get-PSDWizardElement -Name "_grdNetworkDetails" | Set-PSDWizardElement -Visible:$False
            }

            If ($_JoinDomainRadio.GetType().Name -eq 'CheckBox') {
                $NetworkSelectionAvailable = $false
                Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Visible:$False
                Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Visible:$False
            }
        }

        <#TODO: Need PSDDomainJoin.ps1 to enable feature
        If('PSDDomainJoin.ps1' -notin (Get-PSDContent -Content "Scripts" -Passthru)){
            $NetworkSelectionAvailable = $false
            Get-PSDWizardElement -Name "JoinDomain" -Wildcard | Set-PSDWizardElement -Visible:$False
        }
        #>

        #change the text for domain join OU to combo box if DomainOUs* values are found
        If( (Get-PSDWizardTSEnvListProperty 'DomainOUs' -ValuesOnly).count -gt 0){
            Get-PSDWizardElement -Name "TS_MachineObjectOU" | Set-PSDWizardElement -Visible:$false
            Get-PSDWizardElement -Name "_DomainOUs" | Set-PSDWizardElement -Visible:$true

            $OUList = Get-PSDWizardTSEnvListProperty 'DomainOUs' -ValuesOnly -SortByValue

            If($OUList.count -gt 0){
                If($DefaultOU = Get-PSDWizardTSEnvProperty 'MachineObjectOU' -ValueOnly){
                    Add-PSDWizardComboList -Array $OUList -ListObject $_DomainOUs -PreSelect $DefaultOU -Sort
                }Else{
                    Add-PSDWizardComboList -Array $OUList -ListObject $_DomainOUs -Sort
                }
            }Else{
                Get-PSDWizardElement -Name "TS_MachineObjectOU" | Set-PSDWizardElement -Visible:$true
                Get-PSDWizardElement -Name "_DomainOUs" | Set-PSDWizardElement -Visible:$false
            }
        }Else{
            Get-PSDWizardElement -Name "TS_MachineObjectOU" | Set-PSDWizardElement -Visible:$true
            Get-PSDWizardElement -Name "_DomainOUs" | Set-PSDWizardElement -Visible:$false
        }

        #Check the current Workgroup/domain values and sets UI appropiately
        If ( -not[string]::IsNullOrEmpty((Get-PSDWizardTSEnvProperty 'JoinWorkgroup' -ValueOnly)) )
        {
            #SET WORKGROUP UP
            Get-PSDWizardElement -Name "_JoinWorkgroupRadio" | Set-PSDWizardElement -Checked:$True
            Get-PSDWizardElement -Name "_JoinDomainRadio" | Set-PSDWizardElement -Checked:$False
            Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Visible:$True

            If ($_JoinDomainRadio.GetType().Name -eq 'CheckBox') {
                Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Visible:$False
            }
            Else {
                Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Enable:$False
            }
        }

        #join domain takes priority over workgroup (if exists)
        If ( -not[string]::IsNullOrEmpty((Get-PSDWizardTSEnvProperty 'JoinDomain' -ValueOnly)) )
        {
            #SET DOMAIN UP
            Get-PSDWizardElement -Name "_JoinWorkgroupRadio" | Set-PSDWizardElement -Checked:$False
            Get-PSDWizardElement -Name "_JoinDomainRadio" | Set-PSDWizardElement -Checked:$True
            Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Visible:$True

            If ($_JoinDomainRadio.GetType().Name -eq 'CheckBox')
            {
                Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Visible:$False
            }
            Else {
                Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Enable:$False
            }

            #clear the workgroup value
            Get-PSDWizardElement -Name "TS_JoinWorkgroup" | Set-PSDWizardElement -Text $null
        }
        #endregion
    }
    #region For Locale Tab objects
    # ---------------------------------------------
    #MUST BE GLOBAL VARIABLES FOR TABS TO USE LATER ON

    #grab customsettings locale settings
    $Global:TSUILanguage = Get-PSDWizardTSEnvProperty 'UILanguage' -ValueOnly
    $Global:TSSystemLocale = Get-PSDWizardTSEnvProperty 'SystemLocale' -ValueOnly
    $Global:TSKeyboardLocale = Get-PSDWizardTSEnvProperty 'KeyboardLocale' -ValueOnly
    $Global:TSInputLocale = Get-PSDWizardTSEnvProperty 'InputLocale' -ValueOnly
    $Global:TSTimeZoneName = Get-PSDWizardTSEnvProperty 'TimeZoneName' -ValueOnly

    #grab customsettings Join value settings
    $Global:JoinWorkgroup = Get-PSDWizardTSEnvProperty 'JoinWorkgroup' -ValueOnly
    $Global:JoinDomain = Get-PSDWizardTSEnvProperty 'JoinDomain' -ValueOnly

    #Grab all timezones and locales
    $Global:PSDWizardLanguageList = Get-PSDWizardLocale -Path $ScriptPath -FileName 'PSDListOfLanguages.xml'
    $Global:PSDWizardTimeZoneIndex = Get-PSDWizardTimeZoneIndex -Path $ScriptPath -FileName 'PSDListOfTimeZoneIndex.xml'
    #store as a different viarable; used to create language list but can change once a ts is selected
    $Global:OSLanguageList = $Global:PSDWizardLanguageList

    #get the defaults for timezone and locale
    $Global:DefaultLocaleObject = $Global:PSDWizardLanguageList | Where-Object { $_.Culture -eq $DefaultLocale }
    $Global:DefaultTimeZoneObject = $Global:PSDWizardTimeZoneIndex | Where-Object { $_.DisplayName -eq $DefaultTimeZone }

    If ($TS_SystemLocale)
    {
        #get mapped data of current SystemLocale from CustomSettings.ini
        If ($Global:TSSystemLocale.Length -gt 0)
        {
            $SystemLocale = $Global:PSDWizardLanguageList | Where-Object { $_.Culture -eq $Global:TSSystemLocale }
        }Else{
            $SystemLocale = $Global:DefaultLocaleObject
        }
        #add the entire list of Systemlocale and preselect the one from CustomSettings.ini (if exists)
        If ($_locTabSystemLocale.GetType().Name -eq 'ComboBox')
        {   
            Add-PSDWizardComboList -InputObject $Global:PSDWizardLanguageList -ListObject $_locTabSystemLocale -Identifier 'Name' -PreSelect $SystemLocale.Name
        }

        If ($_locTabSystemLocale.GetType().Name -eq 'ListBox')
        {
            Add-PSDWizardList -InputObject $Global:PSDWizardLanguageList -ListObject $_locTabSystemLocale -Identifier 'Name' -PreSelect $SystemLocale.Name
        }

        #Map the select item from list to format TS understands
        $MappedLocale = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLanguageList -InputValue $SystemLocale.Name -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SystemLocale.Culture)
        #$MappedLocale = ($Global:PSDWizardLanguageList | Where-Object Name -eq $SystemLocale.Name) | Select-Object -ExpandProperty Culture
        $TS_SystemLocale.Text = (Set-PSDWizardTSEnvProperty -Name SystemLocale -Value $MappedLocale -PassThru).Value
        $TS_UserLocale.Text = (Set-PSDWizardTSEnvProperty -Name UserLocale -Value $MappedLocale -PassThru).Value
    }

    If ($TS_KeyboardLocale)
    {
        #get mapped data of current keyboard layout from CustomSettings.ini
        If ($Global:TSKeyboardLocale)
        {
            #get mapped data of current keyboard layout from CustomSettings.ini
            switch -Regex ($Global:TSKeyboardLocale){
                #check if set to kyeboardlayout property (eg. 0409:00000409)
                '(\d{4}):(\d{8})' { $KeyboardLocale = ($Global:PSDWizardLanguageList | Where-Object { $_.KeyboardLayout -eq $Global:TSKeyboardLocale })}
                #check if set to culture property (eg. en-us)
                '(\w{2})-(\w{2})' {$KeyboardLocale = $Global:PSDWizardLanguageList | Where-Object { $_.Culture -eq $Global:TSKeyboardLocale }}
            }
        }Else{
            $KeyboardLocale = $Global:DefaultLocaleObject
        }
        #add the entire list of keyboard options and preselect the one from CustomSettings.ini (if exists)
        If ($_locTabKeyboardLocale.GetType().Name -eq 'ComboBox')
        {
            Add-PSDWizardComboList -InputObject $Global:PSDWizardLanguageList -ListObject $_locTabKeyboardLocale -Identifier 'Name' -PreSelect $KeyboardLocale.Name
        }

        If ($_locTabKeyboardLocale.GetType().Name -eq 'ListBox')
        {
            Add-PSDWizardList -InputObject $Global:PSDWizardLanguageList -ListObject $_locTabKeyboardLocale -Identifier 'Name' -PreSelect $KeyboardLocale.Name
        }
        #Map the select item from list to format TS understands
        $MappedKeyboard = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLanguageList -InputValue $KeyboardLocale.Name -MappedProperty 'Name' -SelectedProperty 'KeyboardLayout' -DefaultValueOnNull $KeyboardLocale.KeyboardLayout)
        $TS_KeyboardLocale.Text = (Set-PSDWizardTSEnvProperty -Name KeyboardLocale -Value $MappedKeyboard -PassThru).Value
    }

    If ($Global:TSInputLocale -and [string]::IsNullOrEmpty($TS_KeyboardLocale.Text) )
    {
        $MappedKeyboard = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLanguageList -InputValue $KeyboardLocale.Name -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)
        $TS_InputLocale.Text = (Set-PSDWizardTSEnvProperty -Name InputLocale -Value $MappedKeyboard -PassThru).Value
        $TS_KeyboardLocale.Text = (Set-PSDWizardTSEnvProperty -Name KeyboardLocale -Value $MappedKeyboard -PassThru).Value
    }

    If ($TS_TimeZoneName)
    {
        #get mapped data of current timezone from CustomSettings.ini
        If ($Global:TSTimeZoneName.Length -gt 0) {
            $TimeZoneName = $Global:PSDWizardTimeZoneIndex | Where-Object { $_.DisplayName -eq $Global:TSTimeZoneName }
        }Else{
            $TimeZoneName = $Global:DefaultTimeZoneObject
        }
        #add the entire list of timezone options and preselect the one from CustomSettings.ini (if exists)
        If ($_locTabTimeZoneName.GetType().Name -eq 'ComboBox') {
            Add-PSDWizardComboList -InputObject $Global:PSDWizardTimeZoneIndex -ListObject $_locTabTimeZoneName -Identifier 'TimeZone' -PreSelect $TimeZoneName.TimeZone
        }
        If ($_locTabTimeZoneName.GetType().Name -eq 'ListBox') {
            Add-PSDWizardList -InputObject $Global:PSDWizardTimeZoneIndex -ListObject $_locTabTimeZoneName -Identifier 'TimeZone' -PreSelect $TimeZoneName.TimeZone
        }

        $MappedTimeZone = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardTimeZoneIndex -InputValue $TimeZoneName.TimeZone -MappedProperty 'TimeZone' -DefaultValueOnNull $TimeZoneName.TimeZone)
        #$MappedTimeZone = $Global:PSDWizardTimeZoneIndex | Where-Object TimeZone -eq $TimeZoneName.TimeZone | Select-Object -first 1
        $TS_TimeZoneName.Text = (Set-PSDWizardTSEnvProperty -Name TimeZoneName -Value $MappedTimeZone.DisplayName -PassThru).Value
        $TS_TimeZone.Text = (Set-PSDWizardTSEnvProperty -Name TimeZone -Value ('{0:d3}' -f [int]$MappedTimeZone.id).ToString() -PassThru).Value
    }
    #endregion

    #region For Locale Tab objects
    # ---------------------------------------------
    #get all available task seqeunces
    $Global:TaskSequencesList = Get-PSDWizardTSChildItem -path "DeploymentShare:\Task Sequences" -Recurse -Passthru
    #get all available Operating Systems
    $Global:OperatingSystemList = Get-PSDWizardTSChildItem -path "DeploymentShare:\Operating Systems" -Recurse -Passthru
    #update ID to what in customsettings.ini
    $TS_TaskSequenceID.Text = Get-PSDWizardTSEnvProperty 'TaskSequenceID' -ValueOnly

    #region For Task Sequence Tab objects
    # ---------------------------------------------
    #Build Task Sequence Tree
    If ($_tsTabTree)
    {
        # start by disabling search
        $_tsTabSearchEnter.IsEnabled = $False
        $_tsTabSearchClear.IsEnabled = $False
        If ($_tsTabTree.GetType().Name -eq 'TreeView') {
            Add-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID' -PreSelect $TS_TaskSequenceID.Text
        }
        If ($_tsTabTree.GetType().Name -eq 'ListBox') {
            Add-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID' -PreSelect $TS_TaskSequenceID.Text
        }
    }
    ElseIf( $TS_TaskSequenceID.Text -in $Global:TaskSequencesList.ID )
    {
        #If no Task sequence pageexist just process whats in CS.ini
        #validate OS GUID exists in OS list
        $TSAssignedOSGUID = Get-PSDWizardTSData -TS $TS_TaskSequenceID.Text -DataSet OSGUID

        $Global:OSSupportedLanguages = @(($Global:OperatingSystemList | Where-Object { $_.Guid -eq $TSAssignedOSGUID }).Language)
        #Get only available locales settings from Select OS
        $Global:OSLanguageList = $Global:PSDWizardLanguageList | Where-Object { $_.Culture -in $Global:OSSupportedLanguages } | Select-Object -Unique
    }
    #endregion

    #region For Application Tab objects
    # ---------------------------------------------
    If ($_appBundlesCmb) {
        $Bundles = Add-PSDWizardBundle -ListObject $_appBundlesCmb -Passthru
        If ($null -eq $Bundles) {
            Get-PSDWizardElement -Name "_appBundlesCmb" | Set-PSDWizardElement -Enable:$False
        }
    }

    #if the app list pane exist, populate it
    If ($_appTabList) {
        # start by disabling search
        $_appTabSearchEnter.IsEnabled = $False
        $_appTabSearchClear.IsEnabled = $False
        Add-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Identifier "Name" -Exclude "Bundles"
    }

    #if the app tree pane exist, populate it
    If ($_appTabTree) {
        Add-PSDWizardTree -SourcePath "DeploymentShare:\Applications" -TreeObject $_appTabTree -Identifier "Name" -Exclude "Bundles"
    }
    #endregion

    #region Hide all items that are named Validation
    # ----------------------------------------------
    Get-PSDWizardElement -Name "TabValidation" -Wildcard | Set-PSDWizardElement -Visible:$False

    #Show hidden TS_ value element if debug
    Get-PSDWizardElement -Name "TS_UILanguage" | Set-PSDWizardElement -Visible:$PSDDeBug
    Get-PSDWizardElement -Name "TS_SystemLocale" -Wildcard | Set-PSDWizardElement -Visible:$PSDDeBug
    Get-PSDWizardElement -Name "TS_UserLocale" | Set-PSDWizardElement -Visible:$PSDDeBug
    Get-PSDWizardElement -Name "TS_KeyboardLocale" | Set-PSDWizardElement -Visible:$PSDDeBug
    Get-PSDWizardElement -Name "TS_TimeZoneName" | Set-PSDWizardElement -Visible:$PSDDeBug
    Get-PSDWizardElement -Name "TS_TimeZone" | Set-PSDWizardElement -Visible:$PSDDeBug
    Get-PSDWizardElement -Name "TS_TaskSequenceID" | Set-PSDWizardElement -Visible:$PSDDeBug

    #region: Task Sequence pane preloader
    If('_wizTaskSequence' -in $_wizTabControl.items.Name ){
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

        <#
        $_tsTabTree.add_SelectedItemChanged({
            If ($_tsTabTree.GetType().Name -eq 'TreeView') {
                $TS_TaskSequenceID.Text = $this.SelectedItem.Tag[2]
            }Else{
                $TS_TaskSequenceID.Text = $this.SelectedItem
            }
            Test-PSDWizardTaskSequence -UIObject $_tsTabTree -TaskSequenceID $TS_TaskSequenceID.Text -ShowValidation
        })
        #>

        #if TS changed, check that too
        If ($_tsTabTree.GetType().Name -eq 'TreeView')
        {
            #make sure task sequence is selected
            $_tsTabTree.add_SelectedItemChanged( {
                    $TS_TaskSequenceID.Text = $this.SelectedItem.Tag[2]
                    $TSAssignedOSGUID = Get-PSDWizardTSData -TS $TS_TaskSequenceID.Text -DataSet OSGUID
                    #validate OS GUID exists in OS list
                    #If ($TS_TaskSequenceID.Text -in $Global:TaskSequencesList.ID) {
                    If($TSAssignedOSGUID -in $Global:OperatingSystemList.Guid)
                    {
                        Invoke-PSDWizardNotification -OutputObject $_tsTabValidation -Type Hide
                        #find the language name in full langauge object list
                        $Global:OSSupportedLanguages = @(($Global:OperatingSystemList | Where-Object { $_.Guid -eq $TSAssignedOSGUID }).Language)
                        #Get only available locales settings from Select OS
                        $Global:OSLanguageList = $Global:PSDWizardLanguageList | Where-Object { $_.Culture -in $Global:OSSupportedLanguages }
                        #set button to enable
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                    }
                    ElseIf($TS_TaskSequenceID.Text -eq 'ID'){
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                        #Invoke-PSDWizardNotification -Message 'Folder Selected!' -OutputObject $_tsTabValidation -Type Error
                    }
                    Else {
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                        Invoke-PSDWizardNotification -Message 'Invalid TS: No OS found!' -OutputObject $_tsTabValidation -Type Error
                    }
                })
        }

        If ($_tsTabTree.GetType().Name -eq 'ListBox')
        {
            $_tsTabTree.add_SelectionChanged( {
                    $TS_TaskSequenceID.Text = $this.SelectedItem
                    $TSAssignedOSGUID = Get-PSDWizardTSData -TS $TS_TaskSequenceID.Text -DataSet OSGUID
                    #validate OS GUID exists in OS list
                    If($TSAssignedOSGUID -in $Global:OperatingSystemList.Guid)
                    {
                        Invoke-PSDWizardNotification -OutputObject $_tsTabValidation -Type Hide
                        #find the language name in full langauge object list (eg.en-US)
                        $Global:OSSupportedLanguages = @(($Global:OperatingSystemList | Where-Object { $_.Guid -eq $TSAssignedOSGUID }).Language)
                        #Get only available locales settings from Select OS
                        $Global:OSLanguageList = $Global:PSDWizardLanguageList | Where-Object { $_.Culture -in $Global:OSSupportedLanguages }
                        #set button to enable
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                    }
                    ElseIf($TS_TaskSequenceID.Text -eq 'ID'){
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                        #Invoke-PSDWizardNotification -Message 'Folder Selected!' -OutputObject $_tsTabValidation -Type Error
                    }
                    Else {
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                        Invoke-PSDWizardNotification -Message 'Invalid TS: No OS found!' -OutputObject $_tsTabValidation -Type Error
                    }
                })
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
        <#
        $_tsTabRefresh.Add_Click( {

            If ($_tsTabTree.GetType().Name -eq 'TreeView') {
                Add-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID'
            }
            If ($_tsTabTree.GetType().Name -eq 'ListBox') {
                Add-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID'
            }
        })
        #>
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

        #actions for expansion and collapse
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

    } #end Tasksequence switch value
    #endregion

    #region: Domain Settings Pane preloader
    If('_wizTargetDisk' -in $_wizTabControl.items.Name ){
        #populate data on start
        $Global:Disks = Get-Disk
        $Global:PhysicalDisks = Get-PhysicalDisk
        $Global:Volumes = $Global:Disks | Get-Partition | Get-Volume
        $Global:Partitions = $Global:Disks | Get-Partition

        $Global:OSDDiskIndex = Get-PSDWizardTSEnvProperty -Name "OSDDiskIndex" -ValueOnly
        #$Global:WmiVolumes = Get-WMIObject Win32_LogicalDisk | Foreach-Object { Get-WmiObject -Query "Associators of {Win32_LogicalDisk.DeviceID='$($_.DeviceID)'} WHERE ResultRole=Antecedent" | Select *}
        
        #populate the list boxes for the disks and volumes
        $_lstDisks.ItemsSource = @($Global:Disks | Sort DiskNumber | Select Number,FriendlyName,PartitionStyle,
                                        @{Name="Model";Expression={($Global:PhysicalDisks | Where-Object DeviceID -eq $_.Number).Model}},
                                        @{Name="Bus";Expression={($Global:PhysicalDisks | Where-Object DeviceID -eq $_.Number).BusType}},
                                        @{Name="Media";Expression={($Global:PhysicalDisks | Where-Object DeviceID -eq $_.Number).MediaType}},
                                        @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}})

        $_lstVolumes.ItemsSource = @($Global:Volumes | Sort DriveLetter |
                                    Select-Object DriveLetter,FileSystemLabel,FileSystem,DriveType,
                                        @{Name="Disk";Expression={($Global:Partitions | Where-Object AccessPaths -contains "$($_.DriveLetter):\").DiskNumber}},
                                        @{Name="Size";Expression={([math]::round($_.Size /1Gb, 2)).ToString() + ' GB'}},
                                        @{Name="SizeRemaining";Expression={([math]::round($_.SizeRemaining /1Gb, 2)).ToString() + ' GB'}})

        [System.Windows.RoutedEventHandler]$Script:OnVolumeListChanged = {   
            
            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected Volume Index item: {1}" -f ${CmdletName}, ($this.SelectedItem).DriveLetter) -LogLevel 1 }
            # Create a hash table to store values
            $VolDataSet = @{}
            # Get local Volume usage from WMI
            $Vol = $Global:Volumes | Where-Object{$_.DriveLetter -eq ($this.SelectedItem).DriveLetter}
            # Add Free Volume to a hash table
            $VolDataSet.FreeVol = @{}
            $VolDataSet.FreeVol.Header = "Free Space"
            $VolDataSet.FreeVol.Value = [math]::Round(($Vol.SizeRemaining / 1Gb),2)
            # Add used Volume to a hash table
            $VolDataSet.UsedVol = @{}
            $VolDataSet.UsedVol.Header = "Used Space"
            $VolDataSet.UsedVol.Value = [math]::Round(($Vol.Size / 1Gb - $Vol.SizeRemaining / 1Gb),2)
            # Create the Chart
            # Set the image source
            Add-Type -AssemblyName System.Windows.Forms,System.Windows.Forms.DataVisualization
        
            #Create our chart object
            $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
            $Chart.Width = 200
            $Chart.Height = 160
            $Chart.Left = 0
            $Chart.Top = 0

            #Create a chartarea to draw on and add this to the chart
            $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
            $Chart.ChartAreas.Add($ChartArea)
            [void]$Chart.Series.Add("Data")

            #Add a datapoint for each value specified in the parameter hash table
            $VolDataSet.GetEnumerator() | foreach {
                $datapoint = new-object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $_.Value.Value)
                $datapoint.AxisLabel = "$($_.Value.Header)" + "(" + $($_.Value.Value) + " GB)"
                $Chart.Series["Data"].Points.Add($datapoint)
            }

            $Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
            $Chart.Series["Data"]["PieLabelStyle"] = "Outside"
            $Chart.Series["Data"]["PieLineColor"] = "Black"
            $Chart.Series["Data"]["PieDrawingStyle"] = "Concave"
            ($Chart.Series["Data"].Points.FindMaxByValue())["Exploded"] = $true

            #Set the title of the Chart
            $Title = new-object System.Windows.Forms.DataVisualization.Charting.Title
            $Chart.Titles.Add($Title)
            $Chart.Titles[0].Text = ('Volume Usage for: {0}' -f ($this.SelectedItem).DriveLetter)
            
            $File = ($env:Temp + '\' + ($this.SelectedItem).DriveLetter + '_' + $(Get-Date -format "yyyyMMdd_hhmmsstt") + '.png')
            $Chart.SaveImage($File, "PNG")
            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Pie chart image path is now: {1}" -f ${CmdletName}, $File)}
        
            $_imgPieChart.Source = $File
            
            $Chart.Dispose()
        }

        [System.Windows.RoutedEventHandler]$Script:OnDiskListChanged = {

            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected Disk item: {1}" -f ${CmdletName}, $this.SelectedItem) -LogLevel 1 }

            #set the text box to the selected disk number
            $TS_OSDDiskIndex.Text = ($this.SelectedItem).Number
            $_cmbTargetDisk.SelectedItem = ($this.SelectedItem).Number
            #Clear the volume list box and pie chart
            $_lstVolumes.SelectedItem = $null
            $_imgPieChart.Source = $null
            Write-PSDLog -Message ("Target Disk Index selected: " + $TS_OSDDiskIndex.Text)
        }

        #$_lstVolumes.AddHandler([System.Windows.Controls.ListView]::SelectionChangedEvent, $OnVolumeListChanged)
        #$_lstDisks.AddHandler([System.Windows.Controls.ListView]::SelectionChangedEvent, $OnDiskListChanged)

        #Add an event to the text box to enable the next button if text if populated
        [System.Windows.RoutedEventHandler]$Script:OnTargetDiskTextChanged = {
            
            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: OSDDiskIndex value is now: {1}" -f ${CmdletName}, $TS_OSDDiskIndex.Text) -LogLevel 1 }

            If ( $TS_OSDDiskIndex.Text -in $Global:Disks.Number) {            
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
            }Else{
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
            }
        }

        [System.Windows.RoutedEventHandler]$Script:OnTargetDiskChanged = {  
            $TS_OSDDiskIndex.Text = $this.SelectedItem
            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected Target Disk Index item: {1}" -f ${CmdletName}, $this.SelectedItem) -LogLevel 1 }
        }

        #Default to the first disk in the list
        $Global:PreSelectValue = 0


        If ( $_cmbTargetDisk.GetType().Name -eq 'ComboBox') {
            #Add the list to the combo box
            Add-PSDWizardComboList -InputObject $Global:Disks -ListObject $_cmbTargetDisk -Identifier 'Number' -PreSelectIndex $Global:PreSelectValue
        }
        If ( $_cmbTargetDisk.GetType().Name -eq 'ListBox') {
            
            #Add the list to the list box
            Add-PSDWizardList -InputObject $Global:Disks -ListObject $_cmbTargetDisk -Identifier 'Number' -PreSelectIndex $Global:PreSelectValue
        }
    }
    #endregion

    #BUILD EVENT HANDLERS
    #======================================
    #Event for domain or workgroup selection (modern style)
    [System.Windows.RoutedEventHandler]$Script:OnDomainWorkgroupChange = {

        If ($_.source.name -eq '_JoinDomainRadio')
        {
            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Checked JoinDomain radio button" -f ${CmdletName}) -LogLevel 1 }
            
            #remove workgroup value
            Get-PSDWizardElement -Name "TS_JoinWorkgroup" | Set-PSDWizardElement -Text $null
            #Remove-PSDWizardTSEnvProperty -Name "JoinWorkGroup"

            #update UI for domain selection
            Get-PSDWizardElement -Name "Workgroup" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3' #highlight green
            Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Enable:$True
            Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Enable:$False

            #update value from customsettings.ini
            Get-PSDWizardElement -Name "TS_JoinDomain" | Set-PSDWizardElement -Text $Global:JoinDomain

            $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_JoinDomain -OutputObject $_detTabValidation2 -Passthru)
            $_wizNext.IsEnabled = (Confirm-PSDWizardUserName -UserNameObject $TS_DomainAdmin -OutputObject $_detTabValidation2 -Passthru)
            $_wizNext.IsEnabled = (Confirm-PSDWizardFQDN -DomainNameObject $TS_DomainAdminDomain -OutputObject $_detTabValidation2 -Passthru)

            if ([string]::IsNullOrEmpty($TS_DomainAdminPassword.Password)) {
                $_wizNext.IsEnabled = (Confirm-PSDWizardPassword -PasswordObject $TS_DomainAdminPassword -ConfirmedPasswordObject $_DomainAdminConfirmPassword -OutputObject $_detTabValidation2 -Passthru)
            }
            Else {
                $_DomainAdminConfirmPassword.Password = (Get-PSDWizardTSEnvProperty 'DomainAdminPassword' -ValueOnly)
            }
        }

        If ($_.source.name -eq '_JoinWorkgroupRadio')
        {
            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Checked JoinWorkgroup radio button" -f ${CmdletName}) -LogLevel 1 }

            #remove domain value
            Get-PSDWizardElement -Name "TS_JoinDomain" | Set-PSDWizardElement -Text $null
            #Remove-PSDWizardTSEnvProperty -Name "JoinDomain"

            #update UI for workgroup selection
            Get-PSDWizardElement -Name "Domain" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3' #highlight green
            Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Enable:$False
            Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Enable:$True

            #update value from customsettings.ini
            Get-PSDWizardElement -Name "TS_JoinWorkgroup" | Set-PSDWizardElement -Text $Global:JoinWorkgroup

            $TS_JoinWorkgroup.AddHandler(
                [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
                [System.Windows.RoutedEventHandler] {
                    $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
                }
            )

            If ([string]::IsNullOrEmpty($TS_JoinWorkgroup.Text)) {
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
            }
            Else {
                $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
            }
        }
    }

    #Event for domain selection (non modern)
    [System.Windows.RoutedEventHandler]$Script:OnDomainCheck = {

        if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Checked Domain checkbox" -f ${CmdletName}) -LogLevel 1 }

        #remove workgroup value
        Get-PSDWizardElement -Name "TS_JoinWorkgroup" | Set-PSDWizardElement -Text $null

        #update UI for domain selection
        Get-PSDWizardElement -Name "Workgroup" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3' #highlight green
        Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Enable:$True
        Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Enable:$False

        #update value from customsettings.ini
        Get-PSDWizardElement -Name "TS_JoinDomain" | Set-PSDWizardElement -Text $Global:JoinDomain

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

    #Event for workgroup selection (non modern)
    [System.Windows.RoutedEventHandler]$Script:OnWorkgroupCheck = {

        if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Checked Workgroup checkbox" -f ${CmdletName}) -LogLevel 1 }

        #remove domain value
        Get-PSDWizardElement -Name "TS_JoinDomain" | Set-PSDWizardElement -Text $null

        #update UI for workgroup selection
        Get-PSDWizardElement -Name "Domain" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3' #highlight green
        Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Enable:$False
        Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Enable:$True

        #update value from customsettings.ini
        Get-PSDWizardElement -Name "TS_JoinWorkgroup" | Set-PSDWizardElement -Text $Global:JoinWorkgroup

        If ([string]::IsNullOrEmpty($TS_JoinWorkgroup.Text)) {
            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
        }
        Else {
            $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
        }
    }

    #Event for locale system selection
    [System.Windows.RoutedEventHandler]$Script:OnDomainOUSelection = {
        if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected DomainOU item: {1}" -f ${CmdletName}, $this.SelectedItem) -LogLevel 1 }

        #If($Global:CurrentDomainOUSelected -ne $this.SelectedItem){
            $TS_MachineObjectOU.Text = (Set-PSDWizardTSEnvProperty -Name MachineObjectOU -Value $this.SelectedItem -PassThru).Value
        #}
        #store value in a global to compare later
        $Global:CurrentDomainOUSelected = $this.SelectedItem
    }

    #region: Domain Settings Pane preloader
    If('_wizDomainSettings' -in $_wizTabControl.items.Name ){}
    #endregion

    #region: Device Details Pane preloader
    If('_wizDeviceDetails' -in $_wizTabControl.items.Name ){}
    #endregion

    #region: Role Pane preloader
    If('_wizDeviceRole' -in $_wizTabControl.items.Name ){
        #get list from customsettings.ini
        #make the list global so it can be used in the page load script block
        $Global:DeviceRoleList = Get-PSDWizardTSEnvListProperty -Name "DeviceRole" -ValuesOnly #| Sort -Unique
        
        If($Global:DeviceRoleList.count -gt 0){
            Write-PSDLog -Message ("DeviceRole list values are: " + ($Global:DeviceRoleList -join ', '))

            #Add an event to the text box to enable the next button if text if populated
            [System.Windows.RoutedEventHandler]$Script:OnDeviceRoleTextChanged = {
                if ($PSDDeBug) { Write-PSDLog -Message ("{0}: DeviceRole value is now: {1}" -f ${CmdletName}, $TS_DeviceRole.Text) -LogLevel 1 }
                
                If ($TS_DeviceRole.Text -in $Global:DeviceRoleList) {
                    Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                }Else{
                    Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                }
            }

            [System.Windows.RoutedEventHandler]$Script:OnDeviceRoleChanged = {  
                $TS_DeviceRole.Text = $this.SelectedItem
                if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected Intune Group item: {1}" -f ${CmdletName}, $this.SelectedItem) -LogLevel 1 }
            }

            If ( $_cmbDeviceRole.GetType().Name -eq 'ComboBox') {
                $_cmbDeviceRole.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnDeviceRoleChanged) 
            }

            #Add the event to the list box
            If ( $_cmbDeviceRole.GetType().Name -eq 'ListBox') {
                $_cmbDeviceRole.AddHandler([System.Windows.Controls.ListBox]::SelectionChangedEvent, $OnDeviceRoleChanged)
            }

            #Add the event to the combo box
            If ( $_cmbDeviceRole.GetType().Name -eq 'ComboBox') {
                $_cmbDeviceRole.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnDeviceRoleChanged)
                #Add the list to the combo box
                Add-PSDWizardComboList -InputObject $Global:DeviceRoleList -ListObject $_cmbDeviceRole #-Sort
            }

            #Add the event to the list box
            If ( $_cmbDeviceRole.GetType().Name -eq 'ListBox') {
                $_cmbDeviceRole.AddHandler([System.Windows.Controls.ListBox]::SelectionChangedEvent, $OnDeviceRoleChanged)
                #Add the list to the list box
                Add-PSDWizardList -InputObject $Global:DeviceRoleList -ListObject $_cmbDeviceRole
            }


            #Add the event to the text box
            $TS_DeviceRole.AddHandler([System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent, $OnDeviceRoleTextChanged)
        }Else{
            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: DeviceRole list is null: {1}" -f ${CmdletName}) -LogLevel 2 }
            Get-PSDWizardElement -Name "_wizDeviceRole" | Set-PSDWizardElement -visible:$False
        }
        
    }
    #endregion

    #region: Device Details Pane preloader
    If('_wizIntuneGroup' -in $_wizTabControl.items.Name ){
        #get list from customsettings.ini
        #make the list global so it can be used in the page load script block
        $Global:IntuneGroupList = Get-PSDWizardTSEnvListProperty -Name "IntuneGroup" -ValuesOnly #| Sort -Unique
        
        If($Global:IntuneGroupList.count -gt 0){
            Write-PSDLog -Message ("IntuneGroup list values are: " + ($Global:IntuneGroupList -join ', '))
            #Add an event to the text box to enable the next button if text if populated
            [System.Windows.RoutedEventHandler]$Script:OnIntuneGroupTextChanged = {
                if ($PSDDeBug) { Write-PSDLog -Message ("{0}: IntuneGroup value is now: {1}" -f ${CmdletName}, $TS_IntuneGroup.Text) -LogLevel 1 }
                
                If ( $TS_IntuneGroup.Text -in $Global:IntuneGroupList) {            
                    Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                }Else{
                    Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                }
            }

            [System.Windows.RoutedEventHandler]$Script:OnIntuneGroupChanged = {  
                $TS_IntuneGroup.Text = $this.SelectedItem
                if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected Intune Group item: {1}" -f ${CmdletName}, $this.SelectedItem) -LogLevel 1 }
            }
            

            If ( $_cmbIntuneGroup.GetType().Name -eq 'ComboBox') {
                $_cmbIntuneGroup.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnIntuneGroupChanged) 
            }

            #Add the event to the list box
            If ( $_cmbIntuneGroup.GetType().Name -eq 'ListBox') {
                $_cmbIntuneGroup.AddHandler([System.Windows.Controls.ListBox]::SelectionChangedEvent, $OnIntuneGroupChanged)
            }

            #Add the event to the combo box
            If ( $_cmbIntuneGroup.GetType().Name -eq 'ComboBox') {
                $_cmbIntuneGroup.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnIntuneGroupChanged)
                #Add the list to the combo box
                Add-PSDWizardComboList -InputObject $Global:IntuneGroupList -ListObject $_cmbIntuneGroup #-Sort
            }

            #Add the event to the list box
            If ( $_cmbIntuneGroup.GetType().Name -eq 'ListBox') {
                $_cmbIntuneGroup.AddHandler([System.Windows.Controls.ListBox]::SelectionChangedEvent, $OnIntuneGroupChanged)
                #Add the list to the list box
                Add-PSDWizardList -InputObject $Global:IntuneGroupList -ListObject $_cmbIntuneGroup
            }

            
            #Add the event to the text box
            $TS_IntuneGroup.AddHandler([System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent, $OnIntuneGroupTextChanged)
        }Else{
            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: IntuneGroup list is null: {1}" -f ${CmdletName}) -LogLevel 2 }
            Get-PSDWizardElement -Name "_wizIntuneGroup" | Set-PSDWizardElement -visible:$False
        }
    }
    #endregion

    #region: Locale Pane preloader
    If('_wizLocaleTime' -in $_wizTabControl.items.Name )
    {
        #Event for language install selection
        [System.Windows.RoutedEventHandler]$Script:OnLanguageSelection = {

            
            If($Global:CurrentLanguageSelected -ne $this.SelectedItem){
                if($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected Language locale item: {1}" -f ${CmdletName}, $this.SelectedItem) -LogLevel 1 }
                #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
                $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:OSLanguageList -InputValue $this.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture')
                #$TS_UILanguage.Text = ($Global:OSLanguageList | Where-Object { $_.Name -eq $_locTabLanguage.SelectedItem }) | Select-Object -ExpandProperty Culture
            }Else{
                If($PSDDeBug) { Write-PSDLog -Message ("{0}: Language locale item: {1} already selected" -f ${CmdletName}, $Global:CurrentLanguageSelected) -LogLevel 1 }
            }
            #store value in a global to compare later
            $Global:CurrentLanguageSelected = $this.SelectedItem

            #enable next button if all values exist
            If($TS_UILanguage.Text -and $TS_SystemLocale.Text -and $TS_KeyboardLocale.Text -and $TS_TimeZone.Text){
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
            }Else{
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$false
            }

        }

        #Event for locale system selection
        [System.Windows.RoutedEventHandler]$Script:OnSystemLocaleSelection = {

           
            If($Global:CurrentSystemLocaleSelected -ne $this.SelectedItem){
                if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected System locale item: {1}" -f ${CmdletName}, $this.SelectedItem) -LogLevel 1 }
            
                #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
                $MappedLocale = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLanguageList -InputValue $this.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture')
                #$MappedLocale = ($Global:PSDWizardLanguageList | Where-Object { $_.Name -eq $_locTabSystemLocale.SelectedItem }) | Select-Object -ExpandProperty Culture
                $TS_SystemLocale.Text = (Set-PSDWizardTSEnvProperty -Name SystemLocale -Value $MappedLocale -PassThru).Value
                $TS_UserLocale.Text = (Set-PSDWizardTSEnvProperty -Name UserLocale -Value $MappedLocale -PassThru).Value
            }Else{
                If($PSDDeBug) { Write-PSDLog -Message ("{0}: Language locale item: {1} already selected" -f ${CmdletName}, $Global:CurrentLanguageSelected) -LogLevel 1 }
            }
            #store value in a global to compare later
            $Global:CurrentLanguageSelected = $this.SelectedItem
            $Global:CurrentSystemLocaleSelected = $this.SelectedItem

            #enable next button if all values exist
            If($TS_UILanguage.Text -and $TS_SystemLocale.Text -and $TS_KeyboardLocale.Text -and $TS_TimeZone.Text){
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
            }Else{
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$false
            }

        }

        #Event for keyboard selection
        [System.Windows.RoutedEventHandler]$Script:OnKeyboardLocaleSelection = {

            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected Keyboard locale item: {1}" -f ${CmdletName}, $this.SelectedItem) -LogLevel 1 }
            
            #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
            #If($Global:CurrentKeyboardLocaleSelected -ne $this.SelectedItem){
                $MappedKeyboard = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLanguageList -InputValue $this.SelectedItem -MappedProperty 'Name' -SelectedProperty 'KeyboardLayout')
                #$TS_KeyboardLocale.Text = ($Global:PSDWizardLanguageList | Where-Object { $_.Name -eq $_locTabKeyboardLocale.SelectedItem }) | Select-Object -ExpandProperty KeyboardLayout
                $TS_KeyboardLocale.Text = (Set-PSDWizardTSEnvProperty -Name KeyboardLocale -Value $MappedKeyboard -PassThru).Value

                If ( [string]::IsNullOrEmpty($TS_KeyboardLocale.Text) ) {
                    $MappedKeyboard = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLanguageList -InputValue $this.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture')
                    $TS_InputLocale.Text = (Set-PSDWizardTSEnvProperty -Name InputLocale -Value $MappedKeyboard -PassThru).Value
                    $TS_KeyboardLocale.Text = (Set-PSDWizardTSEnvProperty -Name KeyboardLocale -Value $MappedKeyboard -PassThru).Value
                }
            #}
            #store value in a global to compare later
            $Global:CurrentKeyboardLocaleSelected = $this.SelectedItem

            #enable next button if all values exist
            If($TS_UILanguage.Text -and $TS_SystemLocale.Text -and $TS_KeyboardLocale.Text -and $TS_TimeZone.Text){
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
            }Else{
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$false
            }

        }

        #Event for timezone selection
        [System.Windows.RoutedEventHandler]$Script:OnTimeZoneSelection = {

            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected TimeZone item: {1}" -f ${CmdletName}, $this.SelectedItem) -LogLevel 1 }
            
            #If($Global:CurrentTimeZoneSelected -ne $this.SelectedItem){
                $MappedTimeZone = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardTimeZoneIndex -InputValue $this.SelectedItem -MappedProperty 'TimeZone')
                #$MappedTimeZone = $Global:PSDWizardTimeZoneIndex | Where-Object { $_.TimeZone -eq $_locTabTimeZoneName.SelectedItem } | Select-Object -first 1
                $TS_TimeZoneName.Text = (Set-PSDWizardTSEnvProperty -Name TimeZoneName -Value $MappedTimeZone.DisplayName -PassThru).Value
                $TS_TimeZone.Text = (Set-PSDWizardTSEnvProperty -Name TimeZone -Value ('{0:d3}' -f [int]$MappedTimeZone.id).ToString() -PassThru).Value
            #}
            #store value in a global to compare later
            $Global:CurrentTimeZoneSelected = $this.SelectedItem

            #enable next button if all values exist
            If($TS_UILanguage.Text -and $TS_SystemLocale.Text -and $TS_KeyboardLocale.Text -and $TS_TimeZone.Text){
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
            }Else{
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$false
            }

        }

        #Event for all locale selection
        [System.Windows.RoutedEventHandler]$Script:OnLocaleSelection = {

            if ($PSDDeBug) { Write-PSDLog -Message ("{0}: Selected Language locale item: {1}" -f ${CmdletName}, $this.SelectedItem) -LogLevel 1 }
            
            #check if global value is different from the current selection
            #this will change as the user selects different values
            #If($Global:CurrentLanguageSelected -ne $this.SelectedItem){
                #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
                $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:OSLanguageList -InputValue $this.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture')

                $SelectedLocale = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLanguageList -InputValue $this.SelectedItem -MappedProperty 'Name')
                #$SelectedLocale = $Global:PSDWizardLanguageList | Where-Object { $_.Name -eq $_locTabLanguage.SelectedItem }
                $TS_SystemLocale.Text = (Set-PSDWizardTSEnvProperty -Name SystemLocale -Value $SelectedLocale.Culture -PassThru).Value
                $TS_UserLocale.Text = (Set-PSDWizardTSEnvProperty -Name UserLocale -Value $SelectedLocale.Culture -PassThru).Value
                $TS_KeyboardLocale.Text = (Set-PSDWizardTSEnvProperty -Name KeyboardLocale -Value $SelectedLocale.KeyboardLayout -PassThru).Value
            #}

            #store value in a global to compare later
            $Global:CurrentLanguageSelected = $SelectedLocale.Culture
            $Global:CurrentSystemLocaleSelected = $SelectedLocale.Culture
            $Global:CurrentKeyboardLocaleSelected = $SelectedLocale.KeyboardLayout

            #enable next button if all values exist
            If($TS_UILanguage.Text -and $TS_SystemLocale.Text -and $TS_KeyboardLocale.Text -and $TS_TimeZone.Text){
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
            }Else{
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$false
            }

        }
    }
    #endregion

    #region: Application Pane preloader
    If('_wizApplications' -in $_wizTabControl.items.Name ){

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
            $Apps = @()
            $Apps += $this.SelectedItems -join "`n"

            #$_appTabList.items
            # Grab all selected apps a output as a list  like string (viewable by wizard summary)
            # We don't need to process each one with its own variables (eg. Application001, Applications002, etc),
            # the Export-PSDWizardResult cmdlet does that
            $TS_Applications.text = ($Apps | Select-Object -Unique)
            #endregion
        })


        #LIVE SEARCH
        $_appTabSearch.AddHandler(
            [System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent,
            [System.Windows.RoutedEventHandler] {
                If (-not([string]::IsNullOrEmpty($_appTabSearch.Text))) {
                    Search-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Identifier "Name" -Filter $this.Text
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

    } #end Application switch
    #endregion

    #region: Custom Pane preloader
    $CustomPanes = $_wizTabControl.items.Name -match '_wizCustomPane'
    If($CustomPanes.count -gt 0)
    {
        $CustomScriptPath = (Get-PSDContent -Content 'PSDResources\CustomScripts')

        Foreach($CustomPane in $CustomPanes)
        {
            #reset scriptblock to empty string
            $PreloadScriptBlock = [string]::Empty

            #process each custom page 's preload scriptblocks
            $CustomPaneScript = $CustomPane.replace('_wizCustomPane','PSDWizard') + '.ps1'

            If(Test-Path "$CustomScriptPath\$CustomPaneScript"){

                Try{
                    #load script
                    . "$CustomScriptPath\$CustomPaneScript"

                    #invoke scriptblock
                    If( $PreloadScriptBlock.GetType() -eq [System.Management.Automation.ScriptBlock] ){
                        Write-PSDLog -Message ("{0}: Invoking [PreloadScriptBlock] from: {1}" -f ${CmdletName},"$CustomScriptPath\$CustomPaneScript")
                        Invoke-Command -ScriptBlock $PreloadScriptBlock
                    }Else{
                        Write-PSDLog -Message ("{0}: [PreloadScriptBlock] is not a scriptblock or does not exist" -f ${CmdletName}) -LogLevel 3
                    }

                }Catch{
                    Write-PSDLog -Message ("{0}: Failed to run [PreloadScriptBlock]: {1}" -f ${CmdletName}, $_.exception.message) -LogLevel 3
                }
            }Else{
                Write-PSDLog -Message ("{0}: No custom pane script found: {1}" -f ${CmdletName},"$CustomScriptPath\$CustomPaneScript") -LogLevel 2
            }
        }
    }Else{
        Write-PSDLog -Message ("{0}: No custom panes found" -f ${CmdletName}) -LogLevel 1
    }
    #endregion
    #====================================
    # ACTIONS TO PERFORM ON PAGE CHANGE
    #====================================
    [System.Windows.RoutedEventHandler]$Script:OnTabControlChanged = {
    #$_wizTabControl.Add_SelectionChanged( {

            Switch -regex ($this.SelectedItem.Name) {

                '_wizReadiness' {
                    #currently for version 2.2.2b+ hide the ability to select or use selection profiles
                    Get-PSDWizardElement -Name "depSelectionProfiles" -Wildcard | Set-PSDWizardElement -Visible:$False

                    #check if we should skip and/or bypass readiness checks
                    $SkipReadinessCheck = Get-PSDWizardTSEnvProperty -Name 'SkipReadinessCheck' -ValueOnly
                    $AllowReadinessCheckBypass = Get-PSDWizardTSEnvProperty -Name 'PSDReadinessAllowBypass' -ValueOnly

                    If( $SkipReadinessCheck -ne 'YES' )
                    {
                        #load readiness script and call each function for each check
                        $MaxChecks=4
                        #$ReadinessPath = "X:\Deploy\Readiness"
                        $ReadinessScript = Get-PSDWizardTSEnvProperty -Name 'PSDReadinessScript' -ValueOnly
                        $ReadinessPath = (Get-PSDContent -Content 'PSDResources\Readiness')
                        $RunChecks = $true

                        If(Test-Path "$ReadinessPath\$ReadinessScript")
                        {
                            Try{
                                Write-PSDLog -Message ("{0}: Loading readiness script [{1}]" -f ${CmdletName},"$ReadinessPath\$ReadinessScript")
                                . "$ReadinessPath\$ReadinessScript"
                            }Catch{
                                Invoke-PSDWizardNotification -Message $_.exception.message -OutputObject $_depTabValidation01 -Type Error
                                Write-PSDLog -Message ("{0}: Failed to load readiness script [{1}]: {2}" -f ${CmdletName},$ReadinessScript,$_.exception.HResult) -LogLevel 3
                                $RunChecks = $false
                            }

                        }Else{
                            Invoke-PSDWizardNotification -Message "Readiness script not found" -OutputObject $_depTabValidation01 -Type Error
                            Write-PSDLog -Message ("{0}: Failed to load readiness script [{1}]: Not found" -f ${CmdletName},$ReadinessScript) -LogLevel 3
                            $RunChecks = $false
                        }

                        #run checks if script loaded
                        If($RunChecks -eq $true)
                        {
                            #get the number of checks to run
                            $TotalChecks = (Get-PSDWizardTSEnvListProperty -Name "PSDReadinessCheck").count
                            Write-PSDLog -Message ("{0}: Found {1} readiness check(s)" -f ${CmdletName},$TotalChecks)
                            $ReadinessCheckCnt = 0
                            #loop through each check and call the function
                            For ($i=1; ($i -le $MaxChecks) -and ($i -le $TotalChecks); $i++)
                            {
                                #pad variables for variable list and UI element
                                $PSDReadinessCheckPaddVar = ("PSDReadinessCheck{0:D3}" -f $i)
                                $PSDWizardPadElement = ("_depTabValidation{0:D2}" -f $i)

                                If(Get-PSDWizardTSEnvProperty -Name $PSDReadinessCheckPaddVar -ValueOnly)
                                {
                                    Try{
                                        Write-PSDLog -Message ("{0}: running readiness check [{1}]" -f ${CmdletName},$PSDReadinessCheckPaddVar)
                                        $ReadinessCheck = Invoke-Expression -Command (Get-PSDWizardTSEnvProperty -Name $PSDReadinessCheckPaddVar -ValueOnly) -ErrorAction Stop
                                        $ReadinessElement = Get-PSDWizardElement -Name $PSDWizardPadElement
                                        If($ReadinessCheck.Ready -eq $true){
                                            $ReadinessCheckCnt++
                                            Invoke-PSDWizardNotification -Message $ReadinessCheck.Message -OutputObject $ReadinessElement -Type Info
                                        }Else{
                                            Invoke-PSDWizardNotification -Message $ReadinessCheck.Message -OutputObject $ReadinessElement -Type Error
                                        }
                                    }Catch{
                                        Write-PSDLog -Message ("{0}: Failed to readiness check {1}: {2}" -f ${CmdletName}, $i, $_.exception.HResult) -LogLevel 3
                                    }
                                }

                            }



                            If ( ($ReadinessCheckCnt -eq $TotalChecks) -or ($AllowReadinessCheckBypass -eq 'YES') ) {
                                #set button to enable
                                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                            }
                            Else {
                                #set button to disable
                                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                            }

                        }ElseIf($AllowReadinessCheckBypass -eq 'YES'){
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                        }Else{
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                        }
                    }

                }

                '_wizTaskSequence' {
                    #PROCESS ON PAGE LOAD
                    #region For Task Sequence Tab event handlers
                    # -------------------------------------------
                    If( (Get-PSDWizardTSEnvProperty 'PSDWizardCollapseTSList' -ValueOnly) -eq 'YES' ){
                        #collapse all items on load
                        For($i=0; $i -lt $_tsTabTree.Items.Count; $i++)
                        {
                            $_tsTabTree.Items[$i].IsExpanded = $false;
                        }
                    }

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

                    #check if preselect tasksequence is within list
                    If ($TS_TaskSequenceID.Text -in $Global:TaskSequencesList.ID)
                    {
                        #validate OS GUID exists in OS list
                        $TSAssignedOSGUID = Get-PSDWizardTSData -TS $TS_TaskSequenceID.Text -DataSet OSGUID
                        If($TSAssignedOSGUID -in $Global:OperatingSystemList.Guid)
                        {
                            Invoke-PSDWizardNotification -OutputObject $_tsTabValidation -Type Hide
                            #find the language name in full langauge object list
                            $Global:OSSupportedLanguages = @(($Global:OperatingSystemList | Where-Object { $_.Guid -eq $TSAssignedOSGUID }).Language)
                            #Get only available locales settings from Select OS
                            $Global:OSLanguageList = $Global:PSDWizardLanguageList | Where-Object { $_.Culture -in $Global:OSSupportedLanguages }
                            #set button to enable
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                        }
                        ElseIf($TS_TaskSequenceID.Text -eq 'ID'){
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                            #Invoke-PSDWizardNotification -Message 'Folder Selected!' -OutputObject $_tsTabValidation -Type Error
                        }
                        Else {
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                            Invoke-PSDWizardNotification -Message 'Invalid TS: No OS found!' -OutputObject $_tsTabValidation -Type Error
                        }
                    }
                    Else {
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                        #Invoke-PSDWizardNotification -Message 'No TS Selected!' -OutputObject $_tsTabValidation -Type Error
                    }
                }

                '_wizTargetDisk' {
                    
                    Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False

                    #hide the text box if not in debug mode
                    Get-PSDWizardElement -Name "TS_OSDDiskIndex" | Set-PSDWizardElement -Visible:$PSDDeBug
                    #Add the event to the text box
                    $_lstVolumes.AddHandler([System.Windows.Controls.ListView]::SelectionChangedEvent, $OnVolumeListChanged)
                    $_lstDisks.AddHandler([System.Windows.Controls.ListView]::SelectionChangedEvent, $OnDiskListChanged)
                    $TS_OSDDiskIndex.AddHandler([System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent, $OnTargetDiskTextChanged)
                    
                    #set the text box to the preselected value
                    If([string]::IsNullOrEmpty($TS_OSDDiskIndex.Text)){
                        $TS_OSDDiskIndex.Text = $Global:PreSelectValue
                    }
 
                    #Add the event to the combo box
                    If ( $_cmbTargetDisk.GetType().Name -eq 'ComboBox') {
                        $_cmbTargetDisk.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnTargetDiskChanged)
                    }
                    #Add the event to the list box
                    If ( $_cmbTargetDisk.GetType().Name -eq 'ListBox') {
                        $_cmbTargetDisk.AddHandler([System.Windows.Controls.ListBox]::SelectionChangedEvent, $OnTargetDiskChanged)
                    }
                    

                    #set the next button to disabled until a selection is made
                    #Write-PSDLog -Message ("OSDDiskIndex value is now: " + $TS_OSDDiskIndex.Text)
                    If ( -not([string]::IsNullOrEmpty($TS_OSDDiskIndex.Text))) {            
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                    }Else{
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                    }
                    
                }

                '_wizComputerName' {
                    #set focus on computer name; ensures valid name does not get skipped
                    $TS_OSDComputerName.focus()

                    #Check what value is provided by computer name and rebuild it based on supported variables
                    # Any variables declared in CustoSettings.ini are supported + variables with %SERIAL% or %RAND%
                    $TS_OSDComputerName.Text = (Get-PSDWizardComputerName -Value (Get-PSDWizardTSEnvProperty 'OSDComputerName' -ValueOnly))

                    #DETERMINE IF COMPUTERNAME IS VALID ON PAGE LOAD
                    $ValidName = (Confirm-PSDWizardComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru)
                    Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$ValidName

                    #RUN EVENTS AS COMPUTER NAME IS TYPED
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
                    #EVENT: MONITOR SELECTION ON PAGE
                    $_JoinDomainRadio.AddHandler([System.Windows.Controls.CheckBox]::CheckedEvent, $OnDomainCheck)
                    $_JoinDomainRadio.AddHandler([System.Windows.Controls.CheckBox]::UncheckedEvent, $OnWorkgroupCheck)
                    $_DomainOUs.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnDomainOUSelection)

                    #DISPLAY PAGE BASED ON CURRENT SELECTION
                    If (($_JoinDomainRadio.IsChecked -eq $False) -and ([string]::IsNullOrEmpty($TS_JoinDomain.text)) )
                    {

                        #update UI for workgroup selection
                        Get-PSDWizardElement -Name "Domain" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3'
                        Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Visible:$True
                        Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Visible:$False

                        If ([string]::IsNullOrEmpty($TS_JoinWorkgroup.Text)) {
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                        }
                        Else {
                            $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
                        }
                    }
                    Else {

                        #update UI for domain selection
                        Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Visible:$False
                        Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Visible:$True
                        Get-PSDWizardElement -Name "Workgroup" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3'

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


                } #end device switch value

                '_wizDeviceDetails' {

                    #EVENT: MONITOR SELECTION ON PAGE
                    $_wizDeviceDetails.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $OnDomainWorkgroupChange)
                    $_DomainOUs.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnDomainOUSelection)

                    #set focus on computer name;ensures valid name does not get skipped
                    $TS_OSDComputerName.focus()
                    #RUN EVENTS ON PAGE LOAD
                    #Check what value is provided by computer name and rebuild it based on supported variables
                    # Any variables declared in CustoSettings.ini are supported + variables with %SERIAL% or %RAND%
                    $TS_OSDComputerName.Text = (Get-PSDWizardComputerName -Value (Get-PSDWizardTSEnvProperty 'OSDComputerName' -ValueOnly))

                    $ValidName = (Confirm-PSDWizardComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru)
                    Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$ValidName

                    #add handler to name as typing occures to check valid char
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
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False

                    }Else{

                        #Grayout appropiate section
                        If ($_JoinDomainRadio.IsChecked -eq $True)
                        {

                            #update UI for domain selection
                            Get-PSDWizardElement -Name "Workgroup" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3'
                            Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Enable:$True
                            Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Enable:$False

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

                        If ($_JoinWorkgroupRadio.IsChecked -eq $True)
                        {

                            #update UI for workgroup selection
                            Get-PSDWizardElement -Name "Domain" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3'
                            Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Enable:$False
                            Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Enable:$True

                            If ([string]::IsNullOrEmpty($TS_JoinWorkgroup.Text)) {
                                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                            }
                            Else {
                                $_wizNext.IsEnabled = (Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru)
                            }
                        }
                    }

                } #end device switch value

                '_wizCustomPane'{

                    $AllowBypassCustomPane = Get-PSDWizardTSEnvProperty -Name 'PSDWizardCustomPaneAllowBypass' -ValueOnly

                    $CustomPaneScript = ($this.SelectedItem.Name).replace('_wizCustomPane','PSDWizard') + '.ps1'
                    #$CustomPaneScript = (Get-PSDWizardTSEnvProperty -Name ($this.SelectedItem.Name).replace('_wizCustomPane','PSDWizard') -ValueOnly)
                    $CustomScriptPath = (Get-PSDContent -Content 'PSDResources\CustomScripts')

                    If(Test-Path "$CustomScriptPath\$CustomPaneScript")
                    {
                        #reset scriptblock to empty string
                        $PageLoadScriptBlock = [string]::Empty
                        Try{
                            #load script
                            . "$CustomScriptPath\$CustomPaneScript"

                            #invoke scriptblock
                            If( $PageLoadScriptBlock.GetType() -eq [System.Management.Automation.ScriptBlock] ){
                                Write-PSDLog -Message ("{0}: Invoking [PageLoadScriptBlock] from: {1}" -f ${CmdletName},"$CustomScriptPath\$CustomPaneScript")
                                Invoke-Command -ScriptBlock $PageLoadScriptBlock
                            }Else{
                                Write-PSDLog -Message ("{0}: [PageLoadScriptBlock] is not a scriptblock or does not exist" -f ${CmdletName}) -LogLevel 3
                            }
                        }Catch{
                            Write-PSDLog -Message ("{0}: Failed to run [PageLoadScriptBlock]: {1}" -f ${CmdletName}, $_.exception.message) -LogLevel 3
                            If($AllowBypassCustomPane -eq 'YES'){
                                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                            }Else{
                                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                            }
                        }
                    }Else{
                        Write-PSDLog -Message ("{0}: No custom pane script/function found: {1}" -f ${CmdletName},$CustomPaneScript) -LogLevel 2
                        If($AllowBypassCustomPane -eq 'YES'){
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                        }Else{
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                        }
                    }
                    #endregion
                }

                '_wizDomainSettings|_wizDeviceDetails' {
                        #EVENT: REALTIME TEXT CHECKING FOR PAGE
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

                }

                '_wizDeviceRole' {
                    #hide the text box if not in debug mode
                    Get-PSDWizardElement -Name "TS_DeviceRole" | Set-PSDWizardElement -Visible:$PSDDeBug

                    #set the next button to disabled until a selection is made
                    if($tsenv:DeviceRoleAllowBypass -eq "YES"){
                        Write-PSDLog -Message ("DeviceRoleAllowBypass is now: YES")
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                    }
                    else{
                        If ($TS_DeviceRole.Text -in $Global:DeviceRoleList) {
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                        }Else{
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                        }
                    }
                }

                '_wizIntuneGroup' {
                    #hide the text box if not in debug mode
                    Get-PSDWizardElement -Name "TS_IntuneGroup" | Set-PSDWizardElement -Visible:$PSDDeBug

                    #set the next button to disabled until a selection is made
                    if($tsenv:IntuneGroupAllowBypass -eq "YES"){
                        Write-PSDLog -Message ("IntuneGroupAllowBypass is now: YES")
                        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                    }
                    else{
                    Write-PSDLog -Message ("IntuneGroup value is now: " + $TS_IntuneGroup.Text)
                        If ( $TS_IntuneGroup.Text -in $Global:IntuneGroupList) {            
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                        }Else{
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                        }
                    }
                }

                '_wizAdminAccount' {
                    #RUN EVENTS ON PAGE LOAD
                    #currently for version 2.2.2b+ hide the ability to add additional local admin accounts
                    Get-PSDWizardElement -Name "OSDAddAdmin" -wildcard | Set-PSDWizardElement -Visible:$False

                    #check if confirm password has value
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
                    
                    #get mapped data of current UILanguage from CustomSettings.ini
                    If($Global:OSLanguageList.Culture.count -eq 1){
                        $SelectedUILanguage = $Global:OSLanguageList
                    }ElseIf($Global:TSUILanguage.Length -gt 0) {
                        $SelectedUILanguage = $Global:OSLanguageList | Where-Object { $_.Culture -eq $Global:TSUILanguage }
                    }Else{
                        $SelectedUILanguage = $Global:DefaultLocaleObject
                    }
                    if($PSDDebug){Write-PSDLog -Message ("{0}: Default UI languages is: {1}" -f ${CmdletName},$SelectedUILanguage.Name) -LogLevel 1}

                    #only add if needed (would run each time a selection is made)
                    If($_locTabLanguage.items.count -eq 0 ){
                        #refresh Language to install list based on OS support
                        If ($_locTabLanguage.GetType().Name -eq 'ComboBox') {
                            Add-PSDWizardComboList -InputObject $Global:OSLanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
                        }
                        If ($_locTabLanguage.GetType().Name -eq 'ListBox') {
                            Add-PSDWizardList -InputObject $Global:OSLanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
                        }
                    }
                    
                    <#
                    If($Global:CurrentLanguageSelected -ne $SelectedUILanguage.Culture){
                        #choose default (non selecteditem)
                        $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:OSLanguageList -InputValue $Global:CurrentLanguageSelected -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)
                    }
                    #> 
                    If ($_locTabLanguage.GetType().Name -eq 'ComboBox') {
                        $_locTabLanguage.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnLanguageSelection)
                    }
                    If ($_locTabLanguage.GetType().Name -eq 'ListBox') {
                        $_locTabLanguage.AddHandler([System.Windows.Controls.ListBox]::SelectionChangedEvent, $OnLanguageSelection)
                    }
                    #Load eventhandler so value is changed when selection change
                    $_locTabSystemLocale.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnSystemLocaleSelection)
                    $_locTabKeyboardLocale.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnKeyboardLocaleSelection)
                    $_locTabTimeZoneName.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnTimeZoneSelection)                  

                } #end locale and time switch value

                '_wizLanguage' {
                    

                    #get mapped data of current UILanguage from CustomSettings.ini
                    If($Global:OSLanguageList.Culture.count -eq 1){
                        $SelectedUILanguage = $Global:OSLanguageList
                    }ElseIf ($Global:TSUILanguage.Length -gt 0) {
                        $SelectedUILanguage = $Global:OSLanguageList | Where-Object { $_.Culture -eq $Global:TSUILanguage }
                    }Else{
                        $SelectedUILanguage = $Global:DefaultLocaleObject
                    }
                    if($PSDDebug){Write-PSDLog -Message ("{0}: Default UI language is: {1}" -f ${CmdletName},$SelectedUILanguage.Name) -LogLevel 1}

                    #only add if needed (would run each time a selection is made)
                    If($_locTabLanguage.items.count -eq 0 ){
                        #refresh Language to install list based on OS support
                        If ($_locTabLanguage.GetType().Name -eq 'ComboBox') {
                            Add-PSDWizardComboList -InputObject $Global:OSLanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
                        }
                        If ($_locTabLanguage.GetType().Name -eq 'ListBox') {
                            Add-PSDWizardList -InputObject $Global:OSLanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
                         }
                    }
                    
                    <#
                    If($Global:CurrentLanguageSelected -ne $SelectedUILanguage.Culture){
                        #choose default (non selecteditem)
                        $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:OSLanguageList -InputValue $Global:CurrentLanguageSelected -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)
                    }
                    #>
                    If ($_locTabLanguage.GetType().Name -eq 'ComboBox') {
                        $_locTabLanguage.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnLocaleSelection)
                    }
                    If ($_locTabLanguage.GetType().Name -eq 'ListBox') {
                        $_locTabLanguage.AddHandler([System.Windows.Controls.ListBox]::SelectionChangedEvent, $OnLocaleSelection)
                    }

                } #end locale switch value


                '_wizTimeZone' {
                    If ( $_locTabTimeZoneName.GetType().Name -eq 'ComboBox') {
                        $_locTabTimeZoneName.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnTimeZoneSelection)
                    }
                    If ( $_locTabTimeZoneName.GetType().Name -eq 'ListBox') {
                        $_locTabTimeZoneName.AddHandler([System.Windows.Controls.ListBox]::SelectionChangedEvent, $OnTimeZoneSelection)
                    }
                } #end timezone switch value

                '_wizApplications' {
                    #currently for version 2.2.2b+ hide the ability to select applications using bundles
                    Get-PSDWizardElement -Name "appBundles" -wildcard | Set-PSDWizardElement -Visible:$False
                } #end Application switch

                '_wizReady' {
                    #Collect all TS_* variables and their values
                    $NewTSVars = Get-PSDWizardElement -Name "TS_" -Wildcard | Select-Object -Property @{Name = 'Name'; Expression = { $_.Name.replace('TS_', '') } }, @{Name = 'Value'; Expression = { $_.Text } }
                    #Add list to output screen
                    Add-PSDWizardListView -UIObject $_summary -ItemData $NewTSVars
                } #end Summary switch

            } #end all tabs switch
        #}) #end change event
    }
    #Do readonly action when unchecked
    $_wizTabControl.AddHandler([System.Windows.Controls.TabControl]::SelectionChangedEvent, $OnTabControlChanged)


    #region For Main Wizard Template event handlers
    # ---------------------------------------------
    #Change nack and next button display based on tabs
    $_wizTabControl.Add_SelectionChanged( {
            $Tabcount = $this.items.count
            #show the back button if next on first page is displayed
            If ($this.SelectedIndex -eq 0) {
                $_wizBack.Visibility = 'hidden'
            }
            Else {
                $_wizBack.Visibility = 'Visible'
            }

            #change the button text to display begin on the last tab
            If ($this.SelectedIndex -eq ($Tabcount - 1)) {
                $_wizNext.Content = 'Begin'

                $script:UI.Add_KeyDown( {
                        if ($_.Key -match 'Return') {
                            #need to set a result back to true when Begin is clicked
                            $Global:WizardDialogResult = $true
                            $script:UI.Add_Closing( { $_.Cancel = $false })
                            $script:UI.Close()
                        }
                    })

            }
            Else {
                $_wizNext.Content = 'Next'

                #Use tab on keyboard to navigate mentu forward (only works until last page)
                $script:UI.Add_KeyDown( {
                        if ( ($_.Key -match 'Tab') -and ($_wizNext.IsEnabled -eq $True) ) {
                            Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -increment 1
                        }
                    })
            }

            #Enable tab click functionality as wizard progress
            Get-PSDWizardElement -Name ("_wizTab{0:d2}" -f $_wizTabControl.SelectedIndex) | Set-PSDWizardElement -Enable:$true -ErrorAction SilentlyContinue

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
            If(Test-PSDWizardInPE){
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
                $script:UI.Add_Closing( { $_.Cancel = $false })
                $script:UI.Close()
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
            $script:UI.Add_Closing( { $_.Cancel = $false })
            $script:UI.Close() | Out-Null
        })
    #endregion

    #====================================
    # KEYBOARD EVENTS
    #====================================
    #Use shift+tab on keyboard to navigate mentu backward (only works when after first tab)
    $shiftTabPressed = {
        [System.Windows.Input.KeyEventArgs]$Alt = $args[0]
        if ( ($Alt.Key -eq 'Shift') -and ($Alt.Key -eq 'Tab') ) {
            If ($_wizTabControl.SelectedIndex -ne 0) {
                Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -increment -1
            }
        }ElseIf ($Alt.Key -eq 'Tab') {
            Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -increment 1
        }
    }
    Try {
        $null = $script:UI.add_KeyDown([System.Windows.Input.KeyEventHandler]::new($shiftTabPressed))
    }
    Catch {}


    #Use tab on keyboard to navigate menru forward (only works until last page)
    $script:UI.Add_KeyDown( {

        switch ($_.Key) {
            #allow window in front if ESC is hit
            'Esc' {
                If($PSDDebug -eq $false){Write-PSDLog -Message ("{0}: Esc Key was hit. Allowing Items infront of PSDWizard" -f ${CmdletName})}
                $script:UI.Topmost = $false
            }

            #Allow space to hide start wizard
            'Space' {
                If($PSDDebug -eq $false){ Write-PSDLog -Message ("{0}: Space Key was hit. Hiding Start Page" -f ${CmdletName})}
                Get-PSDWizardElement -Name "_startPage" | Set-PSDWizardElement -Visible:$false
            }

            #Allow F5 to refresh wizard content
            'F5' {
                #redownload control content
                $null = Get-PSDContent -Content 'control'
                
                If('_wizTaskSequence' -in $_wizTabControl.items.Name )
                {
                    If($PSDDebug -eq $false){ Write-PSDLog -Message ("{0}: F5 Key was hit. Refreshing Task sequences" -f ${CmdletName})}
                    Invoke-PSDWizardNotification -Message 'Updating, please wait...' -OutputObject $_tsTabValidation -Type Info
                    Try {
                        If ($_tsTabTree.GetType().Name -eq 'TreeView') {
                            Try{$_tsTabTree.Clear() | Out-Null}Catch{}
                            Add-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID'
                        }
                        If ($_tsTabTree.GetType().Name -eq 'ListBox') {
                            Try{$_tsTabTree.Clear() | Out-Null}Catch{}
                            Add-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID'
                        }
                    }
                    Catch {}

                    Invoke-PSDWizardNotification -OutputObject $_tsTabValidation -Type Hide
                }

                If('_wizApplications' -in $_wizTabControl.items.Name )
                {
                    If($PSDDebug -eq $false){ Write-PSDLog -Message ("{0}: F5 Key was hit. Refreshing Applications" -f ${CmdletName})}
                    Try {
                        If ($_appTabList.GetType().Name -eq 'ListBox') {
                            Try{$_appTabList.Clear() | Out-Null}Catch{}
                            Add-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Identifier "Name" -Exclude "Bundles"
                        }
                    }
                    Catch {}
                }
            }

            'F9' {
                If($script:UI.WindowState -eq 'Normal'){
                    If($PSDDebug -eq $false){ Write-PSDLog -Message ("{0}: F9 Key was hit. Minimizing PSDWizard" -f ${CmdletName})}
                    $script:UI.ShowInTaskbar = $true
                    $script:UI.WindowState = 'Minimized'
                }
            }

            'F11' {
                If(Get-PSDWizardDebugConsole){
                    If($PSDDebug -eq $false){ Write-PSDLog -Message ("{0}: F11 Key was hit. Show PSDWizard Debug Console" -f ${CmdletName})}
                    Show-PSDWizardDebugConsole
                }Else{
                    If($PSDDebug -eq $false){ Write-PSDLog -Message ("{0}: F11 Key was hit again. Hiding PSDWizard Debug Console" -f ${CmdletName})}
                    Hide-PSDWizardDebugConsole
                }
            }
        }
    })


    If ($Passthru) {
        # Return the results to the caller
        return $script:UI
    }
}

Function Show-PSDWizardSplashScreen {
    <#
    .SYNOPSIS
        Show the splash screen for the wizard

    .EXAMPLE
        Show-PSDWizardSplashScreen
    #>
    [CmdletBinding()]
    Param(
        $Theme,
        $Language
    )

    [string]${CmdletName} = $MyInvocation.MyCommand
    Write-PSDLog -Message ("{0}: PSDWizard Splashscreen started" -f ${CmdletName})

    # build a hash table with locale data to pass to runspace
    $syncHash = [hashtable]::Synchronized(@{})
    $PSDRunSpace =[runspacefactory]::CreateRunspace()
    $syncHash.Runspace = $PSDRunSpace
    $syncHash.Theme = $Theme
    $syncHash.Language = $Language
    #build runspace
    $PSDRunSpace.ApartmentState = "STA"
    $PSDRunSpace.ThreadOptions = "ReuseThread"
    $PSDRunSpace.Open() | Out-Null
    $PSDRunSpace.SessionStateProxy.SetVariable("syncHash",$syncHash)
    $Script:Pwshell = [PowerShell]::Create().AddScript({
        [string]$xaml = @"
<Window x:Class="PSDMDTUI.splashscreen"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:PSDMDTUI"
        mc:Ignorable="d"
        WindowState="Maximized"
        ResizeMode="NoResize"
        WindowStyle="None"
        Title="Splashscreen"
        WindowStartupLocation="CenterScreen"
        Background="#1f1f1f"
        Height="180" Width="600">
    <Grid x:Name="background" Background="Black" VerticalAlignment="Center">
        <Grid x:Name="grdProgressBar" Visibility="Visible" HorizontalAlignment="Stretch" VerticalAlignment="Center" Height="180" Panel.ZIndex="20" >
            <StackPanel Orientation="Vertical" Width="500" HorizontalAlignment="Center" VerticalAlignment="Center">
                <Label x:Name="lblTitle" Content="@MainTitle" Foreground="White" Height="70" FontSize="30"/>
                <ProgressBar x:Name="ProgressBar" Height="20" HorizontalAlignment="Stretch" Foreground="White" VerticalAlignment="Top" Margin="0"/>
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition></RowDefinition>
                        <RowDefinition></RowDefinition>
                    </Grid.RowDefinitions>
                    <TextBox x:Name="txtStatus" Text="@StatusMsg" HorizontalContentAlignment="Left" HorizontalAlignment="Left" BorderThickness="0" Background="Black" Foreground="White" FontSize="16" Width="346" Margin="10,0,0,0" IsEnabled="False"/>
                    <TextBox x:Name="txtPercentage" Text=" " HorizontalContentAlignment="Right" HorizontalAlignment="Left" BorderThickness="0" Background="Black" Foreground="White" FontSize="16" Width="92" Margin="408,0,0,0" IsEnabled="False"/>
                </Grid>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

        #Load assembies to display UI
        [void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')

        #change background color based on theme (Not used yet)
        switch($syncHash.Theme){
            'Classic' {
                $BGColor = '#004275'
                $FGColor = '#ffffff'
                $WindowState="Normal"
                $Width='600'
                $WindowBackground = '#004275'
            }
            'Refresh' {
                $BGColor = '#004275'
                $FGColor = '#ffffff'
                $WindowState="Normal"
                $Width='600'
                $WindowBackground = '#004275'
            }
            'Tabular' {
                $BGColor = '#004275'
                $FGColor = '#ffffff'
                $WindowState="Maximized"
                $Width='1000'
                $WindowBackground = 'White'
            }
            'Modern' {
                $BGColor = '#004275'
                $FGColor = '#FFE8EDF9'
                $WindowState="Maximized"
                $Width='1024'
                $WindowBackground = '#1f1f1f'
            }
            'Dark' {
                $BGColor = '#343447'
                $FGColor = '#A0A0A0'
                $WindowState="Normal"
                $Width='600'
                $WindowBackground = '#004275'
            }
            default{
                $BGColor = '#004275'
                $FGColor = '#ffffff'
                $WindowState="Normal"
                $Width='600'
                $WindowBackground = '#004275'
            }
        }
        $xaml = $xaml -replace 'Background="Black"', "Background=`"$BGColor`""
        $xaml = $xaml -replace 'Foreground="White"', "Foreground=`"$FGColor`""

        #being inclusive of language
        #add more languages as needed
        switch ($syncHash.Language){
            'en-US' {
                $MainTitle = 'Loading PSD Wizard...'
                $StatusMsg = 'Please wait...'
            }
            default{
                $MainTitle = 'Loading PSD Wizard...'
                $StatusMsg = 'Please wait...'
            }
        }
        $xaml = $xaml -replace '@MainTitle', $MainTitle -replace '@StatusMsg', $StatusMsg

        [xml]$xaml = $xaml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
        $syncHash.window = [Windows.Markup.XamlReader]::Load($reader)

        #===========================================================================
        # Store Form Objects In PowerShell
        #===========================================================================
        $xaml.SelectNodes("//*[@Name]") | %{ $syncHash."$($_.Name)" = $syncHash.Window.FindName($_.Name)}
        
        $syncHash.Window.WindowState = $WindowState
        $syncHash.Window.Width = $Width
        $syncHash.Window.Background = $WindowBackground

        # INNER  FUNCTIONS
        #Closes UI objects and exits (within runspace)
        Function Close-PSDStartLoader
        {
            if ($syncHash.hadCritError) { Write-Host -Message "Background thread had a critical error" -ForegroundColor red }
            #if runspace has not errored Dispose the UI
            if (!($syncHash.isClosing)) { $syncHash.Window.Close() | Out-Null }
        }

        #Add smooth closing for Window
        $syncHash.Window.Add_Loaded({ $syncHash.isLoaded = $True })
    	$syncHash.Window.Add_Closing({ $syncHash.isClosing = $True; Close-PSDWizardSplashScreen })
    	$syncHash.Window.Add_Closed({ $syncHash.isClosed = $True })

        #always force windows on bottom
        $syncHash.Window.Topmost = $False

        $syncHash.Window.ShowDialog()
        #$PSDRunspace.Close()
        #$PSDRunspace.Dispose()
        $syncHash.Error = $Error
    }) # end scriptblock

    #collect data from runspace
    $Data = $syncHash

    #invoke scriptblock in runspace
    $Script:Pwshell.Runspace = $PSDRunSpace
    $AsyncHandle = $Script:Pwshell.BeginInvoke()

    #cleanup registered object
    Register-ObjectEvent -InputObject $syncHash.Runspace `
            -EventName 'AvailabilityChanged' `
            -Action {

                    if($Sender.RunspaceAvailability -eq "Available")
                    {
                        $Sender.Closeasync()
                        $Sender.Dispose()
                        # Speed up resource release by calling the garbage collector explicitly.
                        # Note that this will pause *all* threads briefly.
                        [GC]::Collect()
                    }

                } | Out-Null

    If($Data.Error){Write-PSDLog -Message ("{0}: PSDWizard Splashscreen errored: {1}" -f ${CmdletName}, $Data.Error) -LogLevel 3}
    Else{Write-PSDLog -Message ("{0}: PSDWizard Splashscreen closed" -f ${CmdletName})}
    Return $Data
}

#region FUNCTION: close splashscreen from runspace
function Close-PSDWizardSplashScreen
{
    Param (
        [Parameter(Mandatory=$true, Position=1,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $Runspace
    )
    [string]${CmdletName} = $MyInvocation.MyCommand

    Write-PSDLog -Message ("{0}: Closing PSDWizardSplashScreen..." -f ${CmdletName})
    $Runspace.Window.Dispatcher.Invoke([action]{
      $Runspace.Window.close()
    },'Normal')
}
#endregion


#region Update progress bar for PSDwizard splashscreen
function Update-PSDWizardProgressBar
{
    [CmdletBinding(DefaultParameterSetName='percent')]
    Param (
        [Parameter(Mandatory=$true)]
        $Runspace,
        [parameter(Mandatory=$true, ParameterSetName="percent")]
        [int]$PercentComplete,
        [parameter(Mandatory=$true, ParameterSetName="steps")]
        [int]$Step,
        [parameter(Mandatory=$true, ParameterSetName="steps")]
        [int]$MaxSteps,
        [parameter(Mandatory=$false, ParameterSetName="steps")]
        [int]$Timespan = 1,
        [parameter(Mandatory=$true, ParameterSetName="indeterminate")]
        [switch]$Indeterminate,
        [String]$Status = $Null,
        [ValidateSet("LightGreen", "Yellow", "Red", "Blue")]
        [string]$Color = 'LightGreen'
    )

    [string]${CmdletName} = $MyInvocation.MyCommand

    Try{
        #build field object from name
        If ($PSCmdlet.ParameterSetName -eq "steps")
        {
            #calculate percentage
            $PercentComplete = (($Step / $MaxSteps) * 100)
            #determine where increment will start
            If($Step -eq 1){
                $IncrementFrom = 1
            }Else{
                $IncrementFrom = ((($Step-1) / $MaxSteps) * 100)
            }
            $IncrementBy = ($PercentComplete-$IncrementFrom)/$Timespan
        }

        if($PSCmdlet.ParameterSetName -eq "indeterminate"){
            Write-PSDLog -Message ("{0}: Setting progress bar to indeterminate with status: {1}" -f ${CmdletName},$Status)

            $Runspace.ProgressBar.Dispatcher.Invoke([action]{
                $Runspace.ProgressBar.IsIndeterminate = $True
                $Runspace.ProgressBar.Foreground = $Color

                $Runspace.txtPercentage.Visibility = 'Hidden'
                $Runspace.txtPercentage.Text = ' '

                $Runspace.txtStatus.Text = $Status
            },'Normal')

        }
        else
        {
            if(($PercentComplete -gt 0) -and ($PercentComplete -lt 100))
            {
                If($Timespan -gt 1){
                    $Runspace.ProgressBar.Dispatcher.Invoke([action]{
                        $t=1
                        #Determine the incement to go by based on timespan and difference
                        Do{
                            $IncrementTo = $IncrementFrom + ($IncrementBy * $t)
                            Runspace.ProgressBar.IsIndeterminate = $False
                            $Runspace.ProgressBar.Value = $IncrementTo
                            $Runspace.ProgressBar.Foreground = $Color

                            $Runspace.txtPercentage.Visibility = 'Visible'
                            $Runspace.txtPercentage.Text = ('' + $IncrementTo + '%')

                            $Runspace.txtStatus.Text = $Status

                            $t++
                            Start-Sleep 1

                        } Until ($IncrementTo -ge $PercentComplete -or $t -gt $Timespan)
                    },'Normal')
                }
                Else{
                    Write-PSDLog -Message ("{0}: Setting progress bar to {1}% with status: {2}" -f ${CmdletName},$PercentComplete,$Status)
                    $Runspace.ProgressBar.Dispatcher.Invoke([action]{
                        $Runspace.ProgressBar.IsIndeterminate = $False
                        $Runspace.ProgressBar.Value = $PercentComplete
                        $Runspace.ProgressBar.Foreground = $Color

                        $Runspace.txtPercentage.Visibility = 'Visible'
                        $Runspace.txtPercentage.Text = ('' + $PercentComplete + '%')

                        $Runspace.txtStatus.Text = $Status
                    },'Normal')
                }
            }
            elseif($PercentComplete -eq 100)
            {
                Write-PSDLog -Message ("{0}: Setting progress bar to complete with status: {1}" -f ${CmdletName},$Status)
                $Runspace.ProgressBar.Dispatcher.Invoke([action]{
                        $Runspace.ProgressBar.IsIndeterminate = $False
                        $Runspace.ProgressBar.Value = $PercentComplete
                        $Runspace.ProgressBar.Foreground = $Color

                        $Runspace.txtPercentage.Visibility = 'Visible'
                        $Runspace.txtPercentage.Text = ('' + $PercentComplete + '%')

                        $Runspace.txtStatus.Text = $Status
                },'Normal')
            }
            else{
                Write-PSDLog ("{0}: progress bar is out of range" -f ${CmdletName}) -LogLevel 3
            }
        }
    }Catch{}
}
#endregion


#region FUNCTION: Show-PSDWizard
Function Show-PSDWizard {
    <#
    .SYNOPSIS
        Start the wizard

    .EXAMPLE
        $ResourcePath = (Get-PSDContent -Content 'scripts') + '\PSDWizardNew'
        $Language = 'en-US'
        $Theme = 'Classic'
        Show-PSDWizard -ResourcePath $ResourcePath -Language $Language -Theme $Theme
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('XamlPath')]
        [string]$ResourcePath,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('en-US')]
        [string]$Language = 'en-US',

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$Theme = 'Classic',

        [Parameter(Mandatory = $false)]
        $Page,

        [Parameter(Mandatory = $false)]
        [switch]$AsAsyncJob,

        [Parameter(Mandatory = $false)]
        [switch]$Passthru,

        [switch]$NoSplashScreen
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If($NoSplashScreen -ne $true){
        $splashScreen = Show-PSDWizardSplashScreen -Theme $Theme -Language $Language
        Update-PSDWizardProgressBar -Runspace $splashScreen -Indeterminate -Status "Initializing PSDWizard components..."
    }

    $ResourcePath = $ResourcePath.TrimEnd('\')

    #Default to false
    $Global:WizardDialogResult = $false
    #Load functions from external file
    Write-PSDLog -Message ("{0}: Loading PSD Wizard helper script [{1}\PSDWizard.Helper.ps1]" -f ${CmdletName}, $ResourcePath)
    If($splashScreen.isLoaded){Update-PSDWizardProgressBar -Runspace $splashScreen -Indeterminate -Status "Loading PSDwizard helper file..."}
    . "$ResourcePath\PSDWizard.Helper.ps1" -Caller ${CmdletName}

    #parse changelog for version for a more accurate version
    $ChangeLogPath = Join-Path $ResourcePath 'CHANGELOG.MD'
    If (Test-Path $ChangeLogPath)
    {
        Write-PSDLog -Message ("{0}: ChangeLog found at [{1}]" -f ${CmdletName}, $ChangeLogPath)
        $ChangeLog = Get-Content $ChangeLogPath
        $Changedetails = (($ChangeLog -match '##')[0].TrimStart('##') -split '-').Trim()
        [string]$MenuVersion = [string]$Changedetails[0]
        [string]$MenuDate = $Changedetails[1]
        $VersionTitle = "v$MenuVersion [$MenuDate]"
    }
    Else {
        $VersionTitle = "v2"
    }

    If ( (Get-PSDWizardTSEnvProperty -Name 'PSDDeBug' -ValueOnly) -eq 'YES') {
        $PSDDeBug = $true
    }

    #Set theme in 1 of 3 ways: Parameter, CustomeSettings.ini, Default
    If($splashScreen.isLoaded){Update-PSDWizardProgressBar -Runspace $splashScreen -Indeterminate -Status ("Determining PSDWizard defintion: {0}..." -f $theme)}
    If ($Theme) {
        If ( $PSDDeBug -eq $true ) { Write-PSDLog -Message ("{0}: Show-PSDWizard cmdlet was called with Theme parameter, will attempt to use the theme [{1}]" -f ${CmdletName}, $Theme) }
        $SelectedTheme = $Theme
    }
    ElseIf ($ThemeFromCS = Get-PSDWizardTSEnvProperty -Name 'WizardTheme' -ValueOnly) {
        If ( $PSDDeBug -eq $true ) { Write-PSDLog -Message ("{0}: [WizardTheme] setting found in CustomSetting.ini; will attempt to use the theme [{1}]" -f ${CmdletName}, $ThemeFromCS) }
        $SelectedTheme = $ThemeFromCS
    }
    Else {
        $SelectedTheme = 'Classic'
        If ( $PSDDeBug -eq $true ) { Write-PSDLog -Message ("{0}: No theme control was found; defaulting to theme [{1}]" -f ${CmdletName}, $SelectedTheme) }
    }

    #Build Path to definition files; if file not found, default to en-US version
    If($splashScreen.isLoaded){Update-PSDWizardProgressBar -Runspace $splashScreen -Indeterminate -Status ("Processing PSDWizard language definition: {0}..." -f $Language)}
    [string]$LangDefinitionXml = Join-Path -Path $ResourcePath -ChildPath ('PSDWizard_Definitions_' + $Language + '.xml')
    [string]$ThemeDefinitionXml = Join-Path -Path "$ResourcePath\Themes" -ChildPath ($SelectedTheme + '_Theme_Definitions_' + $Language + '.xml')

    If ( (Test-Path $LangDefinitionXml) -and (Test-Path $ThemeDefinitionXml) )
    {
        [string]$XmlLangDefinitionFile = ('PSDWizard_Definitions_' + $Language + '.xml')
        [string]$XmlThemeDefinitionFile = ($SelectedTheme + '_Theme_Definitions_' + $Language + '.xml')
    }
    Else {
        Write-PSDLog -Message ("{0}: language definition file [{1}] or theme definitions file [{2}] missing; reverting to defaults" -f ${CmdletName}, ('PSDWizard_Definitions_' + $Language + '.xml'), ($SelectedTheme + '_Theme_Definitions_' + $Language + '.xml')) -LogLevel 2
        [string]$XmlLangDefinitionFile = 'PSDWizard_Definitions_en-US.xml'
        [string]$XmlThemeDefinitionFile = 'Classic_Theme_Definitions_en-US.xml'
    }

    #Rebuild Build path to language and theme definition (if paths aren't found)
    [string]$LangDefinitionXml = Join-Path -Path $ResourcePath -ChildPath $XmlLangDefinitionFile
    [string]$ThemeDefinitionXml = Join-Path -Path "$ResourcePath\Themes" -ChildPath $XmlThemeDefinitionFile


    #Check again (Incase definition defaulted to en-US and ARE still missing)
    If ( (Test-Path $LangDefinitionXml) -and (Test-Path $ThemeDefinitionXml) )
    {
        #Get content of Defintion file
        [Xml.XmlDocument]$LangDefinitionXmlDoc = (Get-Content $LangDefinitionXml)
        [Xml.XmlDocument]$ThemeDefinitionXmlDoc = (Get-Content $ThemeDefinitionXml)
    }
    Else {
        Write-PSDLog -Message ("{0}: language definition file [{1}] or theme definitions file [{2}] not found" -f ${CmdletName}, $LangDefinitionXml, $ThemeDefinitionXml) -LogLevel 3
        If($splashScreen.isLoaded){Update-PSDWizardProgressBar -Runspace $splashScreen -PercentComplete 100 -Status ("language and theme definition file not found") -Color Red}
        Break
    }

    If($splashScreen.isLoaded){Update-PSDWizardProgressBar -Runspace $splashScreen -Indeterminate -Status ("Formatting PSDWizard layout...")}
    #Build the XAML file based on definitions
    Write-PSDLog -Message ("{0}: Running [Format-PSDWizard -Path {1} -LangDefinition (xml:{2}) -ThemeDefinition (xml:{3})]" -f ${CmdletName}, $ResourcePath, $XmlLangDefinitionFile, $XmlThemeDefinitionFile)
    Try{
        $script:Xaml = Format-PSDWizard -Path $ResourcePath -LangDefinition $LangDefinitionXmlDoc -ThemeDefinition $ThemeDefinitionXmlDoc
        If ( $PSDDeBug -eq $true ) {
            $Logpath = Split-Path $Global:PSDLogPath -Parent
            $script:Xaml.OuterXml | Out-File "$Logpath\PSDWizardNew_$($SelectedTheme)_$($Language).xaml" -Force
        }
    }Catch{
        If($splashScreen.isLoaded){Update-PSDWizardProgressBar -Runspace $splashScreen -PercentComplete 100 -Status ("Error formatting PSDWizard") -Color Red}
        Write-PSDLog -Message ("{0}: Error formatting PSDWizard: {1}" -f ${CmdletName}, $_.Exception.Message) -LogLevel 3
        Break
    }

    #load wizard
    If($splashScreen.isLoaded){Update-PSDWizardProgressBar -Runspace $splashScreen -Indeterminate -Status ("Importing PSDWizard content...")}
    Write-PSDLog -Message ("{0}: Running [Invoke-PSDWizard -XamlContent `$script:Xaml -Version `"{1}`" -Passthru]" -f ${CmdletName}, $VersionTitle)
    try{
        $script:PSDWizard = Invoke-PSDWizard -XamlContent $script:Xaml -Version "$VersionTitle" -Passthru
        If($script:PSDWizard.length -eq 0){
            If($splashScreen.isLoaded){Update-PSDWizardProgressBar -Runspace $splashScreen -PercentComplete 100 -Status ("Failed to Invoke PSDWizard") -Color Red}
            Write-PSDLog -Message ("{0}: Error loading PSDWizard: No content returned" -f ${CmdletName}) -LogLevel 3
            Break
        }
    }Catch{
        If($splashScreen.isLoaded){Update-PSDWizardProgressBar -Runspace $splashScreen -PercentComplete 100 -Status ("Failed to Invoke PSDWizard") -Color Red}
        Write-PSDLog -Message ("{0}: Error loading PSDWizard: {1}" -f ${CmdletName}, $_.Exception.Message) -LogLevel 3
        Break
    }

    #Get Defintions prefix
    [PSCustomObject]$GlobalElement = Get-PSDWizardDefinitions -Xml $LangDefinitionXmlDoc -Section Global

    Write-PSDLog -Message ("{0}: Running [Set-PSDWizardDefault -XMLContent `$script:Xaml -VariablePrefix {1} -Form `$script:PSDWizard]" -f ${CmdletName}, $GlobalElement.TSVariableFieldPrefix)
    Set-PSDWizardDefault -XMLContent $script:Xaml -VariablePrefix $GlobalElement.TSVariableFieldPrefix -Form $script:PSDWizard

    Write-PSDLog -Message ("{0}: Invoking PSDWizard using locale [{1}] and with [{2}] theme " -f ${CmdletName}, $Language, $SelectedTheme)

    If($NoSplashScreen -ne $true){Update-PSDWizardProgressBar -Runspace $splashScreen -Indeterminate -Status ("Launching PSDwizard...")}
    #Optimize UI when running in Windows
    If ($AsAsyncJob)
    {
        Try{
            $script:PSDWizard.Add_Closing( {
                    #$_.Cancel = $true
                    [System.Windows.Forms.Application]::Exit()
                    Write-PSDLog -Message ("{0}: Closing PSD Wizard" -f ${CmdletName})
                })

            $async = $script:PSDWizard.Dispatcher.InvokeAsync( {
                    Add-Type -AssemblyName System.Drawing, System.Windows.Forms, WindowsFormsIntegration
                    
                    # Enables a Window to receive keyboard messages correctly when it is opened modelessly from Windows Forms.
                    [Void][System.Windows.Forms.Integration.ElementHost]::EnableModelessKeyboardInterop($script:PSDWizard)

                    #make sure this display on top of every window
                    $script:PSDWizard.Topmost = $true
                    # https://blog.netnerds.net/2016/01/showdialog-sucks-use-applicationcontexts-instead/
                    # ShowDialog shows the form as a modal window.
                    # Modal meaning the form cannot lose focus until it's closed and the user can not click on other windows within the same application
                    # With Show, the code proceeds to the line after the Show statement by spawning a new thread
                    # With ShowDialog, it single threaded and does not continue until closed.
                    # Running this without $appContext & ::Run would actually cause a really poor response.
                    # https://docs.microsoft.com/en-us/dotnet/desktop/wpf/app-development/how-to-return-a-dialog-box-result?view=netframeworkdesktop-4.8

                    $script:PSDWizard.Show() | Out-Null
                    # This makes the form pop up
                    $script:PSDWizard.Activate() | Out-Null

                    If($splashScreen.isLoaded){Close-PSDWizardSplashScreen -Runspace $splashScreen}
                    #Wait for the async is complete before continuing
                    $async.Wait() | Out-Null

                    ## Force garbage collection to start the wizard with lower RAM usage.
                    [System.GC]::Collect() | Out-Null
                    [System.GC]::WaitForPendingFinalizers() | Out-Null

                    # Create an application context for it to all run within.
                    # This helps with responsiveness, especially when exiting.
                    $appContext = New-Object System.Windows.Forms.ApplicationContext
                    [void][System.Windows.Forms.Application]::Run($appContext)
                })
        }Catch{
            If($splashScreen.isLoaded){Update-PSDWizardProgressBar -Runspace $splashScreen -PercentComplete 100 -Status ("Error loading PSDWizard") -Color Red}
            Write-PSDLog -Message ("{0}: Error loading PSDWizard: {1}" -f ${CmdletName}, $_.Exception.Message) -LogLevel 3
        }
    }
    Else {

        #make sure window is on top
        $script:PSDWizard.Topmost = $true
        #disable x button
        $script:PSDWizard.Add_Closing( { $_.Cancel = $true })
        
        If($splashScreen.isLoaded){Close-PSDWizardSplashScreen -Runspace $splashScreen}
        #Slower method to present form for modal (no popups)
        $script:PSDWizard.ShowDialog() | Out-Null
    }

    #NOTE: Function will not continue until wizard is closed

    #Save all entered results back
    Write-PSDLog -Message ("{0}: Running [Export-PSDWizardDefault -XMLContent `$script:Xaml -VariablePrefix {1} -Form `$script:PSDWizard]" -f ${CmdletName}, $GlobalElement.TSVariableFieldPrefix)
    Export-PSDWizardResult -XMLContent $script:Xaml -VariablePrefix $GlobalElement.TSVariableFieldPrefix -Form $script:PSDWizard

    If ($Passthru) {
        # Return the form results to the caller
        return $Global:WizardDialogResult
    }
}


##*========================================================================
##* FUNCTIONS
##*========================================================================
#region FUNCTION: Get-PSDWizardLocal
Function Get-PSDWizardLocale {
    <#
    .SYNOPSIS
        Get locales
    .EXAMPLE
        Get-PSDWizardLocale -Path $script:PSDScriptRoot -FileName 'PSDListOfLanguages.xml'
    #>
    [CmdletBinding()]
    Param(
        $Path = $script:PSDScriptRoot,
        $FileName = 'PSDListOfLanguages.xml'
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $LocaleData = @()

    $FilePath = Join-Path $Path -ChildPath $FileName


    If (Test-Path $FilePath) {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Grabbing content from [{1}] " -f ${CmdletName}, $FilePath) }

        $LocaleData = ([xml](Get-Content $FilePath)).Locales.Locale

        Write-PSDLog -Message ("{0}: [{1}] language locales found" -f ${CmdletName}, $LocaleData.count) -loglevel 1
    }
    Else {
        Write-PSDLog -Message ("{0}: Unable to find locale file [{1}] in path [{2}]" -f ${CmdletName}, $FileName, $Path) -LogLevel 3

        #populate sample data otherwise
        $locale = '' | Select-Object ID, Name, Language, Culture, KeyboardID, KeyboardLayout
        $locale.ID = '0409'
        $locale.Name = 'English (United States)'
        $locale.Language = 'English'
        $locale.Culture = 'en-US'
        $locale.KeyboardID = '00000409'
        $locale.KeyboardLayout = '0409:00000409'

        $LocaleData += $locale
    }
    return $LocaleData
}
#endregion

#region FUNCTION:  Get-PSDWizardTSData
Function Get-PSDWizardTSData{
    <#
    .SYNOPSIS
        Get OS data from TS.xml
    .EXAMPLE
        Get-PSDWizardTSData -TS WIN10_PSD1 -DataSet OSGUID
    .EXAMPLE
        $TS = 'WIN10_PSD1'
        Get-PSDWizardTSData -TS $TS -DataSet Name
    #>
    [CmdletBinding()]
    Param(
        [string]$DataPath = $script:PSDContentPath,
        [string]$TS,
        [ValidateSet('Name','OSGUID')]
        [string]$DataSet,
        [switch]$Passthru
    )

    If($TS -ne 'ID'){
        [xml]$TSdata = Get-Content "$DataPath\$TS\TS.xml"
        If($DataSet){
            switch($DataSet){
                'Name' {return $TSdata.sequence.name}
                'OSGUID' {$OSInstallGroup = ($TSdata.sequence.group.step | Where-Object { $_.Type -eq 'BDD_InstallOS' }).defaultVarList.variable
                        return ($OSInstallGroup | Where-Object { $_.Name -eq 'OSGUID' }).'#text'
                        }
            }
        }Else{
            return $TSdata.sequence.group
        }
    }
}
#endregion

#region FUNCTION:  Test-PSDWizardValidTS
Function Test-PSDWizardValidTS{
    <#
    .SYNOPSIS
        Test if Task Sequence is valid PSD Tasksequence
    .EXAMPLE
        Test-PSDWizardValidTS -TS 'WIN10_PSD1'
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$TS
    )

    $ValidTSTemplates = @(
        'PSD Standard Client Task Sequence'
        'PSD Standard Server Task Sequence'
    )

    If( (Get-PSDWizardTSData -TS $TS -DataSet Name) -in $ValidTSTemplates){
        return $true
    }Else{
        return $false
    }
    
}
#endregion


#region FUNCTION:  Test-PSDWizardValidOS
Function Test-PSDWizardValidOS{
    <#
    .SYNOPSIS
        Test if Task Sequence is valid PSD Tasksequence
    .EXAMPLE
        Test-PSDWizardValidTS -TS 'WIN10_PSD1'
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$TS
    )

    $OSGUIDs = Get-PSDWizardOSList

    If( (Get-PSDWizardTSData -TS $TS -DataSet OSGUID) -in $OSGUIDs){
        return $true
    }Else{
        return $false
    }
}
#endregion

#region FUNCTION:  Get-PSDWizardOSList
Function Get-PSDWizardOSList{
    <#
    .SYNOPSIS
        Get OS list from OperatingSystems.xml
    .EXAMPLE
        $Path = Get-PSDContent -Content 'control'
        Get-PSDWizardOSList
    #>
    [CmdletBinding()]
    Param(
        $Path = $script:PSDContentPath
    )

    If ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Grabbing content from [{1}] " -f ${CmdletName}, $FilePath) }

    [xml]$OSdata = Get-Content "$Path\OperatingSystems.xml"

    Return $OSdata.oss.os
}
#endregion

#region FUNCTION: Get-PSDWizardTimeZoneIndex
Function Get-PSDWizardTimeZoneIndex {
    <#
    .SYNOPSIS
        Get index value of Timezone
    .EXAMPLE
        Get-PSDWizardTimeZoneIndex -Path $script:PSDScriptRoot -FileName 'PSDListOfTimeZoneIndex.xml'
    #>
    [CmdletBinding()]
    Param(
        $Path = $script:PSDScriptRoot,
        $FileName = 'PSDListOfTimeZoneIndex.xml'
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $indexData = @()

    $FilePath = Join-Path $Path -ChildPath $FileName

    If (Test-Path $FilePath) {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Grabbing content from [{1}] " -f ${CmdletName}, $FilePath) }

        $IndexData = ([xml](Get-Content $FilePath)).TimeZoneIndex.Index

        Write-PSDLog -Message ("{0}: [{1}] timezone indexes found" -f ${CmdletName}, $IndexData.count) -loglevel 1
    }
    Else {
        Write-PSDLog -Message ("{0}: Unable to find index file [{1}] in path [{2}]" -f ${CmdletName}, $FileName, $Path) -LogLevel 3

        #populate sample data otherwise
        $index = '' | Select-Object id, TimeZone, DisplayName, Name, UTC
        $index.id = 4
        $index.TimeZone = '(GMT-08:00) Pacific Standard Time'
        $index.DisplayName = 'Pacific Standard Time'
        $index.Name = 'Pacific Time (US and Canada)'
        $index.UTC = 'UTC-08:00'

        $indexData += $index
    }
    return $IndexData
}
#endregion

#region FUNCTION: ConvertTo-PSDWizardHexaDecimal
Function ConvertTo-PSDWizardHexaDecimal{
    <#
    .SYNOPSIS
        Find unsupported strings in xml and convert them to Hexdecimal
    .EXAMPLE
        ConvertTo-PSDWizardHexaDecimal -String 'Brooks & Dunn'
    #>
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [AllowEmptyString()]
        [string]$String = ''
    )

    Switch -regex ($String){
        '\!' {$String = $String -replace '\!','&#33;'}
        '\"' {$String = $String -replace '\"','&#34;'}
        '\#' {$String = $String -replace '\#','&#35;'}
        '\$' {$String = $String -replace '\$','&#36;'}
        '\%' {$String = $String -replace '\%','&#37;'}
        '\&' {$String = $String -replace '\&','&#38;'}
        "\'" {$String = $String -replace "\'",'&#39;'}
        '\(' {$String = $String -replace '\(','&#40;'}
        '\)' {$String = $String -replace '\)','&#41;'}
        '\*' {$String = $String -replace '\*','&#42;'}
        '\+' {$String = $String -replace '\+','&#43;'}
        '\,' {$String = $String -replace '\,','&#44;'}
        '\-' {$String = $String -replace '\-','&#45;'}
        #'\.' {$String = $String -replace '\.','&#46;'}
        '\/' {$String = $String -replace '\/','&#47;'}
        '\:' {$String = $String -replace '\:','&#58;'}
        #'\;' {$String = $String -replace '\;','&#59;'}
        '\<' {$String = $String -replace '\<','&#60;'}
        '\=' {$String = $String -replace '\=','&#61;'}
        '\>' {$String = $String -replace '\>','&#62;'}
        '\?' {$String = $String -replace '\?','&#63;'}
        #'\@' {$String = $String -replace '\@','&#64;'}
        '\[' {$String = $String -replace '\[','&#91;'}
        '\\' {$String = $String -replace '\\','&#92;'}
        '\]' {$String = $String -replace '\]','&#93;'}
        '\^' {$String = $String -replace '\^','&#94;'}
        '_'  {$String = $String -replace '_','&#95;'}
        '\`' {$String = $String -replace '\`','&#96;'}
        '\{' {$String = $String -replace '\{','&#123;'}
        '\|' {$String = $String -replace '\|','&#124;'}
        '\}' {$String = $String -replace '\}','&#125;'}
        '\~' {$String = $String -replace '\~','&#126;'}
    }

    return $String
}
#endregion

#region FUNCTION: Get-PSDWizardTSEnvProperty
Function Get-PSDWizardTSEnvProperty {
    <#
    .SYNOPSIS
        Get PSD property value
    .EXAMPLE
        Get-PSDWizardTSEnvProperty 'Skip' -wildcard
    .EXAMPLE
        Get-PSDWizardTSEnvProperty -Name 'OSDComputerName' -ValueOnly
    .EXAMPLE
        Get-PSDWizardTSEnvProperty * -wildcard
    .EXAMPLE
        Get-PSDWizardTSEnvProperty '%scriptroot%' -NoExpand
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,
        [switch]$WildCard,
        [switch]$ValueOnly,
        [switch]$NoExpand
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    # Define parameters for Select-Object cmdlet
    $selectParams = @{
        Property = 'Name', 'Value'
    }
    # If the ValueOnly switch is used, only return the value
    if ($PSBoundParameters.ContainsKey('ValueOnly')) {
        $selectParams.ExpandProperty = 'Value'
    }

    # Try to get the TSEnv item
    Try{
        If ($PSBoundParameters.ContainsKey('WildCard')) {
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Searching value for [{1}]" -f ${CmdletName}, $Name) -LogLevel 1 }
            $TSItem = Get-Item TSEnv:*$Name*
        }
        Else {
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Grabbing value for [{1}]" -f ${CmdletName}, $Name) -LogLevel 1 }
            $TSItem = Get-Item TSEnv:$Name
        }
    }Catch{ 
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Unable to find value for [{1}]" -f ${CmdletName}, $Name) -LogLevel 2 }
        $TSItem = $null
    }

    # Determine if TSItem's value has an environment variable in it
    If (!$NoExpand -and $TSItem) { $TSItem = Expand-PSDWizardTSEnvValue $TSItem }
    
    # Log the result
    if ($PSDDeBug) {
        if ($TSItem.Value -is [System.Object[]]) {
            Write-PSDLog -Message ("{0}: {1} is an object: {2}" -f ${CmdletName}, $Name, ($TSItem.Value | Out-String))
        } elseif ($TSItem.Value) {
            Write-PSDLog -Message ("{0}: {1} is now: {2}" -f ${CmdletName}, $Name, $TSItem.Value) -LogLevel 1
        } else {
            Write-PSDLog -Message ("{0}: {1} is empty" -f ${CmdletName}, $Name) -LogLevel 1
        }
    }

    # Return the result
    if ($null -ne $TSItem) {
        $TSItem | Select-Object @selectParams
    } else {
        return $null
    }
}
#endregion


#region FUNCTION: Get-PSDWizardTSEnvListProperty 
Function Get-PSDWizardTSEnvListProperty {
    <#
    .SYNOPSIS
        Get PSD property value
    .DESCRIPTION
        This function will return a list of all Task Sequence variables that match the provided name such as 001, 002, 003, etc.
    .EXAMPLE
        Get-PSDWizardTSEnvListProperty  -Name 'DeviceRole' -ValuesOnly
    .EXAMPLE
        Get-PSDWizardTSEnvListProperty  -Name 'DomainOUs' -SortByValue
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,
        [switch]$ValuesOnly,
        [switch]$SortByValue
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $SortBy = 'Name'
    # Define parameters for Select-Object cmdlet
    $selectParams = @{
        Property = 'Name', 'Value'
    }
    # If the ValueOnly switch is used, only return the value
    if ($PSBoundParameters.ContainsKey('ValuesOnly')) {
        $selectParams.ExpandProperty = 'Value'
    }

    if ($PSBoundParameters.ContainsKey('SortByValue')) {
        $SortBy = 'Value'
    }

    # Try to get the TSEnv item
    Try{
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Finding [{1}] list" -f ${CmdletName}, $Name) -LogLevel 1 }
        $TSListItems = Get-Item TSEnv:$($Name)00*
        #order the list by sortby
        $TSListItems = $TSListItems | Sort-Object -Property $SortBy
    }Catch{
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Unable to find value for [{1}]" -f ${CmdletName}, $Name) -LogLevel 2 }
        $TSListItems = $null
    }

    # Return the result
    if ($null -ne $TSListItems) {
        $TSListItems| Select-Object @selectParams
    } else {
        return $null
    }
}

#region FUNCTION: Expand-PSDWizardTSEnvValue
Function Expand-PSDWizardTSEnvValue {
    <#
    .SYNOPSIS
        Replace dynamic variables in Task Sequence variables
    .EXAMPLE
        $TSItem = $test = "" | Select-Object Name,value; $test.name='Locale';$test.Value='en-US'
        $TSItem = $test = "" | Select-Object Name,value; $test.name='PSDWizardLogo';$test.Value='%SCRIPTROOT%\powershell.png'
        Expand-PSDWizardTSEnvValue -TSItem $TSItem
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        $TSItem
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($TSItem.Value) {
        #breakup the value by %
        $DynamicValues = [Regex]::Matches($TSItem.Value, '(?<=\%).*?(?=\%)') | Select-Object -ExpandProperty Value

        #sometimes mutliple values exist, loop through each
        foreach ($DynamicValue in $DynamicValues) {
            if ($PSDDeBug -eq $true){ Write-PSDLog -Message ("{0}: Found dynamic value [{1}]" -f ${CmdletName}, $DynamicValue) -LogLevel 1 }
            
            # Use switch statement for better readability
            switch ( $DynamicValue.ToLower() ) {
                'deployroot' { $value = Get-PSDContent }
                'scriptroot' { $value = Get-PSDContent -Content "scripts" }
                'controlroot' { $value = Get-PSDContent -Content "control" }
                'psddeployroot' { $value = Get-PSDContent }
                'psdscriptroot' { $value = Get-PSDContent -Content "scripts" }
                'psdresourceroot' { $value = Get-PSDContent -Content "psdresources" }
                default { $value = (Get-Item TSEnv:$DynamicValue).Value }
            }

            if ( ($PSDDeBug -eq $true) -and ($null -ne $value) ) { 
                Write-PSDLog -Message ("{0}: Updated TSEnv value [{1}] with [{2}]" -f ${CmdletName}, $DynamicValue, $Value) -LogLevel 1 
            }

            If ($value -and $DynamicValue) {
                #replace %value% with correct variable value
                Try{
                    $TSItem.Value = $TSItem.Value.replace(('%' + $DynamicValue + '%'), $value)
                } catch {
                    # Implement error handling if required
                    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Unable to substitute value [{1}]" -f ${CmdletName}, $DynamicValue) -LogLevel 2 }
                }
            }
        }#end loop
    }

    return $TSItem
}
#endregion

#region FUNCTION: Set-PSDWizardTSEnvProperty
Function Set-PSDWizardTSEnvProperty {
    <#
    .SYNOPSIS
        Set PSD property value
    .EXAMPLE
        $Name='OSDComputerName'
        $Value='PSD-NA'
        Set-PSDWizardTSEnvProperty 'OSDComputerName' -Value 'PSD-NA'
    .LINK
        Get-PSDWizardTSEnvProperty
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [AllowEmptyString()]
        [string]$Value,
        [switch]$WildCard,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSBoundParameters.ContainsKey('WildCard')) {
        Get-PSDWizardTSEnvProperty $Name -WildCard | ForEach-Object {
             Set-Item -Path TSEnv:$_.Name -Value $Value -Force
             if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Set [{1}] to [{2}]" -f ${CmdletName}, $_.Name, $Value) -LogLevel 1 }
        }
    }Else {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Set [{1}] to [{2}]" -f ${CmdletName}, $Name, $Value) -LogLevel 1 }
        Set-Item -Path TSEnv:$Name -Value $Value -Force
    }

    If ($PSBoundParameters.ContainsKey('Passthru')) {
        If ($PSBoundParameters.ContainsKey('WildCard')) {
            Get-PSDWizardTSEnvProperty $Name -WildCard
        }Else {
            Get-PSDWizardTSEnvProperty $Name
        }
    }
}
#endregion

Function Remove-PSDWizardTSEnvProperty {
    <#
    .SYNOPSIS
        Removes the value from Task Sequence variable(s)
    .EXAMPLE
        Remove-PSDWizardTSEnvProperty 'OSDComputerName'
    .LINK
        Get-PSDWizardTSEnvProperty
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,
        [switch]$WildCard
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSBoundParameters.ContainsKey('WildCard')) {
        Get-PSDWizardTSEnvProperty $Name -WildCard | ForEach-Object {
             #Remove-Item -Path TSEnv:$_.Name -Force
             Set-PSDWizardTSEnvProperty -Name $_.Name -Value $null
             if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Cleared Value for [{1}]" -f ${CmdletName}, $_.Name) -LogLevel 1 }
        }
    }Else {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Cleared Value for [{1}]" -f ${CmdletName}, $Name) -LogLevel 1 }
        #Remove-Item -Path TSEnv:$Name -Force
        Get-PSDWizardTSEnvProperty $Name | Set-PSDWizardTSEnvProperty -Value $null
    }
}

#region FUNCTION: Switch-PSDWizardTabItem
function Switch-PSDWizardTabItem {
    <#
    .SYNOPSIS
        Change Tab in WPF menu
    .EXAMPLE
        Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -increment -1
    .EXAMPLE
        Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -increment 1
    .EXAMPLE
        Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -header 'Ready'
    .EXAMPLE
        Switch-PSDWizardTabItem -TabControlObject $_wizTabControl -name '_wizReady'
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Windows.Controls.TabControl]$TabControlObject,
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "index")]
        [int]$increment,
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "name")]
        [string]$name,
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "Header")]
        [string]$header
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSCmdlet.ParameterSetName -eq "index") {
        #Add index number to current tab
        $newtab = $TabControlObject.SelectedIndex + $increment
        #ensure number is not greater than tabs
        If ($newtab -ge $TabControlObject.items.count) {
            $newtab = 0
        }
        elseif ($newtab -lt 0) {
            $newtab = $TabControlObject.SelectedIndex - 1
        }
        #Set new tab index
        $TabControlObject.SelectedIndex = $newtab
        $TabSelected = $TabControlObject.items | Where-Object { $_.IsSelected -eq $true }

        $message = ("Selected tab index [{0}] with name [{1}] and header [{2}]" -f $newtab, $TabSelected.Name, $TabSelected.Header)
    }

    If ($PSCmdlet.ParameterSetName -eq "header") {
        $newtab = $TabControlObject.items | Where-Object { $_.Header -eq $header }
        $newtab.IsSelected = $true

        $message = ("Selected tab header [{0}] with name of [{1}]" -f $newtab.Header, $newtab.Name)
    }

    If ($PSCmdlet.ParameterSetName -eq "name") {
        $newtab = $TabControlObject.items | Where-Object { $_.Name -eq $name }
        $newtab.IsSelected = $true

        $message = ("Selected tab name [{0}] with header of [{1}]" -f , $newtab.Name, $newtab.Header)
    }

    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: {1}" -f ${CmdletName}, $message) -LogLevel 1 }
}
#endregion

#region FUNCTION: Get-PSDWizardElement
Function Get-PSDWizardElement {
    <#
    .SYNOPSIS
        Get UI elements
    .EXAMPLE
        Get-PSDWizardElement -Name "appBundles" -wildcard
    .EXAMPLE
        Get-PSDWizardElement -Name "_wizNext"
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,
        [switch]$Wildcard
    )
    Begin {
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand

        #build array
        $Elements = @()
    }
    Process {

        If ($Wildcard) {
            $Elements += ($Global:PSDWizardElements | Where-Object { $_.Name -like "*$Name*" }).Value
        }
        Else {
            $Elements += ($Global:PSDWizardElements | Where-Object { $_.Name -eq $Name }).Value
        }

        If ($Elements.count -gt 0) {
            Foreach ($Element in $Elements) {
                If ($Element) {
                    If ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Found UI object named [{1}]" -f ${CmdletName}, $Element.Name) }
                }
            }
        }
        Else {
            If ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: UI object [{1}] does not exist" -f ${CmdletName}, $Name) }
        }
    }
    End {
        Return $Elements
    }
}
#endregion

#region FUNCTION: Set-PSDWizardElement
Function Set-PSDWizardElement {
    <#
    .SYNOPSIS
        Set UI element properties
    .EXAMPLE
        Get-PSDWizardElement -Name "appBundles" -wildcard | Set-PSDWizardElement -Visible:$False
    .EXAMPLE
        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
    .EXAMPLE
        Get-PSDWizardElement -Name "Domain" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3'
    .LINK
        Get-PSDWizardElement
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false, Position = 0, ParameterSetName = "object", ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object[]]$Object,
        [parameter(Mandatory = $false, Position = 0, ParameterSetName = "name")]
        [string[]]$Name,
        [boolean]$Checked,
        [boolean]$Enable,
        [boolean]$Visible,
        [AllowNull()]
        [string]$Content,
        [AllowNull()]
        [string]$Text,
        [string]$BorderColor,
        $Source
    )
    Begin {
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand

        #build field object from name
        If ($PSCmdlet.ParameterSetName -eq "name") {
            $Object = Get-PSDWizardElement -Name $Name
        }

        #set visable values
        switch ($Visible) {
            $true { $SetVisible = 'Visible' }
            $false { $SetVisible = 'Hidden' }
        }

    }
    Process {
        Try {
            #loop each field object
            Foreach ($item in $Object) {
                #grab all the parameters
                $Parameters = $PSBoundParameters | Select-Object -ExpandProperty Keys
                #Write-Host ('Found parameter: {0}' -f $Parameters)
                #loop each parameter
                Foreach ($Parameter in $Parameters) {
                    #Determine what each parameter and value is
                    #if parameter is FieldObject of FieldName ignore setting it value
                    #Write-Host ('working with parameter: {0}' -f $Parameter)
                    Switch ($Parameter) {
                        'BorderColor' { $SetValue = $true; $Property = 'BorderBrush'; $value = $BorderColor }
                        'Checked' { $SetValue = $true; $Property = 'IsChecked'; $value = $Checked }
                        'Enable' { $SetValue = $true; $Property = 'IsEnabled'; $value = $Enable }
                        'Visible' { $SetValue = $true; $Property = 'Visibility'; $value = $SetVisible }
                        'Content' { $SetValue = $true; $Property = 'Content'; $value = $Content }
                        'Text' { $SetValue = $true; $Property = 'Text'; $value = $Text }
                        'Source' { $SetValue = $true; $Property = 'Source'; $value = $Source }
                        default { $SetValue = $false; }
                    }

                    If ($SetValue) {
                        # Write-Host ('Parameter value is: {0}' -f $value)
                        If ( $item.$Property -ne $value ) {
                            $item.$Property = $value
                            If ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Object [{1}] {2} property is now: {3}" -f ${CmdletName}, $item.Name, $Property, $Value) }
                        }
                        Else {
                            If ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Object [{1}] {2} property is still: {3}" -f ${CmdletName}, $item.Name, $Property, $Value) }
                        }
                    }
                }#endloop each parameter
            }#endloop each field object
        }
        Catch {
            #Write-Host $_.Exception.Message
        }
    }
}
#endregion

#region FUNCTION: Invoke-PSDWizardNotification
Function Invoke-PSDWizardNotification {
    <#
    .SYNOPSIS
        Sends notifications to UI output element
    .EXAMPLE
        Invoke-PSDWizardNotification -OutputObject $_tsTabValidation -Type Hide
    .EXAMPLE
        Invoke-PSDWizardNotification -Message 'No TS Selected!' -OutputObject $_tsTabValidation -Type Error
    #>
    [CmdletBinding()]
    Param(
        [String]$Message,
        [ValidateSet('Error', 'Info', 'Warning', 'Hide')]
        [String]$Type,
        $HighlightObject,
        $OutputObject,
        [switch]$Passthru
    )

    switch ($Type) {
        'Error' {
            $CanvasColor = 'LightPink';
            $Highlight = 'Red';
            $ReturnValue = $False
            If ($OutputObject) {
                $OutputObject.Visibility = "Visible"
                (Get-Variable ($OutputObject.Name + '_Alert') -Value).Visibility = "Visible"
                (Get-Variable ($OutputObject.Name + '_Check') -Value).Visibility = "Hidden"
                (Get-Variable ($OutputObject.Name + '_Name') -Value).Visibility = "Visible"
            }
        }
        'Info' {
            $CanvasColor = 'LightGreen';
            $Highlight = 'Green';
            $ReturnValue = $true
            If ($OutputObject) {
                $OutputObject.Visibility = "Visible"
                (Get-Variable ($OutputObject.Name + '_Check') -Value).Visibility = "Visible"
                (Get-Variable ($OutputObject.Name + '_Alert') -Value).Visibility = "Hidden"
                (Get-Variable ($OutputObject.Name + '_Name') -Value).Visibility = "Visible"
            }
        }
        'Warning' {
            $CanvasColor = 'Gray';
            $Highlight = 'Yellow';
            $ReturnValue = $true
            If ($OutputObject) {
                $OutputObject.Visibility = "Visible"
                (Get-Variable ($OutputObject.Name + '_Check') -Value).Visibility = "Visible"
                (Get-Variable ($OutputObject.Name + '_Alert') -Value).Visibility = "Hidden"
                (Get-Variable ($OutputObject.Name + '_Name') -Value).Visibility = "Visible"
            }
        }
        'Hide' {
            $CanvasColor = 'White';
            $Highlight = 'White';
            $ReturnValue = $true
            If ($OutputObject) {
                (Get-Variable ($OutputObject.Name + '_Check') -Value).Visibility = "Hidden"
                (Get-Variable ($OutputObject.Name + '_Alert') -Value).Visibility = "Hidden"
                (Get-Variable ($OutputObject.Name + '_Name') -Value).Visibility = "Hidden"
                $OutputObject.Visibility = "Hidden"
            }
        }
        default {
            $CanvasColor = 'White';
            $Highlight = '#FFABADB3';
            $ReturnValue = $true
            If ($OutputObject) {
                (Get-Variable ($OutputObject.Name + '_Check') -Value).Visibility = "Hidden"
                (Get-Variable ($OutputObject.Name + '_Alert') -Value).Visibility = "Hidden"
                (Get-Variable ($OutputObject.Name + '_Name') -Value).Visibility = "Hidden"
                $OutputObject.Visibility = "Hidden"
            }
        }
    }

    #put a border around object(s)
    Foreach ($Object in $HighlightObject) {
        $Object.BorderThickness = "2"
        $Object.BorderBrush = $Highlight
    }

    If ($OutputObject) {
        $OutputObject.Background = $CanvasColor
        (Get-Variable ($OutputObject.Name + '_Name') -Value).Text = $Message
    }
    If ($Passthru) { return $ReturnValue }
}
#endregion

#region FUNCTION: Confirm-PSDWizardFQDN
Function Confirm-PSDWizardFQDN {
    <#
    .SYNOPSIS
        Validate domain name with regex
    .EXAMPLE
        Confirm-PSDWizardFQDN -DomainNameObject $TS_JoinDomain -OutputObject $_detTabValidation2 -Passthru
    .LINK
        Invoke-PSDWizardNotification
    #>
    param(
        [System.Windows.Controls.TextBox]$DomainNameObject,
        $OutputObject,
        [switch]$Passthru
    )
    $Regex = '(?=^.{3,253}$)(^(((?!-)[a-zA-Z0-9-]{1,63}(?<!-))|((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63})$)'

    $ErrorMessage = $null
    If ($DomainNameObject.Text.length -eq 0) { $ErrorMessage = ("Enter a valid domain name"); $Validation = $false }
    ElseIf ($DomainNameObject.Text -notmatch $Regex) { $ErrorMessage = ("Invalid domain name (eg. contoso.com)"); $Validation = $false }
    Else { $Validation = $true }


    If ($Validation -eq $true) {
        Invoke-PSDWizardNotification -Message 'Valid domain name' -HighlightObject $DomainNameObject -OutputObject $OutputObject -Type Info
    }
    Else {
        Invoke-PSDWizardNotification -Message $ErrorMessage -HighlightObject $DomainNameObject -OutputObject $OutputObject -Type Error
    }

    If ($Passthru) { return $Validation }
}
#endregion

#region FUNCTION: Confirm-PSDWizardWorkgroup
Function Confirm-PSDWizardWorkgroup {
    <#
    .SYNOPSIS
       Validate workgroup name with regex
    .EXAMPLE
        Confirm-PSDWizardWorkgroup -WorkgroupNameObject $TS_JoinWorkgroup -OutputObject $_detTabValidation2 -Passthru
    .LINK
        Invoke-PSDWizardNotification
    #>
    param(
        [System.Windows.Controls.TextBox]$WorkgroupNameObject,
        $OutputObject,
        [switch]$Passthru
    )
    $ErrorMessage = $null
    If ($WorkgroupNameObject.Text.length -eq 0) { $ErrorMessage = ("Enter a valid workgroup name"); $Validation = $false }
    Elseif ($WorkgroupNameObject.text.length -gt 20) { $ErrorMessage = ("More than 20 characters!"); $Validation = $false }
    ElseIf ($WorkgroupNameObject.Text -match "^[-_]|[^a-zA-Z0-9-_]") { $ErrorMessage = ("Invalid character(s) [{0}]." -f $Matches[0]); $Validation = $false }
    Else { $Validation = $true }

    If ($Validation -eq $true) {
        Invoke-PSDWizardNotification -Message 'Valid workgroup name' -HighlightObject $WorkgroupNameObject -OutputObject $OutputObject -Type Info
    }
    Else {
        Invoke-PSDWizardNotification -Message $ErrorMessage -HighlightObject $WorkgroupNameObject -OutputObject $OutputObject -Type Error
    }

    If ($Passthru) { return $Validation }
}
#endregion

#region FUNCTION: Get-PSDWizardRandomAlphanumericString
Function Get-PSDWizardRandomAlphanumericString {
    <#
    .SYNOPSIS
       Generate random alphacharacter
    .EXAMPLE
        Get-PSDWizardRandomAlphanumericString -length 5
    #>
    Param (
        $length
    )

    Begin {
        If ([string]::IsNullOrEmpty($length)) { [int]$length = 8 }Else { [int]$length = $length }
    }

    Process {
        Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length  | ForEach-Object { [char]$_ }) )
    }
}
#endregion

#region FUNCTION:  Confirm-PSDWizardUserName
Function Confirm-PSDWizardUserName {
    <#
    .SYNOPSIS
       Validate domain name with regex
    .EXAMPLE
         Confirm-PSDWizardUserName
    .LINK
        Invoke-PSDWizardNotification
    #>
    param(
        [System.Windows.Controls.TextBox]$UserNameObject,
        $OutputObject,
        [switch]$Passthru
    )

    $ErrorMessage = $null
    If ($UserNameObject.Text.length -eq 0) { $ErrorMessage = ("Enter a valid domain account"); $Validation = $false }
    ElseIf ($UserNameObject.Text -match '[^\.\w]') { $ErrorMessage = ("Invalid character(s) [{0}]." -f $Matches[0]); $Validation = $false }
    Else { $Validation = $true }


    If ($Validation -eq $true) {
        Invoke-PSDWizardNotification -Message 'Valid domain name' -HighlightObject $UserNameObject -OutputObject $OutputObject -Type Info
    }
    Else {
        Invoke-PSDWizardNotification -Message $ErrorMessage -HighlightObject $UserNameObject -OutputObject $OutputObject -Type Error
    }

    If ($Passthru) { return $Validation }
}
#endregion


#region FUNCTION: Set-PSDWizardStringLength
function Set-PSDWizardStringLength {
    <#
    .SYNOPSIS
        Adjusts the string to the specified length by trimming or padding, preserving leading zeros.
    .EXAMPLE
        "00123456" | Set-PSDWizardStringLength -Length 4 -TrimDirection Right
    .EXAMPLE
        "00123456" | Set-PSDWizardStringLength -Length 4 -TrimDirection Left
    .EXAMPLE
        "0012" | Set-PSDWizardStringLength -Length 7 -TrimDirection Left
    #>
    param (
        [parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
        [string]$InputString,

        [parameter(Mandatory = $True, Position = 1)]
        [int]$Length,

        [parameter(Mandatory = $False, Position = 2)]
        [ValidateSet('Left', 'Right')]
        [Alias('TrimOff')]
        [string]$TrimDirection = 'Right'
    )

    Begin {}
    Process {
        Try {
            if ($InputString.Length -gt $Length) {
                # Trim the string if it's longer than the desired length
                if ($TrimDirection -eq 'Right') {
                    $InputString = $InputString.Substring(0, $Length)
                } elseif ($TrimDirection -eq 'Left') {
                    $InputString = $InputString.Substring($InputString.Length - $Length)
                }
            } elseif ($InputString.Length -lt $Length) {
                # Pad the string with leading or trailing zeros if it's shorter
                if ($TrimDirection -eq 'Right') {
                    $InputString = $InputString.PadRight($Length, '0')
                } elseif ($TrimDirection -eq 'Left') {
                    $InputString = $InputString.PadLeft($Length, '0')
                }
            }
        } Catch {
            Write-Error "An error occurred: $_"
        }
    }
    End {
        return $InputString
    }
}
#endregion


#region FUNCTION: Get-PSDWizardComputerName
Function Get-PSDWizardComputerName {
    <#
    .SYNOPSIS
        Convert known wariable based comptuer name into a valid TS name

    .EXAMPLE
        "PSD-DTOLAB01" | Set-PSDWizardStringWithVariables
        Output: "PSD-DTOLAB01"

    .EXAMPLE
        "%PREFIX%-DTOLAB01" | Set-PSDWizardStringWithVariables
        Where %PREFIX% is a value of: DTO
        Output: "DTO-DTOLAB01"

    .EXAMPLE
        "PSD-%SERIAL:5%" | Set-PSDWizardStringWithVariables
        Output: "PSD-56789" (using the actual serial number)
    .EXAMPLE
        "PSD-%RAND:7%" | Set-PSDWizardStringWithVariables
        Output: "PSD-A3DF321" (randomized output)

    .EXAMPLE
        "PSD-%SERIAL%" | Set-PSDWizardStringWithVariables
        Output: "PSD-WHKL456789" (using the actual serial number)

    .EXAMPLE
        "PSD-%SITE%-%SERIAL:7%" | Set-PSDWizardStringWithVariables
        Where %SITE% is a value of: LAB
        Output: "PSD-LAB-L456789" (using the actual serial number)

    .EXAMPLE
        "%PREFIX%-%8:SERIAL%" | Set-PSDWizardStringWithVariables
        Where %PREFIX% is a value of: DTO
        Output: "DTO-WHKL4567" (using the actual serial number)

    .EXAMPLE
        "%PREFIX%-%RAND:2%-%6:SERIAL%" | Set-PSDWizardStringWithVariables
        Where %PREFIX% is a value of: DTO
        Output: "DTO-A3-WHKL45" (using the actual serial number)

    .EXAMPLE
        "%PREFIX%-%SITE%-%RAND:6%" | Set-PSDWizardStringWithVariables
        Where %PREFIX% is a value of: DTO
        Where %SITE% is a value of: LAB
        Output: "DTO-LAB-A3DF32" (randomized output)

    .EXAMPLE
        "PSD-%ASSETTAG%" | Set-PSDWizardStringWithVariables
        Where %ASSETTAG% is a value of: 3757-0958-4574-7040-8653-1408-52
        Output: "PSD-3757-0958-4574-7040-8653-1408-52" (using the actual asset tag)

    .EXAMPLE
        "PSD-%ASSETTAG:9%" | Set-PSDWizardStringWithVariables
        Where %ASSETTAG% is a value of: 3757-0958-4574-7040-8653-1408-52
        Output: "PSD-3757-0958" (using the actual asset tag)

    .EXAMPLE
        "PSD-%MACADDRESS%" | Set-PSDWizardStringWithVariables
        Where %MACADDRESS% is a value of: 00:15:5D:00:00:01
        Output: "PSD-00155D000001" (using the actual MAC address)

    .EXAMPLE
        "PSD-%MACADDRESS:6%" | Set-PSDWizardStringWithVariables
        Where %MACADDRESS% is a value of: 00:15:5D:00:00:01
        Output: "PSD-00155D" (using the actual MAC address)

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        $InputString
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #set new name array
    $NewNameParts = @()

    If($InputString -match '%')
    {
        #Split Up based on variables
        $Parts = $InputString.Split('%')
        #TEST $Part = $Parts[0]
        #TEST $Part = $Parts[-2]
        Foreach ($Part in $Parts) {
            If ( -Not[string]::IsNullOrEmpty($Part) ) {
                Switch -regex ($Part) {
                    'SERIAL' {

                        $SerialValue = Get-PSDWizardTSEnvProperty 'SerialNumber' -ValueOnly
                        If ([string]::IsNullOrEmpty($SerialValue) ) {
                            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Paring Computername portion [{1}]; SERIAL expression has no value" -f ${CmdletName}, $Part, $SerialValue) }
                            [string]$Part = "NA"
                        }
                        Else {
                            #check if serial is truncated with colon (eg. %SERIAL:6%)
                            If ($Part -match '(?<=\:).*?(?=\d{1,2})') {
                                $Length = $Part.split(':')[1]
                                [string]$SerialValue = $SerialValue | Set-PSDWizardStringLength -Length $Length -TrimDirection Right
                            }
                            ElseIf ($Part -match '(?<=^\d{1,2}:)') {
                                $Length = $Part.split(':')[0]
                                [string]$SerialValue = $SerialValue | Set-PSDWizardStringLength -Length $Length -TrimDirection Left
                            }

                            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Parsing Computername portion [{1}]; Using SERIAL expression with value [{2}]" -f ${CmdletName}, $Part, $SerialValue) }

                            #replace part with serial number
                            [string]$Part = $SerialValue
                        }
                    }

                    'RAND' {

                        #check if serial is truncated with colon (eg. %SERIAL:6%)
                        If ($Part -match '(?<=\:).*?(?=\d)') {
                            $Length = $Part.split(':')[1]
                        }
                        Else {
                            #grab string length not inclusing the %RAND% to determine length
                            $Length = 15 - ($InputString -replace '%.*?RAND%', '').Length
                        }
                        
                        [string]$RandValue = Get-PSDWizardRandomAlphanumericString -Length $Length
                        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Parsing Computername portion [{1}]; Using RAND expression with value [{2}]" -f ${CmdletName}, $Part, $RandValue) }

                        #replace part with random name
                        [string]$Part = $RandValue
                    }

                    'MACADDRESS' {

                        #$MacValue = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | Select-Object -ExpandProperty MACAddress
                        $MacValue = Get-PSDWizardTSEnvProperty 'MacAddress' -ValueOnly
                        $MacValue = ($MacValue -split ":") -join ""
                        
                        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Parsing Computername portion [{1}]; Using MACADDRESS expression with value [{2}]" -f ${CmdletName}, $Part, $MacValue) }
                        #check if mac address is truncated with colon (eg. %MACADDRESS:6%)
                        
                        If ($Part -match '(?<=\:).*?(?=\d{1,2})') {
                            $Length = $Part.split(':')[1]
                            [string]$MacValue = $MacValue | Set-PSDWizardStringLength -Length $Length -TrimDirection Right
                        }
                        ElseIf ($Part -match '(?<=^\d{1,2}:)') {
                            $Length = $Part.split(':')[0]
                            [string]$MacValue = $MacValue | Set-PSDWizardStringLength -Length $Length -TrimDirection Left
                        }

                        [string]$Part = $MacValue
                    }

                    'ASSETTAG' {

                        #write-host 'Replaced: ASSETTAG'
                        $AssetValue = Get-PSDWizardTSEnvProperty 'AssetTag' -ValueOnly
                        #$AssetTag = Get-CimInstance Win32_SystemEnclosure | Select-Object -ExpandProperty SMBIOSAssetTag
                        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Parsing Computername portion [{1}]; Using ASSETTAG expression with value [{2}]" -f ${CmdletName}, $Part, $AssetValue) }
                        
                        If ($Part -match '(?<=\:).*?(?=\d{1,2})') {
                            $Length = $Part.split(':')[1]
                            [string]$AssetValue = $AssetValue | Set-PSDWizardStringLength -Length $Length -TrimDirection Right
                        }
                        ElseIf ($Part -match '(?<=^\d{1,2}:)') {
                            $Length = $Part.split(':')[0]
                            [string]$AssetValue = $AssetValue | Set-PSDWizardStringLength -Length $Length -TrimDirection Left
                        }
                        
                        [string]$Part = $AssetValue
                    }

                    
                    #if any value is - or a number, ignore
                    '-|\d+' {}

                    #check any other characters for
                    default {
                        #determine if there is a TSenv variabel that matches a part of name
                        $TSItem = Get-PSDWizardTSEnvProperty $Part -ValueOnly

                        If (-Not[string]::IsNullOrEmpty($TSItem) ) {
                            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Parsing Computername portion [{1}]; found TSEnv property that matches with value of [{2}]" -f ${CmdletName}, $Part, $TSItem) }
                            [string]$Part = $TSItem
                        } Else{
                            [string]$Part = "%$Part%"
                        }
                    }
                }
                #write-host 'Replaced: Nothing'
                $NewNameParts += $Part
            }

        }
    }Else{
        $NewNameParts += $InputString
    }


    #Build name back together
    $NewName = [string]::Concat($NewNameParts)
    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: New computername formed from expressions is [{1}]" -f ${CmdletName}, $NewName) }

    return $NewName.ToUpper()
}
#endregion


#region FUNCTION: Confirm-PSDWizardComputerName
Function Confirm-PSDWizardComputerName {
    <#
    .SYNOPSIS
        Validate ComputerName input & throw errors
    .EXAMPLE
        Confirm-PSDWizardComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru
    .LINK
        Invoke-PSDWizardNotification
    #>
    [CmdletBinding()]
    param(
        [System.Windows.Controls.TextBox]$ComputerNameObject,
        $OutputObject,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $ErrorMessage = $null
    #Validation Rule for computer names
    if ($ComputerNameObject.text.length -eq 0) { $ErrorMessage = ("Enter a valid device name"); $Validation = $false }

    Elseif ($ComputerNameObject.text.length -lt 1) { $ErrorMessage = ("Less than 1 characters!"); $Validation = $false }

    Elseif ($ComputerNameObject.text.length -gt 15) { $ErrorMessage = ("More than 15 characters!"); $Validation = $false }

    Elseif ($ComputerNameObject.text -match "^[-_]|[^a-zA-Z0-9-_]") { $ErrorMessage = ("Invalid character(s) [{0}]." -f $Matches[0]); $Validation = $false }

    Else { $Validation = $true }

    If ($Validation -eq $true) {
        Invoke-PSDWizardNotification -Message 'Valid device name' -HighlightObject $ComputerNameObject -OutputObject $OutputObject -Type Info
    }
    Else {
        Invoke-PSDWizardNotification -Message $ErrorMessage -HighlightObject $ComputerNameObject -OutputObject $OutputObject -Type Error
    }

    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Validating device name [{1}]: {2}" -f ${CmdletName}, $ComputerNameObject.text, $Validation) }
    If ($Passthru) { return $Validation }
}
#endregion

#region FUNCTION: Confirm-PSDWizardPassword
Function Confirm-PSDWizardPassword {
    <#
    .SYNOPSIS
        Validate passwords
    .EXAMPLE
        Confirm-PSDWizardPassword -PasswordObject $TS_DomainAdminPassword -ConfirmedPasswordObject $_DomainAdminConfirmPassword -OutputObject $_detTabValidation2 -Passthru
    .LINK
        Invoke-PSDWizardNotification
    #>
    [CmdletBinding()]
    param(
        [System.Windows.Controls.PasswordBox]$PasswordObject,
        [System.Windows.Controls.PasswordBox]$ConfirmedPasswordObject,
        $OutputObject,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #check to see if password match
    If ([string]::IsNullOrEmpty($PasswordObject.Password)) {
        $Validation = Invoke-PSDWizardNotification -Message ("Password must be supplied") -HighlightObject @($PasswordObject, $ConfirmedPasswordObject) -OutputObject $OutputObject -Type Error -Passthru
    }
    ElseIf ([string]::IsNullOrEmpty($ConfirmedPasswordObject.Password) -and $ConfirmedPasswordObject.IsEnabled -eq $true) {
        $Validation = Invoke-PSDWizardNotification -Message "Confirm password before continuing" -HighlightObject @($PasswordObject, $ConfirmedPasswordObject) -OutputObject $OutputObject -Type Error -Passthru
    }
    #check to see if password match
    ElseIf ($PasswordObject.Password -ne $ConfirmedPasswordObject.Password) {
        $Validation = Invoke-PSDWizardNotification -Message "Passwords do not match" -HighlightObject @($PasswordObject, $ConfirmedPasswordObject) -OutputObject $OutputObject -Type Error -Passthru
    }
    Else {
        $Validation = Invoke-PSDWizardNotification -Message "Passwords match!" -HighlightObject @($PasswordObject, $ConfirmedPasswordObject) -OutputObject $OutputObject -Type Info -Passthru
    }

    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Validating [{1} = {2}]: {3}" -f ${CmdletName}, $PasswordObject.Name, $ConfirmedPasswordObject.Name, $Validation) }

    If ($Passthru) {
        return $Validation
    }
}
#endregion


#region FUNCTION: ConvertTo-PSDWizardTSVar
Function ConvertTo-PSDWizardTSVar {
    <#
    .SYNOPSIS
        Converts from a PSobject to a TS variable
    .EXAMPLE
        ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLanguageList -InputValue $this.SelectedItem -MappedProperty 'Name' -DefaultValueOnNull $SelectedUILanguage.Name

     .EXAMPLE
        $Object=$Global:PSDWizardLanguageList
        $InputValue=$_locTabLanguage.SelectedItem
        $MappedProperty='Name'
        $DefaultValueOnNull=$SelectedUILanguage.Name
        ConvertTo-PSDWizardTSVar -Object $Object -InputValue $InputValue -MappedProperty $MappedProperty -DefaultValueOnNull $DefaultValueOnNull
    #>
    [CmdletBinding(DefaultParameterSetName = 'object')]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "xml")]
        [Object[]]$XmlImport,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "source")]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "script")]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "object")]
        $Object,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "hashtable")]
        [hashtable]$HashTable,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$InputValue,
        [Parameter(Mandatory = $false, Position = 2)]
        [string]$MappedProperty = 'Name',
        [string]$SelectedProperty,
        [string]$DefaultValueOnNull
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $ObjectArray = @()

    If ($PSCmdlet.ParameterSetName -eq "object") {
        $ObjectArray += $Object
    }
    If ($PSCmdlet.ParameterSetName -eq "xml") {
        $ObjectArray += $XmlImport
    }
    If ($PSCmdlet.ParameterSetName -eq "source") {
        $ObjectArray += (Get-PSDWizardTSChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $ObjectArray += Invoke-command $ScriptBlock
    }
    If ($PSCmdlet.ParameterSetName -eq "hashtable") {
        $ObjectArray += $HashTable
    }


    If ($PSCmdlet.ParameterSetName -eq "hashtable") {
        If ($null -ne $InputValue) {
            #grab the name (key) from value
            $Value = $ObjectArray.Get_Item($InputValue)
        }
    }
    Else {
        If ($SelectedProperty) {
            $Value = ($ObjectArray | Where-Object { $_.$MappedProperty -eq $InputValue }).$SelectedProperty
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Queried [{1}] items where ['{2}' = '{3}'] using [{4}] property." -f ${CmdletName}, $ObjectArray.Count, $MappedProperty, $InputValue, $SelectedProperty) }
        }
        Else {
            $Value = ($ObjectArray | Where-Object { $_.$MappedProperty -eq $InputValue })
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Queried [{1}] items where ['{2}' = '{3}']" -f ${CmdletName}, $ObjectArray.Count, $MappedProperty, $InputValue) }
        }
    }

    If ($Value) {
        Write-PSDLog -Message ("{0}: Changed from [{2}] to [{1}] " -f ${CmdletName}, $Value, $InputValue)
        return $Value
    }
    ElseIf ($DefaultValueOnNull) {
        Write-PSDLog -Message ("{0}: Defaulted to [{1}]" -f ${CmdletName}, $DefaultValueOnNull) -LogLevel 2
        return $DefaultValueOnNull
    }
    Else {
        Write-PSDLog -Message ("{0}: Unable to map property [{1}] with input of [{2}]" -f ${CmdletName}, $MappedProperty, $InputValue) -LogLevel 2
    }

}
#endregion

#region FUNCTION: Get-PSDWizardTSChildItem
Function Get-PSDWizardTSChildItem {
    <#
    .SYNOPSIS
        Retrieve items from deployment share
    .EXAMPLE
        Get-PSDWizardTSChildItem -path "DeploymentShare:\Task Sequences" -Recurse -Passthru

    .NOTES
        $AllFiles = Get-ChildItem -Path "DeploymentShare:\Task Sequences" | Where-Object { $_.PSIsContainer -eq $false } | Select-Object * |
            Select-Object ID,Name,Hide,Enable,Comments,GUID,@{Name = 'Path'; Expression = { (($_.PSPath) -split 'Task Sequences\\','')[1] }}
        $AllDirectory = Get-ChildItem -Path "DeploymentShare:\Task Sequences" | Where-Object { $_.PSIsContainer } | Select-Object * |
            Select-Object Name,Enable,Comments,GUID,@{Name = 'Path'; Expression = { (($_.PSPath) -split 'Task Sequences\\','')[1] }}
    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true, Position = 0)]
        [string]$Path,
        [Parameter(Mandatory = $False, Position = 1)]
        [switch]$Directory,
        [switch]$Recurse,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Try {
        $PSDrive = Get-PSDrive ($Path -split ':\\')[0]
    }
    Catch {
        Break
    }

    If ($Recurse) { $RecurseBool = $true }Else { $RecurseBool = $false }

    $Param = @{
        Path    = $Path;
        Recurse = $RecurseBool
    }
    #grab the root directory
    $workingPath = ($Path -split '\\')[0] + '\' + ($Path -split '\\')[1] + '\'
    $EscapePath = [System.Text.RegularExpressions.Regex]::Escape($workingPath)

    #ensure there is no leading slashes
    If ($Path -match '\\$') { $Path = $Path -replace '\\$', '' }

    if ($PSBoundParameters.ContainsKey('Directory')) {

        If ($Passthru) {
            $Content = Get-ChildItem @Param | Where-Object { $_.PSIsContainer } | Select-Object *
        }Else {
            $Content = Get-ChildItem @Param | Where-Object { $_.PSIsContainer } |
                                            Select-Object Name, Enable, Comments, GUID, @{Name = 'Path'; Expression = { (($_.PSPath) -split $EscapePath, '')[1] } }
        }
    }Else {
        #display content. Passthru displays all info
        If ($Passthru) {
            $Content = Get-ChildItem @Param | Where-Object { $_.PSIsContainer -eq $false } | Select-Object *
        }Else {
            $Content = Get-ChildItem @Param | Where-Object { $_.PSIsContainer -eq $false } |
                                            Select-Object ID, Name, Hide, Enable, Comments, GUID, @{Name = 'Path'; Expression = { (($_.PSPath) -split $EscapePath, '')[1] } }
        }
    }

    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Populating content for PSD Drive [{1}]" -f ${CmdletName}, $Path) }
    return $Content
}
#endregion


#region FUNCTION: Add-PSDWizardComboList
Function Add-PSDWizardComboList {
    <#
    .SYNOPSIS
        populate items in dropdown
    .EXAMPLE
        Add-PSDWizardComboList -InputObject $Global:OSLanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
    .EXAMPLE
        $InputObject=$Global:OSLanguageList
        $ListObject=$_locTabLanguage
        $Identifier='Name'
        $PreSelect=$SelectedUILanguage.Name
        
        Add-PSDWizardComboList -InputObject $Global:OSLanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
    .EXAMPLE
        $InputObject=$Global:PSDWizardLanguageList
        $ListObject=$_locTabSystemLocale
        $Identifier='Name'
        $PreSelect=$SystemLocale.Name
    .LINK
        Get-PSDWizardTSChildItem
    #>
    [CmdletBinding(DefaultParameterSetName = 'object')]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "source")]
        [string]$SourcePath,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "script")]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "object", ValueFromPipeline = $true)]
        $InputObject,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "hashtable")]
        [hashtable]$HashTable,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "array")]
        [array]$Array,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.Windows.Controls.ComboBox]$ListObject,

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$Identifier,

        $PreSelect,

        [int]$PreSelectIndex,

        [switch]$Sort,

        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $List = @()

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $List += (Get-PSDWizardTSChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List += Invoke-command $ScriptBlock
    }
    If ($PSCmdlet.ParameterSetName -eq "object") {
        $List += $InputObject
    }
    If ($PSCmdlet.ParameterSetName -eq "array") {
        $List += $Array
    }

    If ($PSBoundParameters.ContainsKey("Sort")) {
        If ($Identifier) {
            $List = $List | Sort-Object -Property $Identifier -Unique
        }Else{
            $List = $List | Sort-Object -Unique
        }
    }

    $ListObject.Items.Clear() | Out-Null

    If ($PSCmdlet.ParameterSetName -eq "hashtable") {
        Try {
            $List += $HashTable

            $List.keys | ForEach-Object -ErrorAction Stop {
                $ListObject.Items.Add($_) | Out-Null
            }
        }
        Catch { $_.Exception.Message }
    }
    Else {
        foreach ($item in $List) {
            If ($Identifier) {
                If($item.$Identifier -notin $ListObject.Items){
                    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Added to [{2}] dropdown: {1}" -f ${CmdletName},$item.$Identifier,$ListObject.Name) }
                    $ListObject.Items.Add($item.$Identifier) | Out-Null
                }
            }
            Else {
                If($item -notin $ListObject.Items){
                    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Added to [{2}] dropdown: {1}" -f ${CmdletName},$item,$ListObject.Name) }
                    $ListObject.Items.Add($item) | Out-Null
                }
            }
        }
    }

    

    #select the item
    If ($PSBoundParameters.ContainsKey("PreSelect")) {
        If($null -ne $PreSelect) { 
            $ListObject.SelectedItem = $PreSelect
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Preselected item [{1}] for [{2}]" -f ${CmdletName}, $PreSelect, $ListObject.Name) }
        }Else{
            #$ListObject.SelectedIndex = 0
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Preselected item  is Null" -f ${CmdletName}) }
        }
    }

    If($PSBoundParameters.ContainsKey("PreSelectIndex")){
        If($null -ne $PreSelectIndex) { 
            $ListObject.SelectedIndex = $PreSelectIndex
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Preselected index [{1}] for [{2}]" -f ${CmdletName}, $PreSelectIndex, $ListObject.Name) }
        }Else{
            #$ListObject.SelectedIndex = 0
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Preselected index is Null" -f ${CmdletName}) }
        }
    }

    If ($Passthru) {
        return $List
    }
}
#endregion

#region FUNCTION: Add-PSDWizardList
Function Add-PSDWizardList {
    <#
    .SYNOPSIS
        populate items in list
    .EXAMPLE
        $SourcePath="DeploymentShare:\Applications"
        $ListObject=$_appTabList
        $Exclude="Bundles"
        $Identifier="Name"
        Add-PSDWizardList -SourcePath $SourcePath -ListObject $ListObject -Identifier $Identifier -Exclude $Exclude
    .EXAMPLE
        Add-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID' -PreSelect $TS_TaskSequenceID.Text
    .LINK
        Get-PSDWizardTSChildItem
    #>
    [CmdletBinding(DefaultParameterSetName = 'object')]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "source")]
        [string]$SourcePath,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "script")]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "object", ValueFromPipeline = $true)]
        $InputObject,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.Windows.Controls.ListBox]$ListObject,

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$Identifier,

        [Parameter(Mandatory = $false, ParameterSetName = "source")]
        [Parameter(Mandatory = $false, ParameterSetName = "script")]
        [string]$Exclude,

        $Preselect,

        [int]$PreSelectIndex,

        [switch]$Sort,

        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $List = @()

    If ($null -eq $Identifier) { $Identifier = '' }

    If ($PSBoundParameters.ContainsKey('Exclude')) {
        [scriptblock]$ExcludeItemFilter = { ($_.$Identifier -NotLike "*$Exclude*") -and ($_.hide -ne $true) -and ($_.enable -ne $false)}
    }
    Else {
        [scriptblock]$ExcludeItemFilter = { ($_.$Identifier -like '*') -and ($_.hide -ne $true) -and ($_.enable -ne $false)}
    }

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $List += (Get-PSDWizardTSChildItem -Path $SourcePath -Recurse) | Where-Object -FilterScript $ExcludeItemFilter
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Found total of [{2}] from source: {1}" -f ${CmdletName},$SourcePath,$List.count) }
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List += Invoke-command $ScriptBlock | Where-Object -FilterScript $ExcludeItemFilter
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Found total of [{2}] from script: {1}" -f ${CmdletName},$ScriptBlock.ToString(),$List.count) }
    }

    If ($PSCmdlet.ParameterSetName -eq "object") {
        $List += $InputObject
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Found total of [{1}] from object" -f ${CmdletName},$List.count) }
    }

    If ($PSBoundParameters.ContainsKey("Sort")) {
        If ($Identifier) {
            $List = $List | Sort-Object -Property $Identifier -Unique
        }Else{
            $List = $List | Sort-Object -Unique
        }
    }
    #clear list first
    $ListObject.Items.Clear() | Out-Null

    foreach ($item in $List ) {
        #Check to see if propertiues exists
        If ($item.PSobject.Properties.Name.Contains($Identifier)) {
            If($item.$Identifier -notin $ListObject.Items){
                if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Added to [{2}] list: {1}" -f ${CmdletName},$item.$Identifier,$ListObject.Name) }
                $ListObject.Items.Add($item.$Identifier) | Out-Null
            }
        }
        Else {
            If($item -notin $ListObject.Items){
                if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Added to [{2}] list: {1}" -f ${CmdletName},$item,$ListObject.Name) }
                $ListObject.Items.Add($item) | Out-Null
            }
        }
    }

    If ($PSBoundParameters.ContainsKey("PreSelect")) {
        If($null -ne $PreSelect) { 
            $ListObject.ScrollIntoView($ListObject.Items[$ListObject.SelectedIndex + 3])
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Preselected item [{1}] for [{2}]" -f ${CmdletName}, $PreSelect, $ListObject.Name) }
        }
    }

    If($PSBoundParameters.ContainsKey("PreSelectIndex")){
        If($null -ne $PreSelectIndex) { 
            $ListObject.ScrollIntoView($ListObject.Items[$PreSelectIndex + 3])
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Preselected index [{1}] for [{2}]" -f ${CmdletName}, $PreSelectIndex, $ListObject.Name) }
        }
    }

    If ($Passthru) {
        return $List
    }
}
#endregion

#region FUNCTION: Add-PSDWizardSelectionProfile
Function Add-PSDWizardSelectionProfile {
    <#
    .SYNOPSIS
        populate Selection profile to dropdown
    .EXAMPLE
        Add-PSDWizardSelectionProfile -ListObject $_depSelectionProfilesList -Passthru
    .LINK
        Get-PSDWizardTSChildItem
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$SourcePath = "DeploymentShare:\Selection Profiles",
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$ListObject,
        [string]$Filter = 'Deployment',
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $ListObject.Items.Clear() | Out-Null

    $List = @() #declare array
    #grab all profiles
    $List += Get-PSDWizardTSChildItem -Path $SourcePath | Where-Object { ( $_.Name -like "$Filter*") -and ($_.enable -ne $False) }

    foreach ($item in $List) {
        $TrimName = ($item.Name).split('-')[1].Trim()
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Added selection profile: {1}" -f ${CmdletName},$TrimName) }
        $ListObject.Items.Add($TrimName) | Out-Null
    }

    If ($Passthru) {
        return $List
    }
}
#endregion

#region FUNCTION: Add-PSDWizardBundle
Function Add-PSDWizardBundle {
    <#
    .SYNOPSIS
        populate Application bundles to dropdown
    .EXAMPLE
        Add-PSDWizardBundle -ListObject $_appBundlesCmb -Passthru
    .LINK
        Get-PSDWizardTSChildItem
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$SourcePath = "DeploymentShare:\Applications",
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$ListObject,
        [switch]$ClearFirst,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($ClearFirst) {
        $ListObject.Items.Clear() | Out-Null
    }

    $List = @() #declare array
    #grab all bundles
    $List += Get-PSDWizardTSChildItem -Path $SourcePath -Recurse | Where-Object { $_.Name -like "*Bundles*" -and $_.enable -ne $False }

    foreach ($item in $List) {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Added to app bundle list: {1}" -f ${CmdletName},$item.Name) }
        $ListObject.Items.Add($item.Name) | Out-Null
    }

    If ($Passthru) {
        return $List
    }
}
#endregion

#region FUNCTION: Search-PSDWizardList
Function Search-PSDWizardList {
    <#
    .SYNOPSIS
         Search the tree view
    .EXAMPLE
        $SourcePath="DeploymentShare:\Applications"
        $ListObject=$_appTabList
        $Filter='Adobe'
        Search-PSDWizardList -SourcePath $SourcePath -ListObject $ListObject-Identifier "Name" -Filter $Filter
    .EXAMPLE
        Search-PSDWizardList -SourcePath "DeploymentShare:\Applications" -ListObject $_appTabList -Identifier "Name" -Filter $_appTabSearch.Text
    .LINK
        Get-PSDWizardTSChildItem
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = "source")]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, ParameterSetName = "script")]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ListBox]$ListObject,
        [Parameter(Mandatory = $true)]
        [string]$Identifier,
        [Parameter(Mandatory = $true)]
        [string]$Filter,
        [switch]$IncludeAll
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $List = @() #declare array

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $List += (Get-PSDWizardTSChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List += Invoke-command $ScriptBlock
    }

    If ($PSBoundParameters.ContainsKey('IncludeAll')) {
        [scriptblock]$IncludeFolderFilter = { $_.Name -Like "*" }
        [scriptblock]$IncludeItemFilter = { $_.Name -Like "*" }
    }
    Else {
        [scriptblock]$IncludeFolderFilter = { $_.enable -ne $False }
        [scriptblock]$IncludeItemFilter = { ($_.enable -ne $False) -and ($_.hide -ne $True) }
    }

    $ListObject.Items.Clear() | Out-Null

    foreach ($item in ($List | Where-Object -FilterScript $IncludeItemFilter | Where-Object { $_.$Identifier -like "*$Filter*" })) {

        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Added to search list: {1}" -f ${CmdletName},$item.Name) }

        #only include what items exist in either in the folders collected initially or root locations
        $ListObject.Tag = @($item.Name, $item.Path, $item.Guid)
        $ListObject.Items.Add($item.$Identifier) | Out-Null
    }
}
#endregion

#region FUNCTION: Test-PSDWizardApplicationExist
Function Test-PSDWizardApplicationExist {
    <#
    .SYNOPSIS
        Checks to see if there are applications present
    .LINK
        Get-PSDWizardTSChildItem
    #>
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #define an array first
    #fixed issue where a single app will be returned as a string with a count of 0
    $applist = @()

    #build list of all enabled apps
    $appList += Get-PSDWizardTSChildItem -Path "DeploymentShare:\Applications" -Recurse | Where-Object { ($_.enable -ne $False) -and ($_.hide -ne $True) }

    If ($appList.count -gt 0) {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Found {1} applications" -f ${CmdletName},$appList.count) }
        return $true
    } Else {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Found 0 applications" -f ${CmdletName}) }
        return $false
    }
}
#endregion

#region FUNCTION: Add-PSDWizardTree
Function Add-PSDWizardTree {
    <#
    .SYNOPSIS
         Populate treeview with first level folder and files
    .EXAMPLE
         Add-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID' -PreSelect $TS_TaskSequenceID.Text
    .LINK
        Get-PSDWizardTSChildItem
        Expand-PSDWizardTree
    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true, Position = 0)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position = 1)]
        [System.Windows.Controls.TreeView]$TreeObject,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$Identifier,
        [string]$Preselect,
        [switch]$IncludeAll
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSBoundParameters.ContainsKey('IncludeAll')) {
        [int32]$ShowAll = 1
        [scriptblock]$IncludeFolderFilter = { $_.Name -Like "*" }
        [scriptblock]$IncludeItemFilter = { $_.Name -Like "*" }
    }
    Else {
        [int32]$ShowAll = 0
        [scriptblock]$IncludeFolderFilter = { $_.enable -ne $False }
        [scriptblock]$IncludeItemFilter = { ($_.enable -ne $False) -and ($_.hide -ne $True) }
    }
    #Write-host ("Including all root items? {0} using filter: [{1}]" -f $ShowAll,$IncludeItemFilter.ToString())

    $dummyNode = $null
    # ================== Handle FIRST LEVEL Folders ===========================
    # TEST: foreach ($folder in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences" -Directory | Where-Object -FilterScript $IncludeFilter)){$folder}
    foreach ($folder in (Get-PSDWizardTSChildItem -Path $SourcePath -Directory | Where-Object -FilterScript $IncludeFolderFilter)) {

        $treeViewFolder = [Windows.Controls.TreeViewItem]::new()
        $treeViewFolder.Header = $folder.Name
        $treeViewFolder.Tag = @($folder.Path, $SourcePath, $Identifier, $ShowAll,'icons_folderopen')
        #$treeViewFolder.IsEnabled = $false

        #generate a dummy node to allow for expansion
        $treeViewFolder.Items.Add($dummyNode) | Out-Null

        #Does not take values from param, add tags.
        $treeViewFolder.Add_Expanded( {
                #Write-Host ("Expanded [" + $_.OriginalSource.Header + "] from [" + $_.OriginalSource.Tag[0].ToString() + "]")
                Expand-PSDWizardTree -SourcePath $_.OriginalSource.Tag[1].ToString() `
                    -TreeItem $_.OriginalSource `
                    -Identifier $_.OriginalSource.Tag[2].ToString() `
                    -IncludeAll $_.OriginalSource.Tag[3] `
                    -PreSelect $Preselect
            })

        $TreeObject.Items.Add($treeViewFolder) | Out-Null

        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Adding Tree Folder to list: {1}" -f ${CmdletName}, $folder.Name) }
    }

    # ================== Handle FIRST LEVEL Files ===========================
    # TEST: foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences" | Where-Object -FilterScript $IncludeItemFilter)){$item}
    foreach ($item in (Get-PSDWizardTSChildItem -Path $SourcePath | Where-Object -FilterScript $IncludeItemFilter)) {
        #write-host ("Found item --> id:{0},Name:{1},enable:{2},hide:{3}" -f $item.id,$item.Name,$item.enable,$item.hide)
        $treeViewItem = [Windows.Controls.TreeViewItem]::new()
        $treeViewItem.Header = $item.Name
        $FolderPath = Split-Path $item.Path -Parent
        $treeViewItem.Tag = @($FolderPath, $item.Name, $item.$Identifier, $item.Comments, $item.guid, ("icons_" + $SourcePath.split('\')[-1]).ToLower())
        #$treeViewItem.Tag = @($item.Path,$item.$Identifier)
        $TreeObject.Items.Add($treeViewItem) | Out-Null

        #select the item if it matches the preselect
        If($treeViewItem.Tag[2] -eq $PreSelect){
            $treeViewItem.IsSelected = $true
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Pre-selected item [{1}]" -f ${CmdletName}, $treeViewItem.Header) }
        }Else{
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Added item to [{1}]" -f ${CmdletName}, $treeViewItem.Header) }
        }

        $treeViewItem.Add_PreviewMouseLeftButtonDown( {
                [System.Windows.Controls.TreeViewItem]$sender = $args[0]
                [System.Windows.RoutedEventArgs]$e = $args[1]
                If ($sender.Tag[0].ToString()) {
                    $Message = ("Task Sequence selected [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[0].ToString() + "\" + $sender.Tag[1].ToString() + "]")
                }
                Else {
                    $Message = ("Task Sequence selected [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[1].ToString() + "]")
                }
                if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: {1}" -f ${CmdletName}, $Message) }
        })

        <#
        $treeViewItem.Add_PreviewMouseRightButtonDown({
            [System.Windows.Controls.TreeViewItem]$sender = $args[0]
            [System.Windows.RoutedEventArgs]$e = $args[1]
            Write-Host ("Right Click: [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[0].ToString() + "\" + $sender.Tag[1].ToString() +"]")
        })
        #>

    }

}
#endregion

#region FUNCTION: Expand-PSDWizardTree
Function Expand-PSDWizardTree {
    <#
    .SYNOPSIS
        drill into subfolders in treeview
    .EXAMPLE
        #Does not take values from param, add to tag.
        $treeViewFolder.Add_Expanded( {
                #Write-Host ("Expanded [" + $_.OriginalSource.Header + "] from [" + $_.OriginalSource.Tag[0].ToString() + "]")
                Expand-PSDWizardTree -SourcePath $_.OriginalSource.Tag[1].ToString() `
                    -TreeItem $_.OriginalSource `
                    -Identifier $_.OriginalSource.Tag[2].ToString() `
                    -IncludeAll $_.OriginalSource.Tag[3]
        })

    .NOTES
        foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Servers" | Where-Object -FilterScript $IncludeItemFilter)){$item}
        foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Workstations" | Where-Object -FilterScript $IncludeItemFilter)){$item}
        foreach ($folder in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Servers" -Directory | Where-Object -FilterScript $IncludeItemFilter )){$folder}

        (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\VRA\Server" | Where-Object { [string]::IsNullOrEmpty($_.hide) -or ($_.hide -ne $True) })
        [Boolean]::Parse((Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Servers" | Select-Object -First 1 | Select-Object -ExpandProperty Hide)) -eq 'True'
    .LINK
        Get-PSDWizardTSChildItem
        Expand-PSDWizardTree
    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true, Position = 0)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position = 1)]
        [Windows.Controls.TreeViewItem]$TreeItem,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$Identifier,
        [string]$PreSelect,
        $IncludeAll = $false
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($IncludeAll -eq $True) {
        [int32]$ShowAll = 1
        [scriptblock]$IncludeFolderFilter = { $_.Name -Like "*" }
        [scriptblock]$IncludeItemFilter = { $_.Name -Like "*" }
    }
    Else {
        [int32]$ShowAll = 0
        [scriptblock]$IncludeFolderFilter = { $_.enable -ne $False }
        [scriptblock]$IncludeItemFilter = { ($_.enable -ne $False) -and ($_.hide -ne $True) }
    }

    #Write-host ("Including all items: {0}; Filter {1}" -f $ShowAll,$IncludeItemFilter.ToString())
    $dummyNode = $null
    If ($TreeItem.Items.Count -eq 1 -and $TreeItem.Items[0] -eq $dummyNode) {
        #Clear the items to remove existing dummynode from previous expansion (otherwsie causes a space in the treeview)
        $TreeItem.Items.Clear() | Out-Null
        Try {
            #drill into subfolders. $TreeItem.Tag[0] comes from Tag in Root folders
            foreach ($folder in ( Get-PSDWizardTSChildItem -Path ($SourcePath + '\' + $TreeItem.Tag[0].ToString()) -Directory | Where-Object -FilterScript $IncludeFolderFilter) ) {
                $subFolder = [Windows.Controls.TreeViewItem]::new();
                $subFolder.Header = $folder.Name
                $subFolder.Tag = @($folder.Path, $SourcePath, $Identifier, $ShowAll, 'icons_folderopen')
                #$treeViewFolder.IsEnabled = $false

                #generate a dummy node to allow for expansion
                $subFolder.Items.Add($dummyNode)

                #must use tag to pass variables to Add_expanded
                $subFolder.Add_Expanded( {
                        #Write-Host ("Expanded [" + $_.OriginalSource.Header + "] from [" + $_.OriginalSource.Tag[0].ToString() + "]")
                        #expand based on Directory and Identifier
                        Expand-PSDWizardTree -SourcePath $_.OriginalSource.Tag[1].ToString() `
                            -TreeItem $_.OriginalSource `
                            -Identifier $_.OriginalSource.Tag[2].ToString() `
                            -IncludeAll $_.OriginalSource.Tag[3] `
                            -PreSelect $Preselect
                    })
                $TreeItem.Items.Add($subFolder) | Out-Null
            }

            #get all files
            foreach ($item in (Get-PSDWizardTSChildItem -Path ($SourcePath + '\' + $TreeItem.Tag[0].ToString()) | Where-Object -FilterScript $IncludeItemFilter) ) {
                #write-host ("Found item --> id:{0},Name:{1},enable:{2},hide:{3}" -f $item.id,$item.Name,$item.enable,$item.hide)
                $subitem = [Windows.Controls.TreeViewItem]::new()
                $subitem.Header = $item.Name
                $FolderPath = Split-Path $item.Path -Parent
                $subitem.Tag = @($FolderPath, $item.Name, $item.$Identifier, $item.Comments, $item.guid, ("icons_" + $SourcePath.split('\')[-1]).ToLower())
                #$subitem.Tag = @($item.Path,$item.$Identifier)
                $TreeItem.Items.Add($subitem) | Out-Null

                #select the item if it matches the preselect
                If($subitem.Tag[2] -eq $PreSelect){
                    $subitem.IsSelected = $true
                    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Pre-selected item [{1}]" -f ${CmdletName}, $subitem.Header) }
                }Else{
                    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Added item to [{1}]" -f ${CmdletName}, $subitem.Header) }
                }


                $subitem.Add_PreviewMouseLeftButtonDown( {
                    [System.Windows.Controls.TreeViewItem]$sender = $args[0]
                    [System.Windows.RoutedEventArgs]$e = $args[1]
                    $message = ("Selected: [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[0].ToString() + "\" + $sender.Tag[1].ToString() + "]")
                    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: {1}" -f ${CmdletName}, $message) }
                })

                <#
	            $subitem.Add_PreviewMouseRightButtonDown({
		            [System.Windows.Controls.TreeViewItem]$sender = $args[0]
		            [System.Windows.RoutedEventArgs]$e = $args[1]
		                Write-Host ("Right Click: [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[0].ToString() + "\" + $sender.Tag[1].ToString() +"]")
	            })
	            #>
            }
        }
        Catch [Exception] { }


    }
}
#endregion


#region FUNCTION: Search-PSDWizardTree
Function Search-PSDWizardTree {
    <#
    .SYNOPSIS
        Search the tree view
    .EXAMPLE
        $Filter='Server'
        Search-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID' -Filter $Filter
    .EXAMPLE
        $SourcePath="DeploymentShare:\Task Sequences"
        $TreeObject=$_tsTabTree
        $Identifier='ID'
        $Filter='Windows'
        Search-PSDWizardTree -SourcePath $SourcePath -TreeObject $TreeObject -Identifier $Identifier -Filter $Filter

    .NOTES
        foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences" -Recurse | Where-Object { (Split-Path $_.Path -Parent) -in $FolderCollection} |
                Where-Object -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*Server*" })){$item}
        foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences" -Recurse | Where-Object { (Split-Path $_.Path -Parent) -in $FolderCollection} |
                Where-Object -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*Windows*" })){$item}
    .LINK
        Get-PSDWizardTSChildItem
    #>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true, Position = 0)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position = 1)]
        [System.Windows.Controls.TreeView]$TreeObject,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$Identifier,
        [Parameter(Mandatory = $true, Position = 3)]
        [string]$Filter,
        [switch]$IncludeAll
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSBoundParameters.ContainsKey('IncludeAll')) {
        [scriptblock]$IncludeFolderFilter = { $_.Name -Like "*" }
        [scriptblock]$IncludeItemFilter = { $_.Name -Like "*" }
    }
    Else {
        [scriptblock]$IncludeFolderFilter = { $_.enable -ne $False }
        [scriptblock]$IncludeItemFilter = { ($_.enable -ne $False) -and ($_.hide -ne $True) }
    }

    $TreeObject.Items.Clear() | Out-Null

    # Grab all folders
    $FolderCollection = @()
    foreach ($folder in ( Get-PSDWizardTSChildItem -Path $SourcePath -Recurse -Directory | Where-Object -FilterScript $IncludeFolderFilter) ) {
        #collect all folders based on filter into an array
        If ($folder.Path -notin $FolderCollection) { $FolderCollection += $folder.Path }
    }

    # Each item must exist in folder path and match filter.
    foreach ($item in (Get-PSDWizardTSChildItem -Path $SourcePath -Recurse | Where-Object -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*$Filter*" })) {
        #only include what items exist in either in the folders collected initially or root locations
        If ( (($item.Path -match '\\') -and ((Split-Path $item.Path -Parent) -in $FolderCollection)) -or ($item.Path -notmatch '\\') ) {

            $treeViewItem = [Windows.Controls.TreeViewItem]::new()
            $treeViewItem.Header = $item.Name
            $FolderPath = Split-Path $item.Path -Parent
            $treeViewItem.Tag = @($FolderPath, $item.Name, $item.$Identifier, $item.Comments, $item.guid, $SourcePath.split('\')[-1])
            $TreeObject.Items.Add($treeViewItem) | Out-Null

            $treeViewItem.Add_PreviewMouseLeftButtonDown( {
                    [System.Windows.Controls.TreeViewItem]$sender = $args[0]
                    [System.Windows.RoutedEventArgs]$e = $args[1]
                    $message = ("Selected: [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[0].ToString() + "\" + $sender.Tag[1].ToString() + "]")
                    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: {1}" -f ${CmdletName}, $message) }
                })

            <#
            $treeViewItem.Add_PreviewMouseRightButtonDown({
                [System.Windows.Controls.TreeViewItem]$sender = $args[0]
                [System.Windows.RoutedEventArgs]$e = $args[1]
                $message = ("Right Click: [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[0].ToString() + "\" + $sender.Tag[1].ToString() +"]")
                if($PSDDeBug -eq $true){Write-PSDLog -Message ("{0}: {1}" -f ${CmdletName},$message)}
            })
            #>
        }

    }
}
#endregion

#region FUNCTION: Test-PSDWizardTaskSequence
Function Test-PSDWizardTaskSequence {
    <#
    .SYNOPSIS
        Checks if the task sequence is valid
    .LINK
        Get-PSDWizardTSData
        Write-PSDLog
        Get-PSDWizardElement
        Set-PSDWizardElement
    #>
    Param(
        [parameter(Mandatory = $true)]
        $UIObject,
        [string]$TaskSequenceID,
        [switch]$ShowValidation

    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If($null -ne $TaskSequenceID){

        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Selected task sequence: {1}" -f ${CmdletName}, $TaskSequenceID) }

        $TSAssignedOSGUID = Get-PSDWizardTSData -TS $TaskSequenceID -DataSet OSGUID
        #validate OS GUID exists in OS list
        #If ($TaskSequenceID -in $Global:TaskSequencesList.ID) {
        If([string]::IsNullOrEmpty($TSAssignedOSGUID))
        {
            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
            If($ShowValidation){Invoke-PSDWizardNotification -Message ('Invalid TS: No OS found!') -OutputObject $_tsTabValidation -Type Error}

        }Else{
            If($TSAssignedOSGUID -in $Global:OperatingSystemList.Guid)
            {
                If($ShowValidation){Invoke-PSDWizardNotification -OutputObject $_tsTabValidation -Type Hide}
                #find the language name in full langauge object list
                $Global:OSSupportedLanguages = @(($Global:OperatingSystemList | Where-Object { $_.Guid -eq $TSAssignedOSGUID} ).Language)
                #Get only available locales settings from Select OS
                $Global:OSLanguageList = $Global:PSDWizardLanguageList | Where-Object { $_.Culture -in $Global:OSSupportedLanguages }
                #set button to enable
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
            }
            ElseIf($TaskSequenceID -eq 'ID'){
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                #If($ShowValidation){Invoke-PSDWizardNotification -Message 'Folder Selected!' -OutputObject $_tsTabValidation -Type Error}
            }
            Else {
                Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
                If($ShowValidation){Invoke-PSDWizardNotification -Message ('Invalid TS: OS guid not found: {0}!' -f $TSAssignedOSGUID) -OutputObject $_tsTabValidation -Type Error}
            }
        }

        If($TSAssignedOSGUID -in $Global:OperatingSystemList.Guid)
        {
            If($ShowValidation){Invoke-PSDWizardNotification -OutputObject $_tsTabValidation -Type Hide}
            #find the language name in full langauge object list
            $Global:OSSupportedLanguages = @(($Global:OperatingSystemList | Where-Object { $_.Guid -eq $TSAssignedOSGUID }).Language)
            #Get only available locales settings from Select OS
            $Global:OSLanguageList = $Global:PSDWizardLanguageList | Where-Object { $_.Culture -in $Global:OSSupportedLanguages }
            #set button to enable
            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
        }
        ElseIf($TaskSequenceID -eq 'ID'){
            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
            #If($ShowValidation){Invoke-PSDWizardNotification -Message 'Folder Selected!' -OutputObject $_tsTabValidation -Type Error}
        }
        Else {
            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
            If($ShowValidation){Invoke-PSDWizardNotification -Message ('Invalid TS: OS guid not found: {0}!' -f $TSAssignedOSGUID) -OutputObject $_tsTabValidation -Type Error}
        }

    }Else{
        Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$False
        If($ShowValidation){Invoke-PSDWizardNotification -Message 'No selected task sequence!' -OutputObject $_tsTabValidation -Type Warning}
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: No task sequence was selected" -f ${CmdletName}) }
    }


}
#endregion

#region FUNCTION: Get-PSDWizardSelectedApplications
Function Get-PSDWizardSelectedApplications {
     <#
    .SYNOPSIS
          Get all selection application GUIDs
    .EXAMPLE
         Get-PSDWizardSelectedApplications -InputObject $apps -FieldObject $_appTabList -Identifier "Name" -Passthru
    .EXAMPLE
        $InputObject=$apps
        $FieldObject=$_appTabList
        Get-PSDWizardSelectedApplications -InputObject $InputObject -FieldObject $FieldObject -Identifier "Name" -Passthru
    .NOTES
        $AllApps = $FieldObject.Items | foreach {$i=0} {$_ | Add-Member Index ($i++) -PassThru}
    .LINK
        Get-PSDWizardTSChildItem
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $FieldObject,
        [Parameter(Mandatory = $true)]
        $InputObject,
        [Parameter(Mandatory = $false)]
        [string]$Identifier,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #Add index property to app list
    $AllApps = Get-PSDWizardTSChildItem -Path "DeploymentShare:\Applications" -Recurse

    $DefaultAppList = $InputObject | Where-Object { ($_.Name -notlike 'Skip*') -and ($_.Name -notlike '*Codes') -and -not([string]::IsNullOrEmpty($_.Value)) }
    $AppGuids = $DefaultAppList.Value | Select-Object -Unique

    #Set an emptry valus if not specified
    If ($null -eq $Identifier) { $Identifier = '' }

    $SelectedGuids = @()
    Foreach ($AppGuid in $AppGuids) {
        $AppInfo = $AllApps | Where-Object { $_.Guid -eq $AppGuid }
        #collect GUIDs (for Passthru output)
        $SelectedGuids += $AppGuid

        #Check if property exists
        If ($AppInfo.PSobject.Properties.Name.Contains($Identifier)) {
            $FieldObject.SelectedItems.Add($AppInfo.$Identifier);
        }
        Else {
            $FieldObject.SelectedItems.Add($AppInfo) | Out-Null
        }
    }

    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Preselected [{0}] applications" -f ${CmdletName}, $SelectedGuids.count) }
    If ($Passthru) {
        return ($SelectedGuids -join ',')
    }
}
#endregion

#region FUNCTION: Set-PSDWizardSelectedApplications
Function Set-PSDWizardSelectedApplications {
    <#
    .SYNOPSIS
         Set selection application GUIDs
    .EXAMPLE
        $InputObject=$SelectedApps
        $FieldObject=$_appTabList
        Set-PSDWizardSelectedApplications -InputObject $InputObject -FieldObject $FieldObject -Identifier "Name" -Passthru
    .NOTES
       $CurrentAppList = $InputObject | Where-Object { ($_.Name -notlike 'Skip*') -and ($_.Name -notlike '*Codes') }
    .LINK
        Get-PSDWizardTSChildItem
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $FieldObject,
        [Parameter(Mandatory = $false)]
        $InputObject,
        [Parameter(Mandatory = $false)]
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $AllApps = @()
    $AllApps += Get-PSDWizardTSChildItem -Path "DeploymentShare:\Applications" -Recurse

    $SelectedApps = $FieldObject.SelectedItems

    #Get current applist from tsenv if exists
    # Handle cases where InputObject is null
    $CurrentAppList = if ($InputObject) {
        $InputObject | Where-Object { ($_.Name -notlike 'Skip*') -and ($_.Name -notlike '*Codes') -and -not([string]::IsNullOrEmpty($_.Value)) }
    } else {
        @()
    }

    $i = 1
    $SelectedGuids = @()
    Foreach ($App in $SelectedApps) {
        [string]$NumPad = "{0:d3}" -f [int]$i

        $AppInfo = $AllApps | Where-Object { $_.Name -eq $App }
        #collect GUIDs (for Passthru output)
        $SelectedGuids += $AppInfo.Guid

        If ($AppInfo.Guid -in $CurrentAppList.Guid) {
            #TODO: get name to determine what is the next app number?
        }
        Else {
            Set-PSDWizardTSEnvProperty ("Applications" + $NumPad) -Value $AppInfo.Guid
        }
        $i++
    }

    #Write-PSDLog -Message "Selected [$($InputObject.count)] Applications" -LogLevel 1
    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Set [{1}] applications to install" -f ${CmdletName}, $SelectedGuids.count) }
    If ($Passthru) {
        return ($SelectedGuids -join ',')
    }
}
#endregion

#region FUNCTION: Write-PSDWizardOutput
function Write-PSDWizardOutput {
    <#
    .SYNOPSIS
         Append message to UI output
    .EXAMPLE
       Write-PSDWizardOutput -UIObject $_logger -Message 'Test a message' -Append
    #>
    param(
        [parameter(Mandatory = $true)]
        $UIObject,
        [parameter(Mandatory = $true)]
        [string]$Message,
        [switch]$Append
    )

    If (!$Append) {
        $UIObject.Controls.Clear() | Out-Null
    }

    $UIObject.AppendText(("`n{0}" -f $Message))
    #scroll to bottom
    $UIObject.ScrollToEnd()
}
#endregion

#region FUNCTION: Add-PSDWizardListView
function Add-PSDWizardListView {
    <#
    .SYNOPSIS
        Add list to output screen
    .EXAMPLE
       Add-PSDWizardListView -UIObject $_summary -ItemData $NewTSVars
    #>
    param(
        [parameter(Mandatory = $true)]
        $UIObject,
        [parameter(Mandatory = $true)]
        $ItemData
    )

    $UIObject.ItemsSource = $ItemData
}
#endregion

#region FUNCTION: Get-PSDWizardDebugConsole
Function Get-PSDWizardDebugConsole {
    <#
    .SYNOPSIS
        Get current console windows state
    #>
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Try {
        #Console control
        # Credits to - http://powershell.cz/2013/04/04/hide-and-show-console-window-from-gui/
        Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '
    }
    Catch {
        Write-PSDLog -Message ("{0}: Unable to get PowerShell console. {1}" -f ${CmdletName}, $_.exception.message)
    }
    Finally {
        [Console.Window]::GetConsoleWindow()
    }
}
#endregion

#region FUNCTION: Show-PSDWizardDebugConsole
function Show-PSDWizardDebugConsole {
    <#
    .SYNOPSIS
        Show the console window
    .LINK
        Get-PSDWizardDebugConsole
    #>
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Try {
        $consolePtr = Get-PSDWizardDebugConsole
        [Console.Window]::ShowWindow($consolePtr, 5)
    }
    Catch {
        Write-PSDLog -Message ("{0}: Unable to open PowerShell console. {1}" -f ${CmdletName}, $_.exception.message)
    }
}
#endregion

#region FUNCTION: Hide-PSDWizardDebugConsole
function Hide-PSDWizardDebugConsole {
    <#
    .SYNOPSIS
        Hide the console window
    .LINK
        Get-PSDWizardDebugConsole
    #>
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Try {
        $consolePtr = Get-PSDWizardDebugConsole
        [Console.Window]::ShowWindow($consolePtr, 0)
    }
    Catch {
        Write-PSDLog -Message ("{0}: Unable to close PowerShell console. {1}" -f ${CmdletName}, $_.exception.message)
    }
}
#endregion

$exportModuleMemberParams = @{
    Function = @(
        'Expand-PSDWizardTSEnvValue'
        'Export-PSDWizardResult'
        'Format-PSDWizard'

        'ConvertTo-PSDWizardTSVar'
        
        'Get-PSDWizardComputerName'
        'Get-PSDWizardCondition'
        'Get-PSDWizardDefinitions'
        'Get-PSDWizardElement'
        'Get-PSDWizardLocale'
        'Get-PSDWizardSelectedApplications'
        'Get-PSDWizardThemeDefinition'
        'Get-PSDWizardTimeZoneIndex'
        'Get-PSDWizardTSChildItem'
        'Get-PSDWizardTSData'
        'Get-PSDWizardTSEnvListProperty'
        'Get-PSDWizardTSEnvProperty'

        'Hide-PSDWizardDebugConsole'

        'Invoke-PSDWizard'

        'Remove-PSDWizardTSEnvProperty'

        'Set-PSDWizardDefault'
        'Set-PSDWizardElement'
        'Set-PSDWizardTSEnvProperty'
        
        'Show-PSDWizard'
        'Show-PSDWizardDebugConsole'

        'Test-PSDWizardApplicationExist'
        'Test-PSDWizardTaskSequence'
        'Test-PSDWizardValidOS'
        
    )
}

Export-ModuleMember @exportModuleMemberParams

Set-Alias -Name Get-PSDWizardTSEnvVar -Value Get-PSDWizardTSEnvProperty
Set-Alias -Name Set-PSDWizardTSEnvVar -Value Set-PSDWizardTSEnvProperty
Set-Alias -Name Remove-PSDWizardTSEnvVar -Value Remove-PSDWizardTSEnvProperty
Set-Alias -Name Get-PSDWizardTSEnvValue -Value Expand-PSDWizardTSEnvValue