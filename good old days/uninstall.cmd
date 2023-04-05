reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /t REG_SZ /d "0" /f
reg.exe delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaverIsSecure" /f
reg.exe delete "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v "ScreenSaveTimeOut" /f
reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /f
schtasks /delete /tn "RGB" /f