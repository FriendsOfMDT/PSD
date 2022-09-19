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
        Modified: 2022-03-02
        Version: 2.2.1b

        SEE CHANGELOG.MD

        TODO:

.Example
#>


#region FUNCTION: Check if running in ISE
Function Test-IsISE {
    # trycatch accounts for:
    # Set-StrictMode -Version latest
    try {
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}
#endregion

#region FUNCTION: Check if running in Visual Studio Code
Function Test-VSCode {
    if ($env:TERM_PROGRAM -eq 'vscode') {
        return $true;
    }
    Else {
        return $false;
    }
}
#endregion

#region FUNCTION: Find script path for either ISE or console
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
[string]$ScriptRoot = Split-Path -Path $PSDWizardPath -Parent

if ($PSDDeBug -eq $true) {
    Write-PSDLog -Message ("{0}: PSDWizard path is [{1}]" -f $MyInvocation.MyCommand, $PSDWizardPath) -LogLevel 1
    Write-PSDLog -Message ("{0}: DeployRoot path is [{1}]" -f $MyInvocation.MyCommand, $Global:psddsDeployRoot) -LogLevel 1
    Write-PSDLog -Message ("{0}: ScriptRoot path is [{1}]" -f $MyInvocation.MyCommand, $ScriptRoot) -LogLevel 1
}


##*========================================================================
##* FUNCTIONS
##*========================================================================
#region FUNCTION: Get locales
Function Get-PSDWizardLocale {
    [CmdletBinding()]
    Param(
        $Path = $ScriptRoot,
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

#region FUNCTION: Get index value of Timezone
Function Get-PSDWizardTimeZoneIndex {
    [CmdletBinding()]
    Param(
        $Path = $ScriptRoot,
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
        $index.id = 35
        $index.TimeZone = '(GMT-05:00) Eastern Standard Time'
        $index.DisplayName = 'Eastern Standard Time'
        $index.Name = 'Eastern Time (US and Canada)'
        $index.UTC = 'UTC-05:00'

        $indexData += $index
    }
    return $IndexData
}
#endregion




Function Get-PSDWizardTSItem {
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
    # Replace it with actual envrionement's value (eg. %scriptroot% --> \\192.68.1.10\deploymentshare$\scripts)
    Try {
        If (!$IgnoreEnv) { $Results = Get-PSDWizardEnvValue $TSItem }
    }
    Catch {
        $Results = $TSItem
    }
    Finally {
        $Results | Select @param
    }
}


Function Get-PSDWizardEnvValue {
    <#
        .SYNOPSIS
        Replace %DEPLOYROOT% or %SCRIPTROOT% with actual path
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        $TSItem
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($TSItem.Value) {
        #TEST $TSItem = $test = "" | Select Name,value; $test.name='Locale';$test.Value='en-US';$Test
        #TEST $TSItem = $test = "" | Select Name,value; $test.name='OSDComputerName';$test.Value='%Prefix%-%SERIAL:8%';$Test
        #TEST $TSItem = $test = "" | Select Name,value; $test.name='PSDWizardLogo';$test.Value='%SCRIPTROOT%\powershell.png';$Test
        #TEST $TSItem = $test = "" | Select Name,value; $test.name='PSDSample';$test.Value='%DEPLOYROOT%\%SCRIPTROOT%';$Test
        $EnvironmentValues = [Regex]::Matches($TSItem.Value, '(?<=\%).*?(?=\%)') | Select -ExpandProperty Value

        #sometimes mutliple values exist, loop through each
        foreach ($EnvironmentValue in $EnvironmentValues) {
            If ($DeplopRoot) {
                $Path = $DeployRoot
            }
            ElseIf (-Not[string]::IsNullOrEmpty($Global:psddsDeployRoot) ) {
                $Path = $Global:psddsDeployRoot
            }
            Else {
                $Path = (Get-PSDrive -PSProvider MDTProvider).root | Select -First 1
            }

            switch ( $EnvironmentValue.ToLower() ) {
                'deployroot' { $value = $Path }
                'scriptroot' { $value = Join-Path $Path -ChildPath 'Scripts' }
                default { $value = $Null }
            }

            if ( ($PSDDeBug -eq $true) -and ($null -ne $value) ) { Write-PSDLog -Message ("{0}: Replaced TS value [{1}] with [{2}]" -f ${CmdletName}, $EnvironmentValue, $Value) -LogLevel 1 }

            If ($value) { $TSItem.Value = $TSItem.Value.replace(('%' + $EnvironmentValue + '%'), $Value) }
        }
    }

    return $TSItem
}



Function Set-PSDWizardTSItem {

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

    If ($PSBoundParameters.ContainsKey('Passthru')) {
        $param = @{
            Value    = $Value
            Passthru = $True
        }
    }
    Else {
        $param = @{
            Value    = $Value
            Passthru = $False
        }
    }

    If ($PSBoundParameters.ContainsKey('WildCard')) {
        #$Value = (Get-ChildItem -Path TSEnv: | Where {$_.Name -like "*$Name*"}) | Select @param
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Setting OSD value for names that match [{1}] to [{2}]" -f ${CmdletName}, $Name, $Value) -LogLevel 1 }
        $Results = Get-PSDWizardTSItem $Name -WildCard | % { Set-Item -Path TSEnv:$_.Name @param }
    }
    Else {
        #$Value = (Get-ChildItem -Path TSEnv: | Where {$_.Name -eq $Name}) | Select @param
        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Setting OSD value for name [{1}] to [{2}]" -f ${CmdletName}, $Name, $Value) -LogLevel 1 }
        $Results = Set-Item -Path TSEnv:$Name @param
    }
    return $Results
}

#region FUNCTION: Switch tabs
function Switch-PSDWizardTabItem {
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

        #$message = ("Selected tab index [{0}]" -f $newtab)
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


Function Get-PSDWizardUIElement {
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
            $Elements += ($global:PSDWizardUIElements | Where { $_.Name -like "*$Name*" }).Value
        }
        Else {
            $Elements += ($global:PSDWizardUIElements | Where { $_.Name -eq $Name }).Value
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

#region FUNCTION: Set UI fields to either visible and state
Function Set-PSDWizardUIElement {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, Position = 0, ParameterSetName = "object", ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object[]]$Object,
        [parameter(Mandatory = $true, Position = 0, ParameterSetName = "name", ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
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
            $Object = @()
            $Object = Get-PSDWizardUIElement -Name $Name
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


#region FUNCTION: Throw errors to Form's Output field
Function Invoke-PSDWizardNotification {
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

#region FUNCTION: Validate domain name with regex
Function Confirm-PSDWizardFQDN {
    [CmdletBinding()]
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

#region FUNCTION: Validate workgroup name with regex
Function Confirm-PSDWizardWorkgroup {
    [CmdletBinding()]
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

#region FUNCTION: Generate random alphacharacter
Function Get-PSDWizardRandomAlphanumericString {
    [CmdletBinding()]
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

#region FUNCTION: Validate domain name with regex
Function Confirm-PSDWizardUserName {
    [CmdletBinding()]
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


#region FUNCTION: Changes character length
function Set-PSDWizardStringLength {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
        [string]$Str,

        [parameter(Mandatory = $False, Position = 1)]
        $Length,

        [parameter(Mandatory = $False, Position = 2)]
        [ValidateSet('Left', 'Right')]
        [string]$TrimOff
    )

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
#endregion

#region FUNCTION: Change computername where variables might exist
Function Get-PSDWizardComputerName {
    [CmdletBinding()]
    param(
        $Value
    )

    <# TESTS
        $Value="PSD-%SERIAL%"
        $Value="PSD-%SERIAL:8%"
        $Value="PSD-%PREFIX%-%SERIAL:8%"
        $Value="PSD-%PREFIX%-%8:SERIAL%"
        $Value="%PREFIX%-%RAND:2%-%8:SERIAL%"
        $Value="%PREFIX%-%RAND:2%-%SERIAL:8%"
        $Value="PSD%SERIAL%"
        $Value="PSD%SERIAL%PSD"
        $Value="%PREFIX%-%SERIAL%"
        $Value="%PREFIX%%SERIAL%"
        $Value="%PREFIX%%PREFIX%"
        $Value="%SERIAL%-%SERIAL%"
        $Value="%PREFIX%-%RAND:6%"
        $Value="%PREFIX%-%SERIAL:7%"
        $Value="%PREFIX%-%RAND:6%"
        $Value="%PREFIX%-%SERIAL:7%"
        $Value="%PREFIX%-%7:SERIAL%"
        $Value="%PREFIX%-%SERIALNUMBER%"

        $Parts = [Regex]::Matches($Value,'(?<=\%).*?(?=\%)') | Select -ExpandProperty Value       
    #>

    #Split Up based on variables
    $Parts = $Value.Split('%')
    $NewNameParts = @()

    #TEST $Part = $Parts[0]
    #TEST $Part = $Parts[-4]
    #TEST $Part = $Parts[-2]
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
                            [string]$SerialValue = $serial | Set-PSDWizardStringLength -Length $Length -TrimOff Right
                        }
                        ElseIf ($Part -match '(?<=^\d{1,2}:)') {
                            $Length = $Part.split(':')[0]
                            [string]$SerialValue = $serial | Set-PSDWizardStringLength -Length $Length -TrimOff Left
                        }
                        
                        if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Paring Computername portion [{1}]; Using SERIAL expression with value [{2}]" -f ${CmdletName}, $Part, $SerialValue) }

                        #replace part with serial number
                        [string]$Part = $serial
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

#region FUNCTION: Validate ComputerName input & throw errors
Function Confirm-PSDWizardComputerName {
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

#region FUNCTION: Validate passwords
Function Confirm-PSDWizardPassword {
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


#region FUNCTION: Converts from a PSobject to a TS variable
Function ConvertTo-PSDWizardTSVar {
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
    Begin {
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand

        If ($PSCmdlet.ParameterSetName -eq "xml") {
            $Object = $XmlImport
        }
        If ($PSCmdlet.ParameterSetName -eq "source") {
            $Object = (Get-PSDWizardTSChildItem -Path $SourcePath -Recurse)
        }
        If ($PSCmdlet.ParameterSetName -eq "script") {
            $Object = Invoke-command $ScriptBlock
        }
        If ($PSCmdlet.ParameterSetName -eq "hashtable") {
            $Object = $HashTable
        }

    }
    Process {
        If ($PSCmdlet.ParameterSetName -eq "hashtable") {
            If ($null -ne $InputValue) {
                #grab the name (key) from value
                $Value = $Object.Get_Item($InputValue)
            }
        }
        Else {
            If ($SelectedProperty) {
                $Value = ($Object | Where { $_.$MappedProperty -eq $InputValue }).$SelectedProperty
                if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Found [{1}] items where selection ['{2}' = '{3}'] using [{4}] property" -f ${CmdletName}, $Object.Count, $MappedProperty, $InputValue, $SelectedProperty) }
            }
            Else {
                $Value = ($Object | Where { $_.$MappedProperty -eq $InputValue })
                if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Found [{1}] items where selection ['{2}' = '{3}']" -f ${CmdletName}, $Object.Count, $MappedProperty, $InputValue) }
            }
        }
    }
    End {
        If ($Value) {
            Write-PSDLog -Message ("{0}: Updated value [{1}] from input [{2}]" -f ${CmdletName}, $Value, $InputValue)
            return $Value
        }
        ElseIf ($DefaultValueOnNull) {
            Write-PSDLog -Message ("{0}: Defaulted to value [{1}]" -f ${CmdletName}, $DefaultValueOnNull) -LogLevel 2
            return $DefaultValueOnNull
        }
        Else {
            Write-PSDLog -Message ("{0}: Unable to map property [{1}] with input of [{2}]" -f ${CmdletName}, $MappedProperty, $InputValue) -LogLevel 2
        }
    }
}
#endregion

#region FUNCTION: Retrieve items from deployment share
Function Get-PSDWizardTSChildItem {
    <#
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
        }
        Else {
            $Content = Get-ChildItem @Param | Where { $_.PSIsContainer } |
            Select Name, Enable, Comments, GUID, @{Name = 'Path'; Expression = { (($_.PSPath) -split $EscapePath, '')[1] } }
        }

    }
    Else {

        #display content. Passthru displays all info
        If ($Passthru) {
            $Content = Get-ChildItem @Param | Where { $_.PSIsContainer -eq $false } | Select *
        }
        Else {
            $Content = Get-ChildItem @Param | Where { $_.PSIsContainer -eq $false } |
            Select ID, Name, Hide, Enable, Comments, GUID, @{Name = 'Path'; Expression = { (($_.PSPath) -split $EscapePath, '')[1] } }
        }

    }

    if ($PSDDeBug -eq $true) { Write-PSDLog -Message ("{0}: Populating content for PSD Drive [{1}]" -f ${CmdletName}, $Path) }
    return $Content
}
#endregion

#region FUNCTION: populate all time zones in dropdown
Function Add-PSDWizardComboList {
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

    $ListObject.Items.Clear();

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $List = (Get-PSDWizardTSChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List = Invoke-command $ScriptBlock
    }
    If ($PSCmdlet.ParameterSetName -eq "object") {
        $List = $InputObject
    }

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
                $ListObject.Items.Add($item.$Identifier) | Out-Null
            }
            Else {
                $ListObject.Items.Add($item) | Out-Null
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

#region FUNCTION: populate list in wizard
Function Add-PSDWizardList {
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

    #$SourcePath="DeploymentShare:\Applications";$ListObject=$_appTabList;$Exclude="Bundles";$Identifier="Name"
    If ($PSBoundParameters.ContainsKey('Exclude')) {
        [scriptblock]$ExcludeItemFilter = { $_.$Identifier -NotLike "*$Exclude*" }
    }
    Else {
        [scriptblock]$ExcludeItemFilter = { $_.$Identifier -like '*' }
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

    $ListObject.Items.Clear();

    foreach ($item in $List) {
        #Check to see if propertiues exists
        If ($item.PSobject.Properties.Name.Contains($Identifier)) {
            $ListObject.Items.Add($item.$Identifier) | Out-Null
        }
        Else {
            $ListObject.Items.Add($item) | Out-Null
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


#region FUNCTION: populate list in wizard
# TESTS $ListObject=$_depTabProfiles
Function Add-PSDWizardSelectionProfile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$SourcePath = "DeploymentShare:\Selection Profiles",
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$ListObject,
        [string]$Filter = 'Deployment',
        [switch]$Passthru
    )

    $ListObject.Items.Clear();

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

Function Add-PSDWizardBundle {
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
        $ListObject.Items.Clear();
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

#region FUNCTION: Search the tree view
<# TEST
$SourcePath="DeploymentShare:\Applications"
$ListObject=$_appTabList
$Filter='Adobe'

#>
Function Search-PSDWizardList {
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

    $ListObject.Items.Clear();

    foreach ($item in ($List | Where-Object -FilterScript $IncludeItemFilter | Where-Object { $_.$Identifier -like "*$Filter*" })) {
        #only include what items exist in either in the folders collected initially or root locations
        $ListObject.Tag = @($item.Name, $item.Path, $item.Guid)
        $ListObject.Items.Add($item.$Identifier) | Out-Null
    }
}
#endregion

#region FUNCTION: Checks to see if there are applications present
Function Test-PSDWizardApplicationExist {
    $apps = Get-PSDWizardTSChildItem -Path "DeploymentShare:\Applications" -Recurse
    If ($apps.count -gt 1) { return $true }Else { return $false }
}
#endregion


#region FUNCTION: Populate treeview with first level folder and files
Function Add-PSDWizardTree {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true, Position = 0)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position = 1)]
        [System.Windows.Controls.TreeView]$TreeObject,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$Identifier,
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

    $TreeObject.Items.Clear();
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

}
#endregion

#region FUNCTION: drill into subfolders in treeview
Function Expand-PSDWizardTree {
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
        $TreeItem.Items.Clear();
        Try {
            # TEST: foreach ($folder in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Servers" -Directory | Where -FilterScript $IncludeItemFilter )){$folder}
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
            # TEST: foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Servers" | Where -FilterScript $IncludeItemFilter)){$item}
            # TEST: foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Workstations" | Where -FilterScript $IncludeItemFilter)){$item}
            #(Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\VRA\Server" | Where {[string]::IsNullOrEmpty($_.hide) -or ($_.hide -eq $False)})
            #[Boolean]::Parse((Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences\Servers" | Select -First 1 | Select -ExpandProperty Hide)) -eq 'True'

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


#region FUNCTION: Search the tree view
<# TESTS
$SourcePath="DeploymentShare:\Task Sequences"
$TreeObject=$_tsTabTree
$Identifier='ID'
$Filter='Windows'
$Filter='Server'
#>
Function Search-PSDWizardTree {
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

    $TreeObject.Items.Clear();

    # Grab all folders
    $FolderCollection = @()
    foreach ($folder in ( Get-PSDWizardTSChildItem -Path $SourcePath -Recurse -Directory | Where -FilterScript $IncludeFolderFilter) ) {
        #collect all folders based on filter into an array
        If ($folder.Path -notin $FolderCollection) { $FolderCollection += $folder.Path }
    }

    # Each item must exist in folder path and match filter.
    # TEST: foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences" -Recurse | Where-Object { (Split-Path $_.Path -Parent) -in $FolderCollection} | Where -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*Server*" })){$item}
    # TEST: foreach ($item in (Get-PSDWizardTSChildItem -Path "DeploymentShare:\Task Sequences" -Recurse | Where-Object { (Split-Path $_.Path -Parent) -in $FolderCollection} | Where -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*Windows*" })){$item}
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

#region FUNCTION: Get all selection applications
Function Get-PSDWizardSelectedApplications {
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
    #$AllApps = $FieldObject.Items | foreach {$i=0} {$_ | Add-Member Index ($i++) -PassThru}
    $AllApps = Get-PSDWizardTSChildItem -Path "DeploymentShare:\Applications" -Recurse

    #TEST $InputObject=$apps;$property='Value';$FieldObject=$_appTabList
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

Function Set-PSDWizardSelectedApplications {
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

    #Set-PSDWizardSelectedApplications -InputObject $AppObject -property 'Value' -Field ($Form.FindName('_appTabList')) -Tag 'guid'
    #TEST $InputObject=$SelectedApps;$FieldObject=$_appTabList
    $AllApps = Get-PSDWizardTSChildItem -Path "DeploymentShare:\Applications" -Recurse

    $SelectedApps = $FieldObject.SelectedItems

    #Get current applist
    #$CurrentAppList = $InputObject | Where {($_.Name -notlike 'Skip*') -and ($_.Name -notlike '*Codes')}
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

function Write-PSDWizardOutput {
    param(
        [parameter(Mandatory = $true)]
        $UIObject,
        [parameter(Mandatory = $true)]
        [string]$Message,
        [switch]$Append
    )

    If (!$Append) {
        $UIObject.Controls.Clear();
    }

    $UIObject.AppendText(("`n{0}" -f $Message))
    #scroll to bottom
    $UIObject.ScrollToEnd()
}


function Add-PSDWizardListView {
    param(
        [parameter(Mandatory = $true)]
        $UIObject,
        [parameter(Mandatory = $true)]
        $ItemData
    )

    $UIObject.ItemsSource = $ItemData
}


Function Get-PSDWizardConsole {
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

function Show-PSDWizardConsole {
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

function Hide-PSDWizardConsole {
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



