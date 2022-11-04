<#
.SYNOPSIS
    Apply the specified operating system.
.DESCRIPTION
    Apply the specified operating system.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDApplyOS.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2019-05-09

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.1.0 - (2019-05-09) - Check access to image file
          Version - 0.1.1 - (2019-05-09) - Cleanup white space
          Version - 0.1.2 - (2022-05-03) - UEFI Boot issues
          Version - 0.1.5 - (2022-06-15) - added /c to BCDBoot
          Version - 0.1.6 - (Mikael_Nystrom) (2022-06-20) - Replaced some native Posh with Diskpart wrappers, Set-PSDEFIDiskpartition and Set-PSDRecoveryPartitionForMBR
          Version - 0.1.7 - (Johan Arwidmark) (2022-10-03 - Updated BCD Refresh command


          TODO:

.Example
#>

[CmdLetBinding()]
param(
)

if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
    $VerbosePreference = "Continue"
}
Write-Verbose "Verbose is on"

# Set scriptversion for logging
$ScriptVersion = "0.1.6"

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module DISM
Import-Module PSDUtility
Import-Module PSDDeploymentShare

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true)
{
    $verbosePreference = "Continue"
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Starting: $($MyInvocation.MyCommand.Name) - Version $ScriptVersion"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): The task sequencer log is located at $("$tsenv:_SMSTSLogPath\SMSTS.LOG"). For task sequence failures, please consult this log."
Write-PSDEvent -MessageID 41000 -severity 1 -Message "Starting: $($MyInvocation.MyCommand.Name)"

# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"

# Values from TaskSequence Step
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSGUID is $($tsenv:OSGUID)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DestinationDisk is $($tsenv:DestinationDisk)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DestinationPartition is $($tsenv:DestinationPartition)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DestinationOSVariable is $($tsenv:DestinationOSVariable)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DestinationOSRefresh is $($tsenv:DestinationOSRefresh)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DestinationOSDriveLetter is $($tsenv:DestinationOSDriveLetter)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DestinationOSInstallType is $($tsenv:DestinationOSInstallType)"

# Get the OS image details
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get the OS image details"

$os = Get-Item "DeploymentShare:\Operating Systems\$($tsenv:OSGUID)"
$osSource = Get-PSDContent "$($os.Source.Substring(2))"
$image = "$osSource$($os.ImageFile.Substring($os.Source.Length))"
$index = $os.ImageIndex

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell varibale OS is $OS"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable OSSource is $osSource"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable Image is $image"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable index is $index"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Verifying access to $image"
if((Test-Path -Path $image) -ne $true)
{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to continue, could not access the WIM $image"
    Show-PSDInfo -Message "Unable to continue, could not access the WIM $image" -Severity Error
    Exit 1
}

# Create a local scratch folder
$scratchPath = "$(Get-PSDLocalDataPath)\Scratch"
Initialize-PSDFolder $scratchPath
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating $scratchPath as scratch folder"

# Apply the image
# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Apply the image"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Applying image $image index $index to $($tsenv:OSVolume)"
Show-PSDActionProgress -Message "Applying $($image | Split-Path -Leaf) " -Step "1"
$startTime = Get-Date
Expand-WindowsImage -ImagePath $image -Index $index -ApplyPath "$($tsenv:OSVolume):\" -ScratchDirectory $scratchPath -CheckIntegrity
$duration = $(Get-Date) - $startTime
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Time to apply image: $($duration.ToString('hh\:mm\:ss'))"

# Inject drivers using DISM if Setup.exe is missing
#$ImageFolder = $image | Split-Path | Split-Path
#Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Checking if Setup.exe is present in $ImageFolder"
#if(!(Test-Path -Path "$ImageFolder\Setup.exe"))
#{
#    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Could not find Setup.exe, applying Unattend.xml (Use-WindowsUnattend)"
#    if(Test-Path -Path "$($tsenv:OSVolume):\Windows\Panther\Unattend.xml")
#    {
#        Use-WindowsUnattend -Path "$($tsenv:OSVolume):\" -UnattendPath "$($tsenv:OSVolume):\Windows\Panther\Unattend.xml" -ScratchDirectory $scratchPath
#    }
#    else
#    {
#        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Could not $($tsenv:OSVolume):\Windows\Panther\Unattend.xml"
#    }
#    
#}
#else
#{
#    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Found Setup.exe, no need to apply Unattend.xml"
#}

# Make the OS bootable
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Make the OS volume bootable"
Show-PSDActionProgress -Message "Make the OS volume bootable" -Step "2"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Configuring volume $($tsenv:BootVolume) to boot $($tsenv:OSVolume):\Windows."
if ($tsenv:IsUEFI -eq "True"){
    $Arguments =  "$($tsenv:OSVolume):\Windows /s $($tsenv:BootVolume): /f uefi /c"
}
else{
    $Arguments =  "$($tsenv:OSVolume):\Windows /s $($tsenv:BootVolume): /c"
}

$Executable = "bcdboot.exe"
$result = Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running $Executable with the following arguments: $Arguments"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): BCDBoot completed, ReturnCode = $($result)"
Start-Sleep -Seconds 15

$tsenv:BootVolume | Remove-PartitionAccessPath -AccessPath "W:\" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

#if ($tsenv:IsUEFI -eq "True"){
#	# Fix the EFI partition type
#    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Fixing the EFI partition type, flipping $($tsenv:BootVolume) / Partition 1 as 'System'"
#@"
#select volume $($tsenv:BootVolume)
#select partition 1
#set id=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
#exit
#"@ | diskpart
#}

# Fix the recovery partition type for MBR disks, using diskpart.exe since the PowerShell cmdlets are currently missing some options (like ID for MBR disks)
if ($tsenv:IsUEFI -eq "False"){
    # Fix the recovery partition type 
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Fixing the recovery partition type by setting $($tsenv:RecoveryVolume) as '27'"
#  @"
#select volume $($tsenv:RecoveryVolume)
#set id=27 override
#exit
#"@ | diskpart

#Start-Sleep -Seconds 15


    Set-PSDRecoveryPartitionForMBR -Volume $($tsenv:RecoveryVolume)

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Fixing other stuff"
    $Executable = "bcdedit.exe"
    $Arguments = "/store $($tsenv:BootVolume):\boot\bcd /set `{bootmgr`} device locate"
    Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
                
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Fixing other stuff"
    $Executable = "bcdedit.exe"
    $Arguments = "/store $($tsenv:BootVolume):\boot\bcd /set `{default`} device locate"
    Invoke-PSDEXE -Executable $Executable -Arguments $Arguments

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Fixing other stuff"
    $Executable = "bcdedit.exe"
    $Arguments = "/store $($tsenv:BootVolume):\boot\bcd /set `{default`} osdevice locate"
    Invoke-PSDEXE -Executable $Executable -Arguments $Arguments
}

if ($tsenv:IsUEFI -eq "True"){
	# Fix the EFI partition type
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Fixing the EFI partition type, flipping $($tsenv:BootVolume) / Partition 1 as 'System'"
    Set-PSDEFIDiskpartition -Volume $($tsenv:BootVolume)
}

# Set marker for OSDrive detection
$Result = New-Item -Path "$($tsenv:OSVolume):\marker.PSD" -ItemType File -Force
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Created $($Result.FullName) as marker file "

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property LTIDirtyOS is true"
$tsenv:LTIDirtyOS = $true

# Start bcdedit.exe to refresh BCD entries (needed on some hardware)
Start-Sleep -Seconds 5
$Executable = "bcdedit.exe"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): About to run $Executable"
$result = Invoke-PSDEXE -Executable $Executable 
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): ReturnCode = $($result)"