Write-PSDBootInfo -SleepSec 1 -Message "Processing UserExitScript001"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Processing UserExitScript001"

[string]$SerialNumber = (Get-WmiObject win32_bios).Serialnumber
$CleanSerialNumber =  $SerialNumber.Replace("/","").Replace("\","").Replace("|","").Replace("-","").Replace(" ","")
$CutOfNumber = 10
$checklength = $CleanSerialNumber.Length
    If($checklength -lt $CutOfNumber ){
        $numberx = $checklength
    }
    Else{
        $numberx = $CutOfNumber
    }
$tsenv:OSDComputername = "PC-$($CleanSerialNumber.Substring($CleanSerialNumber.Length - $numberx ))"