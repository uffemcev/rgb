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
	cls
	$host.ui.RawUI.WindowTitle = 'uffemcev rgb'
	$python = python -c "import os, sys; print(os.path.dirname(sys.executable))"
}

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
	Write-Host "`nError"
	start-sleep -seconds 5
	taskkill /fi "WINDOWTITLE eq uffemcev*"
}

cls
Write-Host "`nPlease wait"
pythonw -c "import subprocess; subprocess.Popen(r`'$openrgb --noautoconnect --server --gui`')"
start-sleep -seconds 5
cls
Write-Host "`nPlease set up an active profile and press any key"
$null = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
pythonw -c "from openrgb import OpenRGBClient; from openrgb.utils import RGBColor, DeviceType; client = OpenRGBClient(); client.save_profile('Unlock')"
cls
Write-Host "`nPlease set up an idle profile and press any key"
$null = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
pythonw -c "from openrgb import OpenRGBClient; from openrgb.utils import RGBColor, DeviceType; client = OpenRGBClient(); client.save_profile('Lock')"

$Trigger = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
$Principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries

$TriggerUnlock = New-CimInstance -CimClass $Trigger -Property @{StateChange = 8} -ClientOnly
$TriggerLock = New-CimInstance -CimClass $Trigger -Property @{StateChange = 7} -ClientOnly
$TriggerLogon = New-ScheduledTaskTrigger -AtLogon

$ActionUnlock = New-ScheduledTaskAction -Execute 'pythonw.exe' -Argument '-c "import openrgb; client = openrgb.OpenRGBClient(); client.devices[0].set_mode(0); client.devices[2].set_mode(0); client.load_profile(1)"' -WorkingDirectory $python
$ActionLock = New-ScheduledTaskAction -Execute 'pythonw.exe' -Argument '-c "import openrgb; client = openrgb.OpenRGBClient(); client.load_profile(0)"' -WorkingDirectory $python
$ActionLogon = New-ScheduledTaskAction -Execute 'pythonw.exe' -Argument "-c `"import subprocess; import time; subprocess.Popen(r`'$openrgb --noautoconnect --server`'); time.sleep(5); subprocess.call(`'schtasks /run /TN Unlock`')`"" -WorkingDirectory $python

Register-ScheduledTask Unlock -InputObject (New-ScheduledTask -Action ($ActionUnlock) -Principal ($Principal) -Trigger ($TriggerUnlock) -Settings ($Settings))
Register-ScheduledTask Lock -InputObject (New-ScheduledTask -Action ($ActionLock) -Principal ($Principal) -Trigger ($TriggerLock) -Settings ($Settings))
Register-ScheduledTask Logon -InputObject (New-ScheduledTask -Action ($ActionLogon) -Principal ($Principal) -Trigger ($TriggerLogon) -Settings ($Settings))

taskkill /fi "WINDOWTITLE eq OpenRGB*"
cls
write-host "`nInstallation complete"
start-sleep -seconds 5
Start-ScheduledTask -TaskName "Logon"
taskkill /fi "WINDOWTITLE eq uffemcev*"