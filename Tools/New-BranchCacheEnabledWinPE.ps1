# Set parameters

$Windows10Media = "E:\PSProduction\Operating Systems\W10X6417091\sources\install.wim"
$BootMedia = "E:\PSProduction\Boot\LiteTouchPE_x64.wim"
$Windows10Index = "3"
$BootIndex = "1"
$StifleRClientRules = "E:\Software\2Pint\2Pint Software OSD Toolkit v1.9.7\StifleR.ClientApp.exe.Config"

Set-Location "E:\Software\2Pint\2Pint Software OSD Toolkit v1.9.7\WinPE Generator\x64"
.\WinPEGen.exe $Windows10Media $Windows10Index $Bootmedia $BootIndex /Add-StifleR /StifleRConfig:$StifleRClientRules

#Create new/updated ISO

$TempFolder = "E:\ISOTemp"
New-Item -Path $TempFolder -ItemType Directory -Force
New-Item -Path $TempFolder\Sources -ItemType Directory -Force

$PathToOscdimg = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
$ISOFile = "E:\PSProduction\Boot\PSDLiteTouch_x64.iso"
$WimFile = "E:\PSProduction\Boot\LiteTouchPE_x64.wim"

Xcopy $ISOMediaFolder $TempFolder /Y /E
Copy-Item $WimFile $TempFolder\Sources\Boot.wim

#Copy the updated boot back to the boot folder

$BootData='2#p0,e,b"{0}"#pEF,e,b"{1}"' -f "$PathToOscdimg\etfsboot.com","$PathToOscdimg\efisys.bin"
$Proc = Start-Process -FilePath "$PathToOscdimg\oscdimg.exe" -ArgumentList @("-bootdata:$BootData",'-u2','-udfver102',"$TempFolder","$ISOFile") -PassThru -Wait -NoNewWindow
if($Proc.ExitCode -ne 0)
{
    Throw "Failed to generate ISO with exitcode: $($Proc.ExitCode)"
}


