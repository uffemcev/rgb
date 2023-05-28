<#
	Скрипт предлагает выбрать .exe файл OpenRGB или SignalRGB для записи путей.
	
	Заданное в скрипте время регулирует момент, когда включатся следующие опции:
	1. Включать экран блокировки через $locktime
	2. При питании от сети отключать мой экран через $locktime
	3. Переходить в режим сна через $sleeptime
	
	Этот автоматический триггер используется в планировщике:
	1. Задание RGB OFF с триггером блокирования ПК для выключения подсветки
	2. Задание RGB ON c триггером разблокирования ПК для включения подсветки
	
	ПК автоматически включает экран блокировки через заданное время, монитор выключается и активируется задание RGB OFF.
	По возвращению на рабочий стол активируется задание RGB ON.
#>

[CmdletBinding()]
param([string]$option, [int]$locktime, [int]$sleeptime)

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
	$host.ui.RawUI.WindowTitle = 'initialization'
	$MyInvocation.line | where {Start-Process powershell "-ExecutionPolicy Bypass `"cd '$pwd'; $_`"" -Verb RunAs}
	$host.ui.RawUI.WindowTitle | where {taskkill /fi "WINDOWTITLE eq $_"}
} else
{
	$host.ui.RawUI.WindowTitle = 'uffemcev rgb'
}

function install
{	
	if (!(dir -ErrorAction SilentlyContinue -Force | where {$_ -match 'OpenRGB.exe|SignalRgbLauncher.exe'}))
	{
		$host.ui.RawUI.WindowTitle = 'uffemcev rgb'
		"`nPlease select OpenRGB.exe or SignalRgbLauncher.exe"
		Add-Type -AssemblyName System.Windows.Forms
		$b = New-Object System.Windows.Forms.OpenFileDialog
		$b.InitialDirectory = [Environment]::GetFolderPath('Desktop') 
		$b.MultiSelect = $false
		$b.Filter = 'RGB software|OpenRGB.exe; SignalRgbLauncher.exe'
		$b.ShowDialog()
		if ($b.FileName -eq '') {goexit}
		$filepath = Split-Path -Parent $b.FileName
		$filename = Split-Path -Leaf $b.FileName
	} else
	{
		dir -ErrorAction SilentlyContinue -Force | where {$_ -match 'OpenRGB.exe|SignalRgbLauncher.exe'} | where {
			$filepath = Split-Path -Parent $_.FullName
			$filename = $_.Name
		}
	}
	
	if (!$locktime) {$locktime = Read-Host "`nTime in seconds before display and lights turns off"}
	if (!$sleeptime) {$sleeptime = Read-Host "`nTime in seconds before pc goes to sleep"}
	reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /t REG_SZ /d "1" /f
	reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /t REG_SZ /d "$time" /f
	powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_VIDEO VIDEOIDLE $locktime
	powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_VIDEO VIDEOIDLE $locktime
	powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP STANDBYIDLE $sleeptime
	powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP STANDBYIDLE $sleeptime

	$SleepState = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
	$SleepTrigger = New-CimInstance -CimClass $SleepState -ClientOnly
	$SleepTrigger.Subscription = "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[EventID=107]]</Select></Query></QueryList>"
	$LockUnlockState = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
	$LockTrigger = New-CimInstance -CimClass $LockUnlockState -Property @{StateChange = 7} -ClientOnly
	$UnlockTrigger = New-CimInstance -CimClass $LockUnlockState -Property @{StateChange = 8} -ClientOnly
	$LogonTrigger = New-ScheduledTaskTrigger -AtLogon
	$Principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest
	$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
	
	if ($filename -eq 'SignalRgbLauncher.exe')
	{
		Start-Process 'signalrgb://effect/install/Solid%20Color?&-silentlaunch-'
		$RGBON = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'signalrgb://effect/apply/Solid%20Color?color=white&-silentlaunch-'"
		$RGBOFF = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'signalrgb://effect/apply/Solid%20Color?color=black&-silentlaunch-'"
		Register-ScheduledTask "RGB ON" -InputObject (New-ScheduledTask -Action ($RGBON) -Principal ($Principal) -Trigger ($UnlockTrigger) -Settings ($Settings))
		Register-ScheduledTask "RGB OFF" -InputObject (New-ScheduledTask -Action ($RGBOFF) -Principal ($Principal) -Trigger ($LockTrigger) -Settings ($Settings))
	} elseif ($filename -eq 'OpenRGB.exe')
	{
		$RGBON = New-ScheduledTaskAction -Execute $filename -Argument "--noautoconnect -m direct -c white -b 100" -WorkingDirectory $filepath
		$RGBOFF = New-ScheduledTaskAction -Execute $filename -Argument "--noautoconnect -m direct -c black -b 0" -WorkingDirectory $filepath
		Register-ScheduledTask "RGB ON" -InputObject (New-ScheduledTask -Action ($RGBON) -Principal ($Principal) -Trigger ($UnlockTrigger, $LogonTrigger, $SleepTrigger) -Settings ($Settings))
		Register-ScheduledTask "RGB OFF" -InputObject (New-ScheduledTask -Action ($RGBOFF) -Principal ($Principal) -Trigger ($LockTrigger) -Settings ($Settings))
	}
		
	cls
	"`nPlease wait"
	start-sleep -seconds 5
	Start-ScheduledTask -TaskName "RGB OFF"
	start-sleep -seconds 5
	Start-ScheduledTask -TaskName "RGB ON"
	goexit
}

function reset
{
	Remove-ItemProperty -Path "HKCU:Software\Policies\Microsoft\Windows\Control Panel\Desktop\" -Name "ScreenSave*"
	Unregister-ScheduledTask -TaskName *RGB* -Confirm:$false
	goexit
}
	
function goexit
{
	cls
	"`nInstallation complete"
	start-sleep -seconds 5
	exit
}

cls
if ($option -eq "install") {install} elseif ($option -eq "reset") {reset}
"`ngithub.com/uffemcev/rgb `n`n[1] Install `n[2] Reset `n[3] Exit"
switch ([console]::ReadKey($true).KeyChar)
{
	1 {cls; install}
	2 {cls; reset}
	3 {cls; goexit}
}
