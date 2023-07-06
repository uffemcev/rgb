#НАЧАЛЬНЫЕ ПАРАМЕТРЫ
[CmdletBinding()]
param([string]$option, [int]$locktime, [int]$sleeptime)
function cleaner () {$e = [char]27; "$e[H$e[J" + "`nhttps://uffemcev.github.io/rgb`n"}
$host.ui.RawUI.WindowTitle = 'uffemcev rgb'
[console]::CursorVisible = $false
cleaner

#ПРОВЕРКА ПРАВ
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
	try {Start-Process wt "powershell -ExecutionPolicy Bypass -Command &{cd '$pwd'\; $($MyInvocation.line -replace (";"),("\;"))}" -Verb RunAs}
	catch {Start-Process conhost "powershell -ExecutionPolicy Bypass -Command &{cd '$pwd'; $($MyInvocation.line)}" -Verb RunAs}
	(get-process | where MainWindowTitle -eq $host.ui.RawUI.WindowTitle).id | where {taskkill /PID $_}
}

#УСТАНОВКА
function install
{	
	cleaner
	if (!(dir | where Name -match 'OpenRGB.exe|SignalRgbLauncher.exe'))
	{
		"Please select OpenRGB.exe or SignalRgbLauncher.exe"
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
		dir | where Name -match 'OpenRGB.exe|SignalRgbLauncher.exe' | where {$filepath = Split-Path -Parent $_.FullName; $filename = $_.Name}
	}
	
	cleaner
	if (!$locktime) {$locktime = Read-Host "Time in seconds before display and lights turns off"}
	cleaner
	if (!$sleeptime) {$sleeptime = Read-Host "Time in seconds before pc goes to sleep"}
	reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /t REG_SZ /d "1" /f
	reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /t REG_SZ /d "$locktime" /f
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
		explorer "signalrgb://effect/install/Solid%20Color?&-silentlaunch-"
		$RGBON = New-ScheduledTaskAction -Execute "explorer" -Argument "`"signalrgb://effect/apply/Solid%20Color?color=%23ffffff&-silentlaunch-`""
		$RGBOFF = New-ScheduledTaskAction -Execute "explorer" -Argument "`"signalrgb://effect/apply/Solid%20Color?color=%23000000&-silentlaunch-`""
		Register-ScheduledTask "RGB ON" -InputObject (New-ScheduledTask -Action ($RGBON) -Principal ($Principal) -Trigger ($UnlockTrigger) -Settings ($Settings))
		Register-ScheduledTask "RGB OFF" -InputObject (New-ScheduledTask -Action ($RGBOFF) -Principal ($Principal) -Trigger ($LockTrigger) -Settings ($Settings))
	} elseif ($filename -eq 'OpenRGB.exe')
	{
		$RGBON = New-ScheduledTaskAction -Execute $filename -Argument "--noautoconnect -m direct -c white -b 100" -WorkingDirectory $filepath
		$RGBOFF = New-ScheduledTaskAction -Execute $filename -Argument "--noautoconnect -m direct -c black -b 0" -WorkingDirectory $filepath
		Register-ScheduledTask "RGB ON" -InputObject (New-ScheduledTask -Action ($RGBON) -Principal ($Principal) -Trigger ($UnlockTrigger, $LogonTrigger, $SleepTrigger) -Settings ($Settings))
		Register-ScheduledTask "RGB OFF" -InputObject (New-ScheduledTask -Action ($RGBOFF) -Principal ($Principal) -Trigger ($LockTrigger) -Settings ($Settings))
	}
		
	cleaner
	"Please stand by"
	start-sleep -seconds 10
	Start-ScheduledTask -TaskName "RGB ON"
	goexit
}

#СБРОС
function reset
{
	cleaner
	Remove-ItemProperty -Path "HKCU:Software\Policies\Microsoft\Windows\Control Panel\Desktop\" -Name "ScreenSave*"
	Unregister-ScheduledTask -TaskName *RGB* -Confirm:$false
	goexit
}
	
#ВЫХОД
function goexit
{
	cleaner
	"Bye, $Env:UserName"
	start-sleep -seconds 5
	exit
}

#МЕНЮ
cleaner
if ($option -eq "install") {install} elseif ($option -eq "reset") {reset}
"[1] Install `n[2] Reset `n[3] Exit"
switch ([console]::ReadKey($true).KeyChar)
{
	1 {install}
	2 {reset}
	3 {goexit}
}
