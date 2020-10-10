$FrameworkDir=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
$NGENPath = Join-Path $FrameworkDir 'ngen.exe'

$Null = & "$NGENPath" install ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object Location -Like *Microsoft.Management.Infrastructure*).Location /NoDependencies
$Null = & "$NGENPath" install ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object Location -Like *MSCorlib*).Location /NoDependencies
$Null = & "$NGENPath" install ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object Location -Like *System.Management.Automation*).Location /NoDependencies
