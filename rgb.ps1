<#
	Скрипт предлагает выбрать .exe файл OpenRGB или SignalRGB для записи путей.
	
	Заданное в скрипте время регулирует момент, когда включатся следующие опции:
	1. Начинать с экрана входа в систему через $time
	2. При питании от сети отключать мой экран через $time
	
	Этот автоматический триггер используется в планировщике:
	1. Задание RGB_OFF с триггером блокирования ПК для выключения подсветки
	2. Задание RGB_ON c триггером разблокирования ПК для включения подсветки
	
	ПК автоматически переходит на экран входа через заданное время, монитор выключается и активируется задание RGB_OFF.
	По возвращению на рабочий стол активируется задание RGB_ON.
#>

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
	$host.ui.RawUI.WindowTitle = 'initialization'
	$o = $MyInvocation.line
	Start-Process powershell "-ExecutionPolicy Bypass `"cd '$pwd'; $o`"" -Verb RunAs
	taskkill /fi "WINDOWTITLE eq initialization"
} else
{
	$host.ui.RawUI.WindowTitle = 'uffemcev rgb'
	cls
}

function install
{	
	Add-Type -AssemblyName System.Windows.Forms
	$b = New-Object System.Windows.Forms.OpenFileDialog
	$b.InitialDirectory = [Environment]::GetFolderPath('Desktop') 
	$b.MultiSelect = $false
	$b.Filter = 'RGB software|*.exe'
	$b.ShowDialog()
	$filepath = Split-Path -Parent $b.FileName
	$filename = Split-Path -Leaf $b.FileName
	
	$stateChangeTrigger = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
	$onUnlockTrigger = New-CimInstance -CimClass $stateChangeTrigger -Property @{StateChange = 8} -ClientOnly
	$onLockTrigger = New-CimInstance -CimClass $stateChangeTrigger -Property @{StateChange = 7} -ClientOnly
	$Principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest
	$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
	
	$SignalRGB_ON = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'signalrgb://effect/apply/Solid%20Color?color=white&-silentlaunch-'"
	$SignalRGB_OFF = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'signalrgb://effect/apply/Solid%20Color?color=black&-silentlaunch-'"
	$OpenRGB_ON = New-ScheduledTaskAction -Execute $filename -Argument "--noautoconnect --color white --mode direct" -WorkingDirectory $filepath
	$OpenRGB_OFF = New-ScheduledTaskAction -Execute $filename -Argument "--noautoconnect --color black --mode direct" -WorkingDirectory $filepath
	
	if ($filename -eq 'SignalRgbLauncher.exe')
	{
		Start-Process 'signalrgb://effect/install/Solid%20Color?&-silentlaunch-'
		Register-ScheduledTask RGB_ON -InputObject (New-ScheduledTask -Action ($SignalRGB_ON) -Principal ($Principal) -Trigger ($onUnlockTrigger) -Settings ($Settings))
		Register-ScheduledTask RGB_OFF -InputObject (New-ScheduledTask -Action ($SignalRGB_OFF) -Principal ($Principal) -Trigger ($onLockTrigger) -Settings ($Settings))
	} elseif ($filename -eq 'OpenRGB.exe')
	{
		Register-ScheduledTask RGB_ON -InputObject (New-ScheduledTask -Action ($OpenRGB_ON) -Principal ($Principal) -Trigger ($onUnlockTrigger) -Settings ($Settings))
		Register-ScheduledTask RGB_OFF -InputObject (New-ScheduledTask -Action ($OpenRGB_OFF) -Principal ($Principal) -Trigger ($onLockTrigger) -Settings ($Settings))
	} else
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
	goexit
}

function reset
{
	reg delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /f
	reg delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /f
	Unregister-ScheduledTask -TaskName RGB_ON -Confirm:$false
	Unregister-ScheduledTask -TaskName RGB_OFF -Confirm:$false
	goexit
}
	
function goexit
{
	cls
	write-host "`nInstallation complete"
	start-sleep -seconds 5
	taskkill /fi "WINDOWTITLE eq uffemcev*"
}

Write-Host "`ngithub.com/uffemcev/rgb `n`n[1] Install `n[2] Reset `n[3] Exit"
$button = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
if ($button.VirtualKeyCode -eq 49) {cls; install}
if ($button.VirtualKeyCode -eq 50) {cls; reset}
if ($button.VirtualKeyCode -eq 51) {cls; goexit}
