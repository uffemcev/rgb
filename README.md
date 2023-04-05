## Описание
Скрипт автоматизирует переключение подсветки во время простоя ПК через планировщик заданий. Поддерживается OpenRGB и SignalRGB. Изначально скрипт переключается между белой и черной подсветкой.

## Запуск
Скрипт можно запустить онлайн:
```
powershell -ExecutionPolicy Bypass "& ([ScriptBlock]::Create((irm raw.githubusercontent.com/uffemcev/rgb/main/rgb.ps1)))"
```
или локально:
```
powershell -ExecutionPolicy Bypass ".\rgb.ps1"
```
