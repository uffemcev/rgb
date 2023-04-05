$time = 900

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
	$host.ui.RawUI.WindowTitle = 'initialization'
	$o = $MyInvocation.line
	Start-Process powershell "-ExecutionPolicy Bypass `"cd '$pwd'; $o`"" -Verb RunAs
	taskkill /fi "WINDOWTITLE eq initialization"
} else {$host.ui.RawUI.WindowTitle = 'uffemcev rgb'}

function install([string]$a)
{
	if ($null -eq $path) {$path = '.\'}
	
	if ($a -eq 'run')
	{
		$stateChangeTrigger = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
		$onUnlockTrigger = New-CimInstance -CimClass $stateChangeTrigger -Property @{StateChange = 8} -ClientOnly
		$onLockTrigger = New-CimInstance -CimClass $stateChangeTrigger -Property @{StateChange = 7} -ClientOnly
		$Principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest
		$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries

		dir -Path $path -ErrorAction SilentlyContinue -Force | where {$_ -in 'SignalRgbLauncher.exe','OpenRGB.exe'} | %{
	
			if ($_.Name -eq 'SignalRgbLauncher.exe')
			{
				Register-ScheduledTask RGB_on -InputObject (New-ScheduledTask -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'signalrgb://effect/apply/Solid%20Color?color=white&-silentlaunch-'") -Principal ($Principal) -Trigger ($onUnlockTrigger) -Settings ($Settings))
				Register-ScheduledTask RGB_off -InputObject (New-ScheduledTask -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command Start-Process 'signalrgb://effect/apply/Solid%20Color?color=black&-silentlaunch-'") -Principal ($Principal) -Trigger ($onLockTrigger) -Settings ($Settings))
			} elseif ($_.Name -eq 'OpenRGB.exe')
			{
				Register-ScheduledTask RGB_on -InputObject (New-ScheduledTask -Action (New-ScheduledTaskAction -Execute "$path\OpenRGB.exe" -Argument "--noautoconnect --color white --mode direct") -Principal ($Principal) -Trigger ($onUnlockTrigger) -Settings ($Settings))
				Register-ScheduledTask RGB_off -InputObject (New-ScheduledTask -Action (New-ScheduledTaskAction -Execute "$path\OpenRGB.exe" -Argument "--noautoconnect --color black --mode direct") -Principal ($Principal) -Trigger ($onLockTrigger) -Settings ($Settings))
			}
			
			reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /t REG_SZ /d "1" /f
			reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /t REG_SZ /d "$time" /f
			powercfg.exe /setdcvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e $time
			powercfg.exe /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e $time
			$a = 'exit'
		}
	}
	
	if ($a -eq 'reset')
	{
		reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /t REG_SZ /d "0" /f
		reg.exe delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /f
		reg.exe delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /f
		reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /f
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

$Browser = New-Object System.Windows.Forms.OpenFileDialog
$Browser.InitialDirectory = [Environment]::GetFolderPath('Desktop') 
$Browser.Filter = 'RGB sofware (*.exe)|*.exe'
$null = $Browser.ShowDialog()
$path = Split-Path -Parent $Browser.FileName
install run
