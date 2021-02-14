<#
.SYNOPSIS

.DESCRIPTION

.LINK

.NOTES
          FileName: SyncDepShareTOInstallPSD.ps1
          Solution: PowerShell Deployment for MDT
          Purpose: Syncs a deploymentshare with install psd
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus , @SoupAtWork , @JordanTheItGuy, @PowershellCrack
          Primary: @Mikael_Nystrom
          Created:
          Modified: 2021-01-08

          Version - 0.0.0 - () - Finalized functional version 1.
          Version - 0.0.1 - () - Modified array of folders to be created
          Version - 0.0.2 - () - Added force switch and fixed deploymentshare check
          TODO:

.Example
#>

#Requires -RunAsAdministrator
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=0)]
    $psDeploymentShare,
    $PSDInstallerPathPath
)

function Copy-WithProgress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Source,
        [Parameter(Mandatory = $true)]
        [string] $Destination,
        [int] $Gap = 0,
        [int] $ReportGap = 200,
        [ValidateSet("Directories","Files")]
        [string] $ExcludeType,
        [string] $Exclude,
        [string] $ProgressDisplayName,
        [switch] $Passthru
    )
    # Define regular expression that will gather number of bytes copied
    $RegexBytes = '(?<=\s+)\d+(?=\s+)';

    #region Robocopy params
    # MIR = Mirror mode
    # NP  = Don't show progress percentage in log
    # NC  = Don't log file classes (existing, new file, etc.)
    # BYTES = Show file sizes in bytes
    # NJH = Do not display robocopy job header (JH)
    # NJS = Do not display robocopy job summary (JS)
    # TEE = Display log in stdout AND in target log file
    # XF file [file]... :: eXclude Files matching given names/paths/wildcards.
    # XD dirs [dirs]... :: eXclude Directories matching given names/paths.
    $CommonRobocopyParams = '/MIR /NP /NDL /NC /BYTES /NJH /NJS';

    switch ($ExcludeType){
        Files { $CommonRobocopyParams += ' /XF {0}' -f $Exclude };
	    Directories { $CommonRobocopyParams += ' /XD {0}' -f $Exclude };
    }

    #endregion Robocopy params
    #generate log format
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'

    #region Robocopy Staging
    Write-Verbose -Message 'Analyzing robocopy job ...';
    $StagingLogPath = '{0}\robocopy-staging-{1}.log' -f $env:temp, (Get-Date -Format 'yyyy-MM-dd hh-mm-ss');

    $StagingArgumentList = '"{0}" "{1}" /LOG:"{2}" /L {3}' -f $Source, $Destination, $StagingLogPath, $CommonRobocopyParams;
    Write-Verbose -Message ('Staging arguments: {0}' -f $StagingArgumentList);
    Start-Process -Wait -FilePath robocopy.exe -ArgumentList $StagingArgumentList -WindowStyle Hidden;
    # Get the total number of files that will be copied
    $StagingContent = Get-Content -Path $StagingLogPath;
    $TotalFileCount = $StagingContent.Count - 1;

    # Get the total number of bytes to be copied
    [RegEx]::Matches(($StagingContent -join "`n"), $RegexBytes) | % { $BytesTotal = 0; } { $BytesTotal += $_.Value; };
    Write-Verbose -Message ('Total bytes to be copied: {0}' -f $BytesTotal);
    #endregion Robocopy Staging

    #region Start Robocopy
    # Begin the robocopy process
    $RobocopyLogPath = '{0}\robocopy-{1}.log' -f $env:temp, (Get-Date -Format 'yyyy-MM-dd hh-mm-ss');
    $ArgumentList = '"{0}" "{1}" /LOG:"{2}" /ipg:{3} {4}' -f $Source, $Destination, $RobocopyLogPath, $Gap, $CommonRobocopyParams;
    Write-Verbose -Message ('Beginning the robocopy process with arguments: {0}' -f $ArgumentList);
    $Robocopy = Start-Process -FilePath robocopy.exe -ArgumentList $ArgumentList -Verbose -PassThru -WindowStyle Hidden;
    Start-Sleep -Milliseconds 100;
    #endregion Start Robocopy

    #region Progress bar loop
    while (!$Robocopy.HasExited) {
        Start-Sleep -Milliseconds $ReportGap;
        $BytesCopied = 0;
        $LogContent = Get-Content -Path $RobocopyLogPath;
        $BytesCopied = [Regex]::Matches($LogContent, $RegexBytes) | ForEach-Object -Process { $BytesCopied += $_.Value; } -End { $BytesCopied; };
        $CopiedFileCount = $LogContent.Count - 1;
        Write-Verbose -Message ('Bytes copied: {0}' -f $BytesCopied);
        Write-Verbose -Message ('Files copied: {0}' -f $LogContent.Count);
        $Percentage = 0;
        if ($BytesCopied -gt 0) {
           $Percentage = (($BytesCopied/$BytesTotal)*100)
        }
        If ($ProgressDisplayName){$ActivityDisplayName = $ProgressDisplayName}Else{$ActivityDisplayName = 'Robocopy'}
        Write-Progress -Activity $ActivityDisplayName -Status ("Copied {0} of {1} files; Copied {2} of {3} bytes" -f $CopiedFileCount, $TotalFileCount, $BytesCopied, $BytesTotal) -PercentComplete $Percentage
    }
    #endregion Progress loop

    #region Function output
    If($Passthru){
        [PSCustomObject]@{
            BytesCopied = $BytesCopied;
            FilesCopied = $CopiedFileCount;
        };
    }
    #endregion Function output
}


if(!$PSBoundParameters.ContainsKey('psDeploymentShare')){
    Write-Error "You have not specified the -psDeploymentShare"
    Break
}

if(!$PSBoundParameters.ContainsKey('PSDInstallerPath')){
    Write-Host "Using default path $PSScriptRoot" -ForegroundColor Yellow
    $PSDInstallerPath = $PSScriptRoot
}


Write-Host "Syncing Scripts from $psDeploymentShare to $PSDInstallerPath..." 
Copy-WithProgress -Source "$psDeploymentShare\Scripts" -Destination "$PSDInstallerPath\Scripts" -ProgressDisplayName "Copying Script files from $psDeploymentShare..."
Write-Host "Syncing Templates from $psDeploymentShare to $PSDInstallerPath..."
Copy-WithProgress -Source "$psDeploymentShare\Templates" -Destination "$PSDInstallerPath\Templates" -ProgressDisplayName "Copying Templates files from $psDeploymentShare..."
Write-Host "Syncing PSDResources from $psDeploymentShare to $PSDInstallerPath..."
Copy-WithProgress -Source "$psDeploymentShare\PSDResources" -Destination "$PSDInstallerPath\PSDResources" -ProgressDisplayName "Copying PSDResources files from $psDeploymentShare..."
Move-Item "$PSDInstallerPath\Scripts\PSDWizard\PSDWizard.Initialize.ps1" "$PSDInstallerPath\Scripts"


# Copy the script modules to the right places
Write-Host "Copying PSD Modules to $psDeploymentShare..."
$Modules = "PSDGather", "PSDDeploymentShare", "PSDUtility", "PSDWizard" 
Foreach($ModuleFile in $Modules){
    Write-Host "Copying module $ModuleFile.psm1 to $PSDInstallerPath\Scripts"
    Copy-Item "$psDeploymentShare\Tools\Modules\$ModuleFile\$ModuleFile.psm1" "$PSDInstallerPath\Scripts" -Force
}

Write-Host "Sync Complete from $psDeploymentShare to $PSDInstallerPath..." -ForegroundColor Green