#!/usr/bin/env bash
set -euo pipefail  # выход при ошибке, неинициализированные переменные, ошибки пайпов

# Проверка, что скрипт запущен через sudo от обычного пользователя
if [[ -z "${SUDO_USER:-}" ]]; then
    echo "Ошибка: скрипт должен быть запущен через sudo, а не от root напрямую."
    exit 1
fi

USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
LOGDIR="$USER_HOME/docent-vpn"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/installation.log"

# Сброс лог-файла перед установкой
true > "$LOGFILE"
chown "$SUDO_USER":"$SUDO_USER" "$LOGFILE"

echo "Устанавливаем сервер Outline VPN (лог: $LOGFILE)..."

yes | bash -c "$(wget -qO- https://raw.githubusercontent.com/OutlineFoundation/outline-apps/master/server_manager/install_scripts/install_server.sh)" &>> "$LOGFILE"

# Проверка успешности установки
if [[ -f /opt/outline/access.txt ]]; then
    echo "Outline VPN успешно установлен."
else
    echo "Ошибка: установка Outline не завершилась успешно. Смотрите лог $LOGFILE"
    exit 1
fi

# Настройка ufw, если он присутствует
if command -v ufw &>/dev/null; then
    echo "В системе обнаружен UFW. Необходимо открыть порты для Outline."
    read -r -p "Настроить порты автоматически? [Y/n]: " AUTO_FIREWALL_CONF

    while [[ ! "$AUTO_FIREWALL_CONF" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " AUTO_FIREWALL_CONF
    done

    if [[ -z "$AUTO_FIREWALL_CONF" || "$AUTO_FIREWALL_CONF" =~ ^[yY]$ ]]; then
        echo "Настраиваю UFW..."
        grep 'ufw allow' "$LOGFILE" | sed -e 's/^[[:space:]]*sudo //' -e 's/[[:space:]]*$//' | while read -r cmd; do
            if [[ -n "$cmd" ]]; then
                echo "Выполняю: $cmd"
                $cmd || echo "Предупреждение: команда '$cmd' завершилась с ошибкой"
            fi
        done
        echo "Порты UFW настроены."
    else
        echo "Настройка UFW пропущена. Не забудьте открыть порты вручную."
    fi
fi

#Установка и конфигурация веб-сервера nginx
echo "Проверяем наличие nginx..."
if command -v nginx &>/dev/null; then
    echo "nginx уже установлен в системе."
else
    echo "nginx не обнаружен."
    read -r -p "Установить nginx? [Y/n]: " INSTALL_NGINX
    # Проверка ввода: Y, N или пусто (Enter)
    while [[ ! "$INSTALL_NGINX" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " INSTALL_NGINX
    done

    if [[ -z "$INSTALL_NGINX" || "$INSTALL_NGINX" =~ ^[yY]$ ]]; then
        if command -v apt &>/dev/null; then
            echo "Обновляем список пакетов и устанавливаем nginx..."
            apt update -y && apt install -y nginx &>> "$LOGFILE"
            if command -v nginx &>/dev/null; then
                echo "nginx успешно установлен."
            else
                echo "Ошибка: не удалось установить nginx. Проверьте логи."
            fi
        else
            echo "Не удалось автоматически установить nginx: пакетный менеджер apt не найден."
            echo "Пожалуйста, установите nginx вручную."
        fi
    else
        echo "Установка nginx пропущена."
    fi
fi

echo "Проверяем наличие postgresql..."
if command -v psql &>/dev/null; then
    echo "postgresql уже установлен в системе."
else
    echo "postgresql не обнаружен."
     read -r -p "Установить postgresql? [Y/n]: " INSTALL_SQL
    # Проверка ввода: Y, N или пусто (Enter)
    while [[ ! "$INSTALL_SQL" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " INSTALL_SQL
    done

    if [[ -z "$INSTALL_SQL" || "$INSTALL_SQL" =~ ^[yY]$ ]]; then
        if command -v apt &>/dev/null; then
            echo "Обновляем список пакетов и устанавливаем postgresql..."
            apt update -y && apt install -y postgresql postgresql-contrib &>> "$LOGFILE"
            if command -v nginx &>/dev/null; then
                echo "postgresql успешно установлен."
            else
                echo "Ошибка: не удалось установить postgresql. Проверьте логи."
            fi
        else
            echo "Не удалось автоматически установить postgresql: пакетный менеджер apt не найден."
            echo "Пожалуйста, установите postgresql вручную."
        fi
    else
        echo "Установка postgresql пропущена."
    fi
fi


# Вывод ключевой информации о сервере
echo "=============================="
echo "Информация о сервере Outline:"
echo "Файл параметров: /opt/outline/access.txt"
if command -v jq &>/dev/null; then
    jq '.' /opt/outline/access.txt
else
    cat /opt/outline/access.txt
fi
echo "=============================="
echo "Установка завершена."

exit 0
