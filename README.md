## Описание
Скрипт автоматизирует переключение подсветки во время простоя ПК через планировщик заданий. Поддерживается OpenRGB и SignalRGB. По умолчанию включается белая подсветка при обычной работе и черная подсветка при простое. Работоспособность скрипта проверена на Windows 11 22H2. Необходимы права администратора для работы с реестром и планировщиком. Принцип работы описан в комментариях к скрипту.

Принимаются замечания, предложения и вопросы!

## Запуск
Онлайн установка скрипта с настройками по умолчанию:
```
powershell -ExecutionPolicy Bypass "& ([ScriptBlock]::Create((irm raw.githubusercontent.com/uffemcev/rgb/main/rgb.ps1)))"
```
Если настройки по умолчанию не устраивают, можно изменить скрипт и запустить его с ПК:
```
powershell -ExecutionPolicy Bypass ".\rgb.ps1"
```
По завершению работы файл можно удалить.

## Дополнительно
* При разблокировании ПК на мгновение может появляться консольное окно - это нормальное поведение планировщика заданий
* По умолчанию, сочетание клавиш WIN + L блокирует рабочую станцию, поэтому подсветка так же выключится
* Не стоит устанавливать время слишком низким, рекомендованный минимум - 300 секунд
* Из-за особенностей Windows монитор и подсветка не всегда гаснут ровно через заданное время, иногда необходимо подождать чуть дольше
* OpenRGB 0.8 имеет проблемы в работе с консольными командами. Необходимо пользоваться версией 0.7 или 0.81.

## Ссылки
* [SignalRGB Wiki](https://docs.signalrgb.com/application-url-s)
* [OpenRGB Wiki](https://openrgb-wiki.readthedocs.io/en/latest/Frequently-Asked-Questions)
