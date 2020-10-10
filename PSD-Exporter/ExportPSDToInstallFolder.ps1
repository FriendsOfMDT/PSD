# Export Current Dev to Installer
# Updated for new gen of PSD-Master
$SourceFolder = "E:\PSProduction"
$DestinationFolder = "E:\Software\PSDv"
$MasterFolder = "E:\Software\PSD-master"
$Version = "0.2.0.1"
$PrevVersion = "0.2.0.0"

#Copy PSDMaster
New-Item -Path $($DestinationFolder + $Version) -ItemType Directory -Force
robocopy $MasterFolder $($DestinationFolder + $Version) /e /s

#Cleanup
#Remove-Item -Path "$($DestinationFolder + $Version)\.vscode" -Force -Recurse
Remove-Item -Path "$($DestinationFolder + $Version)\.gitattributes" -Force
Remove-Item -Path "$($DestinationFolder + $Version)\.gitignore" -Force
Remove-Item -Path "$($DestinationFolder + $Version)\LICENSE" -Force
#Remove-Item -Path "$($DestinationFolder + $Version)\PSD.pssproj" -Force
#Remove-Item -Path "$($DestinationFolder + $Version)\PSD.sln" -Force
Remove-Item -Path "$($DestinationFolder + $Version)\README.MD" -Force
Remove-Item -Path "$($DestinationFolder + $Version)\CONTRIBUTING.md" -Force

#Copy Core Modules
$CoreModules = "PSDDeploymentShare","PSDGather","PSDUtility","PSDWizard"
foreach($CoreModule in $CoreModules)
{
    $items = Get-ChildItem -Path $SourceFolder\tools\modules\$CoreModule
    foreach($item in $items)
    {
        Copy-Item -Path $item.FullName -Destination "$($DestinationFolder + $Version)\scripts\$($item.name)" -Force -Verbose
    }
}

#Remove ZTIGather.xml
Remove-Item -Path "$($DestinationFolder + $Version)\Scripts\ZTIGather.xml" -Force -Verbose

#Copy scripts
$CoreFiles = Get-ChildItem -Path $SourceFolder\scripts -Filter *.ps1 | Where-Object Name -ne ZTIOSRolePS.ps1
$CoreFiles.Count
foreach($CoreFile in $CoreFiles)
{
    Copy-Item -Path "$SourceFolder\scripts\$CoreFile" -Destination "$($DestinationFolder + $Version)\scripts\$CoreFile" -Force -Verbose
}

#Copy scripts
$CoreFiles = Get-ChildItem -Path $SourceFolder\scripts -Filter *.xaml
$CoreFiles.Count
foreach($CoreFile in $CoreFiles)
{
    Copy-Item -Path "$SourceFolder\scripts\$CoreFile" -Destination "$($DestinationFolder + $Version)\scripts\$CoreFile" -Force -Verbose
}

#Copy Master TS
Copy-Item -Path "$SourceFolder\control\tasksequence006\ts.xml" -Destination "$($DestinationFolder + $Version)\Templates\PSDClient.xml" -Force -Verbose
Copy-Item -Path "$SourceFolder\control\tasksequence006\ts.xml" -Destination "$SourceFolder\Templates\PSDClient.xml" -Force -Verbose

#Copy RnD TS
#Copy-Item -Path "$SourceFolder\Control\PS001\ts.xml" -Destination "$($DestinationFolder + $Version)\Templates\PSDRnD.xml" -Force -Verbose
#Copy-Item -Path "$SourceFolder\Control\PS001\ts.xml" -Destination "$SourceFolder\Templates\PSDRnD.xml" -Force -Verbose

#Copy Master 2P TS
#Copy-Item -Path "$SourceFolder\control\tasksequence003\ts.xml" -Destination "$($DestinationFolder + $Version)\Templates\PSDClientAutoPilot.xml" -Force -Verbose
#Copy-Item -Path "$SourceFolder\control\tasksequence003\ts.xml" -Destination "$SourceFolder\Templates\PSDClientAutoPilot.xml" -Force -Verbose

#Copy Master AutoPilot TS
#Copy-Item -Path "$SourceFolder\control\tasksequence004\ts.xml" -Destination "$($DestinationFolder + $Version)\Templates\PSDClient2P.xml" -Force -Verbose
#Copy-Item -Path "$SourceFolder\control\tasksequence004\ts.xml" -Destination "$SourceFolder\Templates\PSDClient2P.xml" -Force -Verbose

#Copy Master AutoPilot TS
Copy-Item -Path "$SourceFolder\control\tasksequence005\ts.xml" -Destination "$($DestinationFolder + $Version)\Templates\PSDServer.xml" -Force -Verbose
Copy-Item -Path "$SourceFolder\control\tasksequence005\ts.xml" -Destination "$SourceFolder\Templates\PSDServer.xml" -Force -Verbose

# Copy rest of templates
$templates = "LiteTouchPE.xml","Unattend_PE_x64.xml","Unattend_PE_x86.xml","Unattend_x64.xml","Unattend_x64.xml.10.0","Unattend_x86.xml"."Unattend_x86.xml.10.0"
foreach($template in $templates)
{
    Copy-Item -Path "$SourceFolder\templates\$template" -Destination "$($DestinationFolder + $Version)\Templates\$template" -Force -Verbose
}

# Copy installer
Copy-Item -Path "E:\Software\PSD-Installer\Install-PSD.ps1" -Destination "$($DestinationFolder + $Version)\Install-PSD.ps1" -Force -Verbose

# Copy new tools
New-Item -ItemType Directory -Path "$($DestinationFolder + $Version)\Tools" -Force -Verbose
Copy-Item -Path "E:\Software\PSD-Tools\New-PSDDriverPackage.ps1" -Destination "$($DestinationFolder + $Version)\Tools\New-PSDDriverPackage.ps1" -Force -Verbose
# Copy-Item -Path "E:\Software\PSD-Tools\New-PSDBranchCacheEnabledWinPE.ps1" -Destination "$($DestinationFolder + $Version)\Tools\New-PSDBranchCacheEnabledWinPE.ps1" -Force -Verbose
Copy-Item -Path "E:\Software\PSD-Tools\New-PSDHydration.ps1" -Destination "$($DestinationFolder + $Version)\Tools\New-PSDHydration.ps1" -Force -Verbose
# Copy-Item -Path "E:\Software\PSD-Tools\Set-PSDBootImageWithNoDebug.ps1" -Destination "$($DestinationFolder + $Version)\Tools\Set-PSDBootImageWithNoDebug.ps1" -Force -Verbose
Copy-Item -Path "E:\Software\PSD-Tools\New-PSDWebInstance.ps1" -Destination "$($DestinationFolder + $Version)\Tools\New-PSDWebInstance.ps1" -Force -Verbose
Copy-Item -Path "E:\Software\PSD-Tools\Set-PSDWebInstance.ps1" -Destination "$($DestinationFolder + $Version)\Tools\Set-PSDWebInstance.ps1" -Force -Verbose
Copy-Item -Path "E:\Software\PSD-Tools\New-PSDSelfSignedCert.ps1" -Destination "$($DestinationFolder + $Version)\Tools\New-PSDSelfSignedCert.ps1" -Force -Verbose

# Remove Extra folder
Remove-Item -Path "$($DestinationFolder + $Version)\Templates\Templates" -Force

# Copy Notes if we need
If((Test-Path -Path "$($DestinationFolder + $Version)\Notes.txt") -eq $False)
{
    Copy-Item -Path "$($DestinationFolder + $PrevVersion)\notes.txt" -Destination "$($DestinationFolder + $Version)\Notes.txt" -Force -Verbose
}

# Copy Misc
New-Item -ItemType Directory -Path "$($DestinationFolder + $Version)\Branding" -Force -Verbose
Copy-Item -Path 'C:\Program Files\Microsoft Deployment Toolkit\Samples\PSDBackground.bmp' -Destination "$($DestinationFolder + $Version)\Branding\PSDBackground.bmp" -Force -Verbose

Remove-Item -Path "$($DestinationFolder + $Version)\Templates\$template\PSDClient2P.xml" -Force -Verbose
Remove-Item -Path "$($DestinationFolder + $Version)\Templates\$template\PSDRnD.xml" -Force -Verbose

# Update the Unattend.xml file
$unattendFile = "$($DestinationFolder + $Version)\Templates\Unattend_PE_x64.xml"
$unattendFileData = Get-Content $unattendFile
$unattendFileData | Foreach-Object {$_.replace("powershell.exe -noprofile -file X:\Deploy\Scripts\PSDStart.ps1 -Debug", "powershell.exe -noprofile -windowstyle hidden -file X:\Deploy\Scripts\PSDStart.ps1")} | Set-Content $unattendFile

$unattendFile = "$($DestinationFolder + $Version)\Templates\Unattend_PE_x86.xml"
$unattendFileData = Get-Content $unattendFile
$unattendFileData | Foreach-Object {$_.replace("powershell.exe -noprofile -file X:\Deploy\Scripts\PSDStart.ps1 -Debug", "powershell.exe -noprofile -windowstyle hidden -file X:\Deploy\Scripts\PSDStart.ps1")} | Set-Content $unattendFile

# Remove the old installer folder, not used
Remove-Item -Path "$($DestinationFolder + $Version)\Installer" -Force -Verbose -Recurse

# Cleanup old PSD-Documentation and add new
Remove-Item -Path "$($DestinationFolder + $Version)\Documentation" -Force -Verbose -Recurse
& robocopy E:\Software\PSD-Documentation "$($DestinationFolder + $Version)\Documentation" /e /s


 

