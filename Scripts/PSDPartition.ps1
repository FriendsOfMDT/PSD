# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDPartition.ps1
# // 
# // Purpose:   Partition the disk
# // 
# // 
# // ***************************************************************************

param (

)

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility

$verbosePreference = "Continue"

#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Load core modules"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Load core modules"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Deployroot is now $($tsenv:DeployRoot)"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): env:PSModulePath is now $env:PSModulePath"

# Keep the logging out of the way
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Keep the logging out of the way"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Keep the logging out of the way"
$currentLocalDataPath = Get-PSDLocalDataPath
if ($currentLocalDataPath -NotLike "X:\*")
{
    Stop-PSDLogging
    $logPath = "X:\MININT\Logs"
    if ((Test-Path $logPath) -eq $false) {
        New-Item -ItemType Directory -Force -Path $logPath | Out-Null
    }
    Start-Transcript "$logPath\PSDPartition.ps1.log"
}

# Partition and format the disk
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Partition and format the disk"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Partition and format the disk"
Update-Disk -Number 0
$disk = Get-Disk -Number 0

if ($tsenv:IsUEFI -eq "True")
{
    # UEFI partitioning
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): UEFI partitioning"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): UEFI partitioning"

    # Clean the disk if it isn't raw
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Clean the disk if it isn't raw"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clean the disk if it isn't raw"
    if ($disk.PartitionStyle -ne "RAW")
    {
        #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Clearing disk"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clearing disk"
        Clear-Disk -Number 0 -RemoveData -RemoveOEM -Confirm:$false
    }

    # Initialize the disk
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Initialize the disk"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Initialize the disk"
    Initialize-Disk -Number 0 -PartitionStyle GPT
    Get-Disk -Number 0

    # Calculate the OS partition size, as we want a recovery partiton after it
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Calculate the OS partition size, as we want a recovery partiton after it"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Calculate the OS partition size, as we want a recovery partiton after it"
    $osSize = $disk.Size - 499MB - 128MB - 1024MB

    # Create the paritions
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Create the paritions"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the paritions"
    $efi = New-Partition -DiskNumber 0 -Size 499MB -AssignDriveLetter
    $msr = New-Partition -DiskNumber 0 -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    $os = New-Partition -DiskNumber 0 -Size $osSize -AssignDriveLetter
    $recovery = New-Partition -DiskNumber 0 -UseMaximumSize -AssignDriveLetter -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'

    # Save the drive letters and volume GUIDs to task sequence variables
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs to task sequence variables"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs to task sequence variables"
    $tsenv:BootVolume = $efi.DriveLetter
    $tsenv:BootVolumeGuid = $efi.Guid
    $tsenv:OSVolume = $os.DriveLetter
    $tsenv:OSVolumeGuid = $os.Guid
    $tsenv:RecoveryVolume = $recovery.DriveLetter
    $tsenv:RecoveryVolumeGuid = $recovery.Guid

    # Format the volumes
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Format the volumes"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format the volumes"
    Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem FAT32
    Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem NTFS
    Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem NTFS


}
else
{
    # Clean the disk if it isn't raw
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Clean the disk if it isn't raw"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clean the disk if it isn't raw"
    if ($disk.PartitionStyle -ne "RAW")
    {
        #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Clearing disk"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clearing disk"
        Clear-Disk -Number 0 -RemoveData -RemoveOEM -Confirm:$false
    }

    # Initialize the disk
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Initialize the disk"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Initialize the disk"
    Initialize-Disk -Number 0 -PartitionStyle MBR
    Get-Disk -Number 0

    # Calculate the OS partition size, as we want a recovery partiton after it
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Calculate the OS partition size, as we want a recovery partiton after it"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Calculate the OS partition size, as we want a recovery partiton after it"
    $osSize = $disk.Size - 499MB - 1024MB

    # Create the paritions
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Create the partitions"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partitions"
    $boot = New-Partition -DiskNumber 0 -Size 499MB -AssignDriveLetter -IsActive
    $os = New-Partition -DiskNumber 0 -Size $osSize -AssignDriveLetter
    $recovery = New-Partition -DiskNumber 0 -UseMaximumSize -AssignDriveLetter

    # Save the drive letters and volume GUIDs to task sequence variables
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs to task sequence variables"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs to task sequence variables"
    # Modified for better output (admminy)
    $tsenv:BootVolume = $boot.DriveLetter
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): tsenv:BootVolume is now $tsenv:BootVolume"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:BootVolume is now $tsenv:BootVolume"
    
    # Modified for better output (admminy)
    $tsenv:OSVolume = $os.DriveLetter
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVolume is now $tsenv:OSVolume"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVolume is now $tsenv:OSVolume"
    
    # Modified for better output (admminy)
    $tsenv:RecoveryVolume = $recovery.DriveLetter
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): tsenv:RecoveryVolume $tsenv:RecoveryVolume"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:RecoveryVolume $tsenv:RecoveryVolume"
    
    # Removed, there is no guid on MDR disks (admminy)
    # $tsenv:RecoveryVolumeGuid = $recovery.Guid
    # $tsenv:BootVolumeGuid = $boot.Guid
    # $tsenv:OSVolumeGuid = "MBR"

    # Format the partitions (admminy)
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Format the partitions (admminy)"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format the partitions (admminy)"
    Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem NTFS -Verbose
    Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem NTFS -Verbose
    Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem NTFS -Verbose

    #Fix for MBR
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Getting Guids from the volumes"

    $tsenv:OSVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:OSVolume).UniqueId.replace("\\?\Volume","").replace("\","")
    $tsenv:RecoveryVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:RecoveryVolume).UniqueId.replace("\\?\Volume","").replace("\","")
    $tsenv:BootVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:BootVolume).UniqueId.replace("\\?\Volume","").replace("\","")

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVolumeGuid is now $tsenv:OSVolumeGuid"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:RecoveryVolumeGuid is now $tsenv:RecoveryVolumeGuid"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:BootVolumeGuid is now $tsenv:BootVolumeGuid"

}

# Make sure there is a PSDrive for the OS volume
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Make sure there is a PSDrive for the OS volume"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Make sure there is a PSDrive for the OS volume"
if ((Test-Path "$($tsenv:OSVolume):\") -eq $false)
{
    
    New-PSDrive -Name $tsenv:OSVolume -PSProvider FileSystem -Root "$($tsenv:OSVolume):\" -Verbose
}

# If the old local data path survived the partitioning, copy it to the new location
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): If the old local data path survived the partitioning, copy it to the new location"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): If the old local data path survived the partitioning, copy it to the new location"
if (Test-Path $currentLocalDataPath)
{
    # Copy files to new data path
    #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Copy files to new data path"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy files to new data path"
    $newLocalDataPath = Get-PSDLocalDataPath -Move
    if ($currentLocalDataPath -ine $newLocalDataPath)
    {
        #Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Copying $currentLocalDataPath to $newLocalDataPath"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying $currentLocalDataPath to $newLocalDataPath"
        Copy-PSDFolder $currentLocalDataPath $newLocalDataPath
        
        # Change log location for TSxLogPath, since we now have a volume
        $Global:TSxLogPath = "$newLocalDataPath\SMSOSD\OSDLOGS\PSDPartition.log"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Now logging to $Global:TSxLogPath"
    }
}

# Dumping out variables for troubleshooting
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Dumping out variables for troubleshooting"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:BootVolume  is $tsenv:BootVolume"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVolume is $tsenv:OSVolume"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:RecoveryVolume is $tsenv:RecoveryVolume"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:IsUEFI is $tsenv:IsUEFI"

# Save all the current variables for later use
#Write-Verbose -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Save-PSDVariables
