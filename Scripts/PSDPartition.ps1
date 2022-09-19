<#
.SYNOPSIS
    Partion and format the disk.
.DESCRIPTION
    Partion and format the disk.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDPartition.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2022-06-20

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.5 - () - Fixed spelling.
          Version - 0.0.6 - (Mikael_Nystrom) - Replaced Clear-Disk with Clear-PSDDisk

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
$ScriptVersion = "0.0.6"

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility

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

# Keep the logging out of the way

$currentLocalDataPath = Get-PSDLocalDataPath
if ($currentLocalDataPath -NotLike "X:\*")
{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Stop-PSDLogging, need to keep the logging out of the way"
    Stop-PSDLogging
    $logPath = "X:\MININT\Logs"
    if ((Test-Path $logPath) -eq $false) {
        New-Item -ItemType Directory -Force -Path $logPath | Out-Null
    }
    Start-Transcript "$logPath\PSDPartition.ps1.log"
}

# Get the dynamic variable
foreach($i in (Get-ChildItem -Path TSEnv:)){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property $($i.Name) is $($i.Value)"
}

# Partition and format the disk
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Partition and format the disk [$tsenv:OSDDiskIndex]"
Show-PSDActionProgress -Message "Partition and format disk [$tsenv:OSDDiskIndex]" -Step "1" -MaxStep "1"
Update-Disk -Number $tsenv:OSDDiskIndex
$disk = Get-Disk -Number $tsenv:OSDDiskIndex

if ($tsenv:IsUEFI -eq "True"){
    
    # UEFI partitioning
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): UEFI partitioning"

    # Clean the disk if it isn't raw
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clean the disk if it isn't raw"
    if ($disk.PartitionStyle -ne "RAW"){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clearing disk"
        Show-PSDActionProgress -Message "Clearing disk" -Step "1" -MaxStep "1"
        # Clear-Disk -Number $tsenv:OSDDiskIndex -RemoveData -RemoveOEM -Confirm:$false
        Clear-PSDDisk -Number $tsenv:OSDDiskIndex
    }

    # Initialize the disk
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Initialize the disk"
    Show-PSDActionProgress -Message "Initialize the disk" -Step "1" -MaxStep "1"
    Initialize-Disk -Number $tsenv:OSDDiskIndex -PartitionStyle GPT
    # Get-Disk -Number $tsenv:OSDDiskIndex

    # Calculate the OS partition size, as we want a recovery partiton after it
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Calculate the OS partition size, as we want a recovery partiton after it"
    Show-PSDActionProgress -Message "Calculate the OS partition size, as we want a recovery partiton after it" -Step "1" -MaxStep "1"
    $osSize = $disk.Size - 499MB - 128MB - 1024MB

    # Create the partitions
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partitions"
    Show-PSDActionProgress -Message "Create the paritions" -Step "1" -MaxStep "1"
    
    #$efi = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size 499MB -AssignDriveLetter
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the EFI partition"
    Show-PSDActionProgress -Message "Create the EFI partition" -Step "1" -MaxStep "1"
    $efi = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size 499MB -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the MSR partition"
    Show-PSDActionProgress -Message "Create the MSR partition" -Step "1" -MaxStep "1"
    $msr = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    
    #$os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $osSize -AssignDriveLetter
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the OS partition"
    Show-PSDActionProgress -Message "Create the OS partition" -Step "1" -MaxStep "1"
    $os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $osSize
    
    #$recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -UseMaximumSize -AssignDriveLetter -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the Recovery partition"
    Show-PSDActionProgress -Message "Create the Recovery partition" -Step "1" -MaxStep "1"
    $recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -UseMaximumSize -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'

    # Assign driveletters
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning drivletters"
    Show-PSDActionProgress -Message "Assigning drivletters" -Step "1" -MaxStep "1"
    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): EFI is set to W:"
    $efi | Set-Partition -NewDriveLetter W
    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): OS is set to S:"
    $os | Set-Partition -NewDriveLetter S
    
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Recovery is set to R:"
    $recovery | Set-Partition -NewDriveLetter R

    # Save the drive letters and volume GUIDs to task sequence variables
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs to task sequence variables"
    $tsenv:BootVolume = "W"
    $tsenv:BootVolumeGuid = $efi.Guid
    $tsenv:OSVolume = "S"
    $tsenv:OSVolumeGuid = $os.Guid
    $tsenv:RecoveryVolume = "R"
    $tsenv:RecoveryVolumeGuid = $recovery.Guid

    # Format the volumes
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format the volumes"
    
    Show-PSDActionProgress -Message "Format Bootvolume as FAT32" -Step "1" -MaxStep "1"
    Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem FAT32

    Show-PSDActionProgress -Message "Format OSvolume as NTFS" -Step "1" -MaxStep "1"
    Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem NTFS

    Show-PSDActionProgress -Message "Format Recoveryvolume as NTFS" -Step "1" -MaxStep "1"
    Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem NTFS
}
else{
    # Clean the disk if it isn't raw
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clean the disk if it isn't raw"
    if ($disk.PartitionStyle -ne "RAW")
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clearing disk"
        Show-PSDActionProgress -Message "Clearing disk" -Step "1" -MaxStep "1"
        # Clear-Disk -Number $tsenv:OSDDiskIndex -RemoveData -RemoveOEM -Confirm:$false
        Clear-PSDDisk -Number $tsenv:OSDDiskIndex
    }

    # Initialize the disk
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Initialize the disk"
    Show-PSDActionProgress -Message "Initialize the disk" -Step "1" -MaxStep "1"
    Initialize-Disk -Number $tsenv:OSDDiskIndex -PartitionStyle MBR
    Get-Disk -Number $tsenv:OSDDiskIndex

    # Calculate the OS partition size, as we want a recovery partiton after it
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Calculate the OS partition size, as we want a recovery partiton after it"
    Show-PSDActionProgress -Message "Calculate the OS partition size, as we want a recovery partiton after it" -Step "1" -MaxStep "1"
    $osSize = $disk.Size - 499MB - 1024MB

    # Create the partitions
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partitions"
    Show-PSDActionProgress -Message "Create the paritions" -Step "1" -MaxStep "1"
    $boot = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size 499MB -AssignDriveLetter -IsActive
    $os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $osSize -AssignDriveLetter
    $recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -UseMaximumSize -AssignDriveLetter

    # Save the drive letters and volume GUIDs to task sequence variables
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs to task sequence variables"

    # Modified for better output (admminy)
    $tsenv:BootVolume = $boot.DriveLetter
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property BootVolume is $tsenv:BootVolume"
    
    # Modified for better output (admminy)
    $tsenv:OSVolume = $os.DriveLetter
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSVolume is $tsenv:OSVolume"
    
    # Modified for better output (admminy)
    $tsenv:RecoveryVolume = $recovery.DriveLetter
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property RecoveryVolume is $tsenv:RecoveryVolume"
    
    # Format the partitions (admminy)
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format the partitions (admminy)"
    Show-PSDActionProgress -Message "Format the volumes" -Step "1" -MaxStep "1"
    Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem NTFS -Verbose
    Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem NTFS -Verbose
    Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem NTFS -Verbose

    #Fix for MBR
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Getting Guids from the volumes"

    $tsenv:OSVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:OSVolume).UniqueId.replace("\\?\Volume","").replace("\","")
    $tsenv:RecoveryVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:RecoveryVolume).UniqueId.replace("\\?\Volume","").replace("\","")
    $tsenv:BootVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:BootVolume).UniqueId.replace("\\?\Volume","").replace("\","")

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSVolumeGuid is $tsenv:OSVolumeGuid"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property RecoveryVolumeGuid is $tsenv:RecoveryVolumeGuid"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property BootVolumeGuid is $tsenv:BootVolumeGuid"
}

# Make sure there is a PSDrive for the OS volume
if ((Test-Path "$($tsenv:OSVolume):\") -eq $false){
    New-PSDrive -Name $tsenv:OSVolume -PSProvider FileSystem -Root "$($tsenv:OSVolume):\" -Verbose
}

# If the old local data path survived the partitioning, copy it to the new location
# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): If the old local data path survived the partitioning, copy it to the new location"
if (Test-Path $currentLocalDataPath){
    # Copy files to new data path
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy files to new data path"
    $newLocalDataPath = Get-PSDLocalDataPath -Move
    if ($currentLocalDataPath -ine $newLocalDataPath){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying $currentLocalDataPath to $newLocalDataPath"
        Copy-PSDFolder $currentLocalDataPath $newLocalDataPath
        
        # Change log location for LogPath, since we now have a volume
        $Global:LogPath = "$newLocalDataPath\SMSOSD\OSDLOGS\PSDPartition.log"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Now logging to $Global:LogPath"
    }
}

# Dumping out variables for troubleshooting
# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Dumping out variables for troubleshooting"
# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:BootVolume  is $tsenv:BootVolume"
# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVolume is $tsenv:OSVolume"
# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:RecoveryVolume is $tsenv:RecoveryVolume"
# Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:IsUEFI is $tsenv:IsUEFI"

# Save all the current variables for later use
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Save-PSDVariables
