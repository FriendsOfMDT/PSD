function Write-PSDBootInfo{
    Param(
        $Message,
        $SleepSec = "NA"
    )

    # Check for BGInfo
    if(!(Test-Path -Path "$env:SystemRoot\system32\bginfo.exe")){
        Return
    }

    # Check for BGinfo file
    if(!(Test-Path -Path "$env:SystemRoot\system32\psd.bgi")){
        Return
    }

    # Update background
    $Result = New-Item -Path HKLM:\SOFTWARE\PSD -ItemType Directory -Force
    $Result = New-ItemProperty -Path HKLM:\SOFTWARE\PSD -Name PSDBootInfo -PropertyType MultiString -Value $Message -Force
    & bginfo.exe "$env:SystemRoot\system32\psd.bgi" /timer:0 /NOLICPROMPT /SILENT
    
    if($SleepSec -ne "NA"){
        Start-Sleep -Seconds $SleepSec
    }
}

Write-PSDBootInfo -Message "Running PSD Prestart"

$FrameworkDir=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
$NGENPath = Join-Path $FrameworkDir 'ngen.exe'

$Null = & "$NGENPath" install ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object Location -Like *Microsoft.Management.Infrastructure*).Location /NoDependencies
$Null = & "$NGENPath" install ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object Location -Like *System.Management.Automation*).Location /NoDependencies
