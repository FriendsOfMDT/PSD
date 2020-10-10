# The Final Countdown
Param(
    $Restart,
    $ParentPID
)

Write-Verbose "Running Stop-Process -Id $ParentPID"
Stop-Process -Id $ParentPID -Force

$Folders = "MININT","Drivers"
Foreach($Folder in $Folders){
    Get-Volume | ? {-not [String]::IsNullOrWhiteSpace($_.DriveLetter) } | ? {$_.DriveType -eq 'Fixed'} | ? {$_.DriveLetter -ne 'X'} | ? {Test-Path "$($_.DriveLetter):\MININT"} | % {
        $localPath = "$($_.DriveLetter):\$Folder"
        if(Test-Path -Path "$localPath"){
            Write-Verbose "trying to remove $localPath"
            Remove-Item "$localPath" -Recurse -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
}

if($Restart -eq $True){
    Write-Verbose "Running Shutdown.exe /r /t 30 /f"
    Shutdown.exe /r /t 30 /f
}
