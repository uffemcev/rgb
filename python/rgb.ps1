<#
	Запуск:
	powershell -ExecutionPolicy Bypass "& ([ScriptBlock]::Create((irm raw.githubusercontent.com/uffemcev/rgb/main/python/rgb.ps1)))"
	powershell -ExecutionPolicy Bypass ".\rgb.ps1"
	
	Для работы необходимы права администратора, winget и python. При необходимости всё подтягивается автоматически.
#>

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
	$host.ui.RawUI.WindowTitle = 'initialization: admin'
	$o = $MyInvocation.line
	Start-Process powershell "-ExecutionPolicy Bypass `"cd '$pwd'; $o`"" -Verb RunAs
	taskkill /fi "WINDOWTITLE eq initialization*"
} elseif (!(dir -Path ($env:Path -split ';') -ErrorAction SilentlyContinue -Force | where {$_ -in 'winget.exe'}))
{
	$host.ui.RawUI.WindowTitle = 'initialization: winget'
	$o = $MyInvocation.line
	pushd (ni -Force -Path $env:USERPROFILE\uffemcev_utilities -ItemType Directory)
	& ([ScriptBlock]::Create((irm raw.githubusercontent.com/asheroto/winget-installer/master/winget-install.ps1)))
	$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
	popd
	Start-Process powershell "-ExecutionPolicy Bypass `"cd '$pwd'; $o`"" -Verb RunAs
	taskkill /fi "WINDOWTITLE eq initialization*"
} elseif (!(dir -Path ($env:Path -split ';') -ErrorAction SilentlyContinue -Force | where {$_ -in 'python.exe'}))
{
	$host.ui.RawUI.WindowTitle = 'initialization: python'
	$o = $MyInvocation.line
	winget install --id=Python.Python.3.12 --accept-package-agreements --accept-source-agreements --exact --silent
	$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
	Start-Process powershell "-ExecutionPolicy Bypass `"cd '$pwd'; $o`"" -Verb RunAs
	taskkill /fi "WINDOWTITLE eq initialization*"
} else
{
	pip3 install openrgb-python
	$host.ui.RawUI.WindowTitle = 'uffemcev rgb'
	$python = python -c "import os, sys; print(os.path.dirname(sys.executable))"
	cls
}

function install
{
	Write-Host "`nPlease select OpenRGB.exe"
	Add-Type -AssemblyName System.Windows.Forms
	$b = New-Object System.Windows.Forms.OpenFileDialog
	$b.InitialDirectory = [Environment]::GetFolderPath('Desktop') 
	$b.Title = 'OpenRGB'
	$b.MultiSelect = $false
	$b.Filter = 'OpenRGB|OpenRGB.exe'
	$b.ShowDialog()
	$openrgb = $b.FileName
	
	if ($openrgb -eq '')
	{
		cls
		Write-Host "`nIncorrect file"
		start-sleep -seconds 5
		goexit
	}
	
	cls
	$time = Read-Host "`nTime in seconds before monitor and rgb turns off"
	cls
	Write-Host "`nPlease wait"
	pythonw -c "import subprocess; subprocess.Popen(r`'$openrgb --noautoconnect --server --gui`')"
	start-sleep -seconds 5
	cls
	Write-Host "`nPlease set up an active profile and press any key"
	$null = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	pythonw -c "from openrgb import OpenRGBClient; from openrgb.utils import RGBColor, DeviceType; client = OpenRGBClient(); client.save_profile('UnlockRGB')"
	cls
	Write-Host "`nPlease set up an idle profile and press any key"
	$null = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	pythonw -c "from openrgb import OpenRGBClient; from openrgb.utils import RGBColor, DeviceType; client = OpenRGBClient(); client.save_profile('LockRGB')"
	
	$Principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest
	$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
	$LogonTrigger = New-ScheduledTaskTrigger -AtLogon	

	$SleepState = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
	$SleepTrigger = New-CimInstance -CimClass $SleepState -ClientOnly
	$SleepTrigger.Subscription = "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[EventID=107]]</Select></Query></QueryList>"
	
	$LockUnlockState = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
	$LockTrigger = New-CimInstance -CimClass $LockUnlockState -Property @{StateChange = 7} -ClientOnly
	$UnlockTrigger = New-CimInstance -CimClass $LockUnlockState -Property @{StateChange = 8} -ClientOnly
	
	$LockAction = New-ScheduledTaskAction -Execute 'pythonw.exe' -Argument "-c `"import openrgb; client = openrgb.OpenRGBClient(); client.load_profile(`'LockRGB`')`"" -WorkingDirectory $python
	$UnlockAction = New-ScheduledTaskAction -Execute 'pythonw.exe' -Argument "-c `"import openrgb; client = openrgb.OpenRGBClient(); client.devices[0].set_mode(0); client.devices[2].set_mode(0); client.load_profile(`'UnlockRGB`')`"" -WorkingDirectory $python
	$LogonAction = New-ScheduledTaskAction -Execute 'pythonw.exe' -Argument "-c `"import subprocess, time; subprocess.Popen(r`'$openrgb --noautoconnect --server`'); time.sleep(5); subprocess.call(`'schtasks /run /TN UnlockRGB`')`"" -WorkingDirectory $python
	
	Register-ScheduledTask LockRGB -InputObject (New-ScheduledTask -Action ($LockAction) -Principal ($Principal) -Trigger ($LockTrigger) -Settings ($Settings))
	Register-ScheduledTask UnlockRGB -InputObject (New-ScheduledTask -Action ($UnlockAction) -Principal ($Principal) -Trigger ($UnlockTrigger) -Settings ($Settings))
	Register-ScheduledTask LogonRGB -InputObject (New-ScheduledTask -Action ($LogonAction) -Principal ($Principal) -Trigger ($LogonTrigger, $SleepTrigger) -Settings ($Settings))
	
	reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /t REG_SZ /d "1" /f
	reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /t REG_SZ /d "$time" /f
	powercfg /setdcvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e $time
	powercfg /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e $time

	taskkill /fi "WINDOWTITLE eq OpenRGB*"
	cls
	Write-Host "`nPlease wait"
	start-sleep -seconds 5
	Start-ScheduledTask -TaskName "LogonRGB"
	goexit
}

function reset
{
	reg delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /f
	reg delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /f
	Unregister-ScheduledTask -TaskName UnlockRGB -Confirm:$false
	Unregister-ScheduledTask -TaskName LockRGB -Confirm:$false
	Unregister-ScheduledTask -TaskName LogonRGB -Confirm:$false
	taskkill /im OpenRGB.exe /f
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
