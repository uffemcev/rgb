<#
	Скрипт предлагает выбрать .exe файл OpenRGB или SignalRGB для записи путей.
	
	Заданное в скрипте время регулирует момент, когда включатся следующие опции:
	1. Начинать с экрана входа в систему через $time
	2. При питании от сети отключать мой экран через $time
	
	Этот автоматический триггер используется в планировщике:
	1. Задание RGB OFF с триггером блокирования ПК для выключения подсветки
	2. Задание RGB ON c триггером разблокирования ПК для включения подсветки
	
	ПК автоматически переходит на экран входа через заданное время, монитор выключается и активируется задание RGB OFF.
	По возвращению на рабочий стол активируется задание RGB ON.
#>

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
	$host.ui.RawUI.WindowTitle = 'initialization'
	$o = $MyInvocation.line
	Start-Process powershell "-ExecutionPolicy Bypass `"cd '$pwd'; $o`"" -Verb RunAs
	taskkill /fi "WINDOWTITLE eq initialization"
} elseif ($host.ui.RawUI.WindowTitle -ne "uffemcev utilities")
{
	$host.ui.RawUI.WindowTitle = 'uffemcev rgb'
} else
{
	$host.ui.RawUI.WindowTitle = 'uffemcev utilities'
}

cls
function install
{	
	Write-Host "`nPlease select OpenRGB.exe or SignalRgbLauncher.exe"
	Add-Type -AssemblyName System.Windows.Forms
	$b = New-Object System.Windows.Forms.OpenFileDialog
	$b.InitialDirectory = [Environment]::GetFolderPath('Desktop') 
	$b.MultiSelect = $false
	$b.Filter = 'RGB software|OpenRGB.exe; SignalRgbLauncher.exe'
	$b.ShowDialog()
	$filepath = Split-Path -Parent $b.FileName
	$filename = Split-Path -Leaf $b.FileName
	
	if ($b.FileName -eq '')
	{
		cls
		Write-Host "`nIncorrect file"
		start-sleep -seconds 5
		goexit
	}

	cls
	$time = Read-Host "`nTime in seconds before monitor and rgb turns off"
	reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /t REG_SZ /d "1" /f
	reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /t REG_SZ /d "$time" /f
	powercfg /setdcvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e $time
	powercfg /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e $time

	$SleepState = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
	$SleepTrigger = New-CimInstance -CimClass $SleepState -ClientOnly
	$SleepTrigger.Subscription = "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[EventID=107]]</Select></Query></QueryList>"
	$LockUnlockState = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
	$LockTrigger = New-CimInstance -CimClass $LockUnlockState -Property @{StateChange = 7} -ClientOnly
	$UnlockTrigger = New-CimInstance -CimClass $LockUnlockState -Property @{StateChange = 8} -ClientOnly
	$LogonTrigger = New-ScheduledTaskTrigger -AtLogon
	$Principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest
	$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
	
	$SignalRGB_ON = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'signalrgb://effect/apply/Solid%20Color?color=white&-silentlaunch-'"
	$SignalRGB_OFF = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'signalrgb://effect/apply/Solid%20Color?color=black&-silentlaunch-'"
	$OpenRGB_ON = New-ScheduledTaskAction -Execute $filename -Argument "--noautoconnect -m direct -c white -b 100" -WorkingDirectory $filepath
	$OpenRGB_OFF = New-ScheduledTaskAction -Execute $filename -Argument "--noautoconnect -m direct -c black -b 0" -WorkingDirectory $filepath
	
	if ($filename -eq 'SignalRgbLauncher.exe')
	{
		Start-Process 'signalrgb://effect/install/Solid%20Color?&-silentlaunch-'
		Register-ScheduledTask "RGB ON" -InputObject (New-ScheduledTask -Action ($SignalRGB_ON) -Principal ($Principal) -Trigger ($UnlockTrigger) -Settings ($Settings))
		Register-ScheduledTask "RGB OFF" -InputObject (New-ScheduledTask -Action ($SignalRGB_OFF) -Principal ($Principal) -Trigger ($LockTrigger) -Settings ($Settings))
	} elseif ($filename -eq 'OpenRGB.exe')
	{
		Register-ScheduledTask "RGB ON" -InputObject (New-ScheduledTask -Action ($OpenRGB_ON) -Principal ($Principal) -Trigger ($UnlockTrigger, $LogonTrigger, $SleepTrigger) -Settings ($Settings))
		Register-ScheduledTask "RGB OFF" -InputObject (New-ScheduledTask -Action ($OpenRGB_OFF) -Principal ($Principal) -Trigger ($LockTrigger) -Settings ($Settings))
	}		
		
	cls
	Write-Host "`nPlease wait"
	start-sleep -seconds 5
	Start-ScheduledTask -TaskName "RGB OFF"
	Start-ScheduledTask -TaskName "RGB ON"
	goexit
}

function reset
{
	reg delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /f
	reg delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /f
	Unregister-ScheduledTask -TaskName *RGB* -Confirm:$false
	goexit
}
	
function goexit
{
	cls
	write-host "`nInstallation complete"
	start-sleep -seconds 5
	taskkill /fi "WINDOWTITLE eq uffemcev rgb"
}

Write-Host "`ngithub.com/uffemcev/rgb `n`n[1] Install `n[2] Reset `n[3] Exit"
$button = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
if ($button.VirtualKeyCode -eq 49) {cls; install}
if ($button.VirtualKeyCode -eq 50) {cls; reset}
if ($button.VirtualKeyCode -eq 51) {cls; goexit}
