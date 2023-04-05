## Описание
Скрипт автоматизирует переключение подсветки во время простоя ПК через планировщик заданий. Поддерживается OpenRGB и SignalRGB. По умолчанию скрипт включает белую подсветку при обычной работе и черную подсветку при простое ПК. 

## Запуск
Скрипт можно запустить онлайн:
```
powershell -ExecutionPolicy Bypass "& ([ScriptBlock]::Create((irm raw.githubusercontent.com/uffemcev/rgb/main/rgb.ps1)))"
```
или локально:
```
powershell -ExecutionPolicy Bypass ".\rgb.ps1"
```
