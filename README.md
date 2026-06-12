# Привет, Савелий
Здесь будет наш репозиторий для Docent VPN, готовься работать по крупному.

## Лог событий
- На тестовый сервачок установлен Outline
- Добавлен apiUrl, содержащий ссылку на Api тестового Outline
- Outline заработал, этo хорошо

## Указания к установке
- Устанавливаем Outline manager на основной компьютер, выбираем установку где угодно
- Копируем команду, исполняем ее на сервере:
```
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/OutlineFoundation/outline-apps/master/server_manager/install_scripts/install_server.sh)"
```
- ОБЯЗАТЕЛЬНО копируем в выводе подсвеченную строку - это и есть Url нашего Api
- Разрешаем обмен данными для outline через firewall. Для этого исполняем:
```
sudo ufw allow 59051/tcp
sudo ufw allow 42976/tcp
sudo ufw allow 42976/udp
```
# Привет, Андрей
- Со всем ознакомился, ждем данные от Федотова и работаем по крупному
