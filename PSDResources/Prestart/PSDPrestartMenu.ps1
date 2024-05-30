function Show-Menu{
    param (
        [string]$Title = 'My Menu'
    )
    Clear-Host
    Write-Host "================ $Title ================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1" -ForegroundColor Green -NoNewline
    Write-Host " : Show Physical Disks"
    Write-Host ""
    Write-Host "4" -ForegroundColor Green -NoNewline
    Write-Host " : Show NetAdapters"
    Write-Host "5" -ForegroundColor Green -NoNewline
    Write-Host " : Show IP Addresses"
    Write-Host "6" -ForegroundColor Green -NoNewline
    Write-Host " : Set IP Address"
    Write-Host ""
    Write-Host "8" -ForegroundColor Green -NoNewline
    Write-Host " : PowerShell prompt"
    Write-Host "9" -ForegroundColor Green -NoNewline
    Write-Host " : DART Tools"
    Write-Host ""
    Write-Host "C" -ForegroundColor Green -NoNewline
    Write-Host " : Press 'C' to continue."
    Write-Host ""
}

Function Wait-PSDPrompt{
    Param(
        $prompt,
        $secondsToWait
    )
    Write-Host -NoNewline $prompt
    $secondsCounter = 0
    $subCounter = 0
    While ( (!$host.ui.rawui.KeyAvailable) -and ($count -lt $secondsToWait) ){
        start-sleep -m 10
        $subCounter = $subCounter + 10
        if($subCounter -eq 1000)
        {
            $secondsCounter++
            $subCounter = 0
            Write-Host -NoNewline "."
        }       
        If ($secondsCounter -eq $secondsToWait) { 
            Write-Host "`r`n"
            return $false;
        }
    }
    Write-Host "`r`n"
    return $true;
}

$val = Wait-PSDPrompt -prompt "Press any key run Pre PSD menu; will continue to PSD in 10 seconds" -secondsToWait 10
if($val){
    do{
         Show-Menu -Title "Pre-PSD"
         $selection = Read-Host "Please make a selection"
         switch ($selection)
         {
            '1' {
                Clear-Host
                Get-PhysicalDisk | FT
                Pause
            } 
            '4' {
                Clear-Host
                Get-CimInstance -ClassName win32_networkadapter -Filter "netconnectionstatus = 2 and NetEnabled='True' and PhysicalAdapter='True'" | Select-Object Name,MACAddress | FT
                Pause

            } 
            '5' {
                Clear-Host
                IPconfig /all
                Pause
            }
            '6'{
                Clear-Host
                $Nics = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object IPenabled -eq $true
                Clear-Host
                $Menu = @{}
                $Nics | ForEach-Object -Begin {$i = 1} { 
                    Write-Host "$($_.Description)`: Press '$i' for this option." 
                    $Menu.add("$i",$_)
                    $i++
                }
                Write-Host ""
                Write-Host "Q: Press 'Q' to quit."
                $Selection = Read-Host "Please make a selection"
                if ($Selection -eq 'Q'){

                }
                Else{
                    $SelectedNic = $Menu.$Selection
                    Clear-Host
                    $IPAddress = Read-Host -Prompt "Enter IP Address for $($SelectedNic.Description) :"
                    $Subnetmask = Read-Host -Prompt "Enter Subnetmask for $($SelectedNic.Description) :"
                    $DefaultGateway = Read-Host -Prompt "Enter DefaultGateway for $($SelectedNic.Description) :"
                    $DNS = Read-Host -Prompt "Enter DNS Server for $($SelectedNic.Description) :"
                    $Menu.$Selection.EnableStatic($IPAddress, $Subnetmask)
                    $Menu.$Selection.SetGateways($DefaultGateway, 1)
                    $Menu.$Selection.SetDNSServerSearchOrder($DNS)
                    IPConfig
                }
                Pause
            } 
            '8' {
                Clear-Host 
                Start PowerShell -Wait
            } 
            '9' {
                Clear-Host
                If((Test-Path X:\Sources\Recovery\Tools\MsDartTools.exe) -eq $true){
                    Start-Process X:\Sources\Recovery\Tools\MsDartTools.exe -Wait
                }
                else{
                    Clear-Host
                    Write-Warning "The Dart Tools has not been included in this boot media"
                    Pause
                }
                
            }
            'T' {
                Clear-Host
                "The T is on..."
                Pause
            } 
        }
    }
    until ($selection -eq 'c')
}

Clear-Host