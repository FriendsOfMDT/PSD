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
        Modified: 2022-10-07
        Version: 2.2.5

        SEE CHANGELOG.MD

        TODO:
            - Add deployment readiness checks
            - Add refresh event handler
            - Show Applications tab if application step in Task seqeunce

.Example
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


#region FUNCTION: Get-PSDWizardThemeDefinitions
Function Get-PSDWizardThemeDefinitions {
    <#
    .SYNOPSIS
        Retrieve theme definition file sections
    #>
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
        $TSEnvSettings = Get-PSDWizardTSItem 'Skip' -wildcard
        Get-PSDWizardCondition -Condition $Condition -TSEnvSettings $TSEnvSettings
    
    .EXAMPLE
        $Condition = 'Property("Model") in Properties("SupportedModels(*)")'
        $TSEnvSettings = Get-PSDWizardTSItem *
        Get-PSDWizardCondition -Condition $Condition -TSEnvSettings $TSEnvSettings -Passthru

    .EXAMPLE
        $Condition = 'Property(IsUEFI) == "True"'
        $TSEnvSettings = Get-PSDWizardTSItem *
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


#region FUNCTION: Format-PSDWizard
Function Format-PSDWizard {
    <#
    .SYNOPSIS
        Build the XAML dynamically from definition file

    .EXAMPLE
        $Path = 'D:\DeploymentShares\PSD\scripts\PSDWizardNew'
        $ThemeFile = 'Classic_Theme_Definitions_en-US.xml'
        [Xml.XmlDocument]$LangDefinitions = (Get-Content "$Path\PSDWizard_Definitions_en-US.xml")
        [Xml.XmlDocument]$ThemeDefinitions = (Get-Content "$Path\Themes\$ThemeFile")
        Format-PSDWizard -Path $Path -LangDefinitions $LangDefinition -ThemeDefinitions $ThemeDefinition -Test -Passthru

    .EXAMPLE
        $Path = 'D:\DeploymentShares\PSD\scripts\PSDWizardNew'
        $ThemeFile = 'Refresh_Theme_Definitions_en-US.xml'
        [Xml.XmlDocument]$LangDefinitions = (Get-Content "$Path\PSDWizard_Definitions_en-US.xml")
        [Xml.XmlDocument]$ThemeDefinitions = (Get-Content "$Path\Themes\$ThemeFile")
        Format-PSDWizard -Path $Path -LangDefinitions $LangDefinition -ThemeDefinitions $ThemeDefinition
    #>
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

    #[string]$PSDWizardPath = (Join-Path -Path $WorkingPath -ChildPath 'PSDWizard')
    [string]$ResourcePath = (Join-Path -Path $WorkingPath -ChildPath 'Resources')
    [string]$TemplatePath = (Join-Path -Path $WorkingPath -ChildPath 'Themes')

    #grab needed elements from Lang definition file
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
        $SkipSettings = @{SkipBDDWizard = 'NO' }
    }
    Else {
        #grab the SMSTSOrgName from settings
        $OrgName = (Get-PSDWizardTSItem '_SMSTSOrgName' -ValueOnly)
        If(!$OrgName){
            $OrgName = (Get-PSDWizardTSItem 'OrgName' -ValueOnly)
        }
        #make sure no invalid characters exist
        $OrgName = (ConvertTo-PSDWizardHexaDecimal -String $OrgName)

        #grab all variables that contain skip
        $SkipSettings = Get-PSDWizardTSItem 'Skip' -wildcard
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
            
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: [Welcome Start Page] was loaded[{1}]" -f ${CmdletName}, $StartPagePath) }
        }
        Else {
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: [Welcome Start Page] was not found [{1}]; unable to load page" -f ${CmdletName}, $StartPagePath) }
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

#region FUNCTION: Set-PSDWizardDefault
function Set-PSDWizardDefault {
    <#
    .SYNOPSIS
        Sets all variables for PSD wizard

    .EXAMPLE
        $Path = 'D:\DeploymentShares\PSD\scripts\PSDWizardNew\Scripts'
        $ResourcePath = 'D:\DeploymentShares\PSD\scripts\PSDWizardNew'
        [string]$LangDefinitionsXml = Join-Path -Path $ResourcePath -ChildPath 'PSDWizard_Definitions_en-US.xml'
        [string]$ThemeDefinitionsXml = Join-Path -Path "$ResourcePath\Themes" -ChildPath 'Classic_Theme_Definitions_en-US.xml'
        [Xml.XmlDocument]$LangDefinitionXmlDoc = (Get-Content $LangDefinitionsXml)
        [Xml.XmlDocument]$ThemeDefinitionXmlDoc = (Get-Content $ThemeDefinitionsXml)
        $XMLContent = Format-PSDWizard -Path $ResourcePath -LangDefinitions $LangDefinitionXmlDoc -ThemeDefinitions $ThemeDefinitionXmlDoc
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
        [string]$ScriptPath,
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
        $script:Wizard = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-PSDLog -Message ("{0}: {1}" -f ${CmdletName}, $ErrorMessage) -LogLevel 3
        Throw $ErrorMessage
    }

    # Store xaml objects as PowerShell variables and add them to a gloabl array to use
    $Global:PSDWizardElements = @()
    $XamlContent.SelectNodes("//*[@Name]") | % {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Creating wizard variable: {1}" -f ${CmdletName}, $_.Name) }
        $Global:PSDWizardElements += Set-Variable -Name ($_.Name) -Value $script:Wizard.FindName($_.Name) -Scope Global -PassThru
    }

    #add title to window and version label
    $script:Wizard.Title = "PSD Wizard " + $Version
    $_wizVersion.Content = $Version

    #add logo if found
    If ($LogoPath = Get-PSDWizardTSItem 'PSDWizardLogo' -ValueOnly) {
        If(Test-Path $LogoPath){
            If($_wizMainLogo){$_wizMainLogo.Source = $LogoPath}
            If($_wizBeginLogo){$_wizBeginLogo.Source = $LogoPath}
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
            Get-PSDWizardElement -Name "_depSelectionProfilesList" | Set-PSDWizardElement -Enable:$True
        }
    }
    #endregion


    #region For Device tab objects
    # ---------------------------------------------
    #hide device details is specified
    #if skipcomputername is YES, hide input unless value is invalid
    If ( ((Get-PSDWizardTSItem 'SkipComputerName' -ValueOnly).ToUpper() -eq 'YES') -and ($results -ne $False)) {
        Get-PSDWizardElement -Name "_grdDeviceDetails" | Set-PSDWizardElement -Visible:$False
    }

    $NetworkSelectionAvailable = $True
    #if the check comes back false; show name
    If ((Get-PSDWizardTSItem 'SkipDomainMembership' -ValueOnly).ToUpper() -eq 'YES') {
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
    #Check the furrent Workgroup/domain values and sets UI appropiately
    If ( -not[string]::IsNullOrEmpty((Get-PSDWizardTSItem 'JoinWorkgroup' -ValueOnly)) ) {
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

    If ( -not[string]::IsNullOrEmpty((Get-PSDWizardTSItem 'JoinDomain' -ValueOnly)) ) {
        #SET DOMAIN UP
        Get-PSDWizardElement -Name "_JoinWorkgroupRadio" | Set-PSDWizardElement -Checked:$False
        Get-PSDWizardElement -Name "_JoinDomainRadio" | Set-PSDWizardElement -Checked:$True
        Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Visible:$True

        If ($_JoinDomainRadio.GetType().Name -eq 'CheckBox') {
            Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Visible:$False
        }
        Else {
            Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Enable:$False
        }
    }
    #endregion

    #region For Locale Tab objects
    # ---------------------------------------------
    #MUST BE GLOBAL VARIABLES FOR TABS TO USE LATER ON

    #grab customsettings locale sessing
    $Global:TSUILanguage = Get-PSDWizardTSItem 'UILanguage' -ValueOnly
    $Global:TSSystemLocale = Get-PSDWizardTSItem 'SystemLocale' -ValueOnly
    $Global:TSKeyboardLocale = Get-PSDWizardTSItem 'KeyboardLocale' -ValueOnly
    $Global:TSInputLocale = Get-PSDWizardTSItem 'InputLocale' -ValueOnly
    $Global:TSTimeZoneName = Get-PSDWizardTSItem 'TimeZoneName' -ValueOnly

    #Grab all timezones and locales
    $Global:PSDWizardLocales = Get-PSDWizardLocale -Path $ScriptPath -FileName 'PSDListOfLanguages.xml'
    $Global:PSDWizardTimeZoneIndex = Get-PSDWizardTimeZoneIndex -Path $ScriptPath -FileName 'PSDListOfTimeZoneIndex.xml'
    #stroe as a different viarable; used to create language list but can change once a ts is selected
    $Global:LanguageList = $Global:PSDWizardLocales

    #get the defaults for timezone and locale
    $Global:DefaultLocaleObject = $Global:PSDWizardLocales | Where {$_.Culture -eq $DefaultLocale}
    $Global:DefaultTimeZoneObject = $Global:PSDWizardTimeZoneIndex | Where { $_.DisplayName -eq $DefaultTimeZone }

    #The display name is different than the actual variable value. (eg. English (United States) --> en-US)
    # first get the current value and convert it to an object the list will compare
    # second populate full list, and preselect the current value
    <#
    If ($TS_UILanguage) {
        
        #get mapped data of current UILanguage from CustomSettings.ini
        If($Global:LanguageList.count -eq 1){
            $SelectedUILanguage = $Global:LanguageList
        }
        ElseIf ($Global:TSUILanguage) {
            $SelectedUILanguage = $Global:LanguageList | Where {$_.Culture -eq $Global:TSUILanguage}
        }Else{
            $SelectedUILanguage = $Global:DefaultLocaleObject
        }
        #add the entire list of UILangauge and preselect the one from CustomSettings.ini (if exists)                 
        If ($_locTabLanguage.GetType().Name -eq 'ComboBox') {
            Add-PSDWizardComboList -InputObject $Global:LanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
        }
        If ($_locTabLanguage.GetType().Name -eq 'ListBox') {
            Add-PSDWizardList -InputObject $Global:LanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
        }
        Add-PSDWizardComboList -InputObject $Global:PSDWizardLocales -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
        #Map the select item from list to format TS understands
        $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $SelectedUILanguage.Name -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)
    }
    #>

    If ($TS_SystemLocale) {
        #get mapped data of current SystemLocale from CustomSettings.ini
        If ($Global:TSSystemLocale.Length -gt 0) {
            $SystemLocale = $Global:PSDWizardLocales | Where {$_.Culture -eq $Global:TSSystemLocale}
        }Else{
            $SystemLocale = $Global:DefaultLocaleObject
        }
        #add the entire list of Systemlocale and preselect the one from CustomSettings.ini (if exists)
        If ($_locTabSystemLocale.GetType().Name -eq 'ComboBox') {
            Add-PSDWizardComboList -InputObject $Global:PSDWizardLocales -ListObject $_locTabSystemLocale -Identifier 'Name' -PreSelect $SystemLocale.Name
        }
        If ($_locTabSystemLocale.GetType().Name -eq 'ListBox') {
            Add-PSDWizardList -InputObject $Global:PSDWizardLocales -ListObject $_locTabSystemLocale -Identifier 'Name' -PreSelect $SystemLocale.Name
        }
        #Map the select item from list to format TS understands
        $MappedLocale = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $SystemLocale.Name -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SystemLocale.Culture)
        #$MappedLocale = ($Global:PSDWizardLocales | Where Name -eq $SystemLocale.Name) | Select -ExpandProperty Culture
        $TS_SystemLocale.Text = (Set-PSDWizardTSItem -Name SystemLocale -Value $MappedLocale -PassThru).Value
        $TS_UserLocale.Text = (Set-PSDWizardTSItem -Name UserLocale -Value $MappedLocale -PassThru).Value
    }

    If ($TS_KeyboardLocale) {
        #get mapped data of current keyboard layout from CustomSettings.ini
        If ($Global:TSKeyboardLocale) {
            #get mapped data of current keyboard layout from CustomSettings.ini
            switch -Regex ($Global:TSKeyboardLocale){
                #check if set to kyeboardlayout property (eg. 0409:00000409)
                '(\d{4}):(\d{8})' { $KeyboardLocale = ($Global:PSDWizardLocales | Where { $_.KeyboardLayout -eq $Global:TSKeyboardLocale })}
                #check if set to culture property (eg. en-us)
                '(\w{2})-(\w{2})' {$KeyboardLocale = $Global:PSDWizardLocales | Where { $_.Culture -eq $Global:TSKeyboardLocale }}
            }
        }Else{
            $KeyboardLocale = $Global:DefaultLocaleObject
        }
        #add the entire list of keyboard options and preselect the one from CustomSettings.ini (if exists)
        If ($_locTabKeyboardLocale.GetType().Name -eq 'ComboBox') {
            Add-PSDWizardComboList -InputObject $Global:PSDWizardLocales -ListObject $_locTabKeyboardLocale -Identifier 'Name' -PreSelect $KeyboardLocale.Name
        }
        If ($_locTabKeyboardLocale.GetType().Name -eq 'ListBox') {
            Add-PSDWizardList -InputObject $Global:PSDWizardLocales -ListObject $_locTabKeyboardLocale -Identifier 'Name' -PreSelect $KeyboardLocale.Name
        }
        #Map the select item from list to format TS understands
        $MappedKeyboard = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $KeyboardLocale.Name -MappedProperty 'Name' -SelectedProperty 'KeyboardLayout' -DefaultValueOnNull $KeyboardLocale.KeyboardLayout)
        $TS_KeyboardLocale.Text = (Set-PSDWizardTSItem -Name KeyboardLocale -Value $MappedKeyboard -PassThru).Value
    }

    If ($Global:TSInputLocale -and [string]::IsNullOrEmpty($TS_KeyboardLocale.Text) ) {
        $MappedKeyboard = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $KeyboardLocale.Name -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)
        $TS_InputLocale.Text = (Set-PSDWizardTSItem -Name InputLocale -Value $MappedKeyboard -PassThru).Value
        $TS_KeyboardLocale.Text = (Set-PSDWizardTSItem -Name KeyboardLocale -Value $MappedKeyboard -PassThru).Value
    }

    If ($TS_TimeZoneName) {
        #get mapped data of current timezone from CustomSettings.ini
        If ($Global:TSTimeZoneName.Length -gt 0) {
            $TimeZoneName = $Global:PSDWizardTimeZoneIndex | Where { $_.DisplayName -eq $Global:TSTimeZoneName }
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
        #$MappedTimeZone = $Global:PSDWizardTimeZoneIndex | Where TimeZone -eq $TimeZoneName.TimeZone | Select -first 1
        $TS_TimeZoneName.Text = (Set-PSDWizardTSItem -Name TimeZoneName -Value $MappedTimeZone.DisplayName -PassThru).Value
        $TS_TimeZone.Text = (Set-PSDWizardTSItem -Name TimeZone -Value ('{0:d3}' -f [int]$MappedTimeZone.id).ToString() -PassThru).Value
    }
    #endregion

    #region For Locale Tab objects
    # ---------------------------------------------
    #get all available task seqeunces
    $Global:TaskSequencesList = Get-PSDWizardTSChildItem -path "DeploymentShare:\Task Sequences" -Recurse -Passthru
    #get all available Operating Systems
    $Global:OperatingSystemList = Get-PSDWizardTSChildItem -path "DeploymentShare:\Operating Systems" -Recurse -Passthru
    #update ID to what in customsettings.ini
    $TS_TaskSequenceID.Text = Get-PSDWizardTSItem 'TaskSequenceID' -ValueOnly

    #region For Task Sequence Tab objects
    # ---------------------------------------------
    #Build Task Sequence Tree
    If ($_tsTabTree) {
        # start by disabling search
        $_tsTabSearchEnter.IsEnabled = $False
        $_tsTabSearchClear.IsEnabled = $False
        If ($_tsTabTree.GetType().Name -eq 'TreeView') {
            Add-PSDWizardTree -SourcePath "DeploymentShare:\Task Sequences" -TreeObject $_tsTabTree -Identifier 'ID' -PreSelect $TS_TaskSequenceID.Text
        }
        If ($_tsTabTree.GetType().Name -eq 'ListBox') {
            Add-PSDWizardList -SourcePath "DeploymentShare:\Task Sequences" -ListObject $_tsTabTree -Identifier 'ID' -PreSelect $TS_TaskSequenceID.Text
        }
    }ElseIf($TS_TaskSequenceID.Text -in $Global:TaskSequencesList.ID){
        #If no Task sequence pageexist just process whats in CS.ini
        #validate OS GUID exists in OS list
        $TSAssignedOSGUID = Get-PSDWizardTSData -TS $TS_TaskSequenceID.Text -DataSet OSGUID

        $Global:OSSupportedLanguages = @(($Global:OperatingSystemList | Where Guid -eq $TSAssignedOSGUID).Language)
        #Get only available locales settings from Select OS
        $Global:LanguageList = $Global:PSDWizardLocales | Where {$_.Culture -in $Global:OSSupportedLanguages} | Select -Unique
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
        
        #if TS changed, check that too
        If ($_tsTabTree.GetType().Name -eq 'TreeView') {
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
                        $Global:OSSupportedLanguages = @(($Global:OperatingSystemList | Where Guid -eq $TSAssignedOSGUID).Language)
                        #Get only available locales settings from Select OS
                        $Global:LanguageList = $Global:PSDWizardLocales | Where {$_.Culture -in $Global:OSSupportedLanguages}
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

        If ($_tsTabTree.GetType().Name -eq 'ListBox') {
            $_tsTabTree.add_SelectionChanged( {
                    $TS_TaskSequenceID.Text = $this.SelectedItem
                    $TSAssignedOSGUID = Get-PSDWizardTSData -TS $TS_TaskSequenceID.Text -DataSet OSGUID
                    #validate OS GUID exists in OS list
                    If($TSAssignedOSGUID -in $Global:OperatingSystemList.Guid)
                    {
                        Invoke-PSDWizardNotification -OutputObject $_tsTabValidation -Type Hide
                        #find the language name in full langauge object list (eg.en-US)
                        $Global:OSSupportedLanguages = @(($Global:OperatingSystemList | Where Guid -eq $TSAssignedOSGUID).Language)
                        #Get only available locales settings from Select OS
                        $Global:LanguageList = $Global:PSDWizardLocales | Where {$_.Culture -in $Global:OSSupportedLanguages}
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

    #BUILD EVENT HANDLERS
    #======================================
    #Event for domain or workgroup selection (modern style)
    [System.Windows.RoutedEventHandler]$Script:OnDomainWorkgroupChange = {
        If ($_.source.name -eq '_JoinDomainRadio') {
            Get-PSDWizardElement -Name "Workgroup" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3'
            Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Enable:$True
            Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Enable:$False

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
            Get-PSDWizardElement -Name "Domain" -Wildcard | Set-PSDWizardElement -BorderColor '#FFABADB3'
            Get-PSDWizardElement -Name "_grdJoinDomain" | Set-PSDWizardElement -Enable:$False
            Get-PSDWizardElement -Name "_grdJoinWorkgroup" | Set-PSDWizardElement -Enable:$True

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
    [System.Windows.RoutedEventHandler]$Script:OnDomainSelect = {
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

    #Event for workgroup selection (non modern)
    [System.Windows.RoutedEventHandler]$Script:OnWorkgroupSelect = {
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
    
    #Event for language install selection
    [System.Windows.RoutedEventHandler]$Script:OnLanguageSelection = {
        If($Global:CurrentLanguageSelected -ne $this.SelectedItem){
            #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
            $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:LanguageList -InputValue $this.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)
            #$TS_UILanguage.Text = ($Global:LanguageList | Where Name -eq $_locTabLanguage.SelectedItem) | Select -ExpandProperty Culture
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
            #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
            $MappedLocale = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $this.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)
            #$MappedLocale = ($Global:PSDWizardLocales | Where Name -eq $_locTabSystemLocale.SelectedItem) | Select -ExpandProperty Culture
            $TS_SystemLocale.Text = (Set-PSDWizardTSItem -Name SystemLocale -Value $MappedLocale -PassThru).Value
            $TS_UserLocale.Text = (Set-PSDWizardTSItem -Name UserLocale -Value $MappedLocale -PassThru).Value
        }
        #store value in a global to compare later
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
        #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
        If($Global:CurrentKeyboardLocaleSelected -ne $this.SelectedItem){
            $MappedKeyboard = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $this.SelectedItem -MappedProperty 'Name' -SelectedProperty 'KeyboardLayout' -DefaultValueOnNull $SelectedUILanguage.KeyboardLayout)
            #$TS_KeyboardLocale.Text = ($Global:PSDWizardLocales | Where Name -eq $_locTabKeyboardLocale.SelectedItem) | Select -ExpandProperty KeyboardLayout
            $TS_KeyboardLocale.Text = (Set-PSDWizardTSItem -Name KeyboardLocale -Value $MappedKeyboard -PassThru).Value

            If ($TS_InputLocale -and [string]::IsNullOrEmpty($TS_KeyboardLocale.Text) ) {
                $MappedKeyboard = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $this.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)
                $TS_InputLocale.Text = (Set-PSDWizardTSItem -Name InputLocale -Value $MappedKeyboard -PassThru).Value
                $TS_KeyboardLocale.Text = (Set-PSDWizardTSItem -Name KeyboardLocale -Value $MappedKeyboard -PassThru).Value
            }
        }
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
        If($Global:CurrentTimeZoneSelected -ne $this.SelectedItem){
            $MappedTimeZone = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardTimeZoneIndex -InputValue $this.SelectedItem -MappedProperty 'TimeZone' -DefaultValueOnNull $Global:DefaultTimeZoneObject.TimeZone)
            #$MappedTimeZone = $Global:PSDWizardTimeZoneIndex | Where TimeZone -eq $_locTabTimeZoneName.SelectedItem | Select -first 1
            $TS_TimeZoneName.Text = (Set-PSDWizardTSItem -Name TimeZoneName -Value $MappedTimeZone.DisplayName -PassThru).Value
            $TS_TimeZone.Text = (Set-PSDWizardTSItem -Name TimeZone -Value ('{0:d3}' -f [int]$MappedTimeZone.id).ToString() -PassThru).Value
        }
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
        If($Global:CurrentLanguageSelected -ne $this.SelectedItem){
            #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
            $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:LanguageList -InputValue $this.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)

            $SelectedLocale = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $this.SelectedItem -MappedProperty 'Name' -DefaultValueOnNull $SelectedUILanguage.Name)
            #$SelectedLocale = $Global:PSDWizardLocales | Where Name -eq $_locTabLanguage.SelectedItem
            $TS_SystemLocale.Text = (Set-PSDWizardTSItem -Name SystemLocale -Value $SelectedLocale.Culture -PassThru).Value
            $TS_UserLocale.Text = (Set-PSDWizardTSItem -Name UserLocale -Value $SelectedLocale.Culture -PassThru).Value
            $TS_KeyboardLocale.Text = (Set-PSDWizardTSItem -Name KeyboardLocale -Value $SelectedLocale.KeyboardLayout -PassThru).Value
        }
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
            $TS_Applications.text = ($Apps | Select -Unique)
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
    #====================================
    # EVENTS HANDLERS ON PAGE CHANGE
    #====================================
    [System.Windows.RoutedEventHandler]$Script:OnTabControlChanged = {
    #$_wizTabControl.Add_SelectionChanged( {
        
            Switch -regex ($this.SelectedItem.Name) {

                '_wizReadiness' {
                    #currently for version 2.2.2b+ hide the ability to select or use selection profiles
                    Get-PSDWizardElement -Name "depSelectionProfiles" -Wildcard | Set-PSDWizardElement -Visible:$False
                    
                }

                '_wizTaskSequence' {
                    #PROCESS ON PAGE LOAD
                    #region For Task Sequence Tab event handlers
                    # -------------------------------------------

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
                    If ($TS_TaskSequenceID.Text -in $Global:TaskSequencesList.ID) {
                        #validate OS GUID exists in OS list
                        $TSAssignedOSGUID = Get-PSDWizardTSData -TS $TS_TaskSequenceID.Text -DataSet OSGUID
                        If($TSAssignedOSGUID -in $Global:OperatingSystemList.Guid)
                        {
                            Invoke-PSDWizardNotification -OutputObject $_tsTabValidation -Type Hide
                            #find the language name in full langauge object list
                            $Global:OSSupportedLanguages = @(($Global:OperatingSystemList | Where Guid -eq $TSAssignedOSGUID).Language)
                            #Get only available locales settings from Select OS
                            $Global:LanguageList = $Global:PSDWizardLocales | Where {$_.Culture -in $Global:OSSupportedLanguages}
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
                        Invoke-PSDWizardNotification -Message 'No TS Selected!' -OutputObject $_tsTabValidation -Type Error
                    }
                }

                '_wizComputerName' {
                    #set focus on computer name;ensures valid name does not get skipped
                    $TS_OSDComputerName.focus()
                    #RUN EVENTS ON PAGE LOAD
                    #Check what value is provided by computer name and rebuild it based on supported variables
                    # Any variables declared in CustoSettings.ini are supported + variables with %SERIAL% or %RAND%
                    $TS_OSDComputerName.Text = (Get-PSDWizardComputerName -Value (Get-PSDWizardTSItem 'OSDComputerName' -ValueOnly))

                    $ValidName = (Confirm-PSDWizardComputerName -ComputerNameObject $TS_OSDComputerName -OutputObject $_detTabValidation -Passthru)
                    Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$ValidName

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
                    #RUN EVENTS ON PAGE LOAD
                    #when page loads, check current status
                     #Do DOMAIN actions when checked
                    $_JoinDomainRadio.AddHandler([System.Windows.Controls.CheckBox]::CheckedEvent, $OnDomainSelect)
                    $_JoinDomainRadio.AddHandler([System.Windows.Controls.CheckBox]::UncheckedEvent, $OnWorkgroupSelect)

                    If (($_JoinDomainRadio.IsChecked -eq $False) -and ([string]::IsNullOrEmpty($TS_JoinDomain.text)) ) {
                        #DO WORKGROUP ACTIONS
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
                        #DO DOMAIN ACTIONS
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
                   
                    $_wizDeviceDetails.AddHandler([System.Windows.Controls.RadioButton]::CheckedEvent, $OnDomainWorkgroupChange)

                    #set focus on computer name;ensures valid name does not get skipped
                    $TS_OSDComputerName.focus()
                    #RUN EVENTS ON PAGE LOAD
                    #Check what value is provided by computer name and rebuild it based on supported variables
                    # Any variables declared in CustoSettings.ini are supported + variables with %SERIAL% or %RAND%
                    $TS_OSDComputerName.Text = (Get-PSDWizardComputerName -Value (Get-PSDWizardTSItem 'OSDComputerName' -ValueOnly))
                   
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
                    }
                    ElseIf ($_JoinDomainRadio.IsChecked -eq $True) {
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
                    ElseIf ($_JoinWorkgroupRadio.IsChecked -eq $True) {
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

                } #end device switch value
                
                '_wizDomainSettings|_wizDeviceDetails' {
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

                    #Change value when selection change
                    $_locTabSystemLocale.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnSystemLocaleSelection)
                    $_locTabKeyboardLocale.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnKeyboardLocaleSelection)
                    $_locTabTimeZoneName.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnTimeZoneSelection)

                    #get mapped data of current UILanguage from CustomSettings.ini
                    If($Global:LanguageList.Culture.count -eq 1){
                        $SelectedUILanguage = $Global:LanguageList
                    }ElseIf($Global:TSUILanguage.Length -gt 0) {
                        $SelectedUILanguage = $Global:LanguageList | Where {$_.Culture -eq $Global:TSUILanguage}
                    }Else{
                        $SelectedUILanguage = $Global:DefaultLocaleObject
                    }

                    #only add if needed (would run each time a selection is made)
                    If($_locTabLanguage.items.count -eq 0 ){
                        #refresh Language to install list based on OS support                   
                        If ($_locTabLanguage.GetType().Name -eq 'ComboBox') {
                            Add-PSDWizardComboList -InputObject $Global:LanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
                            $_locTabLanguage.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnLanguageSelection)
                        }
                        If ($_locTabLanguage.GetType().Name -eq 'ListBox') {
                            Add-PSDWizardList -InputObject $Global:LanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
                            $_locTabLanguage.AddHandler([System.Windows.Controls.ListBox]::SelectionChangedEvent, $OnLanguageSelection)
                        }
                    }
                    
                    If($Global:CurrentLanguageSelected -ne $SelectedUILanguage.Name){   
                        #choose default (non selecteditem)
                        $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:LanguageList -InputValue $SelectedUILanguage.Name -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)
                        #$TS_UILanguage.Text = ($Global:LanguageList | Where Name -eq $_locTabLanguage.SelectedItem) | Select -ExpandProperty Culture
                    }
                    
                } #end locale and time switch value

                '_wizLanguage' {
                    #get mapped data of current UILanguage from CustomSettings.ini
                    If($Global:LanguageList.Culture.count -eq 1){
                        $SelectedUILanguage = $Global:LanguageList
                    }ElseIf ($Global:TSUILanguage.Length -gt 0) {
                        $SelectedUILanguage = $Global:LanguageList | Where {$_.Culture -eq $Global:TSUILanguage}
                    }Else{
                        $SelectedUILanguage = $Global:DefaultLocaleObject
                    }
                    #only add if needed (would run each time a selection is made)
                    If($_locTabLanguage.items.count -eq 0 ){
                        #refresh Language to install list based on OS support                   
                        If ($_locTabLanguage.GetType().Name -eq 'ComboBox') {
                            Add-PSDWizardComboList -InputObject $Global:LanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
                            $_locTabLanguage.AddHandler([System.Windows.Controls.ComboBox]::SelectionChangedEvent, $OnLocaleSelection)
                        }
                        If ($_locTabLanguage.GetType().Name -eq 'ListBox') {
                            Add-PSDWizardList -InputObject $Global:LanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
                            $_locTabLanguage.AddHandler([System.Windows.Controls.ListBox]::SelectionChangedEvent, $OnLocaleSelection)
                        }
                    }
                    If($Global:CurrentLanguageSelected -ne $SelectedUILanguage.Name){   
                        #choose default (non selecteditem)
                        $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:LanguageList -InputValue $SelectedUILanguage.Name -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)
                    }
                                        
                    <#
                    $_locTabLanguage.Add_SelectionChanged( {
                        If($_locTabLanguage.SelectedItem){
                            #Use ConvertTo-PSDWizardTSVar cmdlet instead of where operator for debugging
                            $TS_UILanguage.Text = (ConvertTo-PSDWizardTSVar -Object $Global:LanguageList -InputValue $_locTabLanguage.SelectedItem -MappedProperty 'Name' -SelectedProperty 'Culture' -DefaultValueOnNull $SelectedUILanguage.Culture)

                            $SelectedLocale = (ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $_locTabLanguage.SelectedItem -MappedProperty 'Name' -DefaultValueOnNull $SelectedUILanguage.Name)
                            #$SelectedLocale = $Global:PSDWizardLocales | Where Name -eq $_locTabLanguage.SelectedItem
                            $TS_SystemLocale.Text = $SelectedLocale.Culture
                            $TS_UserLocale.Text = $SelectedLocale.Culture
                            $TS_KeyboardLocale.Text = $SelectedLocale.KeyboardLayout
                        }
                        #enable next button if all values exist
                        If($TS_UILanguage.Text -and $TS_SystemLocale.Text -and $TS_KeyboardLocale.Text){
                            Get-PSDWizardElement -Name "_wizNext" | Set-PSDWizardElement -Enable:$True
                        }
                    })
                    #>

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
            Get-PSDWizardElement -Name "_startPage" | Set-PSDWizardElement -Visible:$false
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

#region FUNCTION: Show-PSDWizard
Function Show-PSDWizard {
    <#
    .SYNOPSIS
        Start the wizard

    .EXAMPLE
        $ResourcePath= '\\192.168.1.10\dep-psd$\Scripts\PSDWizardNew'
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
        If ( $PSDDeBug -eq $true ) { Write-PSDLog -Message ("{0}: No theme control was found; defaulting to theme [{1}]" -f ${CmdletName}, $SelectedTheme) }
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
    $ScriptPath = Get-PSDContent -Content "Scripts"
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