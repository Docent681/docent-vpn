#!/usr/bin/env bash

# Проверка, что скрипт запущен через sudo от обычного пользователя
if [[ -z "${SUDO_USER:-}" ]]; then
    echo "Ошибка: скрипт должен быть запущен через sudo, а не от root напрямую."
    exit 1
fi

USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

PROJECT_DIR="$USER_HOME/docent-vpn"
if [[ ! -d "$PROJECT_DIR" ]]; then
	mkdir -p "$PROJECT_DIR"
fi

# Деинсталляция Outline
if [[ -f /opt/outline/access.txt ]]; then
    read -r -p "Удалить Outline из системы? [Y/n]: " DELETE_OUTLINE

    while [[ ! "$DELETE_OUTLINE" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " DELETE_OUTLINE
    done

    if [[ -z "$DELETE_OUTLINE" || "$DELETE_OUTLINE" =~ ^[yY]$ ]]; then
        OUTLINE_ID=$(docker ps -q -f name=shadowbox)
        if [[ -z "$OUTLINE_ID" ]]; then
            echo "В ходе деинсталляции Outline произошла ошибка"
        else
            docker stop "$OUTLINE_ID"
            docker rm "$OUTLINE_ID"
            echo "Outline был удален из системы"
        fi
    else
        echo "Вы решили пропустить деинсталляцию"
    fi
else
    echo "Outline не обнаружен в системе. Пропускаем деинсталляцию"
fi

# Сброс фаерволла
 if command -v ufw &>/dev/null; then
    echo "В системе обнаружен UFW"

    read -r -p "Сбросить настройки фаерволла и выключить его (ВНИМАНИЕ! ТАКЖЕ ЗАТРОНЕТ НАСТРОЙКИ ФАЕРВОЛЛА, НЕ СВЯЗАННЫЕ С Docent-VPN)? [Y/n]: " RESET_FIREWALL

    while [[ ! "$RESET_FIREWALL" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " RESET_FIREWALL
    done

    if [[ -z "$RESET_FIREWALL" || "$RESET_FIREWALL" =~ ^[yY]$ ]]; then
        ufw reset
        ufw allow 22
        ufw enable
        echo "Настройки ufw были сброшены, порт подключения ssh оставлен открытым"
    else
        echo "Вы решили пропустить деинсталляцию"
    fi
 else
     echo "ufw в системе не найден, пропускаем сброс настроек"
 fi

 # Деинсталляция nginx
if ! command -v nginx &>/dev/null; then
    echo "nginx не обнаружен в системе."
else
    echo "nginx обнаружен в системе."
    read -r -p "Удалить nginx? [Y/n]: " DELETE_NGINX
    # Проверка ввода: Y, N или пусто (Enter)
    while [[ ! "$DELETE_NGINX" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " DELETE_NGINX
    done

    if [[ -z "$DELETE_NGINX" || "$DELETE_NGINX" =~ ^[yY]$ ]]; then
        if command -v apt &>/dev/null; then
            echo "Удаляем nginx..."
            apt purge nginx
        else
            echo "Не удалось автоматически удалить nginx: пакетный менеджер apt не найден."
            echo "Пожалуйста, удалите nginx вручную."
        fi
    else
        echo "Деинсталляция nginx пропущена."
    fi
fi

#Деинсталляция базы данных PostgreSQL
if ! command -v psql &>/dev/null; then
    echo "postgresql не обнаружен в системе."
else
    echo "postgresql обнаруженв системе."
     read -r -p "Удалить postgresql? [Y/n]: " DELETE_SQL
    # Проверка ввода: Y, N или пусто (Enter)
    while [[ ! "$DELETE_SQL" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " DELETE_SQL
    done

    if [[ -z "$DELETE_SQL" || "$DELETE_SQL" =~ ^[yY]$ ]]; then
        if command -v apt &>/dev/null; then
            echo "Удаляем PostgreSql"
            apt purge postgresql postgresql-contrib
        else
            echo "Не удалось автоматически удалить postgresql: пакетный менеджер apt не найден."
            echo "Пожалуйста, удалить postgresql вручную."
        fi
    else
        echo "Деинсталляция postgresql пропущена."
    fi
fi

# Деинсталляция конкретно базы данных docent-vpn, если пользователь решил оставить PostgreSql
if [[ "$DELETE_SQL" =~ ^[nN]$ ]]; then
    read -r -p "Установить базу данных веб-интерфейса? [Y/n]: " DELETE_DOCENT_DB
    # Проверка ввода: Y, N или пусто (Enter)
    while [[ ! "$DELETE_DOCENT_DB" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " DELETE_DOCENT_DB
    done

    if [[ -z "$DELETE_DOCENT_DB" || "$DELETE_DOCENT_DB" =~ ^[yY]$ ]]; then
        echo "Удаляем Базу данных docent-vpn"
        DB_NAME=$(sed -n '1p' "$PROJECT_DIR"/envy.conf | cut -d' ' -f1 )
        if [[ -n "$DB_NAME" ]]; then
            sudo -u postgres psql -c "DROP DATABASE $DB_NAME;"
            echo "База данных docent-vpn была удалена"
        else
            echo "Не удалось определить имя базы данных, деинсталляция пропущена"
        fi
    else
        echo "Деинсталляция базы данных docent-vpn пропущена."
    fi
fi


# Удаление службы docent-vpn в systemd
if [[ -f /etc/systemd/system/docent-vpn.service ]]; then
    echo "В systemd найдена служба docent-vpn"

    read -r -p "Удалить службу docent-vpn в systemd? [Y/n]: " DELETE_DOCENT_VPN
    # Проверка ввода: Y, N или пусто (Enter)
    while [[ ! "$DELETE_DOCENT_VPN" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " DELETE_DOCENT_VPN
    done

    if [[ -z "$DELETE_DOCENT_VPN" || "$DELETE_DOCENT_VPN" =~ ^[yY]$ ]]; then
        echo "Удаляем службу docent-vpn"
        systemctl stop docent-vpn
        systemctl disable docent-vpn
        rm /etc/systemd/system/docent-vpn.service
        systemctl daemon-reload
    else
        echo "Деинсталляция службы docent-pvn пропущена."
    fi
else
    echo "служба docent-vpn в systemd не найдена, пропускаем деинсталляцию"
fi

# Удаление рабочего каталога docent-vpn
if [[ -d "$PROJECT_DIR/" ]]; then
    echo "Рабочий каталог docent-vpn обнаружен"

    read -r -p "Удалить docent-vpn? [Y/n]: " DELETE_MAIN
    # Проверка ввода: Y, N или пусто (Enter)
    while [[ ! "$DELETE_MAIN" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " DELETE_MAIN
    done
    if [[ -z "$DELETE_MAIN" || "$DELETE_MAIN" =~ ^[yY]$ ]]; then
        cd ~
        rm -rf "$PROJECT_DIR"
        echo "Рабочий каталог docent-vpn успешно удален"
    else
        echo "Деинсталляция рабочего каталога docent-vpn была пропущена"
    fi

else
    echo "Рабочий каталог docent-vpn не найден, пропускаем деинсталляцию"
fi

# Очистка кэша и ненужных зависимостей apt
read -r -p "очистить кэш и удалить ненужные зависимости apt? [Y/n]: " DELETE_CACHE
# Проверка ввода: Y, N или пусто (Enter)
while [[ ! "$DELETE_CACHE" =~ ^([yYnN]?)$ ]]; do
    read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " DELETE_CACHE
done
if [[ -z "$DELETE_CACHE" || "$DELETE_CACHE" =~ ^[yY]$ ]]; then
    if command -v apt &>/dev/null; then
        apt autoremove
        apt clean
        echo "Кэш и зависимости apt успешно удалены"
    else
        echo "apt не найден в системе, пропускаем очистку"
    fi
else
    echo "Очистка кэша и ненужных зависимостей apt пропущена"
fi


echo "=============================="
echo "Деинсталляция docent-vpn завершена"
echo "=============================="

exit 0
