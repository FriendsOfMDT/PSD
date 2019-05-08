# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDApplyOS.ps1
# // 
# // Purpose:   Apply the specified operating system.
# // 
# // 
# // ***************************************************************************

param (

)

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module DISM
Import-Module PSDUtility
Import-Module PSDDeploymentShare

$verbosePreference = "Continue"

#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Load core modules"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $($tsenv:DeployRoot)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"

# Make sure we run at full power
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Make sure we run at full power"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Make sure we run at full power"
& powercfg.exe /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Get the OS image details
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Get the OS image details"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Get the OS image details"
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Operating system: $($tsenv:OSGUID)"
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
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Create a local scratch folder"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create a local scratch folder"
$scratchPath = "$(Get-PSDLocalDataPath)\Scratch"
Initialize-PSDFolder $scratchPath

# Apply the image
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Apply the image"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Apply the image"
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Applying image $image index $index to $($tsenv:OSVolume)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Applying image $image index $index to $($tsenv:OSVolume)"
$startTime = Get-Date
Expand-WindowsImage -ImagePath $image -Index $index -ApplyPath "$($tsenv:OSVolume):\" -ScratchDirectory $scratchPath
$duration = $(Get-Date) - $startTime
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Time to apply image: $($duration.ToString('hh\:mm\:ss'))"
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
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Make the OS bootable"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Make the OS bootable"
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Configuring volume $($tsenv:BootVolume) to boot $($tsenv:OSVolume):\Windows."
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
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Running bcdboot.exe with the following arguments: $args"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running bcdboot.exe with the following arguments: $args"

$result = Start-Process -FilePath "bcdboot.exe" -ArgumentList $args -Wait -Passthru
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): BCDBoot completed, rc = $($result.ExitCode)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): BCDBoot completed, rc = $($result.ExitCode)"

# Fix the EFI partition type
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Fix the EFI partition type if using UEFI"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Fix the EFI partition type if using UEFI"
if ($tsenv:IsUEFI -eq "True")
{
	# Fix the EFI partition type
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Fix the EFI partition type"
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