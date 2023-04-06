<#
	Скрипт предлагает выбрать exe файл OpenRGB или SignalRGB для записи путей, если до этого файл не был найден в директории скрипта.
	
	Заданное в скрипте время регулирует момент, когда включатся следующие опции:
	1. Начинать с экрана входа в систему через $time
	2. При питании от сети отключать мой экран через $time
	
	Этот автоматический триггер используется в планировщике:
	1. Задание RGB_off с триггером блокирования ПК для выключения подсветки
	2. Задание RGB_on c триггером разблокирования ПК для включения подсветки
	
	ПК автоматически переходит на экран входа через заданное время, монитор выключается и активируется задание RGB_off.
	По возвращению на рабочий стол активируется задание RGB_on.
#>

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
	$host.ui.RawUI.WindowTitle = 'initialization'
	$o = $MyInvocation.line
	Start-Process powershell "-ExecutionPolicy Bypass `"cd '$pwd'; $o`"" -Verb RunAs
	taskkill /fi "WINDOWTITLE eq initialization"
} else {$host.ui.RawUI.WindowTitle = 'uffemcev rgb'; cls}

function install([string]$a)
{	
	if ($a -eq 'run')
	{
		if ($null -eq $path) {$path = $pwd}
		dir -Path $path -ErrorAction SilentlyContinue -Force | where {$_ -in 'SignalRgbLauncher.exe','OpenRGB.exe'} | %{
			cls
			$stateChangeTrigger = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
			$onUnlockTrigger = New-CimInstance -CimClass $stateChangeTrigger -Property @{StateChange = 8} -ClientOnly
			$onLockTrigger = New-CimInstance -CimClass $stateChangeTrigger -Property @{StateChange = 7} -ClientOnly
			$Principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest
			$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
			$time = Read-Host "`nTime in seconds before monitor and rgb turns off"
	
			if ($_.Name -eq 'SignalRgbLauncher.exe')
			{
				Start-Process 'signalrgb://effect/install/Solid%20Color?&-silentlaunch-'
				Register-ScheduledTask RGB_on -InputObject (New-ScheduledTask -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'signalrgb://effect/apply/Solid%20Color?color=white&-silentlaunch-'") -Principal ($Principal) -Trigger ($onUnlockTrigger) -Settings ($Settings))
				Register-ScheduledTask RGB_off -InputObject (New-ScheduledTask -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'signalrgb://effect/apply/Solid%20Color?color=black&-silentlaunch-'") -Principal ($Principal) -Trigger ($onLockTrigger) -Settings ($Settings))
			} elseif ($_.Name -eq 'OpenRGB.exe')
			{
				Register-ScheduledTask RGB_on -InputObject (New-ScheduledTask -Action (New-ScheduledTaskAction -Execute "$path\OpenRGB.exe" -Argument "--noautoconnect --color white --mode direct") -Principal ($Principal) -Trigger ($onUnlockTrigger) -Settings ($Settings))
				Register-ScheduledTask RGB_off -InputObject (New-ScheduledTask -Action (New-ScheduledTaskAction -Execute "$path\OpenRGB.exe" -Argument "--noautoconnect --color black --mode direct") -Principal ($Principal) -Trigger ($onLockTrigger) -Settings ($Settings))
			}
			
			reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /t REG_SZ /d "1" /f
			reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /t REG_SZ /d "$time" /f
			powercfg /setdcvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e $time
			powercfg /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e $time
			$a = 'exit'
		}
	}
	
	if ($a -eq 'reset')
	{
		reg delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /f
		reg delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /f
		Unregister-ScheduledTask -TaskName RGB_on -Confirm:$false
		Unregister-ScheduledTask -TaskName RGB_off -Confirm:$false
		$a = 'exit'
	}
	
	if ($a -eq 'exit')
	{
		cls
		write-host "`nInstallation complete"
		start-sleep -seconds 5
		taskkill /fi "WINDOWTITLE eq uffemcev rgb"
	}
}

$o = Read-Host "`ngithub.com/uffemcev/rgb `n`n0 Run script `n1 Reset `n2 Exit`n"
if ($o -eq 0) {install run}
if ($o -eq 1) {install reset}
if ($o -eq 2) {install exit}

Add-Type -AssemblyName System.Windows.Forms
$b = New-Object System.Windows.Forms.OpenFileDialog
$b.InitialDirectory = [Environment]::GetFolderPath('Desktop') 
$b.MultiSelect = $false
$b.Filter = 'RGB sofware (*.exe)|*.exe'
$b.ShowDialog()
$path = Split-Path -Parent $b.FileName
install run
