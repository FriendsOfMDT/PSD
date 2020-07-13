<#
.SYNOPSIS

.DESCRIPTION

.LINK

.NOTES
          FileName: New-PSDHydration.PS1
          Author: PSD Development Team
          Contact: @Mikael Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy
          Primary: @JordanTheItGuy 
          Created: 2019-04-23
          Modified: 2020-07-25

          Version - 0.0.0 - (2019-05-02) - Finalized functional version 1.
          Version - 0.1.0 - (2019-05-02) - Migrated code around to ask all questions at the start of the script
          Version - 0.1.1 - (2019-05-02) - Remediated bugs with reboot for IIS not processing properly
                                         - Remediated Displaying the FILE Path in the proper order for ADK content Download
                                         - Remediated Displaying the File PAth in the Proper order for the ADK PE Content Download if needed 
          Version - 0.1.2 - (2019-05-03) - Corrected spelling issue in the Get-IISInfo
          Version - 0.1.3 - (2019-05-09) - Corrected bs.ini and cs.ini
          Version - 0.1.4 - (2020-07-25) - Corrected bs.ini and cs.ini, Changed from ISO to WIM import, changed to create one task sequqnce for each imported OS.


          TODO:
               [X] Build a lab environment with a fully configured and functioanl PSDK Environment
               [] Test the process and confirm that the hydrated environment works. 

.Example
#>

[cmdletbinding()]
param(
    
)
begin
{

############################################
#Region HelperFunctions

Function Start-PSDLog{
    #Set global variable for the write-PSDInstallLog function in this session or script.
    [CmdletBinding()]
    param (
    #[ValidateScript({ Split-Path $_ -Parent | Test-Path })]
    [string]$FilePath
    )
    try{
    if(!(Split-Path $FilePath -Parent | Test-Path))
    {
            New-Item (Split-Path $FilePath -Parent) -Type Directory | Out-Null
    }
    #Confirm the provided destination for logging exists if it doesn't then create it.
    if (!(Test-Path $FilePath))
            {
                ## Create the log file destination if it doesn't exist.
                New-Item $FilePath -Type File | Out-Null
            }
            ## Set the global variable to be used as the FilePath for all subsequent write-PSDInstallLog
            ## calls in this session
            $global:ScriptLogFilePath = $FilePath
    }
    catch{
    #In event of an error write an exception
    Write-Error $_.Exception.Message
    }
}
Function Write-PSDInstallLog{
    #Write the log file if the global variable is set
        param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter()]
        [ValidateSet(1, 2, 3)]
        [string]$LogLevel=1,
        [Parameter(Mandatory = $false)]
        [bool]$writetoscreen = $true   
    )
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
    $Line = $Line -f $LineFormat
    [system.GC]::Collect()
    Add-Content -Value $Line -Path $global:ScriptLogFilePath
    if($writetoscreen)
    {
        switch ($LogLevel)
        {
            '1'{
                Write-Verbose -Message $Message
                }
            '2'{
                Write-Warning -Message $Message
                }
            '3'{
                Write-Error -Message $Message
                }
            Default {
            }
        }
    }
}
Function set-PSDDefaultLogPath{
          #Function to set the default log path if something is put in the field then it is sent somewhere else. 
          [CmdletBinding()]
          param
          (
               [parameter(Mandatory = $false)]
               [bool]$defaultLogLocation = $true,
               [parameter(Mandatory = $false)]
               [string]$LogLocation
          )
          if($defaultLogLocation)
          {
               $LogPath = Split-Path $script:MyInvocation.MyCommand.Path
               $LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
               Start-PSDLog -FilePath $($LogPath + "\" + $LogFile)
          }
          else 
          {
               $LogPath = $LogLocation
               $LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
               Start-PSDLog -FilePath $($LogPath + "\" + $LogFile)
          }
}

#endregion HelperFunctions
############################################

############################################
#region ScriptSpecificfunctions

function Get-GuiFilePath{
    [cmdletbinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(HelpMessage ="Use this switch to choose the type of file you would like to use" , Mandatory=$true)]
        [string]$FileType,
        [Parameter(HelpMessage ="Use this switch to enable a message box explaining the prompt before hand." , Mandatory=$false , ParameterSetName = "MSGBOX")]
        [switch]$EnableMsgBox,
        [Parameter(HelpMessage ="Enter the message you would like to display before asking the user to make a selection" , ParameterSetName = "MSGBOX" , Mandatory=$true)]
        [string]$Message,
        [Parameter(HelpMessage ="Enter the title of the message you would like to display before asking the user to make a selection" , ParameterSetName= "MSGBOX" , Mandatory=$true )]
        [string]$MessageTitle
    )
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName Microsoft.VisualBasic
    $msboxReturn = [Microsoft.VisualBasic.Interaction]::MsgBox("$($Message)", "OKCancel,SystemModal,DefaultButton1", "PSD Installer Message")
    if($msboxReturn -eq "Cancel")
    {
        Write-PSDInstallLog -Message "You have chosen to cancel and not provide required information, aborting..." -LogLevel 2
        break
    }
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Filter = "$($FileType) FILE (*.$($FileType))|*.$($FileType)"}
    $FileBrowser.ShowDialog()
    Write-PSDInstallLog -Message "The file chosen for the request $($message) was $($FileBrowser.FileName)"
    return $FileBrowser
}
Function Get-PSDFolder{
    [cmdletbinding()]
    param(
    )
          [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null
          $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
          $Topmost = New-Object System.Windows.Forms.Form
          $Topmost.TopMost = $true
          $Topmost.MinimizeBox = $true
          $foldername.Description = "Select the PSDeployment Folder the name of the folder will be used for the deployment share"
          $Results = $foldername.ShowDialog($Topmost)
          if($Results -eq "OK")
          {
               Write-PSDInstallLog -Message "The folder path chosen was $($FolderName.SelectedPath)"
               return $($foldername.SelectedPath)
          }
          else 
          {
               break
          }
}

function Get-OSInfo{
    [cmdletbinding()]
    param(
        [Parameter(HelpMessage = "This Parameter sets the OS Folder Name" )]
        [string]$OSFolderName
    )
    begin
    {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
    }
    process
    {


        $objForm = New-Object System.Windows.Forms.Form 
        $objForm.Text = "PSD Hydration Image Import Info"
        $objForm.Size = New-Object System.Drawing.Size(350,150) 
        $objForm.StartPosition = "CenterScreen"

        $objForm.KeyPreview = $True
        $objForm.Add_KeyDown({
            if ($_.KeyCode -eq "Enter" -or $_.KeyCode -eq "Escape"){
                $objForm.Close()
            }
        })

        $OKButton = New-Object System.Windows.Forms.Button
        $OKButton.Location = New-Object System.Drawing.Size(10,80)
        $OKButton.Size = New-Object System.Drawing.Size(75,23)
        $OKButton.Text = "OK"
        $OKButton.Add_Click({$objForm.Close()})
        $objForm.Controls.Add($OKButton)

        $CancelButton = New-Object System.Windows.Forms.Button
        $CancelButton.Location = New-Object System.Drawing.Size(250,80)
        $CancelButton.Size = New-Object System.Drawing.Size(75,23)
        $CancelButton.Text = "Cancel"
        $CancelButton.Add_Click({$objForm.Close()})
        $objForm.Controls.Add($CancelButton)

        $objLabel = New-Object System.Windows.Forms.Label
        $objLabel.Location = New-Object System.Drawing.Size(10,20) 
        $objLabel.Size = New-Object System.Drawing.Size(315,20) 
        $objLabel.Text = "Destination directory name (OS Folder Name):"
        $objForm.Controls.Add($objLabel)

        $objTextBox = New-Object System.Windows.Forms.TextBox 
        $objTextBox.Location = New-Object System.Drawing.Size(10,40) 
        $objTextBox.Size = New-Object System.Drawing.Size(315,20) 
        $objTextBox.Text = $OSFolderName
        $objForm.Controls.Add($objTextBox) 

        $objForm.Topmost = $True

        $objForm.Add_Shown({$objForm.Activate()})
        [void]$objForm.ShowDialog()

        $Hash = @{
            OSFolderName = $objTextBox.Text
        }
        $Object = New-Object -TypeName psobject -Property $Hash
        return $Object
    }
}

function Get-UserNamePassword{
    [cmdletbinding()]
    param(
    )
    begin
    {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
    }

    process
    {
        $objForm = New-Object System.Windows.Forms.Form 
        $objForm.Text = "PSD Hydration MDT Share and INI Info"
        $objForm.Size = New-Object System.Drawing.Size(350,240) 
        $objForm.StartPosition = "CenterScreen"

        $objForm.KeyPreview = $True
        $objForm.Add_KeyDown({
            if ($_.KeyCode -eq "Enter" -or $_.KeyCode -eq "Escape"){
                $objForm.Close()
            }
        })

        $OKButton = New-Object System.Windows.Forms.Button
        $OKButton.Location = New-Object System.Drawing.Size(10,170)
        $OKButton.Size = New-Object System.Drawing.Size(75,23)
        $OKButton.Text = "OK"
        $OKButton.Add_Click({
            $objForm.DialogResult = "OK"
            $objForm.Close()
        })
        $objForm.Controls.Add($OKButton)

        $CancelButton = New-Object System.Windows.Forms.Button
        $CancelButton.Location = New-Object System.Drawing.Size(250,170)
        $CancelButton.Size = New-Object System.Drawing.Size(75,23)
        $CancelButton.Text = "Cancel"
        $CancelButton.Add_Click({$objForm.Close()})
        $objForm.Controls.Add($CancelButton)

        ###Field 1###
        $objLabel = New-Object System.Windows.Forms.Label
        $objLabel.Location = New-Object System.Drawing.Size(10,20) 
        $objLabel.Size = New-Object System.Drawing.Size(315,20) 
        $objLabel.Text = "Please Enter a User Name with Access to the Share"
        $objForm.Controls.Add($objLabel) 

        $objTextBox = New-Object System.Windows.Forms.TextBox 
        $objTextBox.Location = New-Object System.Drawing.Size(10,40) 
        $objTextBox.Size = New-Object System.Drawing.Size(315,20)
        #If you want to default this to something replace the text with your default
        $objTextBox.Text = "BuildAccountName"
        $objForm.Controls.Add($objTextBox) 

        ###Field 2###
        $objLabel2 = New-Object System.Windows.Forms.Label
        $objLabel2.Location = New-Object System.Drawing.Size(10,70) 
        $objLabel2.Size = New-Object System.Drawing.Size(315,20) 
        $objLabel2.Text = "Please enter the password"
        $objForm.Controls.Add($objLabel2)

        $objTextBox2 = New-Object System.Windows.Forms.TextBox 
        $objTextBox2.Location = New-Object System.Drawing.Size(10,90) 
        $objTextBox2.Size = New-Object System.Drawing.Size(315,20) 
        $objTextBox2.PasswordChar = '*'
        $objForm.Controls.Add($objTextBox2)

        ###Field 2###
        $objLabel3 = New-Object System.Windows.Forms.Label
        $objLabel3.Location = New-Object System.Drawing.Size(10,120) 
        $objLabel3.Size = New-Object System.Drawing.Size(315,20) 
        $objLabel3.Text = "Please enter the domain or machine name"
        $objForm.Controls.Add($objLabel3)

        $objTextBox3 = New-Object System.Windows.Forms.TextBox 
        $objTextBox3.Location = New-Object System.Drawing.Size(10,140) 
        $objTextBox3.Size = New-Object System.Drawing.Size(315,20) 
        $objForm.Controls.Add($objTextBox3)
    

        $objForm.Topmost = $True

        $objForm.Add_Shown({$objForm.Activate()})
        [void]$objForm.ShowDialog()
    


        $Hash = @{
            UserName = $objTextBox.Text
            Password = (Convertto-SecureString $objTextBox2.Text -AsPlainText -Force)
            MachineorDomain = $objTextBox3.Text
        }
        $Object = New-Object -TypeName psobject -Property $Hash
        return $Object
    }
}
function Get-PSDVirtualDir{
[cmdletbinding()]
param(
)
begin
{
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
}

process
{
    $objForm = New-Object System.Windows.Forms.Form 
    $objForm.Text = "PSD Hydration IIS Configure"
    $objForm.Size = New-Object System.Drawing.Size(350,150) 
    $objForm.StartPosition = "CenterScreen"

    $objForm.KeyPreview = $True
    $objForm.Add_KeyDown({
        if ($_.KeyCode -eq "Enter" -or $_.KeyCode -eq "Escape"){
            $objForm.Close()
        }
    })

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Size(10,80)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.Add_Click({
        $objForm.DialogResult = "OK"
        $objForm.Close()
    })
    $objForm.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Size(250,80)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.Add_Click({$objForm.Close()})
    $objForm.Controls.Add($CancelButton)

    ###Field 1###
    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(10,20) 
    $objLabel.Size = New-Object System.Drawing.Size(315,20) 
    $objLabel.Text = "Please enter the the virtual directory Name"
    $objForm.Controls.Add($objLabel) 

    $objTextBox = New-Object System.Windows.Forms.TextBox 
    $objTextBox.Location = New-Object System.Drawing.Size(10,40) 
    $objTextBox.Size = New-Object System.Drawing.Size(315,20)
    #If you want to default this to something replace the text with your default
    $objTextBox.Text = "PSDProduction"
    $objForm.Controls.Add($objTextBox) 

    $objForm.Topmost = $True

    $objForm.Add_Shown({$objForm.Activate()})
    [void]$objForm.ShowDialog()
    
    if($objForm.DialogResult -eq "Cancel"){
        break
    }
    $Hash = @{
        SiteName = $objTextBox.Text
    }
    $Object = New-Object -TypeName psobject -Property $Hash
    return $Object
    }
}

#endregion ScriptSpecificfunctions
############################################
}
process{

    $host.PrivateData.VerboseForegroundColor = 'Cyan'

    #Start Time Calculation
	$HydrationStartTime = Get-Date

    if(!(Test-Path -Path "$($PSScriptRoot)\ExportedData.CSV" )){
        set-PSDDefaultLogPath
        Write-PSDInstallLog -Message "Now Starting the PSDHydrationKit"
        Write-PSDInstallLog -Message "Now gathering information from the end user"
        $ADKPath = Get-GuifilePath -EnableMsgBox -Message "Please select Windows ADK 10 Installer (adksetup.exe)" -MessageTitle "PSDHydration Kit Installer" -FileType "EXE"
        ############################################
        #region ADKDownloadedCheck
        $RequiredFileTest = Get-Childitem -path ((Get-Item -Path $ADKPath.FileName).Directory.FullName) -Recurse
        if(($RequiredfileTest | Where-Object {$_.Name -like "Windows Assessment Toolkit*"}).Count -ge 3)
        {
            $ADKContent = ($RequiredFileTest | Where-Object {$_.Name -Like "Windows Assessment Toolkit *"}).Directory.FullName
            ForEach($Path in $ADKContent)
            {
            $i = 0
            do
            {
                if($Path -ne $ADKContent[$i])
                {
                        $i = 41
                }
                $i++
            }
            until($ADKContent.Length -ge $i)
            }
            if($i -eq 42)
            {
                Write-PSDInstallLog -Message "ADK content files not located with the ADK installer in any logical order that can be used now breaking." -LogLevel 3
            BREAK
            }
            $ADKContentPath = $ADKContent[0]
        }
        Elseif(-not(($RequiredfileTest | Where-Object {$_.Name -like "Windows Assessment Toolkit*"}).Count -ge 3))
        {
            Write-PSDInstallLog -Message "Warning we did NOT find the files confirming with the user if they want to download the files or have them saved." -LogLevel 2
            $DownloadConfirm = [Microsoft.VisualBasic.Interaction]::MsgBox("Windows ADK 10 setup files not located with the ADK installer at $($AKDPath.FileName). Click OK to download the setup files from Microsoft.", "OKCancel,SystemModal,DefaultButton1", "PSD Installer Message")
            if($DownloadConfirm -eq "Cancel")
            {
                Write-PSDInstallLog -Message "The user voluntarily exited the program, aborting..."
                break
            }
        }
        #endregion ADKDownloadedCheck    
        ############################################

        if((Get-Item -Path $ADKPath.FileName).VersionInfo.FileVersion -ge '10.1.17763.1')
        {
            $ADKPEPath = Get-GuifilePath -EnableMsgBox -Message "Please select Windows ADK 10 WinPE Addon Installer (adkwinpesetup.exe). " -MessageTitle "PSDHydration Kit Installer" -FileType "EXE"
            ############################################
            #region ADKPEDownloadedCheck
        if($ADKPEPath)
        {
            $RequiredFileTest = Get-Childitem -path ((Get-Item -Path $ADKPEPath.FileName).Directory.FullName) -Recurse
            if(($RequiredfileTest | Where-Object {$_.Name -like "Windows PE*"}).Count -ge 3)
            {
                $ADKPEContent = ($RequiredFileTest | Where-Object {$_.Name -Like "Windows PE*"}).Directory.FullName
                ForEach($Path in $ADKPEContent)
                {
                        $i = 0
                        do
                        {
                            if($Path -ne $ADKPEContent[$i])
                            {
                                $i = 41
                            }
                            $i++
                        }
                        until($ADKPEContent.Length -ge $i)
                        }
                        if($i -eq 42)
                        {
                        Write-PSDInstallLog -Message "ADK content files not located with the ADK installer in any logical order that can be used now breaking." -LogLevel 3
                        BREAK
                        }
                            $ADKPEContentPath = $ADKPEContent[0]
            }
            Elseif(-not(($RequiredfileTest | Where-Object {$_.Name -like "Windows Assessment Toolkit*"}).Count -ge 3))
            {
                Write-PSDInstallLog -Message "Warning we did NOT find the files confirming with the user if they want to download the files or have them saved." -LogLevel 2
                $DownloadConfirm = [Microsoft.VisualBasic.Interaction]::MsgBox("ADK content files not located with the ADK installer at $($AKDPEPath.FileName). If you click OK we will download the supporting files this can be as much as 3GB of Content.", "OKCancel,SystemModal,DefaultButton1", "PSD Installer Message")
                if($DownloadConfirm -eq "Cancel")
                {
                        Write-PSDInstallLog -Message "The user voluntarily exited the program now cancelling the run"
                        break
                }
            }
        }
        #Endregion ADKPEDownloadedCheck
        ############################################
        }
        $MDTPath = Get-GuiFilePath -EnableMsgBox -Message "Please select MDT Installer (MicrosoftDeploymentToolkit_x64.msi)" -MessageTitle "PSDHydration Kit Installer" -FileType "MSI"
        $PSDInstaller = Get-GuiFilePath -EnableMsgBox -Message "Please select PSD Installer (Install-PSD.ps1)" -MessageTitle "PSDHydration Kit Installer" -FileType "PS1"
        $WIMFilePath = Get-GuiFilePath -EnableMsgBox -Message "Please select the WIM Image to import" -MessageTitle "PSDHydration Kit Installer" -FileType "WIM"
        $WimInfo = Get-WindowsImage -ImagePath $WIMFilePath.fileName
        $psDeploymentFolder = Get-PSDFolder
        $OSInfo = Get-OSInfo -OSFolderName $($WimInfo | Select-Object -First 1).ImageName
        $AccountInfo = Get-UserNamePassword
        $IISVirtualInfo = Get-PSDVirtualDir
        $IISVirtualInfo = $IISVirtualInfo.SiteName
        $psDeploymentShare = $($($($psDeploymentFolder.Split("\")))[$($psDeploymentFolder.Split("\")).length-1]) + "$"
        Write-PSDInstallLog -Message "$($ADKPath.FileName) was selected for the ADK Installer"
        if($ADKPEPath){
            Write-PSDInstallLog -Message "$($ADKPEPath.FileName) Was selected for the ADKPE Installer"
        }
        Write-PSDInstallLog -Message "$($MDTPath.FileName) Was selected for the MDT Installer"
        Write-PSDInstallLog -Message "The Folder for the PSDeployment is $($PSDeploymentFolder)"
        Write-PSDInstallLog -Message "The Share Name for the PSDeploymentShare is $($PSDeploymentShare)" 
        Write-PSDInstallLog -Message "Now installing the ADK"   
        $ADKArgument = "/Features OptionId.DeploymentTools OptionId.ImagingAndConfigurationDesigner OptionId.ICDConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"
        Write-PSDInstallLog -Message "The install string for the ADK is: $($ADKPath.FileName) $($AdKArgument)"
        $ADKProcess = Start-Process -FilePath $ADKPath.FileName -ArgumentList $ADKArgument -NoNewWindow -PassThru -Wait
        if(-not($ADKProcess.ExitCode -eq 0)){
            Write-PSDInstallLog -Message "Something went wrong during the installation of the ADK please validate what it was exit code: $($ADKProcess.ExitCode)" -LogLevel 3
            break
        }
        Write-PSDInstallLog -Message "Succesfully installed the ADK now moving on to install Windows PE add-in if needed"
        #Starting ADK PE Install IF The Path was true 
        if($ADKPEPath){
            Write-PSDInstallLog -Message "The ADKPE  IS required now starting the PE add - in Install"
            $ADKPEArgument = "/Features OptionId.WindowsPreinstallationEnvironment /norestart /quiet /ceip off"
            Write-PSDInstallLog -Message "The install string is: start-process -FilePath $($ADKPEPath.FileName) -ArgumentList $($AdKPEArgument) -NoNewWindow -PassThru -Wait"
            $ADKPEProcess = Start-Process -FilePath $ADKPEPath.FileName -ArgumentList $ADKPEArgument -NoNewWindow -PassThru -Wait
            if(-not($ADKPEProcess.ExitCode -eq 0)){
                Write-PSDInstallLog -Message "Something went wrong during the installation of the ADK please validate what it was exit code: $($ADKPEProcess.ExitCode)" -LogLevel 3
                break
            }
            Write-PSDInstallLog -Message "Succesfully installed the ADK PE Environment now moving on to install MDT"
        }
        Write-PSDInstallLog -Message "Now starting the MDT install steps"
        $MDTArgument = " /i `"$($MDTPath.FileName)`" /qb"
        $MDTProcess = Start-Process msiexec.exe -ArgumentList $MDTArgument -NoNewWindow -PassThru -Wait
        if(-not($MDTProcess.ExitCode -eq 0)){
            Write-PSDInstallLog -Message "Something went wrong during the installation of MDT please validate what it was exit code: $($MDT.Process.ExitCode)"
            break
        }
        Write-PSDInstallLog -Message "Succesfully installed MDT now extending MDT with PSD"

        # Call the right arguments depending on starting the script with -Verbose or not
        If ($VerbosePreference -eq "SilentlyCOntinue"){
            $PSDArgument = "$($PSDInstaller.FileName) -psDeploymentFolder $($psDeploymentFolder) -psDeploymentShare $($psDeploymentShare)"
        }
        Else{
            $PSDArgument = "$($PSDInstaller.FileName) -psDeploymentFolder $($psDeploymentFolder) -psDeploymentShare $($psDeploymentShare) -Verbose"
        }

        $PSDProcess = Start-Process PowerShell -ArgumentList $PSDArgument  -NoNewWindow -PassThru -Wait
        Write-PSDInstallLog -Message "The PSD Exit Code Was: $($PSDProcess.ExitCode)"
        if(-not($MDTProcess.ExitCode -eq 0)){
            break
        }
        Write-PSDInstallLog -Message "Completed installing the PSD Toolkit base structure now configuring MDT"
        Write-PSDInstallLog -Message "Now importing a non-standard module"
        Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
        Write-PSDInstallLog -Message "Now-Removing the Default MDT PowerShell Drive and provider"
        Get-PSDrive -PSProvider MDTProvider | Remove-PSDrive
        Write-PSDInstallLog -Message "Now creating the PSD PS Drive and attaching the provider"
        New-PSDrive -Name "PSD" -PSProvider MDTProvider -Root $psDeploymentFolder | Out-Null
        Write-PSDInstallLog -Message "We have now completed the BASE install now hydrating with ISO Files requesting information from user"
        Write-PSDInstallLog -Message "Collected Information from the user"
        Write-PSDInstallLog -Message "Now creating the Operating System Folder for import"
        #New-Item -path "PSD:\Operating Systems" -enable "True" -Name $($OSInfo.OSFolderName) -ItemType "folder" -Verbose
        #Write-PSDInstallLog -Message "Now mounting and generating the ISO Path at $($OSInfo.ISOLocation)"
        #$ISO = Mount-DiskImage -ImagePath $($OSInfo.ISOLocation) -PassThru
        #Write-Debug -Message "Completed the ISO Mount Step"
        #Write-PSDInstallLog -Message "Now calculating the source path for the Mounted ISO Directory"
        #Write-Debug -Message "Now attempting to source the ISO file"
        #$SourcePath = "$(($ISO | Get-Volume).DriveLetter):\"
        #Write-Debug -Message "Now Pending The import step"
        #Write-PSDInstallLog -Message "Now importing the OS using the MDT import cmdlet"
        $ImportResult = Import-MDTOperatingSystem -Path "PSD:\Operating Systems" -SourceFile "$($WIMFilePath.FileName)" -DestinationFolder "$($OSInfo.OSFolderName)"
        Write-PSDInstallLog -Message "We completed this operation with $($ImportResult)"
        #Write-PSDInstallLog -Message "Now removing the ISO image"
        #$ISO | Dismount-DiskImage
        Write-PSDInstallLog -Message "Now Generating the task sequences"
        foreach($item in $ImportResult){
                $PSDImagePath = ($item.ImageFile).Replace(".\","")
                $PSDWimInfo = Get-WindowsImage -ImagePath "$psDeploymentFolder\$PSDImagePath" -Index $item.ImageIndex
                If($PSDWimInfo.ProductType -eq "ServerNT"){
                    $Template = "PSDServer.xml"
                    $BaseID = "PSDServer"
                }
                Else{
                    $Template = "PSDClient.xml"
                    $BaseID = "PSDClient"
                }
        $Result = Import-MDTTaskSequence -Path "PSD:\Task Sequences" -Name $item.name -Template $Template -Comments "" -ID "$BaseID$($item.ImageIndex)" -Version "1.0" -OperatingSystemPath "PSD:\Operating Systems\$($item.Name)" -FullName "ViaMonstra" -OrgName "ViaMonstra" -HomePage "about:blank"
        }
          
$BSINI=@"
[Settings]
Priority=Default
Properties=PSDDeployRoots

[Default]
PSDDeployRoots=http://$($ENV:ComputerName)/$($IISVirtualInfo),\\$($ENV:ComputerName)\$($psDeploymentShare)
UserID=$($AccountInfo.UserName)
UserPassword=$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto($([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccountInfo.Password))))
UserDomain=$($AccountInfo.MachineorDomain)
"@
        Write-PSDInstallLog "Created bootstrap.ini file to variable now forcing overwrite in the PSD Generated share"
        $BSINI | Out-File -Force "\\$($ENV:ComputerName)\$($psDeploymentShare)\control\bootstrap.ini"
$CSINI=@"
[Settings]
Priority=Default
Properties=PSDDeployRoots

[Default]
OSInstall=Y
"@

        $CSINI | Out-File -Force "\\$($ENV:ComputerName)\$($psDeploymentShare)\control\CustomSettings.ini"
        Write-PSDInstallLog -Message "Created the customsettings.ini file over the top of existing files"
        Write-PSDInstallLog -Message "Now enabling monitoring on the server"
        Set-ItemProperty -Path PSD: -Name MonitorHost -Value $ENV:ComputerName
        write-PSDInstallLog -Message "Now disabling the creation of 32bit boot media"
        Set-ItemProperty -Path PSD: -Name SupportX86 -Value 'False'
        Write-PSDInstallLog -Message "Now updating the deployment share boot image"
        Update-MDTDeploymentShare -Path PSD:
        #Write-PSDInstallLog -Message "Now copying out the LiteTouch ISO"
        #Copy-Item -Path $psDeploymentFolder\boot\psdlitetouch_x64.iso -Destination $PSScriptRoot
        #"We've done everything but install IIS" | Out-File -FilePath "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).TXT"
        $ExportedInfo = @{psDeploymentFolder = $psDeploymentFolder;psVirtualDirectory = $IISVirtualInfo}
        $ExportedInfo = New-Object -TypeName psobject -Property $ExportedInfo
        Export-Csv -InputObject $ExportedInfo -Path "$($PSScriptRoot)\ExportedData.csv" -NoTypeInformation
        $InstallMonitor = Start-Process -FilePath C:\Windows\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe -ArgumentList "C:\Program Files\Microsoft Deployment Toolkit\Monitor\Microsoft.BDD.MonitorService.exe"
        Write-PSDInstallLog -Message "Made it to the IIS install and configure section."
        # Call the right arguments depending on starting the script with -Verbose or not
        If ($VerbosePreference -eq "SilentlyCOntinue"){
            $InstallIIS = Start-Process PowerShell -ArgumentList "$($PSScriptRoot | Split-Path)\Tools\New-PSDWebInstance.ps1 -StartedFromHydration" -NoNewWindow -PassThru -Wait
        }
        Else{
            $InstallIIS = Start-Process PowerShell -ArgumentList "$($PSScriptRoot | Split-Path)\Tools\New-PSDWebInstance.ps1 -StartedFromHydration -verbose" -NoNewWindow -PassThru -Wait
        }

        $HydrationEndTime = Get-Date
	    $HydrationDuration = New-TimeSpan -Start $HydrationStartTime -End $HydrationEndTime
	    Write-PSDInstallLog -Message "The Hydration script has completed running and took $($HydrationDuration.Hours) Hours and $($HydrationDuration.Minutes) Minutes and $($HydrationDuration.Seconds) seconds"

        Write-PSDInstallLog -Message "You must restart to complete the WebDAV install." -LogLevel 2
        Write-PSDInstallLog -Message "After restart, run New-PSDHydration.ps1 again to finish the configuration." -LogLevel 2
    }
    elseif ("$($PSScriptRoot)\ExportedData.CSV"){
         set-PSDDefaultLogPath
         Write-PSDInstallLog -Message "Found the ExportedData.CSV file, will continue the configuration..."
         
         $IISVirtualInfo = Import-Csv -Path "$($PSScriptRoot)\ExportedData.Csv"
        # Call the right arguments depending on starting the script with -Verbose or not
        If ($VerbosePreference -eq "SilentlyCOntinue"){
            $InstallIIS = Start-Process PowerShell -ArgumentList "$($PSScriptRoot | Split-Path)\Tools\Set-PSDWebInstance.ps1 -psVirtualDirectory $($IISVirtualInfo.psVirtualDirectory) -psDeploymentFolder $($IISVirtualInfo.psDeploymentFolder) -StartedFromHydration" -NoNewWindow -PassThru -Wait
        }
        Else{
            $InstallIIS = Start-Process PowerShell -ArgumentList "$($PSScriptRoot | Split-Path)\Tools\Set-PSDWebInstance.ps1 -psVirtualDirectory $($IISVirtualInfo.psVirtualDirectory) -psDeploymentFolder $($IISVirtualInfo.psDeploymentFolder) -StartedFromHydration -verbose" -NoNewWindow -PassThru -Wait
        }
        Write-PSDInstallLog -Message "Completed the IIS Configuration review the webinstance log for details."
        $HydrationEndTime = Get-Date
	    $HydrationDuration = New-TimeSpan -Start $HydrationStartTime -End $HydrationEndTime
	    Write-PSDInstallLog -Message "The Hydration script has completed running and took $($HydrationDuration.Hours) Hours and $($HydrationDuration.Minutes) Minutes and $($HydrationDuration.Seconds) seconds"

    }


    $host.PrivateData.VerboseForegroundColor = 'Yellow'
}

