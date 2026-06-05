# Привет, Савелий
Здесь будет наш репозиторий для Docent VPN, готовься работать по крупному.

## Лог событий
- 1. На тестовый сервачок установлен Outline
- 2. Добавлен apiUrl, содержащий ссылку на Api тестового Outline
- 3. Outline заработал, этo хорошо

## Указания к установке
- 1. Устанавливаем Outline manager на основной компьютер, выбираем установку где угодно
- 2. Копируем команду, исполняем ее на сервере:
"""
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/OutlineFoundation/outline-apps/master/server_manager/install_scripts/install_server.sh)"
"""
- 3. ОБЯЗАТЕЛЬНО копируем в выводе подсвеченную строку - это и есть Url нашего Api
- 4. Разрешаем обмен данными для outline через firewall. Для этого исполняем:
"""
sudo ufw allow 59051/tcp
sudo ufw allow 42976/tcp
sudo ufw allow 42976/udp
"""
