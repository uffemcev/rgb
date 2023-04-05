@echo off
Setlocal EnableDelayedExpansion

set /a time = 900

for /f %%i in ('dir /a:-d /b "%~dp0OpenRGB.exe" "%~dp0SignalRgbLauncher.exe"') do (
	set app=%%i
	schtasks /query /tn "RGB" > nul
	if !errorlevel!==0 (goto switch) else (goto install)
)
if not defined app (cls & echo Exe not found & ping -n 5 127.0.0.1 > nul & exit)

:install
reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /t REG_SZ /d "1" /f
reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /t REG_SZ /d "%time%" /f
powercfg.exe /setdcvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e %time%
powercfg.exe /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e %time%
powershell.exe -command "Set-ExecutionPolicy Bypass -Scope Process -Force; $stateChangeTrigger = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger; $onUnlockTrigger = New-CimInstance -CimClass $stateChangeTrigger -Property @{StateChange = 8} -ClientOnly; $onLockTrigger = New-CimInstance -CimClass $stateChangeTrigger -Property @{StateChange = 7} -ClientOnly; Register-ScheduledTask RGB -InputObject (New-ScheduledTask -Action (New-ScheduledTaskAction -Execute '\"%0\"') -Principal (New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest) -Trigger ($onUnlockTrigger, $onLockTrigger) -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries))" > nul
cls & echo Installation in progress & ping -n 5 127.0.0.1 > nul & exit

:switch
set "$activ="
2> nul (set /P $activ= < "%~nx0:activ") || set "$activ=toggle"
echo actual [%$activ%] > nul
if /i "%$activ%"=="toggle" (
	if %app%==SignalRgbLauncher.exe (start signalrgb://effect/apply/Solid%%20Color?color=black^&-silentlaunch-)
	if %app%==OpenRGB.exe ("%~dp0OpenRGB.exe" --noautoconnect --color black --mode direct)
	echo headset>%~nx0:activ
	) else (
	if %app%==SignalRgbLauncher.exe (start signalrgb://effect/apply/Solid%%20Color?color=white^&-silentlaunch-)
	if %app%==OpenRGB.exe ("%~dp0OpenRGB.exe" --noautoconnect --color white --mode direct)
	echo toggle>%~nx0:activ
)
