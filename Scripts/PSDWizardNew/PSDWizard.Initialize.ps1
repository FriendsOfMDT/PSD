<#
.SYNOPSIS
    PSDWizard Help File
.DESCRIPTION
    Help File that manages functionality of PSDWizard
.LINK

.NOTES
        FileName: PSDWizard.Initialize.ps1
        Solution: PowerShell Deployment for MDT
        Purpose: Help File that manages functionality of PSDWizard
        Author: PSD Development Team
        Contact: @PowershellCrack
        Primary: @PowershellCrack
        Created: 2020-01-12
        Modified: 2022-10-07
        Version: 2.2.5

        SEE CHANGELOG.MD
.Example
#>


#region FUNCTION: Test-IsISE
Function Test-IsISE {
    <#
    .SYNOPSIS
    Check if running in ISE
    #>
    # Set-StrictMode -Version latest
    try {
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}
#endregion

#region FUNCTION: Test-VSCode
Function Test-VSCode {
    <#
    .SYNOPSIS
        Check if running in Visual Studio Code
    #>
    if ($env:TERM_PROGRAM -eq 'vscode') {
        return $true;
    }
    Else {
        return $false;
    }
}
#endregion

#region FUNCTION: Get-PSDWizardScriptPath
Function Get-PSDWizardScriptPath {
    <#
    .SYNOPSIS
        Finds the current script path even in ISE or VSC
    .LINK
        Test-VSCode
        Test-IsISE
    #>
    param(
        [switch]$Parent
    )

    Begin {}
    Process {
        Try {
            if ($PSScriptRoot -eq "") {
                if (Test-IsISE) {
                    $ScriptPath = $psISE.CurrentFile.FullPath
                }
                elseif (Test-VSCode) {
                    $context = $psEditor.GetEditorContext()
                    $ScriptPath = $context.CurrentFile.Path
                }
                Else {
                    $ScriptPath = (Get-location).Path
                }
            }
            else {
                $ScriptPath = $PSCommandPath
            }
        }
        Catch {
            $ScriptPath = '.'
        }
    }
    End {

        If ($Parent) {
            Split-Path $ScriptPath -Parent
        }
        Else {
            $ScriptPath
        }
    }

}
#endregion


##*========================================================================
##* VARIABLE DECLARATION
##*========================================================================
#region VARIABLES: Building paths & values
# Use function to get paths because Powershell ISE & other editors have differnt results
$ScriptPath = Get-PSDWizardScriptPath
[string]$PSDWizardPath = Split-Path -Path $ScriptPath -Parent
[string]$PSDWizardRoot = Get-PSDContent -Content "Scripts"

if ($PSDDeBug -eq $true) {
    Write-PSDLog -Message ("{0}: PSDWizard path is [{1}]" -f $MyInvocation.MyCommand, $PSDWizardPath) -LogLevel 1
    Write-PSDLog -Message ("{0}: ScriptRoot path is [{1}]" -f $MyInvocation.MyCommand, $PSDWizardRoot) -LogLevel 1
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
        Get-PSDWizardLocale -Path $PSDWizardRoot -FileName 'PSDListOfLanguages.xml'
    #>
    [CmdletBinding()]
    Param(
        $Path = $PSDWizardRoot,
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
        $locale = '' | Select ID, Name, Language, Culture, KeyboardID, KeyboardLayout
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
        [string]$TS,
        [ValidateSet('Name','OSGUID')]
        [string]$DataSet,
        [switch]$Passthru
    )

    $ContentPath = Get-PSDContent -content Control 
    If($TS -ne 'ID'){
        [xml]$TSdata = Get-Content "$ContentPath\$TS\TS.xml"
        If($DataSet){
            switch($DataSet){
                'Name' {return $TSdata.sequence.name}
                'OSGUID' {$OSInstallGroup = ($TSdata.sequence.group.step | Where Type -eq 'BDD_InstallOS').defaultVarList.variable
                        return ($OSInstallGroup | Where Name -eq 'OSGUID').'#text'
                        }
            }
        }Else{
            return $TSdata.sequence.group
        }
    }
}
#endregion

#region FUNCTION:  Get-PSDWizardOSList
Function Get-PSDWizardOSList{
    <#
    .SYNOPSIS
        Get OS list from OperatingSystems.xml
    .EXAMPLE
        $ContentPath = '\\192.168.1.10\dep-psd$\control'
        Get-PSDWizardOSList
    #>
    $ContentPath = Get-PSDContent -content Control 
    [xml]$OSdata = Get-Content "$ContentPath\OperatingSystems.xml"
    Return $OSdata.oss.os
}
#endregion

#region FUNCTION: Get-PSDWizardTimeZoneIndex
Function Get-PSDWizardTimeZoneIndex {
    <#
    .SYNOPSIS
        Get index value of Timezone
    .EXAMPLE
        Get-PSDWizardTimeZoneIndex -Path $PSDWizardRoot -FileName 'PSDListOfTimeZoneIndex.xml'
    #>
    [CmdletBinding()]
    Param(
        $Path = $PSDWizardRoot,
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
        $index = '' | Select id, TimeZone, DisplayName, Name, UTC
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

#region FUNCTION: Get-PSDWizardTSItem
Function Get-PSDWizardTSItem {
    <#
    .SYNOPSIS
        Get Task Sequence variable(s)
    .EXAMPLE
        Get-PSDWizardTSItem 'Skip' -wildcard
    .EXAMPLE
        Get-PSDWizardTSItem -Name 'OSDComputerName' -ValueOnly
    .EXAMPLE
        Get-PSDWizardTSItem * -wildcard
    .EXAMPLE
        Get-PSDWizardTSItem '%scriptroot%' -IgnoreEnv
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,
        [switch]$WildCard,
        [switch]$ValueOnly,
        [switch]$IgnoreEnv
    )
    ## Get the name of this func
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSBoundParameters.ContainsKey('ValueOnly')) {
        $param = @{
            ExpandProperty = 'Value'
        }
    }
    Else {
        $param = @{
            Property = 'Name', 'Value'
        }
    }

    If ($PSBoundParameters.ContainsKey('WildCard')) {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Searching value for [{1}]" -f ${CmdletName}, $Name) -LogLevel 1 }
        $TSItem = Get-Item TSEnv:*$Name*
    }
    Else {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Grabbing value for [{1}]" -f ${CmdletName}, $Name) -LogLevel 1 }
        $TSItem = Get-Item TSEnv:$Name
    }

    # Determine if TSItem's value has an environment variable in it
    # Replace it with actual environment's value (eg. %scriptroot% --> \\192.68.1.10\deploymentshare$\scripts)
    Try {
        If (!$IgnoreEnv) { $Results = Get-PSDWizardEnvValue $TSItem }
    }
    Catch {
        $Results = $TSItem
    }
    Finally {
        if ($PSDDeBug -eq $true) { 
            If($Results.Value){
                Write-PSDLog -Message ("{0}: Value is [{1}]" -f ${CmdletName}, $Results.Value) -LogLevel 1
            }Else{
                Write-PSDLog -Message ("{0}: Value is [Null]" -f ${CmdletName}) -LogLevel 1
            }
        }
            
        $Results | Select @param
    }
}
#endregion

#region FUNCTION: Get-PSDWizardEnvValue
Function Get-PSDWizardEnvValue {
    <#
    .SYNOPSIS
        Replace %DEPLOYROOT% or %SCRIPTROOT% with actual path
    .EXAMPLE
        $TSItem = $test = "" | Select Name,value; $test.name='Locale';$test.Value='en-US'
        $TSItem = $test = "" | Select Name,value; $test.name='PSDWizardLogo';$test.Value='%SCRIPTROOT%\powershell.png'
        Get-PSDWizardEnvValue $TSItem 
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
        $EnvironmentValues = [Regex]::Matches($TSItem.Value, '(?<=\%).*?(?=\%)') | Select -ExpandProperty Value

        #sometimes mutliple values exist, loop through each
        foreach ($EnvironmentValue in $EnvironmentValues) {

            switch ( $EnvironmentValue.ToLower() ) {
                'deployroot' { $value = Get-PSDContent }
                'scriptroot' { $value = Get-PSDContent -Content "scripts" }
                default { $value = $Null }
            }

            if ( ($PSDDeBug -eq $true) -and ($null -ne $value) ) { Write-PSDLog -Message ("{0}: Replaced TS value [{1}] with [{2}]" -f ${CmdletName}, $EnvironmentValue, $Value) -LogLevel 1 }

            If ($value) { 
                #replace %value% with correct variable value
                $TSItem.Value = $TSItem.Value.replace(('%' + $EnvironmentValue + '%'), $Value) 
            }
        }#end loop
    }

    return $TSItem
}
#endregion

#region FUNCTION: Set-PSDWizardTSItem
Function Set-PSDWizardTSItem {
    <#
    .SYNOPSIS
        Replace %DEPLOYROOT% or %SCRIPTROOT% with actual path
    .EXAMPLE
        $Name='OSDComputerName'
        $Value='PSD-NA'
        Set-PSDWizardTSItem 'OSDComputerName' -Value 'PSD-NA'
    .LINK
        Get-PSDWizardTSItem
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Value,
        [switch]$WildCard,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand
    
    If ($PSBoundParameters.ContainsKey('WildCard')) {
        Get-PSDWizardTSItem $Name -WildCard | % {
             Set-Item -Path TSEnv:$_.Name -Value $Value -Force
             if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Set [{1}] to [{2}]" -f ${CmdletName}, $_.Name, $Value) -LogLevel 1 }
        }
    }Else {
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Set [{1}] to [{2}]" -f ${CmdletName}, $Name, $Value) -LogLevel 1 }
        Set-Item -Path TSEnv:$Name -Value $Value -Force
    }

    If ($PSBoundParameters.ContainsKey('Passthru')) {
        If ($PSBoundParameters.ContainsKey('WildCard')) {
            Get-PSDWizardTSItem $Name -WildCard
        }Else {
            Get-PSDWizardTSItem $Name
        }
    }
}
#endregion

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
        $TabSelected = $TabControlObject.items | Where IsSelected -eq $true

        $message = ("Selected tab index [{0}] with name [{1}] and header [{2}]" -f $newtab, $TabSelected.Name, $TabSelected.Header)
    }
    
    If ($PSCmdlet.ParameterSetName -eq "header") {
        $newtab = $TabControlObject.items | Where Header -eq $header
        $newtab.IsSelected = $true

        $message = ("Selected tab header [{0}] with name of [{1}]" -f $newtab.Header, $newtab.Name)
    }

    If ($PSCmdlet.ParameterSetName -eq "name") {
        $newtab = $TabControlObject.items | Where Name -eq $name
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
            $Elements += ($Global:PSDWizardElements | Where { $_.Name -like "*$Name*" }).Value
        }
        Else {
            $Elements += ($Global:PSDWizardElements | Where { $_.Name -eq $Name }).Value
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
        [string]$Content,
        [string]$text,
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
                $Parameters = $PSBoundParameters | Select -ExpandProperty Keys
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
                            If ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Object [{1}] {2} property is changed to [{3}]" -f ${CmdletName}, $item.Name, $Property, $Value) }
                        }
                        Else {
                            If ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Object [{1}] {2} property already set to [{3}]" -f ${CmdletName}, $item.Name, $Property, $Value) }
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
        [ValidateSet('Error', 'Info', 'Hide')]
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
        Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length  | % { [char]$_ }) )
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
        Changes character length
    .EXAMPLE
        00123456 | Set-PSDWizardStringLength -Length 7 -TrimOff Right
    .EXAMPLE
        00123456 | Set-PSDWizardStringLength -Length 7 -TrimOff Left
    #>
    param (
        [parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
        [string]$Str,

        [parameter(Mandatory = $False, Position = 1)]
        $Length,

        [parameter(Mandatory = $False, Position = 2)]
        [ValidateSet('Left', 'Right')]
        [string]$TrimOff
    )
    Begin{}
    Process{
        Try{
            If ([string]::IsNullOrEmpty($length) -or ($length -eq 0)) {
                [int]$length = $Str.length
            }
            ElseIf ($length -match '\d') {
                [int]$length = $length
            }
            Else {
                [int]$length = $Str.length
                #length is not a integer
            }
        
            #$Str[0..($Length-1)] -join ""
            If ($TrimOff -eq 'Left') {
                [string]$Str.Substring($length + 1)
            }
            Else {
                [string]$Str.Substring(0, $length)
            }
        }
        Catch{}
    }
}
#endregion

#region FUNCTION: Get-PSDWizardComputerName
Function Get-PSDWizardComputerName {
    <# 
    .SYNOPSIS 
        Convert known wariable based comptuer name into a valid TS name

    .EXAMPLE

        Get-PSDWizardComputerName "PSD-%SERIAL%"
        Get-PSDWizardComputerName "PSD-%SERIAL:8%"
        Get-PSDWizardComputerName "PSD-%PREFIX%-%SERIAL:8%"
        Get-PSDWizardComputerName "PSD-%PREFIX%-%8:SERIAL%"
        Get-PSDWizardComputerName "%PREFIX%-%RAND:2%-%8:SERIAL%"
        Get-PSDWizardComputerName "%PREFIX%-%RAND:2%-%SERIAL:8%"
        Get-PSDWizardComputerName "PSD%SERIAL%"
        Get-PSDWizardComputerName "PSD%SERIAL%PSD"
        Get-PSDWizardComputerName "%PREFIX%-%SERIAL%"
        Get-PSDWizardComputerName "%PREFIX%%SERIAL%"
        Get-PSDWizardComputerName "%PREFIX%%PREFIX%"
        Get-PSDWizardComputerName "%SERIAL%-%SERIAL%"
        Get-PSDWizardComputerName "%PREFIX%-%RAND:6%"
        Get-PSDWizardComputerName "%PREFIX%-%SERIAL:7%"
        Get-PSDWizardComputerName "%PREFIX%-%RAND:6%"
        Get-PSDWizardComputerName "%PREFIX%-%SERIAL:7%"
        Get-PSDWizardComputerName "%PREFIX%-%7:SERIAL%"
        Get-PSDWizardComputerName "%PREFIX%-%SERIALNUMBER%" 
    #>
    [CmdletBinding()]
    param(
        $Value
    )
    #Split Up based on variables
    $Parts = $Value.Split('%')
    $NewNameParts = @()

    Foreach ($Part in $Parts) {
        If ( -Not[string]::IsNullOrEmpty($Part) ) {
            Switch -regex ($Part) {
                'SERIAL' {
                    
                    #write-host 'Replaced: Serial'
                    $SerialValue = Get-PSDWizardTSItem 'SerialNumber' -ValueOnly
                    If ([string]::IsNullOrEmpty($SerialValue) ) {
                        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Paring Computername portion [{1}]; SERIAL expression has no value" -f ${CmdletName}, $Part, $SerialValue) }
                        [string]$Part = "NA"
                    }
                    Else {
                        #check if serial is truncated with colon (eg. %SERIAL:6%)
                        If ($Part -match '(?<=\:).*?(?=\d{1,2})') {
                            $Length = $Part.split(':')[1]
                            [string]$SerialValue = $SerialValue | Set-PSDWizardStringLength -Length $Length -TrimOff Right
                        }
                        ElseIf ($Part -match '(?<=^\d{1,2}:)') {
                            $Length = $Part.split(':')[0]
                            [string]$SerialValue = $SerialValue | Set-PSDWizardStringLength -Length $Length -TrimOff Left
                        }
                        
                        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Paring Computername portion [{1}]; Using SERIAL expression with value [{2}]" -f ${CmdletName}, $Part, $SerialValue) }

                        #replace part with serial number
                        [string]$Part = $SerialValue
                    }
                }

                'RAND' {
                    #write-host 'Replaced: Random'
                    #check if serial is truncated with colon (eg. %SERIAL:6%)
                    If ($Part -match '(?<=\:).*?(?=\d)') {
                        $Length = $Part.split(':')[1]
                        [string]$RandValue = Get-PSDWizardRandomAlphanumericString -length $Length
                    }
                    Else {
                        [string]$RandValue = Get-PSDWizardRandomAlphanumericString
                    }
                    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Paring Computername portion [{1}]; Using RAND expression with value [{2}]" -f ${CmdletName}, $Part, $RandValue) }
                    
                    #replace part with random name
                    $Part = $RandValue
                }

                #if any value is - or a number, ignore
                '-|\d+' {}

                #check any other characters for 
                default {
                    If ($TSItem = Get-PSDWizardTSItem $Part -ValueOnly) {
                        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Paring Computername portion [{1}]; found TaskSequence variable that matches with value of [{2}]" -f ${CmdletName}, $Part, $TSItem) }
                        [string]$Part = $TSItem
                    }
                    Else {
                        [string]$Part = "%$Part%"
                    }
                }
            }

            #write-host 'Replaced: Nothing'
            $NewNameParts += $Part

        }

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
        ConvertTo-PSDWizardTSVar -Object $Global:PSDWizardLocales -InputValue $this.SelectedItem -MappedProperty 'Name' -DefaultValueOnNull $SelectedUILanguage.Name
    
     .EXAMPLE
        $Object=$Global:PSDWizardLocales
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
            $Value = ($ObjectArray | Where { $_.$MappedProperty -eq $InputValue }).$SelectedProperty
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Queried [{1}] items where ['{2}' = '{3}'] using [{4}] property." -f ${CmdletName}, $ObjectArray.Count, $MappedProperty, $InputValue, $SelectedProperty) }
        }
        Else {
            $Value = ($ObjectArray | Where { $_.$MappedProperty -eq $InputValue })
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
        $AllFiles = Get-ChildItem -Path "DeploymentShare:\Task Sequences" | Where {$_.PSIsContainer -eq $false} | Select * |
            Select ID,Name,Hide,Enable,Comments,GUID,@{Name = 'Path'; Expression = { (($_.PSPath) -split 'Task Sequences\\','')[1] }}
        $AllDirectory = Get-ChildItem -Path "DeploymentShare:\Task Sequences" | Where {$_.PSIsContainer} | Select * |
            Select Name,Enable,Comments,GUID,@{Name = 'Path'; Expression = { (($_.PSPath) -split 'Task Sequences\\','')[1] }}
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
            $Content = Get-ChildItem @Param | Where { $_.PSIsContainer } | Select *
        }Else {
            $Content = Get-ChildItem @Param | Where { $_.PSIsContainer } |
            Select Name, Enable, Comments, GUID, @{Name = 'Path'; Expression = { (($_.PSPath) -split $EscapePath, '')[1] } }
        }
    }Else {
        #display content. Passthru displays all info
        If ($Passthru) {
            $Content = Get-ChildItem @Param | Where { $_.PSIsContainer -eq $false } | Select *
        }Else {
            $Content = Get-ChildItem @Param | Where { $_.PSIsContainer -eq $false } |
            Select ID, Name, Hide, Enable, Comments, GUID, @{Name = 'Path'; Expression = { (($_.PSPath) -split $EscapePath, '')[1] } }
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
        Add-PSDWizardComboList -InputObject $Global:LanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
    .EXAMPLE
        $InputObject=$Global:LanguageList
        $ListObject=$_locTabLanguage
        $Identifier='Name'
        $PreSelect=$SelectedUILanguage.Name
        Add-PSDWizardComboList -InputObject $Global:LanguageList -ListObject $_locTabLanguage -Identifier 'Name' -PreSelect $SelectedUILanguage.Name
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
        [array]$List,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.Windows.Controls.ComboBox]$ListObject,

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$Identifier,
        [string]$PreSelect,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $List = (Get-PSDWizardTSChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List = Invoke-command $ScriptBlock
    }
    If ($PSCmdlet.ParameterSetName -eq "object") {
        $List = $InputObject
    }

    $ListObject.Items.Clear() | Out-Null 

    If ($PSCmdlet.ParameterSetName -eq "hashtable") {
        Try {
            $List = $HashTable

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
                    $ListObject.Items.Add($item.$Identifier) | Out-Null
                }
            }
            Else {
                If($item -notin $ListObject.Items){
                    $ListObject.Items.Add($item) | Out-Null
                }
            }
        }
    }
    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Added [{1}] items to [{2}] list" -f ${CmdletName}, $List.count, $ListObject.Name) }

    #select the item
    If ($null -ne $PreSelect) {
        $ListObject.SelectedItem = $PreSelect
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Preselected item [{1}] for [{2}]" -f ${CmdletName}, $PreSelect, $ListObject.Name) }
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

        [string]$Preselect,
        [switch]$Passthru
    )

    If ($null -eq $Identifier) { $Identifier = '' }

    If ($PSBoundParameters.ContainsKey('Exclude')) {
        [scriptblock]$ExcludeItemFilter = { ($_.$Identifier -NotLike "*$Exclude*") -and ($_.hide -eq $false) -and ($_.enable -eq $true)}
    }
    Else {
        [scriptblock]$ExcludeItemFilter = { ($_.$Identifier -like '*') -and ($_.hide -eq $false) -and ($_.enable -eq $true)}
    }

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $List = (Get-PSDWizardTSChildItem -Path $SourcePath -Recurse) | Where -FilterScript $ExcludeItemFilter
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List = Invoke-command $ScriptBlock | Where -FilterScript $ExcludeItemFilter
    }

    If ($PSCmdlet.ParameterSetName -eq "object") {
        $List = $InputObject
    }

    $ListObject.Items.Clear() | Out-Null 

    foreach ($item in $List ) {
        #Check to see if propertiues exists
        If ($item.PSobject.Properties.Name.Contains($Identifier)) {
            If($item.$Identifier -notin $ListObject.Items){
                $ListObject.Items.Add($item.$Identifier) | Out-Null
            }
        }
        Else {
            If($item -notin $ListObject.Items){
                $ListObject.Items.Add($item) | Out-Null
            }
        }
    }

    If ($null -ne $PreSelect) {
        #+3 below to center selected item on screen
        $ListObject.ScrollIntoView($ListObject.Items[$ListObject.SelectedIndex + 3])
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Preselected item [{1}] for [{2}]" -f ${CmdletName}, $PreSelect, $ListObject.Name) }
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

    $ListObject.Items.Clear() | Out-Null 

    $List = Get-PSDWizardTSChildItem -Path $SourcePath | Where { $_.Name -like "$Filter*" -and $_.enable -eq $True }


    foreach ($item in $List) {
        $TrimName = ($item.Name).split('-')[1].Trim()
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

    If ($ClearFirst) {
        $ListObject.Items.Clear() | Out-Null 
    }

    $List = Get-PSDWizardTSChildItem -Path $SourcePath -Recurse | Where { $_.Name -like "*Bundles*" -and $_.enable -eq $True }

    foreach ($item in $List) {
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

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $List = (Get-PSDWizardTSChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List = Invoke-command $ScriptBlock
    }

    If ($PSBoundParameters.ContainsKey('IncludeAll')) {
        [scriptblock]$IncludeFolderFilter = { $_.Name -Like "*" }
        [scriptblock]$IncludeItemFilter = { $_.Name -Like "*" }
    }
    Else {
        [scriptblock]$IncludeFolderFilter = { $_.enable -eq $True }
        [scriptblock]$IncludeItemFilter = { ($_.enable -eq $True) -and ( ($_.hide -eq $False) -or ([string]::IsNullOrEmpty($_.hide)) ) }
    }

    $ListObject.Items.Clear() | Out-Null 

    foreach ($item in ($List | Where-Object -FilterScript $IncludeItemFilter | Where-Object { $_.$Identifier -like "*$Filter*" })) {
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
    #>
    $apps = Get-PSDWizardTSChildItem -Path "DeploymentShare:\Applications" -Recurse
    If ($apps.count -gt 1) { return $true }Else { return $false }
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
        [scriptblock]$IncludeFolderFilter = { $_.enable -eq $True }
        [scriptblock]$IncludeItemFilter = { ($_.enable -eq $True) -and ( ($_.hide -eq $False) -or ([string]::IsNullOrEmpty($_.hide)) ) }
    }
    #Write-host ("Including all root items? {0} using filter: [{1}]" -f $ShowAll,$IncludeItemFilter.ToString())

    $TreeObject.Items.Clear() | Out-Null 
    $dummyNode = $null
    # ================== Handle FIRST LEVEL Folders ===========================
    # TEST: foreach ($folder in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences" -Directory | Where -FilterScript $IncludeFilter)){$folder}
    foreach ($folder in (Get-PSDWizardTSChildItem -Path $SourcePath -Directory | Where -FilterScript $IncludeFolderFilter)) {

        $treeViewFolder = [Windows.Controls.TreeViewItem]::new()
        $treeViewFolder.Header = $folder.Name
        $treeViewFolder.Tag = @($folder.Path, $SourcePath, $Identifier, $ShowAll)
        $treeViewFolder.Items.Add($dummyNode) | Out-Null

        #Does not take values from param, add to tag.
        $treeViewFolder.Add_Expanded( {
                #Write-Host ("Expanded [" + $_.OriginalSource.Header + "] from [" + $_.OriginalSource.Tag[0].ToString() + "]")
                Expand-PSDWizardTree -SourcePath $_.OriginalSource.Tag[1].ToString() `
                    -TreeItem $_.OriginalSource `
                    -Identifier $_.OriginalSource.Tag[2].ToString() `
                    -IncludeAll $_.OriginalSource.Tag[3]
            })
        $TreeObject.Items.Add($treeViewFolder) | Out-Null
    }

    # ================== Handle FIRST LEVEL Files ===========================
    # TEST: foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences" | Where -FilterScript $IncludeItemFilter)){$item}
    foreach ($item in (Get-PSDWizardTSChildItem -Path $SourcePath | Where -FilterScript $IncludeItemFilter)) {
        #write-host ("Found item --> id:{0},Name:{1},enable:{2},hide:{3}" -f $item.id,$item.Name,$item.enable,$item.hide)
        $treeViewItem = [Windows.Controls.TreeViewItem]::new()
        $treeViewItem.Header = $item.Name
        $FolderPath = Split-Path $item.Path -Parent
        $treeViewItem.Tag = @($FolderPath, $item.Name, $item.$Identifier, $item.Comments, $item.guid)
        #$treeViewItem.Tag = @($item.Path,$item.$Identifier)
        $TreeObject.Items.Add($treeViewItem) | Out-Null

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
    If ($null -ne $PreSelect) {
        #Select item from tree
        $SelectedTreeItem = $TreeObject.Items | Where {$_.Tag[2] -eq $PreSelect}
        $ItemSelected = $TreeObject.ItemContainerGenerator.ContainerFromItem($SelectedTreeItem) 
        if ($null -ne $ItemSelected){
            $ItemSelected.IsSelected = $true
            if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Preselected item [{1}] for [{2}]" -f ${CmdletName}, $PreSelect, $SelectedTreeItem.Header) }
        }
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
        foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Servers" | Where -FilterScript $IncludeItemFilter)){$item}
        foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Workstations" | Where -FilterScript $IncludeItemFilter)){$item}
        foreach ($folder in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Servers" -Directory | Where -FilterScript $IncludeItemFilter )){$folder}

        (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\VRA\Server" | Where {[string]::IsNullOrEmpty($_.hide) -or ($_.hide -eq $False)})
        [Boolean]::Parse((Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Servers" | Select -First 1 | Select -ExpandProperty Hide)) -eq 'True'
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
        [scriptblock]$IncludeFolderFilter = { $_.enable -eq $True }
        [scriptblock]$IncludeItemFilter = { ($_.enable -eq $True) -and ( ($_.hide -eq $False) -or ([string]::IsNullOrEmpty($_.hide)) ) }
    }

    #Write-host ("Including all items: {0}; Filter {1}" -f $ShowAll,$IncludeItemFilter.ToString())
    $dummyNode = $null
    If ($TreeItem.Items.Count -eq 1 -and $TreeItem.Items[0] -eq $dummyNode) {
        $TreeItem.Clear() | Out-Null
        Try {
            #drill into subfolders. $TreeItem.Tag[0] comes from Tag in Root folders
            foreach ($folder in ( Get-PSDWizardTSChildItem -Path ($SourcePath + '\' + $TreeItem.Tag[0].ToString()) -Directory | Where -FilterScript $IncludeFolderFilter) ) {
                $subFolder = [Windows.Controls.TreeViewItem]::new();
                $subFolder.Header = $folder.Name
                $subFolder.Tag = @($folder.Path, $SourcePath, $Identifier, $ShowAll)
                $subFolder.Items.Add($dummyNode)

                #must use tag to pass variables to Add_expanded
                $subFolder.Add_Expanded( {
                        #Write-Host ("Expanded [" + $_.OriginalSource.Header + "] from [" + $_.OriginalSource.Tag[0].ToString() + "]")
                        #expand based on Directory and Identifier
                        Expand-PSDWizardTree -SourcePath $_.OriginalSource.Tag[1].ToString() `
                            -TreeItem $_.OriginalSource `
                            -Identifier $_.OriginalSource.Tag[2].ToString() `
                            -IncludeAll $_.OriginalSource.Tag[3]
                    })
                $TreeItem.Items.Add($subFolder) | Out-Null
            }

            #get all files
            foreach ($item in (Get-PSDWizardTSChildItem -Path ($SourcePath + '\' + $TreeItem.Tag[0].ToString()) | Where -FilterScript $IncludeItemFilter) ) {
                #write-host ("Found item --> id:{0},Name:{1},enable:{2},hide:{3}" -f $item.id,$item.Name,$item.enable,$item.hide)
                $subitem = [Windows.Controls.TreeViewItem]::new()
                $subitem.Header = $item.Name
                $FolderPath = Split-Path $item.Path -Parent
                $subitem.Tag = @($FolderPath, $item.Name, $item.$Identifier, $item.Comments, $item.guid)
                #$subitem.Tag = @($item.Path,$item.$Identifier)
                $TreeItem.Items.Add($subitem) | Out-Null

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
                Where -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*Server*" })){$item}
        foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences" -Recurse | Where-Object { (Split-Path $_.Path -Parent) -in $FolderCollection} | 
                Where -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*Windows*" })){$item}
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
        [scriptblock]$IncludeFolderFilter = { $_.enable -eq $True }
        [scriptblock]$IncludeItemFilter = { ($_.enable -eq $True) -and ( ($_.hide -eq $False) -or ([string]::IsNullOrEmpty($_.hide)) ) }
    }

    $TreeObject.Items.Clear() | Out-Null 

    # Grab all folders
    $FolderCollection = @()
    foreach ($folder in ( Get-PSDWizardTSChildItem -Path $SourcePath -Recurse -Directory | Where -FilterScript $IncludeFolderFilter) ) {
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
            $treeViewItem.Tag = @($FolderPath, $item.Name, $item.$Identifier, $item.Comments, $item.guid)
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

    $DefaultAppList = $InputObject | Where { ($_.Name -notlike 'Skip*') -and ($_.Name -notlike '*Codes') -and -not([string]::IsNullOrEmpty($_.Value)) }
    $AppGuids = $DefaultAppList.Value | select -Unique

    #Set an emptry valus if not specified
    If ($null -eq $Identifier) { $Identifier = '' }

    $SelectedGuids = @()
    Foreach ($AppGuid in $AppGuids) {
        $AppInfo = $AllApps | Where { $_.Guid -eq $AppGuid }
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
       $CurrentAppList = $InputObject | Where {($_.Name -notlike 'Skip*') -and ($_.Name -notlike '*Codes')}
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
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $AllApps = Get-PSDWizardTSChildItem -Path "DeploymentShare:\Applications" -Recurse
    $SelectedApps = $FieldObject.SelectedItems

    #Get current applist
    $CurrentAppList = $InputObject | Where { ($_.Name -notlike 'Skip*') -and ($_.Name -notlike '*Codes') -and -not([string]::IsNullOrEmpty($_.Value)) }
    #TODO: remove apps from list and rebuild

    $i = 1
    $SelectedGuids = @()
    Foreach ($App in $SelectedApps) {
        [string]$NumPad = "{0:d3}" -f [int]$i

        $AppInfo = $AllApps | Where { $_.Name -eq $App }
        #collect GUIDs (for Passthru output)
        $SelectedGuids += $AppInfo.Guid

        If ($AppInfo.Guid -in $CurrentAppList.Guid) {
            #TODO: get name to determine what is the next app number?
        }
        Else {
            Set-PSDWizardTSItem ("Applications" + $NumPad) -Value $AppInfo.Guid
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

#region FUNCTION: Get-PSDWizardConsole
Function Get-PSDWizardConsole {
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

#region FUNCTION: Show-PSDWizardConsole
function Show-PSDWizardConsole {
    <#
    .SYNOPSIS
        Show the console window
    .LINK
        Get-PSDWizardConsole
    #>
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand
    Try {
        $consolePtr = Get-PSDWizardConsole
        [Console.Window]::ShowWindow($consolePtr, 5)
    }
    Catch {
        Write-PSDLog -Message ("{0}: Unable to open PowerShell console. {1}" -f ${CmdletName}, $_.exception.message)
    }
}
#endregion

#region FUNCTION: Hide-PSDWizardConsole
function Hide-PSDWizardConsole {
    <#
    .SYNOPSIS
        Hide the console window
    .LINK
        Get-PSDWizardConsole
    #>
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand
    Try {
        $consolePtr = Get-PSDWizardConsole
        [Console.Window]::ShowWindow($consolePtr, 0)
    }
    Catch {
        Write-PSDLog -Message ("{0}: Unable to close PowerShell console. {1}" -f ${CmdletName}, $_.exception.message)
    }
}
#endregion