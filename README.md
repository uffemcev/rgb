## Описание
Скрипт автоматизирует переключение подсветки во время простоя ПК через планировщик заданий. Поддерживается OpenRGB и SignalRGB. По умолчанию скрипт включает белую подсветку при обычной работе и черную подсветку при простое ПК. 

## Запуск
Скрипт можно запустить онлайн с настройками по умолчанию:
```
powershell -ExecutionPolicy Bypass "& ([ScriptBlock]::Create((irm raw.githubusercontent.com/uffemcev/rgb/main/rgb.ps1)))"
```
или локально отредактировав файл под свои нужды:
```
powershell -ExecutionPolicy Bypass ".\rgb.ps1"
```
