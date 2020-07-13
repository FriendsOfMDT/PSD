# // ***************************************************************************
# // 
# // PowerShell Deployment for MDT
# //
# // File:      PSDWindowsUpdate.ps1
# // 
# // Purpose:   Apply the specified operating system.
# // 
# // 
# // ***************************************************************************

param (

)

# Load core modules
Import-Module PSDUtility
Import-Module PSDDeploymentShare

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true)
{
    $verbosePreference = "Continue"
}

# Write to the 
Write-PSDEvent -MessageID 41000 -severity 1 -Message "Starting: $($MyInvocation.MyCommand.Name)"

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Creating COM object for WU"
$objServiceManager = New-Object -ComObject 'Microsoft.Update.ServiceManager';
$objSession = New-Object -ComObject 'Microsoft.Update.Session';
$objSearcher = $objSession.CreateUpdateSearcher();
$objSearcher.ServerSelection = $serverSelection;
$serviceName = 'Windows Update';
$search = 'IsInstalled = 0';
$objResults = $objSearcher.Search($search);
$Updates = $objResults.Updates;
$FoundUpdatesToDownload = $Updates.Count;

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Searching for updates"
$NumberOfUpdate = 1;
$objCollectionDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl';
$updateCount = $Updates.Count;
Foreach($Update in $Updates)
{
	Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Downloading $($Update.Title)"
    Show-PSDActionProgress -Message "Downloading $($Update.Title)" -Step "$NumberOfUpdate" -MaxStep "$ReadyUpdatesToInstall"
	$NumberOfUpdate++;
	Write-Debug `"Show` update` to` download:` $($Update.Title)`" ;
	Write-Debug 'Accept Eula';
	$Update.AcceptEula();
	Write-Debug 'Send update to download collection';
	$objCollectionTmp = New-Object -ComObject 'Microsoft.Update.UpdateColl';
	$objCollectionTmp.Add($Update) | Out-Null;

	$Downloader = $objSession.CreateUpdateDownloader();
	$Downloader.Updates = $objCollectionTmp;
	Try
	{
		Write-Debug 'Try download update';
		$DownloadResult = $Downloader.Download();
	} <#End Try#>
	Catch
	{
		If($_ -match 'HRESULT: 0x80240044')
		{
			Write-Warning 'Your security policy do not allow a non-administator identity to perform this task';
		} <#End If $_ -match 'HRESULT: 0x80240044'#>

		Return
	} <#End Catch#>

	Write-Debug 'Check ResultCode';
	Switch -exact ($DownloadResult.ResultCode)
	{
		0   { $Status = 'NotStarted'; }
		1   { $Status = 'InProgress'; }
		2   { $Status = 'Downloaded'; }
		3   { $Status = 'DownloadedWithErrors'; }
		4   { $Status = 'Failed'; }
		5   { $Status = 'Aborted'; }
	} <#End Switch#>

	If($DownloadResult.ResultCode -eq 2)
	{
		Write-Debug 'Downloaded then send update to next stage';
		$objCollectionDownload.Add($Update) | Out-Null;
	} <#End If $DownloadResult.ResultCode -eq 2#>
}

$ReadyUpdatesToInstall = $objCollectionDownload.count;
Write-Verbose `"Downloaded` [$ReadyUpdatesToInstall]` Updates` to` Install`" ;
If($ReadyUpdatesToInstall -eq 0)
{
	Return;
} <#End If $ReadyUpdatesToInstall -eq 0#>

$NeedsReboot = $false;
$NumberOfUpdate = 1;

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): install updates"
<#install updates#>
Foreach($Update in $objCollectionDownload)
{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Installing update $($Update.Title)"
	Show-PSDActionProgress -Message "Installing $($Update.Title)" -Step "$NumberOfUpdate" -MaxStep "$ReadyUpdatesToInstall"
	Write-Debug "Show update to install: $($Update.Title)"

	Write-Debug 'Send update to install collection';
	$objCollectionTmp = New-Object -ComObject 'Microsoft.Update.UpdateColl';
	$objCollectionTmp.Add($Update) | Out-Null;

	$objInstaller = $objSession.CreateUpdateInstaller();
	$objInstaller.Updates = $objCollectionTmp;

	Try
	{
		Write-Debug 'Try install update';
		$InstallResult = $objInstaller.Install();
	} <#End Try#>
	Catch
	{
		If($_ -match 'HRESULT: 0x80240044')
		{
			Write-Warning 'Your security policy do not allow a non-administator identity to perform this task';
		} <#End If $_ -match 'HRESULT: 0x80240044'#>

		Return;
	} #End Catch

	If(!$NeedsReboot)
	{
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): RebootRequired"
		Write-Debug 'Set instalation status RebootRequired';
		$NeedsReboot = $installResult.RebootRequired;
	} <#End If !$NeedsReboot#>
	$NumberOfUpdate++;
} <#End Foreach $Update in $objCollectionDownload#>

if($NeedsReboot){
    $tsenv:SMSTSRebootRequested = "true"
}
