#!/usr/bin/bash

# Проверка, что скрипт запущен от root
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт нужно запускать от root: sudo $0"
   exit 1
fi
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

# Проверка наличия рабочего каталога
if [[ ! -d "$USER_HOME/docent-vpn" ]] ; then
    echo "Создаем каталог $USER_HOME/docent-vpn/"
    mkdir -p "$USER_HOME/docent-vpn"
fi

# 1. Установка сервера Outline Vpn
echo "Устанавливаем сервер Outline Vpn..."

if [ -f "$USER_HOME/docent-vpn/installation.log" ]; then
    echo "Создаем файл логгирования установки $USER_HOME/docent-vpn/installation.log"
    touch "$USER_HOME/docent-vpn/installation.log"
fi

yes | bash -c "$(wget -qO- https://raw.githubusercontent.com/OutlineFoundation/outline-apps/master/server_manager/install_scripts/install_server.sh)" > "$USER_HOME/docent-vpn/installation.log"

echo "Outline Vpn успешно установлен. Подробности об установке можно просмотреть в $USER_HOME/docent-vpn/installation.log"

if [[ -n "$(which ufw)" ]]; then
    echo "В системе установлен фаерволл, необходимо пробросить порты для Outline Vpn. Сделать это автоматически?[Y:n]:"
    read -r AUTO_FIREWALL_CONF
fi

while [[ ($AUTO_FIREWALL_CONF != "y") || ($AUTO_FIREWALL_CONF != "Y") || ($AUTO_FIREWALL_CONF != "n") || ($AUTO_FIREWALL_CONF != "N") || ($AUTO_FIREWALL_CONF != "") ]]
do
    echo "Укажите, нужно ли настроить порты для Outline Vpn?[Y:n]:"
    read -r AUTO_FIREWALL_CONF
done

if [[ ($AUTO_FIREWALL_CONF != "y") || ($AUTO_FIREWALL_CONF != "Y") || ($AUTO_FIREWALL_CONF != "") ]]; then
    bash -c "{$(cat $USER_HOME/docent-vpn/installation.log | grep ufw | cut -c 5- )}"
    echo "Порты были успешно проброшены"
fi

# echo "Основная информация о сервере:"
# echo "API URL сервера: $(cat $USER_HOME/docent-vpn/installation.log | grep apiUrl)"
# echo "IP адресс сервера: "

exit 0
