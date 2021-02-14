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
        Created:
        Modified: 2020-01-12

        Version - 0.0.0 - () - Finalized functional version 1.
        Version - 0.0.1 - () - Added Get-TSItem.
        Version - 1.0.1 - (PC) - Cleaned up logging and added script source; moved all variables in messages to format tag
        Version - 1.0.2 - (PC) - Fixed computername detection; added Autopilot like variables (eg. %RAND:4%, %4:SERIAL% and %SERIAL:4%)
        Version - 1.0.3 - (PC) - Added hashtables for locale info; provided quicker UI load. Added hatable parsing for list creations in UI
        TODO:

.Example
#>

#region FUNCTION: Builds dynamic variables in form with alias
Function Get-FormVariable{
    param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$Name,
        [switch]$Wildcard

    )

    If($Wildcard){
        Return [array](Get-Variable | Where {$_.Name -like "*$Name*"}).Value
    }
    Else{
        Return [array](Get-Variable | Where {$_.Name -eq $Name}).Value
    }
}
#endregion

Function Get-TSItem{
    Param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$Name,
        [switch]$WildCard,
        [switch]$ValueOnly
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If($PSBoundParameters.ContainsKey('ValueOnly')){
        $param = @{
            ExpandProperty = 'Value'
        }
    }Else{
        $param = @{
            Property = 'Name','Value'
        }
    }

    If($PSBoundParameters.ContainsKey('WildCard'))
    {
        if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Searching OSD value for [{0}]" -f $Name) -LogLevel 1}
        #$Value = (Get-ChildItem -Path TSEnv: | Where {$_.Name -like "*$Name*"}) | Select @param
        $Results = Get-Item TSEnv:*$Name* | Select @param
    }
    Else{
        if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Grabbing OSD value for for [{0}]" -f $Name) -LogLevel 1}
        #$Value = (Get-ChildItem -Path TSEnv: | Where {$_.Name -eq $Name}) | Select @param
        $Results = Get-Item TSEnv:$Name | Select @param
    }
    return $Results
}

Function Set-TSItem{
    Param(
        [Parameter(Mandatory = $true, Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$Name,
        [Parameter(Mandatory = $true, Position=1)]
        [string]$Value,
        [switch]$WildCard,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If($PSBoundParameters.ContainsKey('Passthru')){
        $param = @{
            Value = $Value
            Passthru = $True
        }
    }Else{
        $param = @{
            Value = $Value
            Passthru = $False
        }
    }

    If($PSBoundParameters.ContainsKey('WildCard')){
        #$Value = (Get-ChildItem -Path TSEnv: | Where {$_.Name -like "*$Name*"}) | Select @param
        if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Setting OSD value for names that match [{0}] to [{1}]" -f $Name,$Value) -LogLevel 1}
        $Results = Get-TSItem $Name -WildCard | %{Set-Item -Path TSEnv:$_.Name @param}
    }Else{
        #$Value = (Get-ChildItem -Path TSEnv: | Where {$_.Name -eq $Name}) | Select @param
        if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Setting OSD value for name [{0}] to [{1}]" -f $Name,$Value) -LogLevel 1}
        $Results = Set-Item -Path TSEnv:$Name @param
    }
    return $Results
}

#region FUNCTION: Switch tabs
function Switch-TabItem {
    param(
        [Parameter(Mandatory = $true, Position=0)]
        [System.Windows.Controls.TabControl]$TabControlObject,
        [Parameter(Mandatory = $true, Position=1,ParameterSetName="index")]
        [int]$increment,
        [Parameter(Mandatory = $true, Position=1,ParameterSetName="name")]
        [string]$name
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSCmdlet.ParameterSetName -eq "index") {
        #Add index number to current tab
        $newtab = $TabControlObject.SelectedIndex + $increment
        #ensure number is not greater than tabs
        If ($newtab -ge $TabControlObject.items.count) {
            $newtab=0
        }
        elseif ($newtab -lt 0) {
            $newtab = $TabControlObject.SelectedIndex - 1
        }
        #Set new tab index
        $TabControlObject.SelectedIndex = $newtab

        $message = ("Selected tab index: {0}" -f $newtab)
    }
    ElseIf($PSCmdlet.ParameterSetName -eq "name"){
        $newtab = $TabControlObject.items | Where Header -eq $name
        $newtab.IsSelected = $true

        $message = ("Selected tab name: {0}" -f $newtab.Header)
    }
    if($PSDDeBug -eq $true){Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $message" -LogLevel 1}
}
#endregion

Function Get-UIFieldElement {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=0,ParameterSetName="name",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [object[]]$Name
    )
    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand

        $objects = @()
    }
    Process{
        Foreach($item in $Name){
            If($null -ne (Get-FormVariable -Name $item)){
                $FieldObject = (Get-FormVariable -Name $item)
                $Objects += $FieldObject
                If($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Found field object [{0}]" -f $FieldObject.Name)}
            }
            Else{
                If($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Field object [{0}] does not exist" -f $FieldObject.Name)}
            }
        }

    }
    End{
        Return $Objects
    }
}

#region FUNCTION: Set UI fields to either visible and state
Function Set-UIFieldElement {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=0,ParameterSetName="object",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [object[]]$FieldObject,
        [parameter(Mandatory=$true, Position=0,ParameterSetName="name",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$FieldName,
        [boolean]$Checked,
        [boolean]$Enable,
        [boolean]$Visible,
        [string]$Content,
        [string]$text,
        $Source
    )
    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand

        #build field object from name
        If ($PSCmdlet.ParameterSetName -eq "name")
        {
            $FieldObject = @()
            $FieldObject = Get-UIFieldElement -Name $FieldName
        }

        #set visable values
        switch($Visible)
        {
            $true  {$SetVisible='Visible'}
            $false {$SetVisible='Hidden'}
        }

    }
    Process{
        Try{
            #loop each field object
            Foreach($item in $FieldObject)
            {
                #grab all the parameters
                $Parameters = $PSBoundParameters | Select -ExpandProperty Keys
                #Write-Host ('Found parameter: {0}' -f $Parameters)
                #loop each parameter
                Foreach($Parameter in $Parameters)
                {
                    #Determine what each parameter and value is
                    #if parameter is FieldObject of FieldName ignore setting it value
                    #Write-Host ('working with parameter: {0}' -f $Parameter)
                    Switch($Parameter){
                        'Checked'    {$SetValue=$true;$Property='IsChecked';$value=$Checked}
                        'Enable'    {$SetValue=$true;$Property='IsEnabled';$value=$Enable}
                        'Visible'    {$SetValue=$true;$Property='Visibility';$value=$SetVisible}
                        'Content'    {$SetValue=$true;$Property='Content';$value=$Content}
                        'Text'    {$SetValue=$true;$Property='Text';$value=$Text}
                        'Source'    {$SetValue=$true;$Property='Source';$value=$Source}
                        default     {$SetValue=$false;}
                    }

                    If($SetValue){
                       # Write-Host ('Parameter value is: {0}' -f $value)
                        If( $item.$Property -ne $value )
                        {
                            $item.$Property = $value
                            If($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Object [{0}] {1} property is changed to [{2}]" -f $item.Name,$Property,$Value)}
                        }
                        Else
                        {
                            If($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Object [{0}] {1} property already set to [{2}]" -f $item.Name,$Property,$Value)}
                        }
                    }
                }#endloop each parameter
            }#endloop each field object
        }
        Catch{
            Write-Host $_.Exception.Message
        }
    }
}
#endregion





#region FUNCTION: Retrieve all cultures
Function Get-LocaleInfo{
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand
    #grab all cultures
    $olderr=$ErrorActionPreference
    $ErrorActionPreference='SilentlyContinue'
    #loop through 20500 numbers to find all cultures
    $Cultures = For ($lcid=0; $lcid -lt 20500; $lcid++) {[System.Globalization.Cultureinfo]::GetCultureInfo($lcid)}
    $ErrorActionPreference=$olderr

    $Results = ($Cultures | Select -Unique | Sort DisplayName)
    if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Populating Language list; [{0}] items found" -f $Results.count) -LogLevel 1}
    return $Results
}
#endregion

#region FUNCTION: Retrieve cultures by property
Function Find-LocaleDetails{
    param(
        [Parameter(Mandatory = $false, Position=0,ParameterSetName="lcid")]
        [int]$lcid,
        [Parameter(Mandatory = $false, Position=0,ParameterSetName="Name")]
        [string]$Name,
        [Parameter(Mandatory = $false, Position=0,ParameterSetName="Display")]
        [string]$DisplayName
    )

    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand

        $Cultures = @()
    }
    Process{
        #loop through 20500 numbers to find all cultures
        If($PSCmdlet.ParameterSetName -eq "lcid"){
            Try{$Cultures = [System.Globalization.Cultureinfo]::GetCultureInfo($lcid)}Catch{$Cultures = $null}Finally{$Results = $Cultures}
        }
        Else{
            If ($PSCmdlet.ParameterSetName -eq "Name") {
                $filterby = "Name"
                $Value = $Name
            }

            If ($PSCmdlet.ParameterSetName -eq "Display") {
                $filterby = "DisplayName"
                $Value = $DisplayName
            }

            #loop through 20500 numbers to find all cultures
            #stop when it reaches the filter
            $lcid=0
            Do {
                $lcid++
                $olderr=$ErrorActionPreference
                $ErrorActionPreference='SilentlyContinue'
                $Culture = [System.Globalization.Cultureinfo]::GetCultureInfo($lcid)
                If($Culture.$filterby -notin $Cultures.$filterby){$Cultures += $Culture}
                $ErrorActionPreference=$olderr
            } # End of 'Do'
            Until ( ($lcid -eq 20500) -or ($Value -in $Cultures.$filterby) )

            $Results = $Cultures | Where {$_.$filterby -eq $Value}
        }
    }
    End{
        if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Populating Language list by {0}; [{1}] items found" -f $PSCmdlet.ParameterSetName,$Results.count) -LogLevel 1}
        return $Results
    }
}
#endregion


#region FUNCTION: Get index value of Timezone
Function Get-TimeZoneIndex{
    Param(
        $Data = "$DeployRoot\scripts\ListOfTimeZoneIndex.xml",
        $TimeZone
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #TEST $TimeZone = '(UTC-05:00) Eastern Time (US & Canada)'
    #TEST $index = $indexData.TimeZoneIndex.Index | Where {$_.TimeZone -like '*Eastern*'} | Select -first 1

    [xml]$IndexData = Get-Content $Data  -ErrorAction Stop
    $TotalIndex = ($indexData.TimeZoneIndex.Index).Count
    Write-PSDLog -Message "Populating TimeZone index; [$TotalIndex] items found" -loglevel 1
    Foreach($index in $indexData.TimeZoneIndex.Index)
    {
        $parsedName = ($index.TimeZone -replace '^.?\((.*?)\)','').Trim()

        #grab UTC time
        $TimeZone -match '.?\((.*?)\).*' | Out-Null
        $UTC = $Matches[1]

        $TZI = $null
        #get only the timezones with matching UTC
        $filterData = $Index | where {$_.UTC -match $UTC}
        If($null -ne $filterData){
            $TZI = $filterData.id
            break
        }

        $IndexName = ($index.Name).Replace('and','&').Trim()
        If($TimeZone -Like "*$IndexName"){
            $TZI = $index.id
            break
        }
    }

    If($TZI){
        $IndexValue = ('{0:d3}' -f [int]$TZI).ToString()
    }

    if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Selected TimeZone index value: {0}" -f $IndexValue) -LogLevel 1}
    return $IndexValue
}
#endregion

Function Get-KeyboardLayouts{
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $Results = Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Keyboard Layouts" | %{Get-ItemProperty $_.pspath} |
                        Select @{Name = 'Name';expression={$_.'Layout Text' -replace '\bUS\b','United States' -replace 'Keyboard','' }},
                        @{Name = 'KeyboardLayout';expression={($_.PSChildName).Substring($_.PSChildName.Length - 4) + ':' + $_.PSChildName}} |
                        Sort Name

    if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Populating Keyboard layouts; [{0}] items found" -f $Results.count) -LogLevel 1}
    return $Results
}

Function Get-KeyboardID{
    <#
    #Get-winUserLangaugeList does not work in PE
    #Commands need to use in PE
    #https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/wpeutil-command-line-options
    #https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-language-pack-default-values
    # Pulls from HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Keyboard Layouts
    $Keyboard = wpeutil ListKeyboardLayouts $lcid
    $Language = wpeutil SetMuiLanguage
    $UserLocale = wpeutil SetUserLocale
    #>
    Param(
        [int]$lcid = 1033
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $report = @()
    $LocaleDetails = Get-LocaleInfo
    #Names are not equal to locale values
    #Parsing them is required. The current solution will see what matches
    #TODO: better solution would be to split up names and compare names and get max matches.
    #$NamesArray = (($Names[$i] -replace '\bUS\b','United States').split(' ').split('-') -replace '[()]','').trim()

    #test if PE key exists
    If(Test-Path -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlset\Control\MiniNT){
        $Keyboards = wpeutil ListKeyboardLayouts $lcid

        $Names = @()
        $IDs = @()
        $data = ($keyboards -split "`r`n") | %{
            If(-not[string]::IsNullOrEmpty($_) -and ($_ -ne 'The command completed successfully.')){
                if($_ -like "Name:*"){
                    $Names += $_ -replace '^Name:\s+',''
                }
                if($_ -like "ID:*"){
                    $IDs += $_ -replace '^ID:\s+',''
                }
            }
        }
        #$Names
        #$IDs
        for ($i = 0; $i -lt $Names.Count; $i++)
        {
            $Name = $Names[$i]
            $LocaleInfo = $LocaleDetails | Where {$_.DisplayName -like "*$Name*"}

            $info = "" | Select Name,ID,LanguageTag,LCID
            $info.Name = ($Name -replace '\bUS\b','United States')
            $info.ID = $IDs[$i]
            $info.LanguageTag = $LocaleInfo.Name
            $info.LCID = $LocaleInfo.LCID
            $report += $info
        }
    }
    Else{
        $LangInfo = Get-WinUserLanguageList
        $LocaleInfo = $LocaleDetails | Where {$_.DisplayName -eq $LangInfo.LocalizedName}

        $report += $Keyboards | Select-Object -Property @{Name = 'Name'; Expression = {$_.LocalizedName}},
                                                    @{Name = 'ID'; Expression = {$_.InputMethodTips -replace '{','' -replace '}',''}},
                                                    @{Name = 'LanguageTag'; Expression = {$_.LanguageTag}},
                                                    @{Name = 'LCID'; Expression = {$LocaleInfo.LCID}}
    }
    #filter out any non unique ones
    $Results = ($report | Select -Unique | Sort Name)

    if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Populating Keyboard layout; [{0}] items found" -f $Results.count) -LogLevel 1}
    Return $Results
}

#region FUNCTION: Converts a variable to an PS object
Function ConvertFrom-TSVar{
    Param(
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="source")]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="script")]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="object")]
        $InputObject,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="hashtable")]
        [hashtable]$HashTable,
        [Parameter(Mandatory = $false, Position=1)]
        [string]$TSVariable,
        [string]$Property,
        [switch]$Passthru
    )

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $Object = (Get-PSDChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $Object = Invoke-command $ScriptBlock
    }
    If ($PSCmdlet.ParameterSetName -eq "object") {
        $Object = $InputObject
    }
    If ($PSCmdlet.ParameterSetName -eq "hashtable") {
        $Object = $HashTable
        If($null -ne $TSVariable){
            $TSValue = (Get-TSItem $TSVariable -ValueOnly)
            #grab the name (key) from value
            $Value = $Object.Keys | Where-Object {$Object["$_"] -eq $TSValue}
        }
    }
    Else{
        If($null -ne $TSVariable)
        {
            $TSValue = (Get-TSItem $TSVariable -ValueOnly)
            If($Passthru){
                $Value = $Object | Where {$_.$Property -eq $TSValue}
            }Else{
                $Value = ($Object | Where {$_.$Property -eq $TSValue}).$Property
            }
        }
    }
    return $Value
}
#endregion

#region FUNCTION: Converts from a PSobject to a TS variable

Function ConvertTo-TSVar{
    Param(
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="source")]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="script")]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="object")]
        $OutputObject,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="hashtable")]
        [hashtable]$HashTable,
        [Parameter(Mandatory = $false, Position=1)]
        [string]$InputValue,
        [string]$Property

    )

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $Object = (Get-PSDChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $Object = Invoke-command $ScriptBlock
    }
    If ($PSCmdlet.ParameterSetName -eq "object") {
        $Object = $OutputObject
    }
    If ($PSCmdlet.ParameterSetName -eq "hashtable") {
        $Object = $HashTable
        If($null -ne $InputValue){
            #grab the name (key) from value
            $Value = $Object.Get_Item($InputValue)
        }
    }
    Else{
        If($null -ne $InputValue)
        {
            If($Property){
                $Value = ($Object | Where {$_.$Property -eq $InputValue}).$Property
            }Else{
                $Value = ($Object | Where {$_.Name -eq $InputValue}).Name
            }
        }
    }
    return $Value
}
#endregion

#region FUNCTION: Convert Locale info from OSD value
Function ConvertFrom-TSLocale{
    Param(
        [parameter(Mandatory=$true)]
        [ValidateSet('UILanguage','KeyboardLocale','UserLocale','SystemLocale','TimeZoneName')]
        [string]$LocaleType,
        [parameter(Mandatory=$false)]
        [string]$TSVariable,
        [string]$DisplayProperty,
        [switch]$Passthru
    )

    switch($LocaleType){
        #'UILanguage' {$LocaleSet = Get-WinUserLanguageList;$OSDLocaleProperty='LanguageTag'}
        #'UserLocale' {$LocaleSet = Get-WinUserLanguageList;$OSDLocaleProperty='LanguageTag'}
        #'KeyboardLocale' {$LocaleSet = Get-WinUserLanguageList;$OSDLocaleProperty='InputMethodTips'}

        'UILanguage' {$LocaleSet = Get-LocaleInfo;$OSDLocaleProperty='Name'}
        'UserLocale' {$LocaleSet = Get-LocaleInfo;$OSDLocaleProperty='Name'}
        'KeyboardLocale' {$LocaleSet = Get-KeyboardLayouts;$OSDLocaleProperty='KeyboardLayout'}
        'SystemLocale' {$LocaleSet = Get-LocaleInfo;$OSDLocaleProperty='Name'}
        'TimeZoneName' {$LocaleSet = Get-TimeZone -ListAvailable;$OSDLocaleProperty='StandardName'}
    }
    $Value = $null
    #If property specified use that as the $SelectProperty, otherwise use $OSDLocaleProperty
    If($DisplayProperty){$SelectProperty = $DisplayProperty}Else{$SelectProperty = $OSDLocaleProperty}

    If($null -ne $TSVariable)
    {
        $TSValue = (Get-TSItem $TSVariable -ValueOnly)
        If($Passthru){
            $Value = $LocaleSet | Where {$_.$OSDLocaleProperty -eq $TSValue}
        }Else{
            $Value = ($LocaleSet | Where {$_.$OSDLocaleProperty -eq $TSValue}).$SelectProperty
        }
    }
    return $Value
}
#endregion

#region FUNCTION: Convert Locale value to a OSD format
Function ConvertTo-TSLocale{
    Param(
        [parameter(Mandatory=$true)]
        [ValidateSet('UILanguage','KeyboardLocale','UserLocale','SystemLocale','TimeZoneName')]
        [string]$LocaleType,
        [string]$DisplayProperty,
        [string]$Value
    )

    switch($LocaleType){
        #'UILanguage' {$LocaleSet = Get-WinUserLanguageList;$OSDLocaleProperty='LanguageTag'}
        #'UserLocale' {$LocaleSet = Get-WinUserLanguageList;$OSDLocaleProperty='LanguageTag'}
        #'KeyboardLocale' {$LocaleSet = Get-WinUserLanguageList;$OSDLocaleProperty='InputMethodTips'}

        'UILanguage' {$LocaleSet = Get-LocaleInfo;$OSDLocaleProperty='Name'}
        'UserLocale' {$LocaleSet = Get-LocaleInfo;$OSDLocaleProperty='Name'}
        'KeyboardLocale' {$LocaleSet = Get-KeyboardLayouts;$OSDLocaleProperty='Name'}
        'SystemLocale' {$LocaleSet = Get-LocaleInfo;$OSDLocaleProperty='Name'}
        'TimeZoneName' {$LocaleSet = Get-TimeZone -ListAvailable;$OSDLocaleProperty='StandardName'}
    }

    If($null -ne $Value)
    {
        If($DisplayProperty){
            $Value = ($LocaleSet | Where {$_.$DisplayProperty -eq $Value}).$OSDLocaleProperty
        }Else{
            $Value = ($LocaleSet | Where {$_.$OSDLocaleProperty -eq $Value}).$OSDLocaleProperty
        }
    }
    return $Value
}
#endregion

#region FUNCTION: Throw errors to Form's Output field
Function Invoke-UIMessage {
    Param(
        [String]$Message,
        [ValidateSet('Error', 'Info','Hide')]
        [String]$Type,
        $HighlightObject,
        $OutputObject,
        [switch]$Passthru
    )
    switch($Type){
        'Error' {
                    $CanvasColor = 'LightPink';
                    $Highlight='Red';
                    $ReturnValue = $False
                    $OutputObject.Visibility="Visible"
                    (Get-Variable ($OutputObject.Name + '_Alert') -Value).Visibility="Visible"
                    (Get-Variable ($OutputObject.Name + '_Check') -Value).Visibility="Hidden"
                }
        'Info'  {
                    $CanvasColor = 'LightGreen';
                    $Highlight='Green';
                    $ReturnValue = $true
                    $OutputObject.Visibility="Visible"
                    (Get-Variable ($OutputObject.Name + '_Check') -Value).Visibility="Visible"
                    (Get-Variable ($OutputObject.Name + '_Alert') -Value).Visibility="Hidden"
                }
        'Hide'  {
                    $CanvasColor = 'White';
                    $Highlight='White';
                    $ReturnValue = $true
                    (Get-Variable ($OutputObject.Name + '_Check') -Value).Visibility="Hidden"
                    (Get-Variable ($OutputObject.Name + '_Alert') -Value).Visibility="Hidden"
                    $OutputObject.Visibility="Hidden"
        }
    }
    #put a border around input
    $HighlightObject.BorderThickness = "2"
    $HighlightObject.BorderBrush = $Highlight

    $OutputObject.Background = $CanvasColor
    (Get-Variable ($OutputObject.Name + '_Name') -Value).Text = $Message

    If($Passthru){return $ReturnValue}
}
#endregion

#region FUNCTION: Validate domain name with regex
Function Confirm-DomainFQDN ($value){
    $Regex = '(?=^.{3,253}$)(^(((?!-)[a-zA-Z0-9-]{1,63}(?<!-))|((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63})$)'
    If($value -match $Regex){return $true}Else{$false}
}
#endregion

#region FUNCTION: Validate workgroup name with regex
Function Confirm-WorkgroupName ($value){
    $Regex = "^[a-z0-9]{3,20}$"
    If($value -match $Regex){return $true}Else{$false}
}
#endregion

#region FUNCTION: Generate random alphacharacter
Function Get-RandomAlphanumericString {
	[CmdletBinding()]
	Param (
        $length
	)

	Begin{
       If([string]::IsNullOrEmpty($length)){[int]$length = 8}Else{[int]$length = $length}
	}

	Process{
        Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length  | % {[char]$_}) )
	}
}
#endregion

#region FUNCTION: Changes character length
function Set-StringLength {
    param (
        [parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [string]$Str,

        [parameter(Mandatory=$False,Position=1)]
        $Length,

        [parameter(Mandatory=$False,Position=2)]
        [ValidateSet('Left','Right')]
        [string]$TrimOff
    )

    If([string]::IsNullOrEmpty($length) -or ($length -eq 0)){
        [int]$length = $Str.length
    }ElseIf($length -match '\d'){
        [int]$length = $length
    }Else{
        [int]$length = $Str.length
        #length is not a integer
    }

    #$Str[0..($Length-1)] -join ""
    If($TrimOff -eq 'Left'){
        [string]$Str.Substring($length+1)
    }
    Else{
        [string]$Str.Substring(0, $length)
    }

}
#endregion

#region FUNCTION: Change computername where variables might exist
Function Set-ComputerName{
    param(
        $Value
    )

    <# TESTS
    $Value="PSD-%SERIAL%"
    $Value="PSD%SERIAL%"
    $Value="PSD%SERIAL%PSD"
    $Value="%PREFIX%-%SERIAL%"
    $Value="%PREFIX%%SERIAL%"
    $Value="%PREFIX%%PREFIX%"
    $Value="%SERIAL%-%SERIAL%"
    $Value="%PREFIX%-%RAND[6]%"
    $Value="%PREFIX%-%SERIAL[7]%"
    $Value="%PREFIX%-%RAND:6%"
    $Value="%PREFIX%-%SERIAL:7%"
    $Value="%PREFIX%-%7:SERIAL%"
    $Value="%PREFIX%-%SERIALNUMBER%"
    #>
    #split the name into parts if % exists; then loop through each part
    [Regex]::Matches($Value,'(?<=\%).*?(?=\%)') | Select -ExpandProperty Value | %{
        If( [string]::IsNullOrEmpty($_) ){
            #write-host 'Replaced: Nothing'
            [string]$Value = $Value
        }
        #does the name have a variable in it for serial number?
        ElseIf($_ -match 'SERIAL')
        {
            $TrimOffSide='Right'
            #write-host 'Replaced: Serial'
            $serial = Get-TSItem SerialNumber -ValueOnly
            If([string]::IsNullOrEmpty($serial) ){Continue}
            #check if serial is truncated with colon (eg. %SERIAL:6%)
            If($_ -match '(?<=\:).*?(?=\d{1,2})'){$Length = $_.split(':')[1]}
            If($_ -match '(?<=^\d{1,2}:)'){$Length = $_.split(':')[0];$TrimOffSide='Left'}
            Write-Host $Length
            #check if serial has digit within brackets [] (eg. %SERIAL[6]%)
            # $Length = [Regex]::Matches($_,'(?<=\[).*?(?=\])') | Select -ExpandProperty Value
            #If($_ -match '(?<=\[).*?(?=\])'){$Length = $Matches[0]}
            $NewSerial = $serial | Set-StringLength $Length -TrimOff $TrimOffSide
            [string]$Value = $Value.replace("%$_%",$NewSerial)
        }
        #does the name have a variable in it for random?
        ElseIf($_ -match 'RAND')
        {
            #write-host 'Replaced: Random'
            #check if serial is truncated with colon (eg. %SERIAL:6%)
            If($_ -match '(?<=\:).*?(?=\d)'){$Length = $_.split(':')[1]}
            #check if RAND is truncated using brackets (eg. %RAND[6]%)
            #$Length = [Regex]::Matches($_,'(?<=\[).*?(?=\])') | Select -ExpandProperty Value
            #If($_ -match '(?<=\[).*?(?=\])'){$Length = $Matches[0]}
            [string]$Value = $Value.replace("%$_%",(Get-RandomAlphanumericString -length $Length))
        }
        #If a part is equal to a name in the TSvariable; get its value
        ElseIf( (Get-TSItem $_ -ValueOnly) )
        {
            #write-host ('Replaced %{0}% with: {1}' -f $_,(Get-TSItem $_ -ValueOnly))
            [string]$Value = $Value.replace("%$_%",(Get-TSItem $_ -ValueOnly))
        }
        Else{
            #write-host 'nothing:' $_
            [string]$Value = $Value
        }
    }

    return $Value.ToUpper()

}
#endregion

#region FUNCTION: Validate ComputerName input & throw errors
Function Confirm-ComputerName {
    [CmdletBinding()]
    param(
        [System.Windows.Controls.TextBox]$ComputerNameObject,
        $OutputObject,
        [switch]$Passthru
    )
    $ErrorMessage = $null
    #Validation Rule for computer names
    if ($ComputerNameObject.text.length -eq 0){$ErrorMessage = ("Enter a valid device name");$Validation = $false}

    Elseif ($ComputerNameObject.text.length -lt 5) {$ErrorMessage = ("Less than 5 characters!");$Validation = $false}

    Elseif ($ComputerNameObject.text.length -gt 15) {$ErrorMessage = ("More than 15 characters!");$Validation = $false}

    Elseif ($ComputerNameObject.text -match "^[-_]|[^a-zA-Z0-9-_]"){$ErrorMessage = ("Invalid character(s) [{0}]." -f $Matches[0]);$Validation = $false}

    Else{$Validation = $true}

    If($Validation -eq $true){
        Invoke-UIMessage -Message 'Valid Device Name' -HighlightObject $ComputerNameObject -OutputObject $OutputObject -Type Info
    }Else{
        Invoke-UIMessage -Message $ErrorMessage -HighlightObject $ComputerNameObject -OutputObject $OutputObject -Type Error
    }

    If($Passthru){return $Validation}
}
#endregion

#region FUNCTION: Validate passwords
Function Confirm-Passwords {
    param(
        [System.Windows.Controls.PasswordBox]$PasswordObject,
        [System.Windows.Controls.PasswordBox]$ConfirmedPasswordObject,
        $OutputObject,
        [switch]$Passthru
    )

    #check to see if password match
    If([string]::IsNullOrEmpty($PasswordObject.Password)){
        $Validation = Invoke-UIMessage -Message ("Password must be supplied") -HighlightObject $PasswordObject -OutputObject $OutputObject -Type Error -Passthru
    }
    ElseIf([string]::IsNullOrEmpty($ConfirmedPasswordObject.Password) -and $ConfirmedPasswordObject.IsEnabled -eq $true){
        $Validation = Invoke-UIMessage -Message "Confirm password before continuing" -HighlightObject $ConfirmedPasswordObject -OutputObject $OutputObject -Type Error -Passthru
    }
    #check to see if password match
    ElseIf($PasswordObject.Password -ne $ConfirmedPasswordObject.Password){
        $Validation = Invoke-UIMessage -Message "Passwords do not match" -HighlightObject $ConfirmedPasswordObject -OutputObject $OutputObject -Type Error -Passthru
    }
    Else{
        $Validation = Invoke-UIMessage -Message "Passwords Match!" -HighlightObject $ConfirmedPasswordObject -OutputObject $OutputObject -Type Info -Passthru
    }

    If($Passthru){return $Validation}
}
#endregion



#region FUNCTION: Retrieve items from deployment share
Function Get-PSDChildItem{
    <#
    $AllFiles = Get-ChildItem -Path "DeploymentShare:\Task Sequences" | Where {$_.PSIsContainer -eq $false} | Select * |
        Select ID,Name,Hide,Enable,Comments,GUID,@{Name = 'Path'; Expression = { (($_.PSPath) -split 'Task Sequences\\','')[1] }}
    $AllDirectory = Get-ChildItem -Path "DeploymentShare:\Task Sequences" | Where {$_.PSIsContainer} | Select * |
        Select Name,Enable,Comments,GUID,@{Name = 'Path'; Expression = { (($_.PSPath) -split 'Task Sequences\\','')[1] }}
    #>
    Param(
        [parameter(Mandatory=$true, Position=0)]
        [string]$Path,
        [Parameter(Mandatory = $False, Position=1)]
        [switch]$Directory,
        [switch]$Recurse,
        [switch]$Passthru
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand
    Try{
        $PSDrive = Get-PSDrive ($Path -split ':\\')[0]
    }
    Catch{
        Break
    }

    If($Recurse){$RecurseBool=$true}Else{$RecurseBool=$false}
    $Param = @{
        Path = $Path;
        Recurse = $RecurseBool
    }
    #grab the root directory
    $workingPath = ($Path -split '\\')[0] + '\' + ($Path -split '\\')[1] + '\'
    $EscapePath = [System.Text.RegularExpressions.Regex]::Escape($workingPath)

    #ensure there is no leading slashes
    If($Path -match '\\$'){$Path = $Path -replace '\\$',''}

    if ($PSBoundParameters.ContainsKey('Directory')) {

        If($Passthru){
            $Content = Get-ChildItem @Param | Where {$_.PSIsContainer} | Select *
        }
        Else{
            $Content = Get-ChildItem @Param | Where {$_.PSIsContainer} |
                Select Name,Enable,Comments,GUID,@{Name = 'Path'; Expression = { (($_.PSPath) -split $EscapePath,'')[1] }}
        }

    }
    Else{

        #display content. Passthru displays all info
        If($Passthru){
            $Content = Get-ChildItem @Param | Where {$_.PSIsContainer -eq $false} | Select *
        }
        Else{
            $Content = Get-ChildItem @Param | Where {$_.PSIsContainer -eq $false} |
                Select ID,Name,Hide,Enable,Comments,GUID,@{Name = 'Path'; Expression = { (($_.PSPath) -split $EscapePath,'')[1] }}
        }

    }

    if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Populating content for PSD Drive: {0}" -f $Path)}
    return $Content
}
#endregion

#region FUNCTION: populate all time zones in dropdown
Function Add-PSDWizardComboList{
    Param(
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="source")]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="script")]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="object")]
        $InputObject,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="hashtable")]
        [hashtable]$HashTable,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="array")]
        [array]$List,
        [Parameter(Mandatory = $true, Position=1)]
        [System.Windows.Controls.ComboBox]$ListObject,
        [Parameter(Mandatory = $false, Position=2)]
        [string]$Identifier,
        [string]$PreSelect,
        [switch]$Passthru
    )

    $ListObject.Items.Clear();

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $List = (Get-PSDChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List = Invoke-command $ScriptBlock
    }
    If ($PSCmdlet.ParameterSetName -eq "object") {
        $List = $InputObject
    }

    If ($PSCmdlet.ParameterSetName -eq "hashtable") {
        Try{
            $List = $HashTable
            
            $List.keys | ForEach-Object -ErrorAction Stop {
                $ListObject.Items.Add($_) | Out-Null
            }
        }
        Catch{$_.Exception.Message}
    }
    Else{
        foreach ($item in $List){
            If($Identifier){
                $ListObject.Items.Add($item.$Identifier) | Out-Null
            }
            Else{
                $ListObject.Items.Add($item) | Out-Null
            }
        }
    }

    #select the item
    If($null -ne $PreSelect){
        $ListObject.SelectedItem = $PreSelect
    }

    If($Passthru){
        return $List
    }
}
#endregion

#region FUNCTION: populate list in wizard
Function Add-PSDWizardList{
    Param(
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="source")]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="script")]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory = $true, Position=1)]
        [System.Windows.Controls.ListBox]$ListObject,
        [Parameter(Mandatory = $false, Position=2)]
        [string]$Identifier,
        [string]$Exclude,
        [switch]$Passthru
    )

    If($null -eq $Identifier){$Identifier = ''}

    #$SourcePath="DeploymentShare:\Applications";$ListObject=$_appTabList;$Exclude="Bundles";$Identifier="Name"
    If($PSBoundParameters.ContainsKey('Exclude')){
        [scriptblock]$ExcludeItemFilter = {$_.$Identifier -NotLike "*$Exclude*"}
    }Else{
        [scriptblock]$ExcludeItemFilter = {$_.$Identifier -like '*'}
    }

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $List = (Get-PSDChildItem -Path $SourcePath -Recurse) | Where -FilterScript $ExcludeItemFilter
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List = Invoke-command $ScriptBlock | Where -FilterScript $ExcludeItemFilter
    }

    $ListObject.Items.Clear();

    foreach ($item in $List)
    {
        #Check to see if propertiues exists
        If($item.PSobject.Properties.Name.Contains($Identifier)){
            $ListObject.Items.Add($item.$Identifier) | Out-Null
        }
        Else{
            $ListObject.Items.Add($item) | Out-Null
        }
    }

    If($Passthru){
        return $List
    }
}
#endregion


#region FUNCTION: populate list in wizard
# TESTS $ListObject=$_depTabProfiles
Function Add-PSDWizardProfiles{
    Param(
        [Parameter(Mandatory = $false)]
        [string]$SourcePath = "DeploymentShare:\Selection Profiles",
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$ListObject,
        [string]$Filter = 'Deployment',
        [switch]$Passthru
    )

    $ListObject.Items.Clear();

    $List = Get-PSDChildItem -Path $SourcePath | Where {$_.Name -like "$Filter*" -and $_.enable -eq $True}


    foreach ($item in $List){
        $TrimName = ($item.Name).split('-')[1].Trim()
        $ListObject.Items.Add($TrimName) | Out-Null
    }

    If($Passthru){
        return $List
    }
}
#endregion

Function Add-PSDWizardBundles{
    Param(
        [Parameter(Mandatory = $false)]
        [string]$SourcePath = "DeploymentShare:\Applications",
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ComboBox]$ListObject,
        [switch]$ClearFirst,
        [switch]$Passthru
    )

    If($ClearFirst){
        $ListObject.Items.Clear();
    }

    $List = Get-PSDChildItem -Path $SourcePath -Recurse | Where {$_.Name -like "*Bundles*" -and $_.enable -eq $True}

    foreach ($item in $List){
        $ListObject.Items.Add($item.Name) | Out-Null
    }

    If($Passthru){
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
Function Search-PSDWizardList{
    Param(
        [Parameter(Mandatory = $true,ParameterSetName="source")]
        [string]$SourcePath,
        [Parameter(Mandatory = $true,ParameterSetName="script")]
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
        $List = (Get-PSDChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List = Invoke-command $ScriptBlock
    }

    If($PSBoundParameters.ContainsKey('IncludeAll')){
        [scriptblock]$IncludeFolderFilter = {$_.Name -Like "*"}
        [scriptblock]$IncludeItemFilter = {$_.Name -Like "*"}
    }Else{
        [scriptblock]$IncludeFolderFilter = {$_.enable -eq $True}
        [scriptblock]$IncludeItemFilter = {($_.enable -eq $True) -and ( ($_.hide -eq $False) -or ([string]::IsNullOrEmpty($_.hide)) )}
    }

    $ListObject.Items.Clear();

    foreach ($item in ($List | Where-Object -FilterScript $IncludeItemFilter | Where-Object { $_.$Identifier -like "*$Filter*" })){
        #only include what items exist in either in the folders collected initially or root locations
        $ListObject.Tag = @($item.Name,$item.Path,$item.Guid)
        $ListObject.Items.Add($item.$Identifier) | Out-Null
    }
}
#endregion

#region FUNCTION: Checks to see if there are applications present
Function IsThereAtLeastOneApplicationPresent{
    $apps = Get-PSDChildItem -Path "DeploymentShare:\Applications" -Recurse
    If($apps.count -gt 1){return $true}Else{return $false}
}
#endregion


#region FUNCTION: Populate treeview with first level folder and files
Function Add-PSDWizardTree{
    Param(
        [parameter(Mandatory=$true, Position=0)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position=1)]
        [System.Windows.Controls.TreeView]$TreeObject,
        [Parameter(Mandatory = $true, Position=2)]
        [string]$Identifier,
        [switch]$IncludeAll
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If($PSBoundParameters.ContainsKey('IncludeAll')){
        [int32]$ShowAll = 1
        [scriptblock]$IncludeFolderFilter = {$_.Name -Like "*"}
        [scriptblock]$IncludeItemFilter = {$_.Name -Like "*"}
    }Else{
        [int32]$ShowAll = 0
        [scriptblock]$IncludeFolderFilter = {$_.enable -eq $True}
        [scriptblock]$IncludeItemFilter = {($_.enable -eq $True) -and ( ($_.hide -eq $False) -or ([string]::IsNullOrEmpty($_.hide)) )}
    }
    #Write-host ("Including all root items? {0} using filter: [{1}]" -f $ShowAll,$IncludeItemFilter.ToString())

    $TreeObject.Items.Clear();
    $dummyNode = $null
    # ================== Handle FIRST LEVEL Folders ===========================
    # TEST: foreach ($folder in (Get-PSDChildItem -Path "DeploymentShare:\Task Sequences" -Directory | Where -FilterScript $IncludeFilter)){$folder}
    foreach ($folder in (Get-PSDChildItem -Path $SourcePath -Directory | Where -FilterScript $IncludeFolderFilter)){

        $treeViewFolder = [Windows.Controls.TreeViewItem]::new()
        $treeViewFolder.Header = $folder.Name
        $treeViewFolder.Tag = @($folder.Path,$SourcePath,$Identifier,$ShowAll)
        $treeViewFolder.Items.Add($dummyNode) | Out-Null

        #Does not take values from param, add to tag.
        $treeViewFolder.Add_Expanded({
            #Write-Host ("Expanded [" + $_.OriginalSource.Header + "] from [" + $_.OriginalSource.Tag[0].ToString() + "]")
            Expand-PSDWizardTree -SourcePath $_.OriginalSource.Tag[1].ToString() `
                                 -TreeItem $_.OriginalSource `
                                 -Identifier $_.OriginalSource.Tag[2].ToString() `
                                 -IncludeAll $_.OriginalSource.Tag[3]
        })
        $TreeObject.Items.Add($treeViewFolder)| Out-Null
    }

    # ================== Handle FIRST LEVEL Files ===========================
    # TEST: foreach ($item in (Get-PSDChildItem -Path "DeploymentShare:\Task Sequences" | Where -FilterScript $IncludeItemFilter)){$item}
    foreach ($item in (Get-PSDChildItem -Path $SourcePath | Where -FilterScript $IncludeItemFilter)){
        #write-host ("Found item --> id:{0},Name:{1},enable:{2},hide:{3}" -f $item.id,$item.Name,$item.enable,$item.hide)
        $treeViewItem = [Windows.Controls.TreeViewItem]::new()
        $treeViewItem.Header = $item.Name
        $FolderPath = Split-Path $item.Path -Parent
        $treeViewItem.Tag = @($FolderPath,$item.Name,$item.$Identifier,$item.Comments,$item.guid)
        #$treeViewItem.Tag = @($item.Path,$item.$Identifier)
        $TreeObject.Items.Add($treeViewItem)| Out-Null

        $treeViewItem.Add_PreviewMouseLeftButtonDown({
            [System.Windows.Controls.TreeViewItem]$sender = $args[0]
            [System.Windows.RoutedEventArgs]$e = $args[1]
            $message = ("Selected: [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[0].ToString() + "\" + $sender.Tag[1].ToString() +"]")
            if($PSDDeBug -eq $true){Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $message"}
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
Function Expand-PSDWizardTree{
    Param(
        [parameter(Mandatory=$true, Position=0)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position=1)]
        [Windows.Controls.TreeViewItem]$TreeItem,
        [Parameter(Mandatory = $true, Position=2)]
        [string]$Identifier,
        $IncludeAll = $false
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If($IncludeAll -eq $True){
        [int32]$ShowAll = 1
        [scriptblock]$IncludeFolderFilter = {$_.Name -Like "*"}
        [scriptblock]$IncludeItemFilter = {$_.Name -Like "*"}
    }
    Else{
        [int32]$ShowAll = 0
        [scriptblock]$IncludeFolderFilter = {$_.enable -eq $True}
        [scriptblock]$IncludeItemFilter = {($_.enable -eq $True) -and ( ($_.hide -eq $False) -or ([string]::IsNullOrEmpty($_.hide)) )}
    }

    #Write-host ("Including all items: {0}; Filter {1}" -f $ShowAll,$IncludeItemFilter.ToString())

    $dummyNode = $null
    If ($TreeItem.Items.Count -eq 1 -and $TreeItem.Items[0] -eq $dummyNode)
    {
        $TreeItem.Items.Clear();
        Try
        {
            # TEST: foreach ($folder in (Get-PSDChildItem -Path "DeploymentShare:\Task Sequences\Servers" -Directory | Where -FilterScript $IncludeItemFilter )){$folder}
            #drill into subfolders. $TreeItem.Tag[0] comes from Tag in Root folders
            foreach ($folder in ( Get-PSDChildItem -Path ($SourcePath + '\' + $TreeItem.Tag[0].ToString()) -Directory | Where -FilterScript $IncludeFolderFilter) ){
                $subFolder = [Windows.Controls.TreeViewItem]::new();
                $subFolder.Header = $folder.Name
                $subFolder.Tag = @($folder.Path,$SourcePath,$Identifier,$ShowAll)
                $subFolder.Items.Add($dummyNode)

                #must use tag to pass variables to Add_expanded
                $subFolder.Add_Expanded({
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
            # TEST: foreach ($item in (Get-PSDChildItem -Path "DeploymentShare:\Task Sequences\Servers" | Where -FilterScript $IncludeItemFilter)){$item}
            # TEST: foreach ($item in (Get-PSDChildItem -Path "DeploymentShare:\Task Sequences\Workstations" | Where -FilterScript $IncludeItemFilter)){$item}
            #(Get-PSDChildItem -Path "DeploymentShare:\Task Sequences\VRA\Server" | Where {[string]::IsNullOrEmpty($_.hide) -or ($_.hide -eq $False)})
            #[Boolean]::Parse((Get-PSDChildItem -Path "DeploymentShare:\Task Sequences\Servers" | Select -First 1 | Select -ExpandProperty Hide)) -eq 'True'

            foreach ($item in (Get-PSDChildItem -Path ($SourcePath + '\' + $TreeItem.Tag[0].ToString()) | Where -FilterScript $IncludeItemFilter) ){
                #write-host ("Found item --> id:{0},Name:{1},enable:{2},hide:{3}" -f $item.id,$item.Name,$item.enable,$item.hide)
                $subitem = [Windows.Controls.TreeViewItem]::new()
                $subitem.Header = $item.Name
                $FolderPath = Split-Path $item.Path -Parent
                $subitem.Tag = @($FolderPath,$item.Name,$item.$Identifier,$item.Comments,$item.guid)
                #$subitem.Tag = @($item.Path,$item.$Identifier)
                $TreeItem.Items.Add($subitem)| Out-Null

                $subitem.Add_PreviewMouseLeftButtonDown({
		            [System.Windows.Controls.TreeViewItem]$sender = $args[0]
		            [System.Windows.RoutedEventArgs]$e = $args[1]
		                $message = ("Selected: [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[0].ToString() + "\" + $sender.Tag[1].ToString() +"]")
                        if($PSDDeBug -eq $true){Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $message"}
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
Function Search-PSDWizardTree{
    Param(
        [parameter(Mandatory=$true, Position=0)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position=1)]
        [System.Windows.Controls.TreeView]$TreeObject,
        [Parameter(Mandatory = $true, Position=2)]
        [string]$Identifier,
        [Parameter(Mandatory = $true, Position=3)]
        [string]$Filter,
        [switch]$IncludeAll
    )

    If($PSBoundParameters.ContainsKey('IncludeAll')){
        [scriptblock]$IncludeFolderFilter = {$_.Name -Like "*"}
        [scriptblock]$IncludeItemFilter = {$_.Name -Like "*"}
    }Else{
        [scriptblock]$IncludeFolderFilter = {$_.enable -eq $True}
        [scriptblock]$IncludeItemFilter = {($_.enable -eq $True) -and ( ($_.hide -eq $False) -or ([string]::IsNullOrEmpty($_.hide)) )}
    }

    $TreeObject.Items.Clear();

    # Grab all folders
    $FolderCollection = @()
    foreach ($folder in ( Get-PSDChildItem -Path $SourcePath -Recurse -Directory | Where -FilterScript $IncludeFolderFilter) ){
        #collect all folders based on filter into an array
        If($folder.Path -notin $FolderCollection){$FolderCollection += $folder.Path}
    }

    # Each item must exist in folder path and match filter.
    # TEST: foreach ($item in (Get-PSDChildItem -Path "DeploymentShare:\Task Sequences" -Recurse | Where-Object { (Split-Path $_.Path -Parent) -in $FolderCollection} | Where -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*Server*" })){$item}
    # TEST: foreach ($item in (Get-PSDChildItem -Path "DeploymentShare:\Task Sequences" -Recurse | Where-Object { (Split-Path $_.Path -Parent) -in $FolderCollection} | Where -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*Windows*" })){$item}
    foreach ($item in (Get-PSDChildItem -Path $SourcePath -Recurse | Where-Object -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*$Filter*" })){
        #only include what items exist in either in the folders collected initially or root locations
        If( (($item.Path -match '\\') -and ((Split-Path $item.Path -Parent) -in $FolderCollection)) -or ($item.Path -notmatch '\\') )
        {

            $treeViewItem = [Windows.Controls.TreeViewItem]::new()
            $treeViewItem.Header = $item.Name
            $FolderPath = Split-Path $item.Path -Parent
            $treeViewItem.Tag = @($FolderPath,$item.Name,$item.$Identifier,$item.Comments,$item.guid)
            $TreeObject.Items.Add($treeViewItem)| Out-Null

            $treeViewItem.Add_PreviewMouseLeftButtonDown({
                [System.Windows.Controls.TreeViewItem]$sender = $args[0]
                [System.Windows.RoutedEventArgs]$e = $args[1]
                Write-Host ("Selected: [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[0].ToString() + "\" + $sender.Tag[1].ToString() +"]")
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
}
#endregion


#region FUNCTION: Get all selection applications
Function Get-SelectedApplications{
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
    $AllApps = Get-PSDChildItem -Path "DeploymentShare:\Applications" -Recurse

    #TEST $InputObject=$apps;$property='Value';$FieldObject=$_appTabList
    $DefaultAppList = $InputObject | Where {($_.Name -notlike 'Skip*') -and ($_.Name -notlike '*Codes') -and -not([string]::IsNullOrEmpty($_.Value))}
    $AppGuids = $DefaultAppList.Value | select -Unique

    #Set an emptry valus if not specified
    If($null -eq $Identifier){$Identifier = ''}

    $SelectedGuids = @()
    Foreach($AppGuid in $AppGuids)
    {
        $AppInfo = $AllApps | Where {$_.Guid -eq $AppGuid}
        #collect GUIDs (for Passthru output)
        $SelectedGuids += $AppGuid

        #Check if property exists
        If($AppInfo.PSobject.Properties.Name.Contains($Identifier)){
            $FieldObject.SelectedItems.Add($AppInfo.$Identifier);
        }
        Else{
            $FieldObject.SelectedItems.Add($AppInfo) | Out-Null
        }
    }

    if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Preselected [(0)] applications" -f $SelectedGuids.count)}
    If($Passthru){
        return ($SelectedGuids -join ',')
    }
}
#endregion

Function Set-SelectedApplications{
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

    #Set-SelectedApplications -InputObject $AppObject -property 'Value' -Field ($Form.FindName('_appTabList')) -Tag 'guid'
    #TEST $InputObject=$SelectedApps;$FieldObject=$_appTabList
    $AllApps = Get-PSDChildItem -Path "DeploymentShare:\Applications" -Recurse

    $SelectedApps = $FieldObject.SelectedItems

    #Get current applist
    #$CurrentAppList = $InputObject | Where {($_.Name -notlike 'Skip*') -and ($_.Name -notlike '*Codes')}
    $CurrentAppList = $InputObject | Where {($_.Name -notlike 'Skip*') -and ($_.Name -notlike '*Codes') -and -not([string]::IsNullOrEmpty($_.Value))}
    #TODO: remove apps from list and rebuild

    $i=1
    $SelectedGuids = @()
    Foreach($App in $SelectedApps)
    {
        [string]$NumPad = "{0:d3}" -f [int]$i

        $AppInfo = $AllApps | Where {$_.Name -eq $App}
        #collect GUIDs (for Passthru output)
        $SelectedGuids += $AppInfo.Guid

        If($AppInfo.Guid -in $CurrentAppList.Guid){
            #TODO: get name to determine what is the next app number?
        }Else{
            Set-TSItem ("Applications" + $NumPad) -Value $AppInfo.Guid
        }
        $i++
    }

    #Write-PSDLog -Message "Selected [$($InputObject.count)] Applications" -LogLevel 1
    if($PSDDeBug -eq $true){Write-PSDLog -Message ("$($MyInvocation.MyCommand.Name): Set [(0)] applications to install" -f $SelectedGuids.count)}
    If($Passthru){
        return ($SelectedGuids -join ',')
    }
}

$TimeZoneNameTable = @{
    '(UTC) Casablanca' = "Morocco Standard Time"
    '(UTC) Coordinated Universal Time' = "Coordinated Universal Time"
    '(UTC) Dublin, Edinburgh, Lisbon, London' = "GMT Standard Time"
    '(UTC) Monrovia, Reykjavik' = "Greenwich Standard Time"
    '(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna' = "W. Europe Standard Time"
    '(UTC+01:00) Belgrade, Bratislava, Budapest, Ljubljana, Prague' = "Central Europe Standard Time"
    '(UTC+01:00) Brussels, Copenhagen, Madrid, Paris' = "Romance Standard Time"
    '(UTC+01:00) Sarajevo, Skopje, Warsaw, Zagreb' = "Central European Standard Time"
    '(UTC+01:00) West Central Africa' = "W. Central Africa Standard Time"
    '(UTC+01:00) Windhoek' = "Namibia Standard Time"
    '(UTC+02:00) Amman' = "Jordan Standard Time"
    '(UTC+02:00) Athens, Bucharest' = "GTB Standard Time"
    '(UTC+02:00) Beirut' = "Middle East Standard Time"
    '(UTC+02:00) Cairo' = "Egypt Standard Time"
    '(UTC+02:00) Damascus' = "Syria Standard Time"
    '(UTC+02:00) E. Europe' = "E. Europe Standard Time"
    '(UTC+02:00) Harare, Pretoria' = "South Africa Standard Time"
    '(UTC+02:00) Helsinki, Kyiv, Riga, Sofia, Tallinn, Vilnius' = "FLE Standard Time"
    '(UTC+02:00) Istanbul' = "Turkey Standard Time"
    '(UTC+02:00) Jerusalem' = "Jerusalem Standard Time"
    '(UTC+02:00) Kaliningrad (RTZ 1)' = "Russia TZ 1 Standard Time"
    '(UTC+02:00) Tripoli' = "Libya Standard Time"
    '(UTC+03:00) Baghdad' = "Arabic Standard Time"
    '(UTC+03:00) Kuwait, Riyadh' = "Arab Standard Time"
    '(UTC+03:00) Minsk' = "Belarus Standard Time"
    '(UTC+03:00) Moscow, St. Petersburg, Volgograd (RTZ 2)' = "Russia TZ 2 Standard Time"
    '(UTC+03:00) Nairobi' = "E. Africa Standard Time"
    '(UTC+03:30) Tehran' = "Iran Standard Time"
    '(UTC+04:00) Abu Dhabi, Muscat' = "Arabian Standard Time"
    '(UTC+04:00) Baku' = "Azerbaijan Standard Time"
    '(UTC+04:00) Izhevsk, Samara (RTZ 3)' = "Russia TZ 3 Standard Time"
    '(UTC+04:00) Port Louis' = "Mauritius Standard Time"
    '(UTC+04:00) Tbilisi' = "Georgian Standard Time"
    '(UTC+04:00) Yerevan' = "Caucasus Standard Time"
    '(UTC+04:30) Kabul' = "Afghanistan Standard Time"
    '(UTC+05:00) Ashgabat, Tashkent' = "West Asia Standard Time"
    '(UTC+05:00) Ekaterinburg (RTZ 4)' = "Russia TZ 4 Standard Time"
    '(UTC+05:00) Islamabad, Karachi' = "Pakistan Standard Time"
    '(UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi' = "India Standard Time"
    '(UTC+05:30) Sri Jayawardenepura' = "Sri Lanka Standard Time"
    '(UTC+05:45) Kathmandu' = "Nepal Standard Time"
    '(UTC+06:00) Astana' = "Central Asia Standard Time"
    '(UTC+06:00) Dhaka' = "Bangladesh Standard Time"
    '(UTC+06:00) Novosibirsk (RTZ 5)' = "Russia TZ 5 Standard Time"
    '(UTC+06:30) Yangon (Rangoon)' = "Myanmar Standard Time"
    '(UTC+07:00) Bangkok, Hanoi, Jakarta' = "SE Asia Standard Time"
    '(UTC+07:00) Krasnoyarsk (RTZ 6)' = "Russia TZ 6 Standard Time"
    '(UTC+08:00) Beijing, Chongqing, Hong Kong, Urumqi' = "China Standard Time"
    '(UTC+08:00) Irkutsk (RTZ 7)' = "Russia TZ 7 Standard Time"
    '(UTC+08:00) Kuala Lumpur, Singapore' = "Malay Peninsula Standard Time"
    '(UTC+08:00) Perth' = "W. Australia Standard Time"
    '(UTC+08:00) Taipei' = "Taipei Standard Time"
    '(UTC+08:00) Ulaanbaatar' = "Ulaanbaatar Standard Time"
    '(UTC+09:00) Osaka, Sapporo, Tokyo' = "Tokyo Standard Time"
    '(UTC+09:00) Seoul' = "Korea Standard Time"
    '(UTC+09:00) Yakutsk (RTZ 8)' = "Russia TZ 8 Standard Time"
    '(UTC+09:30) Adelaide' = "Cen. Australia Standard Time"
    '(UTC+09:30) Darwin' = "AUS Central Standard Time"
    '(UTC+10:00) Brisbane' = "E. Australia Standard Time"
    '(UTC+10:00) Canberra, Melbourne, Sydney' = "AUS Eastern Standard Time"
    '(UTC+10:00) Guam, Port Moresby' = "West Pacific Standard Time"
    '(UTC+10:00) Hobart' = "Tasmania Standard Time"
    '(UTC+10:00) Magadan' = "Magadan Standard Time"
    '(UTC+10:00) Vladivostok, Magadan (RTZ 9)' = "Russia TZ 9 Standard Time"
    '(UTC+11:00) Chokurdakh (RTZ 10)' = "Russia TZ 10 Standard Time"
    '(UTC+11:00) Solomon Is., New Caledonia' = "Central Pacific Standard Time"
    '(UTC+12:00) Anadyr, Petropavlovsk-Kamchatsky (RTZ 11)' = "Russia TZ 11 Standard Time"
    '(UTC+12:00) Auckland, Wellington' = "New Zealand Standard Time"
    '(UTC+12:00) Coordinated Universal Time+12' = "UTC+12"
    '(UTC+12:00) Fiji' = "Fiji Standard Time"
    '(UTC+12:00) Petropavlovsk-Kamchatsky - Old' = "Kamchatka Standard Time"
    '(UTC+13:00) Nuku alofa' = "Tonga Standard Time"
    '(UTC+13:00) Samoa' = "Samoa Standard Time"
    '(UTC+14:00) Kiritimati Island' = "Line Islands Standard Time"
    '(UTC-12:00) International Date Line West' = "Dateline Standard Time"
    '(UTC-11:00) Coordinated Universal Time-11' = "UTC-11"
    '(UTC-10:00) Hawaii' = "Hawaiian Standard Time"
    '(UTC-09:00) Alaska' = "Alaskan Standard Time"
    '(UTC-08:00) Baja California' = "Pacific Standard Time (Mexico)"
    '(UTC-08:00) Pacific Time (US + Canada)' = "Pacific Standard Time"
    '(UTC-07:00) Arizona' = "US Mountain Standard Time"
    '(UTC-07:00) Chihuahua, La Paz, Mazatlan' = "Mountain Standard Time (Mexico)"
    '(UTC-07:00) Mountain Time (US + Canada)' = "Mountain Standard Time"
    '(UTC-06:00) Central America' = "Central America Standard Time"
    '(UTC-06:00) Central Time (US + Canada)' = "Central Standard Time"
    '(UTC-06:00) Guadalajara, Mexico City, Monterrey' = "Central Standard Time (Mexico)"
    '(UTC-06:00) Saskatchewan' = "Canada Central Standard Time"
    '(UTC-05:00) Bogota, Lima, Quito, Rio Branco' = "SA Pacific Standard Time"
    '(UTC-05:00) Chetumal' = "Eastern Standard Time (Mexico)"
    '(UTC-05:00) Eastern Time (US + Canada)' = "Eastern Standard Time"
    '(UTC-05:00) Indiana (East)' = "US Eastern Standard Time"
    '(UTC-04:30) Caracas' = "Venezuela Standard Time"
    '(UTC-04:00) Asuncion' = "Paraguay Standard Time"
    '(UTC-04:00) Atlantic Time (Canada)' = "Atlantic Standard Time"
    '(UTC-04:00) Cuiaba' = "Central Brazilian Standard Time"
    '(UTC-04:00) Georgetown, La Paz, Manaus, San Juan' = "SA Western Standard Time"
    '(UTC-03:30) Newfoundland' = "Newfoundland Standard Time"
    '(UTC-03:00) Brasilia' = "E. South America Standard Time"
    '(UTC-03:00) Cayenne, Fortaleza' = "SA Eastern Standard Time"
    '(UTC-03:00) City of Buenos Aires' = "Argentina Standard Time"
    '(UTC-03:00) Greenland' = "Greenland Standard Time"
    '(UTC-03:00) Montevideo' = "Montevideo Standard Time"
    '(UTC-03:00) Salvador' = "Bahia Standard Time"
    '(UTC-03:00) Santiago' = "Pacific SA Standard Time"
    '(UTC-02:00) Coordinated Universal Time-02' = "UTC-02"
    '(UTC-02:00) Mid-Atlantic - Old' = "Mid-Atlantic Standard Time"
    '(UTC-01:00) Azores' = "Azores Standard Time"
    '(UTC-01:00) Cabo Verde Is.' = "Cabo Verde Standard Time"
}

$UILanguageTable = @{
    'Arabic (Saudi Arabia)' = "ar-SA"
    'Bulgarian (Bulgaria)' = "bg-BG"
    'Chinese (PRC)' = "zh-CN"
    'Chinese (Taiwan)' = "zh-TW"
    'Croatian (Croatia)' = "hr-HR"
    'Czech (Czech Republic)' = "cs-CZ"
    'Danish (Denmark)' = "da-DK"
    'Dutch (Netherlands)' = "nl-NL"
    'English (United States)' = "en-US"
    'English (United Kingdom)' = "en-GB"
    'Estonian (Estonia)' = "et-EE"
    'Finnish (Finland)' = "fi-FI"
    'French (Canada)' = "fr-CA"
    'French (France)' = "fr-FR"
    'German (Germany)' = "de-DE"
    'Greek (Greece)' = "el-GR"
    'Hebrew (Israel)' = "he-IL"
    'Hungarian (Hungary)' = "hu-HU"
    'Italian (Italy)' = "it-IT"
    'Japanese (Japan)' = "ja-JP"
    'Korean (Korea)' = "ko-KR"
    'Latvian (Latvia)' = "lv-LV"
    'Lithuanian (Lithuania)' = "lt-LT"
    'Norwegian, Bokmål (Norway)' = "nb-NO"
    'Polish (Poland)' = "pl-PL"
    'Portuguese (Brazil)' = "pt-BR"
    'Portuguese (Portugal)' = "pt-PT"
    'Romanian (Romania)' = "ro-RO"
    'Russian (Russia)' = "ru-RU"
    'Serbian (Latin, Serbia)' = "sr-Latn-RS"
    'Slovak (Slovakia)' = "sk-SK"
    'Slovenian (Slovenia)' = "sl-SI"
    'Spanish (Mexico)' = "es-MX"
    'Spanish (Spain)' = "es-ES"
    'Swedish (Sweden)' = "sv-SE"
    'Thai (Thailand)' = "th-TH"
    'Turkish (Turkey)' = "tr-TR"
    'Ukrainian (Ukraine)' = "uk-UA"
}

$SystemLocaleTable = @{
    'Arabic (Saudi Arabia)' = "ar-SA"
    'Bulgarian (Bulgaria)' = "bg-BG"
    'Chinese (PRC)' = "zh-CN"
    'Chinese (Taiwan)' = "zh-TW"
    'Croatian (Croatia)' = "hr-HR"
    'Czech (Czech Republic)' = "cs-CZ"
    'Danish (Denmark)' = "da-DK"
    'Dutch (Netherlands)' = "nl-NL"
    'English (United States)' = "en-US"
    'English (United Kingdom)' = "en-GB"
    'Estonian (Estonia)' = "et-EE"
    'Finnish (Finland)' = "fi-FI"
    'French (Canada)' = "fr-CA"
    'French (France)' = "fr-FR"
    'German (Germany)' = "de-DE"
    'Greek (Greece)' = "el-GR"
    'Hebrew (Israel)' = "he-IL"
    'Hungarian (Hungary)' = "hu-HU"
    'Italian (Italy)' = "it-IT"
    'Japanese (Japan)' = "ja-JP"
    'Korean (Korea)' = "ko-KR"
    'Latvian (Latvia)' = "lv-LV"
    'Lithuanian (Lithuania)' = "lt-LT"
    'Norwegian, Bokmål (Norway)' = "nb-NO"
    'Polish (Poland)' = "pl-PL"
    'Portuguese (Brazil)' = "pt-BR"
    'Portuguese (Portugal)' = "pt-PT"
    'Romanian (Romania)' = "ro-RO"
    'Russian (Russia)' = "ru-RU"
    'Serbian (Latin, Serbia)' = "sr-Latn-RS"
    'Slovak (Slovakia)' = "sk-SK"
    'Slovenian (Slovenia)' = "sl-SI"
    'Spanish (Mexico)' = "es-MX"
    'Spanish (Spain)' = "es-ES"
    'Swedish (Sweden)' = "sv-SE"
    'Thai (Thailand)' = "th-TH"
    'Turkish (Turkey)' = "tr-TR"
    'Ukrainian (Ukraine)' = "uk-UA"
}

$UserLocaleTable = @{
    'Arabic (Saudi Arabia)' = "ar-SA"
    'Bulgarian (Bulgaria)' = "bg-BG"
    'Chinese (PRC)' = "zh-CN"
    'Chinese (Taiwan)' = "zh-TW"
    'Croatian (Croatia)' = "hr-HR"
    'Czech (Czech Republic)' = "cs-CZ"
    'Danish (Denmark)' = "da-DK"
    'Dutch (Netherlands)' = "nl-NL"
    'English (United States)' = "en-US"
    'English (United Kingdom)' = "en-GB"
    'Estonian (Estonia)' = "et-EE"
    'Finnish (Finland)' = "fi-FI"
    'French (Canada)' = "fr-CA"
    'French (France)' = "fr-FR"
    'German (Germany)' = "de-DE"
    'Greek (Greece)' = "el-GR"
    'Hebrew (Israel)' = "he-IL"
    'Hungarian (Hungary)' = "hu-HU"
    'Italian (Italy)' = "it-IT"
    'Japanese (Japan)' = "ja-JP"
    'Korean (Korea)' = "ko-KR"
    'Latvian (Latvia)' = "lv-LV"
    'Lithuanian (Lithuania)' = "lt-LT"
    'Norwegian, Bokmål (Norway)' = "nb-NO"
    'Polish (Poland)' = "pl-PL"
    'Portuguese (Brazil)' = "pt-BR"
    'Portuguese (Portugal)' = "pt-PT"
    'Romanian (Romania)' = "ro-RO"
    'Russian (Russia)' = "ru-RU"
    'Serbian (Latin, Serbia)' = "sr-Latn-RS"
    'Slovak (Slovakia)' = "sk-SK"
    'Slovenian (Slovenia)' = "sl-SI"
    'Spanish (Mexico)' = "es-MX"
    'Spanish (Spain)' = "es-ES"
    'Swedish (Sweden)' = "sv-SE"
    'Thai (Thailand)' = "th-TH"
    'Turkish (Turkey)' = "tr-TR"
    'Ukrainian (Ukraine)' = "uk-UA"
}

$InputLocaleTable = @{
    'Arabic (Saudi Arabia)' = "ar-SA"
    'Bulgarian (Bulgaria)' = "bg-BG"
    'Chinese (PRC)' = "zh-CN"
    'Chinese (Taiwan)' = "zh-TW"
    'Croatian (Croatia)' = "hr-HR"
    'Czech (Czech Republic)' = "cs-CZ"
    'Danish (Denmark)' = "da-DK"
    'Dutch (Netherlands)' = "nl-NL"
    'English (United States)' = "en-US"
    'English (United Kingdom)' = "en-GB"
    'Estonian (Estonia)' = "et-EE"
    'Finnish (Finland)' = "fi-FI"
    'French (Canada)' = "fr-CA"
    'French (France)' = "fr-FR"
    'German (Germany)' = "de-DE"
    'Greek (Greece)' = "el-GR"
    'Hebrew (Israel)' = "he-IL"
    'Hungarian (Hungary)' = "hu-HU"
    'Italian (Italy)' = "it-IT"
    'Japanese (Japan)' = "ja-JP"
    'Korean (Korea)' = "ko-KR"
    'Latvian (Latvia)' = "lv-LV"
    'Lithuanian (Lithuania)' = "lt-LT"
    'Norwegian, Bokmål (Norway)' = "nb-NO"
    'Polish (Poland)' = "pl-PL"
    'Portuguese (Brazil)' = "pt-BR"
    'Portuguese (Portugal)' = "pt-PT"
    'Romanian (Romania)' = "ro-RO"
    'Russian (Russia)' = "ru-RU"
    'Serbian (Latin, Serbia)' = "sr-Latn-RS"
    'Slovak (Slovakia)' = "sk-SK"
    'Slovenian (Slovenia)' = "sl-SI"
    'Spanish (Mexico)' = "es-MX"
    'Spanish (Spain)' = "es-ES"
    'Swedish (Sweden)' = "sv-SE"
    'Thai (Thailand)' = "th-TH"
    'Turkish (Turkey)' = "tr-TR"
    'Ukrainian (Ukraine)' = "uk-UA"
}


