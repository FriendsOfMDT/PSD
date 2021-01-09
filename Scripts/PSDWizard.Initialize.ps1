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
        Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy, @PowershellCrack
        Primary: @Mikael_Nystrom
        Created:
        Modified: 2020-12-28

        Version - 0.0.0 - () - Finalized functional version 1.
        Version - 0.0.1 - () - Added Get-TSItem.

        TODO:

.Example
#>
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

    If($PSBoundParameters.ContainsKey('WildCard')){
        Write-PSDLog -Message "${CmdletName} Searching OSD value for [$Name]" -LogLevel 1
        #$Value = (Get-ChildItem -Path TSEnv: | Where {$_.Name -like "*$Name*"}) | Select @param
        $Results = Get-Item TSEnv:*$Name* | Select @param
    }Else{
        Write-PSDLog -Message "${CmdletName} Grabbing OSD value for [$Name]" -LogLevel 1
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
        $Results = Get-TSItem $Name -WildCard | %{Set-Item -Path TSEnv:$_.Name @param}
        Write-PSDLog -Message "${CmdletName} Setting OSD value for names that match [$Name] to [$Value]" -LogLevel 1
    }Else{
        #$Value = (Get-ChildItem -Path TSEnv: | Where {$_.Name -eq $Name}) | Select @param
        $Results = Set-Item -Path TSEnv:$Name @param
        Write-PSDLog -Message "${CmdletName} Setting OSD value for name [$Name] to [$Value]" -LogLevel 1
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

        $message = ("index [{0}]" -f $newtab)
    }
    ElseIf($PSCmdlet.ParameterSetName -eq "name"){
        $newtab = $TabControlObject.items | Where Header -eq $name
        $newtab.IsSelected = $true

        $message = ("name [{0}]" -f $newtab.Header)
    }
}
#endregion

#region FUNCTION: Retrieve all cultures
Function Get-LocaleInfo{
    #grab all cultures
    $olderr=$ErrorActionPreference
    $ErrorActionPreference='SilentlyContinue'
    #loop through 20500 numbers to find all cultures
    $Cultures = For ($lcid=0; $lcid -lt 20500; $lcid++) {[System.Globalization.Cultureinfo]::GetCultureInfo($lcid)}
    $ErrorActionPreference=$olderr

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Populating Language list; [$($Cultures.count)] items found"
    return ($Cultures | Select -Unique | Sort DisplayName)
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
        return $Results
    }
}
#endregion


#region FUNCTION: Get index value of Timezone
Function Get-TimeZoneIndex{
    Param(
        $Data = "$DeployRoot\scripts\ListOfTimeZoneIndexes.xml",
        $TimeZone
    )

    #TEST $TimeZone = '(UTC-05:00) Eastern Time (US & Canada)'
    #TEST $index = $indexData.TimeZoneIndex.Index | Where {$_.TimeZone -like '*Eastern*'} | Select -first 1

    [xml]$IndexData = Get-Content $Data  -ErrorAction Stop
    $TotalIndex = ($indexData.TimeZoneIndex.Index).Count
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Populating TimeZone index; [$TotalIndex] items found" -loglevel 1
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
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Selected TimeZone index value [$IndexValue]"
    return $IndexValue
}
#endregion

Function Get-KeyboardLayouts{
    $results = Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Keyboard Layouts" | %{Get-ItemProperty $_.pspath} |
                        Select @{Name = 'Name';expression={$_.'Layout Text' -replace '\bUS\b','United States' -replace 'Keyboard','' }},
                        @{Name = 'KeyboardLayout';expression={($_.PSChildName).Substring($_.PSChildName.Length - 4) + ':' + $_.PSChildName}} |
                        Sort Name
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Populating Keyboard layout; [$($results.count)] items found"
    return $results
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
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Populating Keyboard layout; [$($report.count)] items found"
    return ($report | Select -Unique | Sort Name)
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

    If($null -ne $TSVariable)
    {
        $TSValue = (Get-TSItem $TSVariable -ValueOnly)
        If($Passthru){
            $Value = $Object | Where {$_.$Property -eq $TSValue}
        }Else{
            $Value = ($Object | Where {$_.$Property -eq $TSValue}).$Property
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

    If($null -ne $InputValue)
    {
        If($Property){
            $Value = ($Object | Where {$_.$Property -eq $Value}).$Property
        }Else{
            $Value = ($Object | Where {$_.Name -eq $Value}).Name
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
        [parameter(Mandatory=$True,ValueFromPipeline=$True)] [string] $Str,
        [parameter(Mandatory=$False,Position=1)]$Length
    )

    If([string]::IsNullOrEmpty($length)){[int]$length = $Str.length}Else{[int]$length = $length}

    $Str[0..($Length-1)] -join ""
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
    #>

    [Regex]::Matches($Value,'(?<=\%).*?(?=\%)') | Select -ExpandProperty Value | %{
        If( [string]::IsNullOrEmpty($_) ){
            #write-host 'Replaced: Nothing'
            [string]$Value = $Value
        }
        ElseIf($_ -match 'SERIAL'){
            #write-host 'Replaced: Serial'
            $serial = Get-TSItem SerialNumber -ValueOnly
            #check if serial is trunucated (eg. %SERIAL[6]%)
            $Length = [Regex]::Matches($_,'(?<=\[).*?(?=\])') | Select -ExpandProperty Value
            $NewSerial = $serial | Set-StringLength $Length
            [string]$Value = $Value.replace("%$_%",$NewSerial)
        }
        ElseIf($_ -match 'RAND'){
            #write-host 'Replaced: Random'
            $Length = [Regex]::Matches($_,'(?<=\[).*?(?=\])') | Select -ExpandProperty Value
            [string]$Value = $Value.replace("%$_%",(Get-RandomAlphanumericString -length $Length))
        }
        ElseIf( (Get-TSItem $_) ){
            #write-host 'Replaced:' (Get-TSItem $_ -ValueOnly)
            [string]$Value = $Value.replace("%$_%",(Get-TSItem $_ -ValueOnly))
        }
        Else{
            #write-host 'nothing:' $_
            [string]$Value = $Value
        }
    }

    return $Value

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
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Populating content for PSD Drive: $Path"
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
        [Parameter(Mandatory = $true, Position=1)]
        [System.Windows.Controls.ComboBox]$ListObject,
        [Parameter(Mandatory = $true, Position=2)]
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

    foreach ($item in $List){
        #$ListObject.Tag = @($item.$Identifier)
        $ListObject.Items.Add($item.$Identifier) | Out-Null
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


Function Add-PSDWizardProfiles{
    Param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$SourcePath = "DeploymentShare:\Selection Profiles",
        [Parameter(Mandatory = $true, Position=1)]
        [System.Windows.Controls.ComboBox]$ListObject,
        [string[]]$Exclude,
        [switch]$Passthru
    )

    $ListObject.Items.Clear();

    $List = Get-PSDChildItem -Path $SourcePath | Where {$_.Name -like "*App*" -and $_.enable -eq $True}


    foreach ($item in $List){
        $ListObject.Items.Add($item.Name) | Out-Null
    }

    If($Passthru){
        return $List
    }
}
#endregion

Function Add-PSDWizardBundles{
    Param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$SourcePath = "DeploymentShare:\Applications",
        [Parameter(Mandatory = $true, Position=1)]
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
Function Search-PSDWizardList{
    Param(
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="source")]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position=0,ParameterSetName="script")]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory = $true, Position=1)]
        [System.Windows.Controls.ListBox]$ListObject,
        [Parameter(Mandatory = $true, Position=2)]
        [string]$Identifier,
        [Parameter(Mandatory = $true, Position=3)]
        [string]$Filter
    )

    $ListObject.Items.Clear();

    If ($PSCmdlet.ParameterSetName -eq "source") {
        $List = (Get-PSDChildItem -Path $SourcePath -Recurse)
    }
    If ($PSCmdlet.ParameterSetName -eq "script") {
        $List = Invoke-command $ScriptBlock
    }

    # ================== Handle FIRST LEVEL Files ===========================
    foreach ($item in ($List  | Where-Object {$_.Name -like "*$Filter*"})){
        $ListObject.Tag = @($item.Name,$item.Path,$item.Guid)
        $ListObject.Items.Add($item) | Out-Null
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
		                Write-Host ("Selected: [" + $sender.Tag[2].ToString() + ": " + $sender.Tag[0].ToString() + "\" + $sender.Tag[1].ToString() +"]")
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

    # Grab all enabled folders
    $FolderCollection = @()
    foreach ($folder in ( Get-PSDChildItem -Path $SourcePath -Recurse -Directory | Where -FilterScript $IncludeFolderFilter) ){
        #add if folder is root path or is in the foldercollection
        #the first loops would only grab root folders (no slash) and add to collection
        #the recursive loops will see if those folders are in the root directories and add to collection
        If(($folder.Path -notmatch '\\') -or ($folder.Path -in $FolderCollection)){$FolderCollection += $folder.Path}
    }

    # Each item must exist in folder path and match filter.
    # TEST: foreach ($item in (Get-PSDChildItem -Path "DeploymentShare:\Task Sequences" -Recurse | Where-Object { (Split-Path $_.Path -Parent) -in $FolderCollection} | Where -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*Server*" })){$item}
    # TEST: foreach ($item in (Get-PSDChildItem -Path "DeploymentShare:\Task Sequences" -Recurse | Where-Object { (Split-Path $_.Path -Parent) -in $FolderCollection} | Where -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*Windows*" })){$item}
    foreach ($item in (Get-PSDChildItem -Path $SourcePath -Recurse | Where-Object { (Split-Path $_.Path -Parent) -in $FolderCollection} |
                                                                    Where-Object -FilterScript $IncludeItemFilter | Where-Object { $_.Name -like "*$Filter*" })){

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

    #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Selected [$($InputObject.count)] Applications" -LogLevel 1
    If($Passthru){
        return ($SelectedGuids -join ',')
    }
}
#endregion

#Set-SelectedApplications -InputObject $AppObject -property 'Value' -Field ($Form.FindName('_appTabList')) -Tag 'guid'
Function Set-SelectedApplications{
    Param(
        [Parameter(Mandatory = $true)]
        $FieldObject,
        [Parameter(Mandatory = $true)]
        $InputObject,
        [Parameter(Mandatory = $false)]
        [switch]$Passthru
    )
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

    #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Selected [$($InputObject.count)] Applications" -LogLevel 1
    If($Passthru){
        return ($SelectedGuids -join ',')
    }
}
