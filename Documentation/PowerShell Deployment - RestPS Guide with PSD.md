# RestPS Guide with PSD

You can find the full instructions here: https://github.com/jpsider/RestPS

## Scripted Install

A script is provided under the tools to install and setup RestPS. There are some requirements

- a valid certificate
- download nssm executable (https://nssm.cc/download)

```powershell
 .\New-PSDRestPS.ps1 -RestPSRootPath "D:\RestPS" -PathtoNSSMexe "D:\NSSM\nssm.exe" -RestPSListenerPort 8080 -SecretKey "SuperSecret" -CertificateFriendlyName "RestPS" -Test
```

## Manual Install

Perform the steps on the PSD server or another server accessible by the client being deployed. Run these commands first to install and setup RestPS

Install the module

```powershell
Install-Module RestPS -Force
```

Set up a workspace for the module
```powershell
Invoke-DeployRestPS -LocalDir 'C:\RestPS'
```

That is it! Now the keep in mind this will only run if you start a RestPS session. You can do this by simply opening up a powershell window and running the command:

```powershell
$RestPSparams = @{
            RoutesFilePath = 'C:\RestPS\endpoints\RestPSRoutes.json'
            Port = '8080'
         }
Start-RestPSListener @RestPSparams
```

While the listener is running, make sure it is working. RestPS provides a few example endpoints in the file _RestPSRoutes.json_ under under _C:\RestPS\endpoints_. 
In this file contains each endpoint you can call. As an example, the first few lines provide a simple get process:

``json
{
    "RequestType": "GET",
    "RequestURL": "/proc",
    "RequestCommand": "Get-Process -ProcessName PowerShell -ErrorAction SilentlyContinue | Select-Object -Property ProcessName,Id -ErrorAction SilentlyContinue"
  },
```

In another PowerShell Windows, call this in REST by using the command: 

```powershell
Invoke-RestMethod -Uri http://localhost:8080/proc -Method Get
```

Notice the uri is follows the RequestType and URL and the port is the one the listener is using. When called, it triggers the RequestCommand and outputs the results. 

There are other examples within the _RestPSRoutes.json_ that can go further and use scripts. For example, in these lines:

```json
  {
    "RequestType": "GET",
    "RequestURL": "/process",
    "RequestCommand": "c:/RestPS/endPoints/GET/Invoke-GetProcess.ps1"
  },
```

This calls a script from the _c:/RestPS/endPoints/GET_ Folder. in that folder is a `Invoke-GetProcess.ps1` which has one input parameter called RequestArgs.
RequestArgs are a querystrings used in urls. You can trigger them with a key=value pair starting with `?` and then adding `&` consecutively. 

For instance if you want to get the process for Powershell; call it like this:

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/process?name=Powershell '-Method Get
```

This will grab the process running on the server and output the properties. In this script it can handle two querystrings or request arguments (see lines 27 and 28). WIth that the list can be fine tuned such as:

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/process?name=Powershell&MainWindowTitle=RestPS' -Method Get
```

This should return the one powershell process running the RestPS service

## Security Concerns

We higly recommned removing all default endpoints provided with this module. 

## Useful References

- https://www.deploymentresearch.com/using-restps-to-access-the-mdt-database/
- https://deploymentbunny.com/2020/11/15/nice-to-know-running-restps-as-a-service/
- https://github.com/NopeNix/RestPS
- https://github.com/PowerShellCrack/RestPSExamples

## Ideas to cover

Here are some idea we thought could be useful during a PSD task sequence:

- an updated guide on how to run RestPS as a service with SSL
- Instructions on how to use RestPS with PSD within the tasksequence
- Call Intune Graph API to:
  - upload device hash to Autopilot
  - add device to Intune categories
  - onboard device to MDE
- Call Azure Graph API to:
  - add device to Azure group(s)
  - add a value to the device extension attribute
- Offline domain join using djoin command
