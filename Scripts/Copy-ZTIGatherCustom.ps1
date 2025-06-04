[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$MinintPath,

    [Parameter(Mandatory=$true)]
    [string]$DestinationPath
)

# Attempt to find ZTIGather.xml
$ztigatherFile = Get-ChildItem -Path $MinintPath -Recurse -Filter "ZTIGather.xml" -File -ErrorAction SilentlyContinue | Select-Object -First 1

if ($null -ne $ztigatherFile) {
    try {
        # Try to use Write-PSDLog if available (it might be if called from PSDUtility context)
        Write-PSDLog -Message "Copy-ZTIGatherCustom: Found ZTIGather.xml at $($ztigatherFile.FullName). Copying to $DestinationPath." -Source "Copy-ZTIGatherCustom"
    }
    catch {
        # Fallback to Write-Host if Write-PSDLog is not available or fails
        Write-Host "Copy-ZTIGatherCustom: Found ZTIGather.xml at $($ztigatherFile.FullName). Copying to $DestinationPath."
    }

    try {
        Copy-Item -Path $ztigatherFile.FullName -Destination $DestinationPath -Force -ErrorAction Stop
        try {
            Write-PSDLog -Message "Copy-ZTIGatherCustom: Successfully copied ZTIGather.xml to $DestinationPath." -Source "Copy-ZTIGatherCustom"
        }
        catch {
            Write-Host "Copy-ZTIGatherCustom: Successfully copied ZTIGather.xml to $DestinationPath."
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        try {
            Write-PSDLog -Message "Copy-ZTIGatherCustom: Error copying ZTIGather.xml to $DestinationPath. Error: $errorMessage" -Source "Copy-ZTIGatherCustom" -LogLevel 3
        }
        catch {
            Write-Host "Copy-ZTIGatherCustom: Error copying ZTIGather.xml to $DestinationPath. Error: $errorMessage"
        }
    }
}
else {
    try {
        Write-PSDLog -Message "Copy-ZTIGatherCustom: ZTIGather.xml not found in $MinintPath." -Source "Copy-ZTIGatherCustom" -LogLevel 2
    }
    catch {
        Write-Host "Copy-ZTIGatherCustom: ZTIGather.xml not found in $MinintPath."
    }
}
