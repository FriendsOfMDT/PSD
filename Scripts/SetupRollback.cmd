@echo off
:: // ***************************************************************************
:: //
:: // Copyright (c) Microsoft Corporation.  All rights reserved.
:: //
:: // Microsoft Deployment Toolkit Solution Accelerator
:: //
:: // File:      SetupRollback.cmd
:: //
:: // Version:   6.3.8456.1000
:: //
:: // Purpose:   Called after a failed in-place upgrade.  This batch file
:: //            sets itself to re-run after reboots, and then calls
:: //            LiteTouch.wsf to run the task sequence.
:: //
:: // ***************************************************************************

:: Workaround for incorrectly-registered TS environment
reg delete HKCR\Microsoft.SMS.TSEnvironment /f > nul 2>&1

set _MDTUpgrade=TRUE

reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Windows" /v Win10UpgradeStatusCode /t REG_SZ /d "Failure" /f >> %WINDIR%\SetupRollback.log
reg add "HKEY_LOCAL_MACHINE\SYSTEM\Setup" /v SetupType /t REG_DWORD /d 2 /f >> %WINDIR%\SetupRollback.log
reg add "HKEY_LOCAL_MACHINE\SYSTEM\Setup" /v CmdLine /t REG_SZ /d "%WINDIR%\Setup\Scripts\SetupRollback.cmd" /f >> %WINDIR%\SetupRollback.log
echo %DATE%-%TIME% Registered SetupRollback.cmd in registry >> %WINDIR%\SetupRollback.log

for %%d in (c d e f g h i j k l m n o p q r s t u v w x y z) do if exist %%d:\MININT\Scripts\LiteTouch.wsf (wscript.exe %%d:\MININT\Scripts\LiteTouch.wsf ) 

IF %ERRORLEVEL% EQU -2147021886 (
echo %DATE%-%TIME% ERRORLEVEL = %ERRORLEVEL%  >> %WINDIR%\SetupRollback.log
echo %DATE%-%TIME% LiteTouch.wsf requested reboot >> %WINDIR%\SetupRollback.log
echo %DATE%-%TIME% Rebooting now >> %WINDIR%\SetupRollback.log
reg add "HKEY_LOCAL_MACHINE\SYSTEM\Setup" /v SetupShutdownRequired /t REG_DWORD /d 1 /f
) else (
echo %DATE%-%TIME% ERRORLEVEL = %ERRORLEVEL%  >> %WINDIR%\SetupRollback.log
echo %DATE%-%TIME% LiteTouch.wsf did not request reboot, resetting registry >> %WINDIR%\SetupRollback.log
reg add "HKEY_LOCAL_MACHINE\SYSTEM\Setup" /v SetupType /t REG_DWORD /d 0 /f >> %WINDIR%\SetupRollback.log
reg add "HKEY_LOCAL_MACHINE\SYSTEM\Setup" /v CmdLine /t REG_SZ /d "" /f >> %WINDIR%\SetupRollback.log
set _MDTCleanup=TRUE
)

echo %DATE%-%TIME% Exiting SetupRollback.cmd >> %WINDIR%\SetupRollback.log

if "%_MDTCleanup%" EQU "TRUE" (
del %WINDIR%\Setup\Scripts\SetupComplete.cmd
del %WINDIR%\Setup\Scripts\SetupRollback.cmd
)