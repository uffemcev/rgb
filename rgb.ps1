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
param([string]$option)

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
	$host.ui.RawUI.WindowTitle = 'initialization'
	$MyInvocation.line | where {Start-Process powershell "-ExecutionPolicy Bypass `"cd '$pwd'; $_`"" -Verb RunAs}
	$host.ui.RawUI.WindowTitle | where {taskkill /fi "WINDOWTITLE eq $_"}
} elseif (!(dir -ErrorAction SilentlyContinue -Force | where {$_ -match 'OpenRGB.exe|SignalRgbLauncher.exe'}))
{
	$host.ui.RawUI.WindowTitle = 'uffemcev rgb'
	Write-Output "`nPlease select OpenRGB.exe or SignalRgbLauncher.exe"
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
	$host.ui.RawUI.WindowTitle = 'uffemcev rgb'
	dir -ErrorAction SilentlyContinue -Force | where {$_ -match 'OpenRGB.exe|SignalRgbLauncher.exe'} | where {
		$filepath = Split-Path -Parent $_.FullName
		$filename = $_.Name
	}
}

function install
{	
	$locktime = Read-Host "`nTime in seconds before display and lights turns off"
	$sleeptime = Read-Host "`nTime in seconds before pc goes to sleep"
	New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\" -Name "InactivityTimeoutSecs" -Value $locktime -PropertyType DWORD -Force
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
	Write-Output "`nPlease wait"
	start-sleep -seconds 5
	Start-ScheduledTask -TaskName "RGB OFF"
	start-sleep -seconds 5
	Start-ScheduledTask -TaskName "RGB ON"
	goexit
}

function reset
{
	Remove-ItemProperty -ErrorAction SilentlyContinue -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\" -Name "InactivityTimeoutSecs"
	Unregister-ScheduledTask -TaskName *RGB* -Confirm:$false
	goexit
}
	
function goexit
{
	cls
	Write-Output "`nInstallation complete"
	start-sleep -seconds 5
	$host.ui.RawUI.WindowTitle | where {taskkill /fi "WINDOWTITLE eq $_"}
}

cls
if ($option -eq "install") {install} elseif ($option -eq "reset") {reset}
Write-Output "`ngithub.com/uffemcev/rgb `n`n[1] Install `n[2] Reset `n[3] Exit"
switch ([console]::ReadKey($true).KeyChar)
{
	1 {cls; install}
	2 {cls; reset}
	3 {cls; goexit}
}
