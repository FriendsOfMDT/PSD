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
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2019-05-09

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.1.0 - (2019-05-09) - Check access to image file
          Version - 0.1.1 - (2019-05-09) - Cleanup white space

          TODO:

.Example
#>

param (

)

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

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"

# Get the OS image details
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get the OS image details"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Operating system: $($tsenv:OSGUID)"
$os = Get-Item "DeploymentShare:\Operating Systems\$($tsenv:OSGUID)"
$osSource = Get-PSDContent "$($os.Source.Substring(2))"
$image = "$osSource$($os.ImageFile.Substring($os.Source.Length))"
$index = $os.ImageIndex

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): os is now $os"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): osSource is now $osSource"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): image is now $image"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): index is now $index"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Verifying access to $image"
if((Test-Path -Path $image) -ne $true)
{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to continue, could not access the WIM $image"
    Show-PSDInfo -Message "Unable to continue, could not access the WIM $image" -Severity Error
    Exit 1
}

# Create a local scratch folder
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create a local scratch folder"
$scratchPath = "$(Get-PSDLocalDataPath)\Scratch"
Initialize-PSDFolder $scratchPath

# Apply the image
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Apply the image"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Applying image $image index $index to $($tsenv:OSVolume)"
Show-PSDActionProgress -Message "Applying $($image | Split-Path -Leaf) " -Step "1" -MaxStep "2"
$startTime = Get-Date
Expand-WindowsImage -ImagePath $image -Index $index -ApplyPath "$($tsenv:OSVolume):\" -ScratchDirectory $scratchPath
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
Show-PSDActionProgress -Message "Make the OS volume bootable" -Step "2" -MaxStep "2"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Configuring volume $($tsenv:BootVolume) to boot $($tsenv:OSVolume):\Windows."
if ($tsenv:IsUEFI -eq "True")
{
    $args = @("$($tsenv:OSVolume):\Windows", "/s", "$($tsenv:BootVolume):", "/f", "uefi")
}
else 
{
    $args = @("$($tsenv:OSVolume):\Windows", "/s", "$($tsenv:BootVolume):")
}
#Added for troubleshooting (admminy)
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running bcdboot.exe with the following arguments: $args"

$result = Start-Process -FilePath "bcdboot.exe" -ArgumentList $args -Wait -Passthru
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): BCDBoot completed, rc = $($result.ExitCode)"

# Fix the EFI partition type
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Fix the EFI partition type if using UEFI"
if ($tsenv:IsUEFI -eq "True")
{
	# Fix the EFI partition type
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Fix the EFI partition type"
	@"
select volume $($tsenv:BootVolume)
set id=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
exit
"@ | diskpart
}

# Fix the recovery partition type for MBR disks, using diskpart.exe since the PowerShell cmdlets are currently missing some options (like ID for MBR disks)
if ($tsenv:IsUEFI -eq "False")
{
    # Fix the recovery partition type 
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Fix the recovery partition type"
  @"
select volume $($tsenv:RecoveryVolume)
set id=27 override
exit
"@ | diskpart
}