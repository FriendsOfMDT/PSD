Function Test-UEFI{
    $hash = @{
        Message = "Test UEFI passed"
        Ready   = "True"
    }
    New-Object PSObject -Property $hash    
}

Function Test-TPM{
    $hash = @{
        Message = "Test TPM passed"
        Ready   = "True"
    }
    New-Object PSObject -Property $hash    
}

Function Test-ADDS{
    $hash = @{
        Message = "Test ADDS passed"
        Ready   = "True"
    }
    New-Object PSObject -Property $hash    
}

Function Test-Intune{
    $hash = @{
        Message = "Test Intune passed"
        Ready   = "True"
    }
    New-Object PSObject -Property $hash    
}
