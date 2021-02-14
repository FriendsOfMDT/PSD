
Param(
    # ISO Original path
    $ISOPath = "$scriptroot\LiteTouchPE_x64.iso"
)

$VerbosePreference = 'Continue'
##*===========================================================================
##* FUNCTIONS
##*===========================================================================
Function Test-IsISE {
    # try...catch accounts for:
    # Set-StrictMode -Version latest
    try {    
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}

Function Get-ScriptPath {
    # Makes debugging from ISE easier.
    if ($PSScriptRoot -eq "")
    {
        if (Test-IsISE)
        {
            $psISE.CurrentFile.FullPath
            #$root = Split-Path -Parent $psISE.CurrentFile.FullPath
        }
        else
        {
            $context = $psEditor.GetEditorContext()
            $context.CurrentFile.Path
            #$root = Split-Path -Parent $context.CurrentFile.Path
        }
    }
    else
    {
        #$PSScriptRoot
        $PSCommandPath
        #$MyInvocation.MyCommand.Path
    }
}

Function Copy-ItemWithProgress
{
    [CmdletBinding()]
    Param
    (
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]
    [Alias("Path")]
    [string]$Source,
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=1)]
    [string]$Destination,
    [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true,
        Position=2)]
    [int16]$ParentID,
    [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true,
        Position=3)]
    [switch]$Force
    )

    Begin{    
        #get the entire folder structure
        $Filelist = Get-Childitem $Source -Recurse | Where {$_.PSIscontainer -eq $False}

        #get the count of all the objects
        $Total = $Filelist.count

        #establish a counter
        $Position = 0

        #set an id for the progress bar
        If($ParentID){$ParentID = $ParentID;$ThisProgressID = ($ParentID+1)}Else{$ParentID=1;$ThisProgressID = 2}
    }
    Process{
        #Stepping through the list of files is quite simple in PowerShell by using a For loop
        foreach ($File in $Filelist)
        {
            #On each file, grab only the part that does not include the original source folder using replace
            $Filename = ($File.Fullname).replace($Source,'')
        
            #rebuild the path for the destination:

            $DestinationFile = Join-Path $Destination -ChildPath $Filename
        
            #get just the folder path
            $DestinationPath = Split-Path $DestinationFile -Parent

            #show progress
            Write-Progress -Activity "Copying data from $source to $Destination" -Status "Copying File $Filename" -PercentComplete (($Position/$total)*100) -Id $ThisProgressID -ParentId $ParentID
        
            #create destination directories
            If (-not (Test-Path $DestinationPath) ) {
                Try{
                    New-Item $DestinationPath -ItemType Directory -ErrorAction Stop | Out-Null
                }Catch{
                    break
                }
            }

            #do copy (enforce)
            Try{
                Copy-Item $File.FullName -Destination $DestinationFile -Force:$Force -ErrorAction Stop -Verbose:($PSBoundParameters['Verbose'] -eq $true) | Out-Null
                Write-Verbose ("Copied file [{0}] to [{1}]" -f $File.FullName,$DestinationFile)
            }
            Catch{
                Write-Host ("Unable to copy file in {0} to {1}; Error: {2}" -f $File.FullName,$DestinationFile ,$_.Exception.Message) -ForegroundColor Red
                break
            }
            #bump up the counter
            $Position++
        }
    }
    End{}
}

##*===========================================================================
##* VARIABLES
##*===========================================================================
# Use function to get paths because Powershell ISE and other editors have differnt results
$scriptPath = Get-ScriptPath
[string]$scriptDirectory = Split-Path $scriptPath -Parent
[string]$scriptName = Split-Path $scriptPath -Leaf
[string]$scriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($scriptName)

# New ISO path
# it will be placed in same directory as original one
$ISODirectory = Split-Path $ISOPath -Parent


#ensure path exists
If(-not(Test-Path $ISOPath)){
    Write-Host ("[{0}] does not exist in path: [{1}].`nRun script from Deploymentshare's boot folder after Deploymentshare has been updated." -f (Split-Path $ISOPath -Leaf),$ISODirectory) -ForegroundColor Red
    Exit
}

$ISOBaseName = (Get-ChildItem $ISOPath).BaseName
$NewISOFullPath = Join-Path $ISODirectory -ChildPath ($ISOBaseName + '-NoPrompt.iso')

# Specified Workspace path
#if it doesn't exists, the users temp directory will be used
$WorkspacePath = "D:\Development\winpe_x64\mount"
If(-not(Test-Path $WorkspacePath)){
    Write-Host ("workspace path does not exist: [{0}]. Attempting to use temp folder [{1}] " -f $WorkspacePath,$env:temp) -ForegroundColor Yellow;
    $WorkspacePath = Join-Path $env:temp -ChildPath 'mount'
    New-Item $WorkspacePath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
}

#Specified Oscdimg path
#$OscdimgFilePath  = "D:\ISO Images\CREATEISO\oscdimg.exe"

#Oscdimg path within ADK
$OscdimgFilePath = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
If(-not(Test-Path $OscdimgFilePath)){
    Write-Host ("oscdimg.exe does not exist in path: [{0}]. Unable to continue. Install the latest ADK: https://go.microsoft.com/fwlink/p/?LinkId=526803" -f (Split-Path $OscdimgFilePath -Parent)) -ForegroundColor Red;
    Exit
}
#grab the source path for Oscdimg to find boot files
$OscdimgPath = Split-Path $OscdimgFilePath -Parent
$etfsBootFilePath = Join-Path $OscdimgPath -ChildPath 'etfsboot.com'
$efisysFilePath = Join-Path $OscdimgPath -ChildPath 'efisys_noprompt.bin'

##*===========================================================================
##* MAIN
##*===========================================================================

# Mount ISO
$mountISO = Mount-DiskImage $ISOPath -PassThru

#wait a few second to enusre ISO is mounted
Start-Sleep 5

# Find Driverletter assign to mounted ISO
$Drive = ($mountISO | Get-Volume).DriveLetter + ':'

#get friendly name of ISO (to use on new ISO)
$FriendlyName = ($mountISO | Get-Volume).FileSystemLabel

# copy mounted iso contents to the workspace folder (uses progress)
Copy-ItemWithProgress -Path $Drive -Destination $WorkspacePath -Force

# remove the read-only attribute from the extracted files.
Get-ChildItem $WorkspacePath -Recurse | %{ if (! $_.psiscontainer) { $_.isreadonly = $false } }
 
# Create a bootable WinPE ISO file (remove the "Press any button key.." message)
Copy-Item -Path $etfsBootFilePath -Destination "$WorkspacePath\boot" -Recurse -Force | Out-Null
Copy-Item -Path $efisysFilePath -Destination "$WorkspacePath\EFI\Microsoft\Boot" -Recurse -Force | Out-Null

Try{
    # recompile the files to an ISO
    $Proc = Start-Process -FilePath "$OscdimgFilePath" -ArgumentList "-u2 -udfver102 -m -o -h -bootdata:2#p0,e,b`"$etfsBootFilePath`"#pEF,e,b`"$efisysFilePath`" -l$FriendlyName `"$WorkspacePath`" `"$NewISOFullPath`"" -PassThru -Wait -NoNewWindow
    Write-Host ("Successfully created new Litetouch.iso with no boot prompt. Located here: {0}" -f $NewISOFullPath) -ForegroundColor Green
}
Catch{
    Throw "Failed to generate ISO with exitcode: $($Proc.ExitCode)"
}
Finally{
    # remove the extracted content.
    Remove-Item $WorkspacePath -Recurse -Force -Exclude (Split-Path $WorkspacePath -leaf)
 
    # dismount the iso.
    Dismount-DiskImage -ImagePath "$ISOPath" | Out-null
    #Dismount-DiskImage -DevicePath
}