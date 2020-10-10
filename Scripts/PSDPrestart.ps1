# PSDPrestart.ps1

if(Test-Path -Path X:\Deploy\Prestart\PSDPrestart.xml){
    [xml]$XML = Get-Content -Path X:\Deploy\Prestart\PSDPrestart.xml
    foreach($item in ($XML.Commands.Command)){
        Start-Process -FilePath $item.Executable -ArgumentList $item.Argument -Wait -NoNewWindow -PassThru
    }
}

