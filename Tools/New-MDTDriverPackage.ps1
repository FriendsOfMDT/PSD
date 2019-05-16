Param(
    $MDTDSRoot
)

# Hard Coded Variables:
$PSDriveName = "MDT001"
#$MDTDSRoot = "E:\PSProduction"

# Add MDT Snapin
Add-PSSnapIn Microsoft.BDD.PSSnapIn
New-PSDrive -Name "$PSDriveName" -PSProvider MDTProvider -Root $MDTDSRoot -ErrorAction SilentlyContinue
$RootDriverPath = "$PSDriveName" + ":\Out-Of-Box Drivers"
$RootDrivers = Get-ChildItem -Path $RootDriverPath -Recurse
$AllDrivers = $RootDrivers | Where-Object NodeType -EQ Driver
foreach($Driver in $AllDrivers){
    $SourceFolderPath = ($MDTDSRoot + "\" + ($Driver.Source | Split-Path -Parent)).Replace(".\","")
    $RemoveMe = "Microsoft.BDD.PSSnapIn\MDTProvider::$($PSDriveName):\Out-Of-Box Drivers\"
    $DestinationFolderName = ($Driver.PsParentPath).Replace("$RemoveMe","").Replace("\"," - ")
    $DestinationFolderPath = $MDTDSRoot + "\DriverSources\" + $DestinationFolderName
    New-Item -Path $DestinationFolderPath -ItemType Directory -Force
    Copy-Item -Path $SourceFolderPath -Destination $DestinationFolderPath -Recurse -Force
}

$DriverZIPs = Get-ChildItem -Path $MDTDSRoot\DriverPackages -Recurse
foreach($DriverZIP in $DriverZIPs){
    Remove-Item -Path $DriverZIP.fullname -ErrorAction SilentlyContinue -Recurse
}

$DriverFolders = Get-ChildItem -Path $MDTDSRoot\DriverSources
foreach($DriverFolder in $DriverFolders){
    $FileName = ($DriverFolder.BaseName).replace(" ","_") + ".zip"
    $DestinationFolderPath = $MDTDSRoot + "\DriverPackages\" + ($DriverFolder.name).replace(" ","_")
    New-Item -Path $DestinationFolderPath -ItemType Directory -Force
    Add-Type -Assembly ‘System.IO.Compression.FileSystem’ -PassThru | Select-Object -First 1 | ForEach-Object {
        [IO.Compression.ZIPFile]::CreateFromDirectory("$($DriverFolder.fullname)", "$($DestinationFolderPath)" + "\" + $FileName)
    }
}

#($MDTDSRoot + "\DriverPackages\" + $DestinationFolderName).replace(" ","_")
#$($DriverFolder.fullname).replace(" ","_")