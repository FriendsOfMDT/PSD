<#
.SYNOPSIS

.DESCRIPTION

.LINK

.NOTES
          FileName: PSDDeploymentShare.psd1
          Solution: PowerShell Deployment for MDT
          Purpose: Connect to a deployment share and obtain content from it, using either HTTP(s) or SMB as needed.
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom
          Created:
          Modified: 2022-09-18

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.1.1 - () - Removed blocker if we item could not be found, instead we continue and log, error handling must happen when object is needed, not when downloading.
          Version - 0.1.2 - () - Added Test-PSDContent,Test-PSDContentWeb,Test-PSDContentUNC - The ability to test if content exists before downloading
          Version - 0.1.3 - () - Minor cleanup
          Version - 0.1.4 - () - More minor cleanup
          Version - 0.1.4 - () - Modified error handling for downloading content from deploymentshare using WebDAV 

          TODO:

.Example
#>

# Check for debug in PowerShell and TSEnv
if ($TSEnv:PSDDebug -eq "YES") {
    $Global:PSDDebug = $true
}
if ($PSDDebug -eq $true) {
    $verbosePreference = "Continue"
}

Import-Module BitsTransfer -Global -Force -Verbose:$False

# Local variables
$global:psddsDeployRoot = ""
$global:psddsDeployUser = ""
$global:psddsDeployPassword = ""
$global:psddsCredential = ""

# Main function for establishing a connection
function Get-PSDConnection {
    param (
        [string] $deployRoot,
        [string] $username,
        [string] $password
    )

    if (($username -eq "\") -or ($username -eq "")) {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No UserID specified"
        $username = Get-PSDInputFromScreen -Header UserID -Message "Enter User ID [DOMAIN\Username] or [COMPUTER\Username]" -ButtonText Ok
        $tsenv:UserDomain = $username | Split-Path
        $tsenv:UserID = $username | Split-Path -Leaf
    }
    if ($password -eq "") {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): No UserPassword specified"
        $Password = Get-PSDInputFromScreen -Header UserPassword -Message "Enter Password"  -ButtonText Ok -PasswordText
        $tsenv:UserPassword = $Password
    }
    Save-PSDVariables | Out-Null
    # Save values in local variables
    $global:psddsDeployRoot = $deployRoot
    $global:psddsDeployUser = $username
    $global:psddsDeployPassword = $password

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable global:psddsDeployRoot is now =  $global:psddsDeployRoot"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable global:psddsDeployUser is now = $global:psddsDeployUser"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable global:psddsDeployPassword is now = $global:psddsDeployPassword"

    # Get credentials
    if (!$global:psddsDeployUser -or !$global:psddsDeployPassword) {
        $global:psddsCredential = Get-Credential -Message "Specify credentials needed to connect to $uncPath"
    }
    else {
        $secure = ConvertTo-SecureString $global:psddsDeployPassword -AsPlainText -Force
        $global:psddsCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $global:psddsDeployUser, $secure
    }

    # Make sure we can connect to the specified location
    if ($global:psddsDeployRoot -ilike "http*") {
        # Get a copy of the Control folder
        $cache = Get-PSDContent -Content "Control"
        $root = Split-Path -Path $cache -Parent

        # Get a copy of the Templates folder
        $null = Get-PSDContent -Content "Templates"

        # Connect to the cache
        Get-PSDProvider -DeployRoot $root
    }
    elseif ($global:psddsDeployRoot -like "\\*") {
        # Connect to a UNC path
        try {
            New-PSDrive -Name (Get-PSDAvailableDriveLetter) -PSProvider FileSystem -Root $global:psddsDeployRoot -Credential $global:psddsCredential -Scope Global
        }
        catch {

        }
        Get-PSDProvider -DeployRoot $global:psddsDeployRoot
    }
    else {
        # Connect to a local path (no credential needed)
        Get-PSDProvider -DeployRoot $global:psddsDeployRoot
    }

}

# Internal function for initializing the MDT PowerShell provider, to be used to get
# objects from the MDT deployment share.
function Get-PSDProvider {
    param (
        [string] $deployRoot
    )
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PowerShell variable deployRoot is now = $deployRoot"

    # Set an install directory if necessary (needed so the provider can find templates)
    if ((Test-Path "HKLM:\Software\Microsoft\Deployment 4") -eq $false) {
        $null = New-Item "HKLM:\Software\Microsoft\Deployment 4" -Force
        Set-ItemProperty "HKLM:\Software\Microsoft\Deployment 4" -Name "Install_Dir" -Value "$deployRoot\" -Force
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Set MDT Install_Dir to $deployRoot\ for MDT Provider."
    }

    # Set an install directory if necessary (needed so the provider can find templates)
    if ((Test-Path "HKLM:\Software\Microsoft\Deployment 4\Install_Dir") -eq $false) {
        Set-ItemProperty "HKLM:\Software\Microsoft\Deployment 4" -Name "Install_Dir" -Value "$deployRoot\" -Force
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Set MDT Install_Dir to $deployRoot\ for MDT Provider."
    }


    # Load the PSSnapIn PowerShell provider module
    $modules = Get-PSDContent -Content "Tools\Modules"
    Import-Module "$modules\Microsoft.BDD.PSSnapIn" -Verbose:$False

    # Create the PSDrive
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating MDT provider drive DeploymentShare: at $deployRoot"
    $Result = New-PSDrive -Name DeploymentShare -PSProvider MDTProvider -Root $deployRoot -Scope Global
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating MDT provider drive $($Result.name): at $($result.Root)"
}

# Internal function for getting the next available drive letter.
function Get-PSDAvailableDriveLetter {
    $drives = (Get-PSDrive -PSProvider filesystem).Name
    foreach ($letter in "ZYXWVUTSRQPONMLKJIHGFED".ToCharArray()) {
        if ($drives -notcontains $letter) {
            return $letter
            break
        }
    }
}

# Function for finding and retrieving the specified content.  The source location specifies
# a relative path within the deployment share.  The destination specifies the local path where
# the content should be placed.  If no destination is specified, it will be placed in a
# cache folder.
function Get-PSDContent {
    param (
        [string] $content,
        [string] $destination = ""
    )
    $dest = ""

    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Content:[$content], destination:[$destination]"

    # Track the time
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Track the time"
    $start = Get-Date

    # If the destination is blank, use a default value
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): If the destination is blank, use a default value"
    if ($destination -eq "") {
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Destination is blank, running $PSDLocalDataPath = Get-PSDLocalDataPath"
        $PSDLocalDataPath = Get-PSDLocalDataPath
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PSDLocalDataPath is $PSDLocalDataPath"
        $dest = "$PSDLocalDataPath\Cache\$content"
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Dest is $dest"
    }
    else {
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Destination is NOT blank"
        $dest = $destination
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Dest is $dest"
    }

    # If the destination already exists, assume the content was already downloaded.
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): If the destination already exists, assume the content was already downloaded."
    # Otherwise, download it, copy it, .
    # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Otherwise, download it, copy it."

    if (Test-Path $dest) {
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Access to $dest is OK"
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Already copied $content, not copying again."
    }
    elseif ($global:psddsDeployRoot -ilike "http*") {
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): global:psddsDeployRoot is now $global:psddsDeployRoot"
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running Get-PSDContentWeb -content $content -destination $dest"
        Get-PSDContentWeb -content $content -destination $dest
    }
    elseif ($global:psddsDeployRoot -like "\\*") {
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): global:psddsDeployRoot is now $global:psddsDeployRoot"
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running Get-PSDContentUNC -content $content -destination $dest"
        Get-PSDContentUNC -content $content -destination $dest
    }
    else {
        # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Path for $content is already local, not copying again"
    }

    # Report the time
    $elapsed = (Get-Date) - $start
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Download from $content to $dest took $elapsed"
    # Return the destination
    return $dest
}

# Internal function for retrieving content from a UNC path (file share)
function Get-PSDContentUNC {
    param (
        [string] $content,
        [string] $destination
    )

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying from $($global:psddsDeployRoot)\$content to $destination"
    $Null = Copy-PSDFolder "$($global:psddsDeployRoot)\$content" $destination
}

# Internal function for retrieving content from URL (web server/HTTP)
function Get-PSDContentWeb {
    param (
        [string] $content,
        [string] $destination
    )

    $maxAttempts = 3
    $attempts = 0
    $RetryInterval = 5
    $Retry = $True

    if ($tsenv:BranchCacheEnabled -eq "YES") {
        if ($tsenv:SMSTSDownloadProgram -ne "" -or $tsenv:SMSTSDownloadProgram -ne $null) {
            if ((Get-Process | Where-Object Name -EQ tsmanager).count -ge 1) {

                # Create the destination folder
                # Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating $destination"
                try {
                    New-Item -Path $destination -ItemType Directory -Force | Out-Null
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating $destination was a success"
                }
                catch {
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating $destination was a failure"
                    Return
                }

                # Make some calc...
                $fullSource = "$($global:psddsDeployRoot)/$content"
                $fullSource = $fullSource.Replace("\", "/")
                #$request = [System.Net.WebRequest]::Create($fullSource)
                $topUri = New-Object system.uri $fullSource
                #$prefixLen = $topUri.LocalPath.Length

                # We are using an ACP/ assume it works in WinPE as well. We use ACP as BITS does not function as regular BITS in WinPE, so cannot use PS cmdlet.
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Downloading files using ACP."

                # Begin create regular ACP style .ini file
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create regular ACP style .ini file"

                #Needed, do not remove.
                $PSDPkgId = "PSD12345"

                # Create regular ACP style .ini file
                $iniPath = "$env:tmp\$PSDPkgId" + "_Download.ini"
                Set-Content -Value '[Download]' -Path $iniPath -Force -Encoding Ascii
                Add-Content -Value "Source=$topUri" -Path $iniPath
                Add-Content -Value "Destination=$destination" -Path $iniPath
                Add-Content -Value "MDT=true" -Path $iniPath

                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Destination=$destination"
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Source=$topUri"

                if ((Get-Process | Where-Object Name -EQ TSManager).count -ne 0) {
                    Add-Content -Value "Username=$($tsenv:UserDomain)\$($tsenv:UserID)" -Path $iniPath
                    Add-Content -Value "Password=$($tsenv:UserPassword)" -Path $iniPath
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Username=$($tsenv:UserDomain)\$($tsenv:UserID)"
                }

                # ToDo, check that the ini file exists before we try...
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Downloading information saved to $iniPath so starting $tsenv:SMSTSDownloadProgram"

                if ((Test-Path -Path $iniPath) -eq $true) {
                    #Start-Process -Wait -FilePath "$tsenv:SMSTSDownloadProgram" -ArgumentList "$iniPath $PSDPkgId `"$($destination)`""
                    $return = Start-Process -Wait -WindowStyle Hidden -FilePath "$tsenv:SMSTSDownloadProgram" -ArgumentList "$iniPath $PSDPkgId `"$($destination)`"" -PassThru
                    if ($return.ExitCode -eq 0) {
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $tsenv:SMSTSDownloadProgram Success"
                        $Retry = $False
                        Return
                    }
                    else {
                        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $tsenv:SMSTSDownloadProgram Fail with exitcode $($return.ExitCode)" -Loglevel 2
                    }
                    # ToDo hash verification?
                }
                else {
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to access $iniPath, aborting..." -Loglevel 2
                    # Show-PSDInfo -Message "Unable to access $iniPath, aborting..." -Severity Information
                    # Start-Process PowerShell -Wait
                    # Exit 1
                }
            }
            else {
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to use ACP since TSManager is not running, using fallback"
            }
        }
    }

    while ($Retry) {
        $attempts++
        try {
            $fullSource = "$($global:psddsDeployRoot)/$content"
            $fullSource = $fullSource.Replace("\", "/")

            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Retrieving directory listing of $fullSource via WebDAV."
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Attempt $attempts of $maxAttempts"

            $request = [System.Net.WebRequest]::Create($fullSource)
            $topUri = new-object system.uri $fullSource
            $prefixLen = $topUri.LocalPath.Length

            $request.UserAgent = "PSD"
            $request.Method = "PROPFIND"
            $request.ContentType = "text/xml"
            $request.Headers.Set("Depth", "infinity")
            $request.Credentials = $global:psddsCredential

            $response = $request.GetResponse()
            $Retry = $False
        }
        catch {
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to retrieve directory listing!"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $($_.Exception.InnerException)"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $response"

            if ($attempts -ge $maxAttempts) {
                # Needs testing and validation
                $Message = "Unable to Retrieve directory listing of $($fullSource) via WebDAV. Error message: $($_.Exception.Message)"
                Show-PSDInfo -Message "$($Message)" -Severity Error
                Start-Process PowerShell -Wait
                Throw
            }
            else {
                Start-Sleep -Seconds $RetryInterval
            }
        }
    }

    if ($response -ne $null) {
        $sr = new-object System.IO.StreamReader -ArgumentList $response.GetResponseStream(), [System.Encoding]::Default
        [xml]$xml = $sr.ReadToEnd()

        # Get the list of files and folders, to make this easier to work with
        $results = @()
        $xml.multistatus.response | ? { $_.href -ine $url } | % {
            $uri = new-object system.uri $_.href
            $dest = $uri.LocalPath.Replace("/", "\").Substring($prefixLen).Trim("\")
            $obj = [PSCustomObject]@{
                href         = $_.href
                name         = $_.propstat.prop.displayname
                iscollection = $_.propstat.prop.iscollection
                destination  = $dest
            }
            $results += $obj
        }
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Directory listing retrieved with $($results.Count) items."

        # Create the folder structure
        $results | ? { $_.iscollection -eq "1" } | sort destination | % {
            $folder = "$destination\$($_.destination)"
            if (Test-Path $folder) {
                # Already exists
            }
            else {
                $null = MkDir $folder
            }
        }

        # If possible, do the transfer using BITS.  Otherwise, download the files one at a time
        if ($env:SYSTEMDRIVE -eq "X:") {
            # In Windows PE, download the files one at a time using WebClient
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Downloading files using WebClient."
            $wc = New-Object System.Net.WebClient
            $wc.Credentials = $global:psddsCredential
            $results | ? { $_.iscollection -eq "0" } | sort destination | % {
                $href = $_.href
                $fullFile = "$destination\$($_.destination)"
                try {
                    $wc.DownloadFile($href, $fullFile)
                }
                catch {
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to download file $href."
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $($_.Exception.InnerException)"
                }
            }
        }
        else {
            # Create the list of files to download
            $sourceUrl = @()
            $destFile = @()
            $results | ? { $_.iscollection -eq "0" } | sort destination | % {
                $sourceUrl += [string]$_.href
                $fullFile = "$destination\$($_.destination)"
                $destFile += [string]$fullFile
            }
            # Do the download using BITS
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Downloading files using BITS."
            $bitsJob = Start-BitsTransfer -Authentication Ntlm -Credential $global:psddsCredential -Source $sourceUrl -Destination $destFile -TransferType Download -DisplayName "PSD Transfer" -Priority High
        }
    }
}

# Reconnection logic
if (Test-Path "tsenv:") {
    if ($tsenv:DeployRoot -ne "") {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reconnecting to the deployment share at $($tsenv:DeployRoot)."
        if ($tsenv:UserDomain -ne "") {
            Get-PSDConnection -deployRoot $tsenv:DeployRoot -username "$($tsenv:UserDomain)\$($tsenv:UserID)" -password $tsenv:UserPassword
        }
        else {
            Get-PSDConnection -deployRoot $tsenv:DeployRoot -username $tsenv:UserID -password $tsenv:UserPassword
        }
    }
}

function Test-PSDContent {
    param (
        [string] $content
    )
    if ($global:psddsDeployRoot -ilike "http*") {
        Return Test-PSDContentWeb -content $content
    }
    if ($global:psddsDeployRoot -like "\\*") {
        Return Test-PSDContentUNC -content $content
    }
}
function Test-PSDContentWeb {
    param (
        [string] $content
    )

    $maxAttempts = 3
    $attempts = 0
    $RetryInterval = 5
    $Retry = $True

    while ($Retry) {
        $attempts++
        try {
            #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Retrieving directory listing of $fullSource via WebDAV."
            #Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Attempt $attempts of $maxAttempts"

            $fullSource = "$($global:psddsDeployRoot)/$content"
            $fullSource = $fullSource.Replace("\", "/")
            $request = [System.Net.WebRequest]::Create($fullSource)
            $topUri = new-object system.uri $fullSource
            $prefixLen = $topUri.LocalPath.Length

            $request.UserAgent = "PSD"
            $request.Method = "PROPFIND"
            $request.ContentType = "text/xml"
            $request.Headers.Set("Depth", "infinity")
            $request.Credentials = $global:psddsCredential

            $response = $request.GetResponse()
            $Retry = $False
        }
        catch {
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to retrieve directory listing!"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $($_.Exception.InnerException)"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $response"


            if ($attempts -ge $maxAttempts) {
                $Message = "Unable to Retrieve directory listing of $($fullSource) via WebDAV. Error message: $($_.Exception.Message)"
                Show-PSDInfo -Message "$($Message)" -Severity Error
                Start-Process PowerShell -Wait
                Throw
            }
            else {
                Start-Sleep -Seconds $RetryInterval
            }
        }
    }

    if ($response -ne $null) {
        $sr = new-object System.IO.StreamReader -ArgumentList $response.GetResponseStream(), [System.Encoding]::Default
        [xml]$xml = $sr.ReadToEnd()

        # Get the list of files and folders, to make this easier to work with
        $results = @()
        $xml.multistatus.response | ? { $_.href -ine $url } | % {
            $uri = new-object system.uri $_.href
            $dest = $uri.LocalPath.Replace("/", "\").Substring($prefixLen).Trim("\")
            $obj = [PSCustomObject]@{
                href         = $_.href
                name         = $_.propstat.prop.displayname
                iscollection = $_.propstat.prop.iscollection
                destination  = $dest
            }
            $results += $obj
        }
    }
    Return $results
}
function Test-PSDContentUNC {
    param (
        [string] $content
    )
    Get-ChildItem "$($global:psddsDeployRoot)\$content"
}

Export-ModuleMember -function Get-PSDConnection
Export-ModuleMember -function Get-PSDContent
Export-ModuleMember -function Test-PSDContent