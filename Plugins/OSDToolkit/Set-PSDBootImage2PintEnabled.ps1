<#
.Synopsis
    This script runs when a deployment share is updated, and the completely generate boot image option is selected.
    
.Description
    This script was written by Johan Arwidmark @jarwidmark. This script is for adding 2Pint Software OSD Toolkit to the boot image WIM and/or ISO.

.LINK
    https://github.com/FriendsOfMDT/PSD

.NOTES
          FileName: Set-PSDBootImage2PintEnabled.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark
          Primary: @jarwidmark 
          Created: 2019-05-09
          Modified: 2020-07-03

          Version - 0.0.0 - () - Finalized functional version 1.

.EXAMPLE
	.\Set-PSDBootImage2PintEnabled.ps1
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
Param(
)

function Start-PSDLog{
	[CmdletBinding()]
    param (
    #[ValidateScript({ Split-Path $_ -Parent | Test-Path })]
	[string]$FilePath
 	)
    try
    	{
			if(!(Split-Path $FilePath -Parent | Test-Path))
			{
				New-Item (Split-Path $FilePath -Parent) -Type Directory | Out-Null
			}
			#Confirm the provided destination for logging exists if it doesn't then create it.
			if (!(Test-Path $FilePath)){
	    			## Create the log file destination if it doesn't exist.
                    New-Item $FilePath -Type File | Out-Null
			}
            else{
                Remove-Item -Path $FilePath -Force
            }
				## Set the global variable to be used as the FilePath for all subsequent write-PSDInstallLog
				## calls in this session
				$global:ScriptLogFilePath = $FilePath
    	}
    catch
    {
		#In event of an error write an exception
        Write-Error $_.Exception.Message
    }
}
function Write-PSDInstallLog{
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
	if($writetolistbox -eq $true)
	{
        $result1.Items.Add("$Message")
    }
}
function set-PSDDefaultLogPath{
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

# Start logging
set-PSDDefaultLogPath 

# Adjust logfile

# Check current log file, truncate if needed. Keeping it between 4000-5000 lines.
# Doing the truncate here since its the first phase that will always run
$NumberOfLines = $(Get-Content $ScriptLogFilePath | Measure-Object –Line).Lines
If ($NumberOfLines -gt 5000){
    # Truncate the file
    $TempLogFileName = $ScriptLogFilePath -replace ".log",".tmp"
    If (Test-Path -Path $TempLogFileName){
        Remove-Item $TempLogFileName -Force
    }
    Move-Item -Path $ScriptLogFilePath -Destination $TempLogFileName
    Get-Content $TempLogFileName | Select-Object -Skip 1000 | Out-File $ScriptLogFilePath
    If (Test-Path -Path $TempLogFileName){
        Remove-Item $TempLogFileName -Force
    }
}

# ----------------------------------------
# Added for OSD Toolkit from 2Pint Software
# ----------------------------------------
#
# The OSD Toolkit components will only be added if BranchCacheEnabled is set to YES in CustomSettings.ini

Write-PSDInstallLog -Message "Entering the 2Pint Software OSD Toolkit section"
Write-PSDInstallLog -Message "Current DEPLOYROOT value is $Env:DEPLOYROOT"

# Checking if BranchCacheEnabled is set to YES in CustomSettings.ini
Import-Module "$Env:DEPLOYROOT\Tools\Modules\PSDGather\PSDGather.psm1"
$RulesFile = Get-IniContent -FilePath "$Env:DEPLOYROOT\Control\CustomSettings.ini"
if(($RulesFile.Default.BranchCacheEnabled) -eq "YES"){

    Write-PSDInstallLog -Message "BranchCacheEnabled is set to YES, entering the 2Pint Software OSD Toolkit section"

    # Verify access to WinPEGen.exe, no point in continuing if OSD Toolkit is missing
    $OSDToolKitPath = "$Env:DEPLOYROOT\PSDResources\Plugins\OSDToolKit"
        Set-Location "$OSDToolKitPath\WinPE Generator\x64"
    If (!(Test-path -Path .\WinPEGen.exe)){
        Write-PSDInstallLog -Message "OSD Toolkit not found in $OSDToolKitPath folder, aborting script..." -LogLevel 2
        Exit
    }

    Write-PSDInstallLog -Message "OSD Toolkit found, setting working directory to $OSDToolKitPath\WinPE Generator\x64"

    # Wait 10 seconds for any open file handles to close
    Write-PSDInstallLog -Message "Wait 10 seconds for any open file handles to close"
    Start-Sleep -Seconds 10

    $mdtDir = $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir
    Import-Module "$($mdtDir)Bin\MicrosoftDeploymentToolkit.psd1"
    New-PSDrive -Name "PSD" -PSProvider MDTProvider -Root $Env:DEPLOYROOT
    
    # Check if there is an imported OS matching the boot image build number (ok if SP version is different)
    $BootImageBuild = (Get-WindowsImage -ImagePath "$Env:DEPLOYROOT\boot\LiteTouchPE_x64.wim" -Index 1).Build
    Write-PSDInstallLog -Message "Boot image build is $BootImageBuild"

    # Look for matching operating system on a build number level, for now assuming the first match is OK
    $MatchingOperatingSystem = (Get-ChildItem -Path "PSD:\Operating Systems" -Recurse | Where-Object NodeType -EQ OperatingSystem | Where-Object Build -Like *$BootImageBuild*) | Select-Object -First 1

    # Abort if no matching operating system was found
    If (!($MatchingOperatingSystem)){
        Write-PSDInstallLog -Message "No matching operating system found, aborting script"
        Exit
    }

    Write-PSDInstallLog -Message "Found matching OS: $($MatchingOperatingSystem.Name)"

    # Update the WIM file that gets added to the ISO file
    Write-PSDInstallLog -Message "Update the WIM file that gets added to the ISO file"
    $Windows10Media = "$Env:DEPLOYROOT\$($MatchingOperatingSystem.ImageFile.TrimStart(".\"))"
    $Windows10Index = $MatchingOperatingSystem.ImageIndex
    Write-PSDInstallLog -Message "Using Windows 10 WIM File: $Windows10Media, index: $Windows10Index"
    $BootMedia = "$Env:CONTENT"
    $BootIndex = "1"
    Write-PSDInstallLog -Message "Using Boot Image: $BootMedia, index: $BootIndex"

    $WinPEGenArgument = "`"$Windows10Media`" $Windows10Index `"$Bootmedia`" $BootIndex"
    Write-PSDInstallLog -Message "About to run: .\WinPEGen.exe $WinPEGenArgument"
    $WinPEGenResult = Start-Process .\WinPEGen.exe -ArgumentList $WinPEGenArgument -NoNewWindow -PassThru -Wait
    if($WinPEGenResult.ExitCode -eq 0){
        Write-PSDInstallLog -Message "BITS and BranchCache added successfully to the $BootMedia boot image"
    }
    Else {
        Write-PSDInstallLog -Message "BITS and BranchCache could not be added to the $BootMedia boot image. Exit code: $($WinPEGenResult.ExitCode)" -LogLevel 2
    }

    # Update the WIM file that is created directly in the deployment share boot folder
    Write-PSDInstallLog -Message "Update the WIM file that is created directly in the deployment share boot folder"
    $Windows10Media = "$Env:DEPLOYROOT\$($MatchingOperatingSystem.ImageFile.TrimStart(".\"))"
    $Windows10Index = $MatchingOperatingSystem.ImageIndex
    Write-PSDInstallLog -Message "Using Windows 10 WIM File: $Windows10Media, index: $Windows10Index"
    $BootMedia = "$Env:DEPLOYROOT\Boot\LiteTouchPE_x64.wim"
    $BootIndex = "1"
    Write-PSDInstallLog -Message "Using Boot Image: $BootMedia, index: $BootIndex"

    $WinPEGenArgument = "`"$Windows10Media`" $Windows10Index `"$Bootmedia`" $BootIndex"
    Write-PSDInstallLog -Message "About to run: .\WinPEGen.exe $WinPEGenArgument"
    $WinPEGenResult = Start-Process .\WinPEGen.exe -ArgumentList $WinPEGenArgument -NoNewWindow -PassThru -Wait
    if($WinPEGenResult.ExitCode -eq 0){
        Write-PSDInstallLog -Message "BITS and BranchCache added successfully to the $BootMedia boot image"
    }
    Else {
        Write-PSDInstallLog -Message "BITS and BranchCache could not be added to the $BootMedia boot image. Exit code: $($WinPEGenResult.ExitCode)" -LogLevel 2
    }

    # Remove the backup file that WinPEGen.exe creates
    Remove-Item "$Env:DEPLOYROOT\Boot\LiteTouchPE_x64.wim_original_backup" -Force
    
    Write-PSDInstallLog -Message "Wait 10 seconds for any open file handles to close"
    Start-Sleep -Seconds 10

    Write-PSDInstallLog -Message "Exiting the 2Pint Software OSD Toolkit section"
}
Else{
    Write-PSDInstallLog -Message "BranchCacheEnabled is not set to YES in CustomSettings.ini, skip adding the OSD ToolKit"
}