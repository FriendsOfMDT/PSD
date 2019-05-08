# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDDeploymentShare.psd1
# // 
# // Purpose:   Connect to a deployment share and obtain content from it, using
# //            either HTTP or SMB as needed.
# // 
# // ***************************************************************************

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Importing module Bitstransfer"
#$VerbosePreference = "SilentlyContinue"

Import-Module BitsTransfer -Global
#$verbosePreference = "Continue"

# Local variables
$global:psddsDeployRoot = ""
$global:psddsDeployUser = ""
$global:psddsDeployPassword = ""
$global:psddsCredential = ""

# Main function for establishing a connection 
function Get-PSDConnection 
{
    param (
        [string] $deployRoot,
        [string] $username,
        [string] $password
    )

    # Save values in local variables
    $global:psddsDeployRoot = $deployRoot
    $global:psddsDeployUser = $username
    $global:psddsDeployPassword = $password

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): global:psddsDeployRoot is now $global:psddsDeployRoot"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): global:psddsDeployUser is now $global:psddsDeployUser"
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): global:psddsDeployPassword is now $global:psddsDeployPassword"

    # Get credentials
    if (!$global:psddsDeployUser -or !$global:psddsDeployPassword)
    {
        $global:psddsCredential = Get-Credential -Message "Specify credentials needed to connect to $uncPath"
    }
    else
    {
        $secure = ConvertTo-SecureString $global:psddsDeployPassword -AsPlainText -Force
        $global:psddsCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $global:psddsDeployUser, $secure
    }

    # Make sure we can connect to the specified location
    if ($global:psddsDeployRoot -ilike "http*")
    {
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
        try
        {
            New-PSDrive -Name (Get-PSDAvailableDriveLetter) -PSProvider FileSystem -Root $global:psddsDeployRoot -Credential $global:psddsCredential -Scope Global
        }
        catch
        {
            
        }
        Get-PSDProvider -DeployRoot $global:psddsDeployRoot
    }
    else
    {
        # Connect to a local path (no credential needed)
        Get-PSDProvider -DeployRoot $global:psddsDeployRoot
    }

}

# Internal function for initializing the MDT PowerShell provider, to be used to get 
# objects from the MDT deployment share.
function Get-PSDProvider
{
    param (
        [string] $deployRoot
    )

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): deployRoot is now $deployRoot"

    # Set an install directory if necessary (needed so the provider can find templates)
    if ((Test-Path "HKLM:\Software\Microsoft\Deployment 4") -eq $false)
    {
        $null = New-Item "HKLM:\Software\Microsoft\Deployment 4"
        Set-ItemProperty "HKLM:\Software\Microsoft\Deployment 4" -Name "Install_Dir" -Value "$deployRoot\"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Set MDT Install_Dir to $deployRoot\ for MDT Provider."
    }

    # Load the PSSnapIn PowerShell provider module
    $modules = Get-PSDContent -Content "Tools\Modules"
    $VerbosePreference = "SilentlyContinue"
    Import-Module "$modules\Microsoft.BDD.PSSnapIn"
    $verbosePreference = "Continue"


    # Create the PSDrive
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating MDT provider drive DeploymentShare: at $deployRoot"
    New-PSDrive -Name DeploymentShare -PSProvider MDTProvider -Root $deployRoot -Scope Global
}

# Internal function for getting the next available drive letter.
function Get-PSDAvailableDriveLetter 
{
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
function Get-PSDContent
{
    param (
        [string] $content,
        [string] $destination = ""
    )

    $verbosePreference = "Continue"
    $dest = ""

    # Track the time
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Track the time"
    $start = Get-Date

    # If the destination is blank, use a default value
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): If the destination is blank, use a default value"
    if ($destination -eq "")
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Destination is blank, setting value Dest"
        $PSDLocalDataPath = Get-PSDLocalDataPath
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PSDLocalDataPath is $PSDLocalDataPath"
        $dest = "$PSDLocalDataPath\Cache\$content"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Dest is $dest"
    }
    else
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Destination is NOT blank"
        $dest = $destination
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Dest is $dest"
    }

    # If the destination already exists, assume the content was already downloaded.
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): If the destination already exists, assume the content was already downloaded."
    # Otherwise, download it, copy it, .
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Otherwise, download it, copy it."

    if (Test-Path $dest)
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Access to $dest is OK"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Already copied $content, not copying again."
    }
    elseif ($global:psddsDeployRoot -ilike "http*")
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): global:psddsDeployRoot is now $global:psddsDeployRoot"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running Get-PSDContentWeb -content $content -destination $dest"
        Get-PSDContentWeb -content $content -destination $dest
    }
    elseif ($global:psddsDeployRoot -like "\\*")
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): global:psddsDeployRoot is now $global:psddsDeployRoot"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Running Get-PSDContentUNC -content $content -destination $dest"
        Get-PSDContentUNC -content $content -destination $dest
    }
    else
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Path for $content is already local, not copying again"
    }

    # Report the time
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Report the time"
    $elapsed = (Get-Date) - $start
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Elapsed time to transfer $content : $elapsed"
    # Return the destination
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Return the destination $dest"
    return $dest
}

# Internal function for retrieving content from a UNC path (file share)
function Get-PSDContentUNC
{
    param (
        [string] $content,
        [string] $destination
    )

    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying from $($global:psddsDeployRoot)\$content to $destination"
    Copy-PSDFolder "$($global:psddsDeployRoot)\$content" $destination
}

# Internal function for retrieving content from URL (web server/HTTP)
function Get-PSDContentWeb
{
    param (
        [string] $content,
        [string] $destination
    )
    
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
          
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Retrieving directory listing of $fullSource via WebDAV."
    try
    {  
        $response = $request.GetResponse()
    }
    catch
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to retrieve directory listing!"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $($_.Exception.InnerException)"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $response"
        #$Message = "Unable to Retrieve directory listing of $($fullSource) via WebDAV. Error message: $($_.Exception.Message)"
        #Show-PSDInfo -Message "$($Message)" -Severity Error
        #Start-Process PowerShell -Wait
        #Break 
    }
	
	if ($response -ne $null)
    {
        $sr = new-object System.IO.StreamReader -ArgumentList $response.GetResponseStream(),[System.Encoding]::Default
        [xml]$xml = $sr.ReadToEnd()		

        # Get the list of files and folders, to make this easier to work with
    	$results = @()
        $xml.multistatus.response | ? { $_.href -ine $url } | % {
            $uri = new-object system.uri $_.href
            $dest = $uri.LocalPath.Replace("/","\").Substring($prefixLen).Trim("\")
            $obj = [PSCustomObject]@{
                href = $_.href
                name = $_.propstat.prop.displayname
                iscollection = $_.propstat.prop.iscollection
                destination = $dest
            }
            $results += $obj
        }
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Directory listing retrieved with $($results.Count) items."

        # Create the folder structure
        $results | ? { $_.iscollection -eq "1"} | sort destination | % {
            $folder = "$destination\$($_.destination)"
            if (Test-Path $folder)
            {
                # Already exists
            }
            else
            {
                $null = MkDir $folder
            }
        }

        # If possible, do the transfer using ACP or BITS.  Otherwise, download the files one at a time
        if($tsenv:SMSTSDownloadProgram)
        {
            #We are using an ACP/ assume it works in WinPE as well. We use ACP as BITS does not function as regular BITS in WinPE, so cannot use PS cmdlet.
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Downloading files using ACP."

            # Begin create regular ACP style .ini file
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create regular ACP style .ini file"

            #Needed, do not remove.
            $PSDPkgId = "PSD12345" 

            # Create regular ACP style .ini file
            $iniPath = "$env:tmp\$PSDPkgId"+"_Download.ini"
            Set-Content -Value '[Download]' -Path $iniPath -Force -Encoding Ascii
            Add-Content -Value "Source=$topUri" -Path $iniPath
            Add-Content -Value "Destination=$destination" -Path $iniPath
            Add-Content -Value "MDT=true" -Path $iniPath
            
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Destination=$destination"
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Source=$topUri"

            # ToDo, check that the ini file exists before we try...
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Downloading information saved to $iniPath so starting $tsenv:SMSTSDownloadProgram"

            if((Test-Path -Path $iniPath) -eq $true)
            {
                #Start-Process -Wait -FilePath "$tsenv:SMSTSDownloadProgram" -ArgumentList "$iniPath $PSDPkgId `"$($destination)`""
                Start-Process -Wait -WindowStyle Hidden -FilePath "$tsenv:SMSTSDownloadProgram" -ArgumentList "$iniPath $PSDPkgId `"$($destination)`""
                # ToDo hash verification?
            }
            else
            {
                Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to access $iniPath, aborting..."
                Show-PSDInfo -Message "Unable to access $iniPath, aborting..." -Severity Information
                Start-Process PowerShell -Wait
                Exit 1
            }
        }

        # If possible, do the transfer using BITS.  Otherwise, download the files one at a time
        elseif ($env:SYSTEMDRIVE -eq "X:")
        {
            # In Windows PE, download the files one at a time using WebClient
            Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Downloading files using WebClient."
            $wc = New-Object System.Net.WebClient
            $wc.Credentials = $global:psddsCredential
            $results | ? { $_.iscollection -eq "0"} | sort destination | % {
                $href = $_.href
                $fullFile = "$destination\$($_.destination)"
                try
                {
                    $wc.DownloadFile($href, $fullFile)
                }
                catch
                {
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Unable to download file $href."
                    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $($_.Exception.InnerException)"
                }
            }            
        }
        else
        {
            # Create the list of files to download
            $sourceUrl = @()
            $destFile = @()
            $results | ? { $_.iscollection -eq "0"} | sort destination | % {
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

Export-ModuleMember -function Get-PSDConnection
Export-ModuleMember -function Get-PSDContent

# Reconnection logic
if (Test-Path "tsenv:")
{
    if ($tsenv:DeployRoot -ne "")
    {
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Reconnecting to the deployment share at $($tsenv:DeployRoot)."
        if ($tsenv:UserDomain -ne "")
        {
            Get-PSDConnection -deployRoot $tsenv:DeployRoot -username "$($tsenv:UserDomain)\$($tsenv:UserID)" -password $tsenv:UserPassword
        }
        else
        {
            Get-PSDConnection -deployRoot $tsenv:DeployRoot -username $tsenv:UserID -password $tsenv:UserPassword
        }
    }
}
