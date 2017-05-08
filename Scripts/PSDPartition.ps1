# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDPartition.ps1
# // 
# // Purpose:   Partition the disk
# // 
# // ***************************************************************************

# Load core modules
Import-Module PSDUtility
$verbosePreference = "Continue"

# Keep the logging out of the way
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
Update-Disk -Number 0
$disk = Get-Disk -Number 0

if ($tsenv:IsUEFI -eq "True")
{
    # UEFI partitioning

    # Clean the disk if it isn't raw
    if ($disk.PartitionStyle -ne "RAW")
    {
        Write-Verbose "Clearing disk"
        Clear-Disk -Number 0 -RemoveData -RemoveOEM -Confirm:$false
    }

    # Initialize the disk
    Write-Verbose "Initializing disk"
    Initialize-Disk -Number 0 -PartitionStyle GPT
    Get-Disk -Number 0

    # Calculate the OS partition size, as we want a recovery partiton after it
    $osSize = $disk.Size - 499MB - 128MB - 499MB

    # Create the paritions
    $efi = New-Partition -DiskNumber 0 -Size 499MB -AssignDriveLetter
    $msr = New-Partition -DiskNumber 0 -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    $os = New-Partition -DiskNumber 0 -Size $osSize -AssignDriveLetter
    $recovery = New-Partition -DiskNumber 0 -UseMaximumSize -AssignDriveLetter -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'

    # Save the drive letters and volume GUIDs to task sequence variables
    $tsenv:BootVolume = $efi.DriveLetter
    $tsenv:BootVolumeGuid = $efi.Guid
    $tsenv:OSVolume = $os.DriveLetter
    $tsenv:OSVolumeGuid = $os.Guid
    $tsenv:RecoveryVolume = $recovery.DriveLetter
    $tsenv:RecoveryVolumeGuid = $recovery.Guid

    # Format the volumes
    Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem FAT32
    Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem NTFS
    Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem NTFS
}
else
{
    # Clean the disk if it isn't raw
    if ($disk.PartitionStyle -ne "RAW")
    {
        Write-Verbose "Clearing disk"
        Clear-Disk -Number 0 -RemoveData -RemoveOEM -Confirm:$false
    }

    # Initialize the disk
    Write-Verbose "Initializing disk"
    Initialize-Disk -Number 0 -PartitionStyle MBR
    Get-Disk -Number 0

    # Calculate the OS partition size, as we want a recovery partiton after it
    $osSize = $disk.Size - 499MB - 499MB

    # Create the paritions
    $boot = New-Partition -DiskNumber 0 -Size 499MB -AssignDriveLetter -IsActive
    $os = New-Partition -DiskNumber 0 -Size $osSize -AssignDriveLetter
    $recovery = New-Partition -DiskNumber 0 -UseMaximumSize -AssignDriveLetter

    # Save the drive letters and volume GUIDs to task sequence variables
    $tsenv:BootVolume = $boot.DriveLetter
    $tsenv:BootVolumeGuid = $boot.Guid
    $tsenv:OSVolume = $os.DriveLetter
    $tsenv:OSVolumeGuid = $os.Guid
    $tsenv:RecoveryVolume = $recovery.DriveLetter
    $tsenv:RecoveryVolumeGuid = $recovery.Guid

    # Format the partitions
    Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem NTFS
    Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem NTFS
    Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem NTFS
}

# Make sure there is a PSDrive for he OS volume
if ((Test-Path "$($tsenv:OSVolume):\") -eq $false)
{
    New-PSDrive -Name $tsenv:OSVolume -PSProvider FileSystem -Root "$($tsenv:OSVolume):\"
}

# If the old local data path survived the partitioning, copy it to the new location
if (Test-Path $currentLocalDataPath)
{
    # Copy files to new data path
    $newLocalDataPath = Get-PSDLocalDataPath -Move
    if ($currentLocalDataPath -ine $newLocalDataPath)
    {
        Write-Verbose "Copying $currentLocalDataPath to $newLocalDataPath"
        Copy-PSDFolder $currentLocalDataPath $newLocalDataPath
    }
}

# Save all the current variables for later use
Save-PSDVariables
