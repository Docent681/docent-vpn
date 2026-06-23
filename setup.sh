#!/usr/bin/env bash
set -euo pipefail  # выход при ошибке, неинициализированные переменные, ошибки пайпов

# Проверка, что скрипт запущен через sudo от обычного пользователя
if [[ -z "${SUDO_USER:-}" ]]; then
    echo "Ошибка: скрипт должен быть запущен через sudo, а не от root напрямую."
    exit 1
fi

USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
PROJECT_DIR="$USER_HOME/docent-vpn"
mkdir -p "$PROJECT_DIR"
LOGFILE="$PROJECT_DIR/installation.log"
chown "$SUDO_USER":"$SUDO_USER" "$LOGFILE" "$PROJECT_DIR"

# Сброс лог-файла перед установкой
true > "$LOGFILE"
chown "$SUDO_USER":"$SUDO_USER" "$LOGFILE"

if [[ -f /opt/outline/access.txt ]]; then
    echo "Outline VPN уже установлен в системе"
else
    echo "Устанавливаем сервер Outline VPN (лог: $LOGFILE)..."

    echo "ЛОГ УСТАНОВКИ OUTLINE VPN" &>> "$LOGFILE"
    yes | bash -c "$(wget -qO- https://raw.githubusercontent.com/OutlineFoundation/outline-apps/master/server_manager/install_scripts/install_server.sh)" &>> "$LOGFILE"

    if [[ -f /opt/outline/access.txt ]]; then
        echo "Outline VPN успешно установлен."
    else
        echo "Ошибка: установка Outline не завершилась успешно. Смотрите лог $LOGFILE"
    fi
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

#Установка веб-сервера nginx
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
            echo "ЛОГ УСТАНОВКИ NGINX" &>> "$LOGFILE"
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

#Конфигурация веб-сервера nginx
echo "Передаем конфиг nginx.conf в /etc/nginx..."
if [[ -f $PROJECT_DIR/nginx.conf  ]]; then
    if [[ -d /etc/nginx ]]; then
        cp -f -T "$PROJECT_DIR/nginx.conf" /etc/nginx/nginx.conf

        if systemctl is-active --quiet nginx; then
            systemctl reload nginx || systemctl restart nginx
        fi
        echo "nginx был настроен и перезагружен"
    else
        echo "nginx не установлен. Пропускаем конфигурацию"
    fi
else
    echo "Не найден файл конфигурации nginx.conf. Настройте nginx вручную"
fi


#Установка базы данных PostgreSQL
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
            if command -v psql &>/dev/null; then
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

#Конфигурация базы данных PostgreSQL и почты
if command -v psql &>/dev/null; then
    if [[ -f "$PROJECT_DIR/envy.conf" ]]; then
        echo "Файл конфигурации envy.conf уже существует, пропускаем конфигурацию"
    else
        read -r -p "Введите имя пользователя базы данных (по умолчанию имя текущего пользователя ОС): " SQL_USER
        if [[ -z "$SQL_USER" ]]; then
            SQL_USER="$SUDO_USER"
        fi
        read -r -p "Введите имя базы данных (по умолчанию: '<текущий пользователь>_db')" SQL_DB_NAME
        if [[ -z "$SQL_DB_NAME" ]]; then
            SQL_DB_NAME="$SUDO_USER"_db
        fi
        read -r -s -p "Введите пароль пользователя базы данных" SQL_USER_PASSWORD
        if [[ -z "$SQL_USER_PASSWORD" ]]; then
            echo "Вы не ввели пароль, не забудьте добавить недостающие данные вручную в envy.conf"
        fi
        read -r -p "Введите почту, которая будет использоваться для двухэтапной аутентификации при регистрации" EMAIL
        if [[ -z "$EMAIL" ]]; then
            echo "Вы не ввели почту, не забудьте добавить недостающие данные вручную в envy.conf"
        fi
        read -r -p "Введите специальный пароль приложения для используемой почты (необходимо сгенерировать вручную в google аккаунте)" EMAIL_PASSWORD
        if [[ -z "$EMAIL_PASSWORD" ]]; then
            echo "Вы не ввели специальный пароль для почты, не забудьте добавить недостающие данные вручную в envy.conf"
        fi

        SECRET_KEY="$(python3 $PROJECT_DIR/backend/secret_key_gen.py)"
        echo "Для доступа к базе данных был сгенерирован ключ $SECRET_KEY. Ключ записан в envy.conf"

        touch "$PROJECT_DIR/envy.conf"
        chown "$SUDO_USER":"$SUDO_USER" "$PROJECT_DIR/envy.conf"
        chmod 600 "$PROJECT_DIR/envy.conf"

        echo "db_name $SQL_DB_NAME" >> "$PROJECT_DIR/envy.conf"
        echo "db_username $SQL_USER" >> "$PROJECT_DIR/envy.conf"
        echo "email $EMAIL" >> "$PROJECT_DIR/envy.conf"
        echo "email_password $EMAIL_PASSWORD" >> "$PROJECT_DIR/envy.conf"
        echo "db_username_password $SQL_USER_PASSWORD" >> "$PROJECT_DIR/envy.conf"
        echo "secret_key $SECRET_KEY" >> "$PROJECT_DIR/envy.conf"

        echo "Создаем новую роль и базу данных в PostgreSQL..."
        sudo -u postgres psql -c "CREATE ROLE $SQL_USER WITH LOGIN PASSWORD '$SQL_USER_PASSWORD';"
        sudo -u postgres psql -c "CREATE DATABASE $SQL_DB_NAME;"
        echo "Конфигурация PostgreSQL была завершена"
    fi
else
    echo "PostgreSQL не установлен. Пропускаем конфигурацию"
fi

#Конфигурация python окружения
echo "Конфигурируем и устанавливаем библиотеки python-окружения..."
if [[ -d "$PROJECT_DIR/backend/.venv" ]]; then
    echo "Каталог python окружения .venv уже существует, пропускаем конфигурацию"
else
    cd "$PROJECT_DIR/backend"
    python3 -m venv .venv
    source "$PROJECT_DIR/backend/.venv/bin/activate"
    if [[ -f "$PROJECT_DIR/backend/requirements.txt" ]]; then
        echo "ЛОГ УСТАНОВКИ PYTHON БИБЛИОТЕК С ПОМОЩЬЮ PIP" &>> $LOGFILE
        echo "Устанавливаем библиотеки. Может занять некоторое время..."
        pip install -r "$PROJECT_DIR/backend/requirements.txt" &>> $LOGFILE
        echo "Библиотеки были успешно установлены"
    else
        echo "requirements.txt для pip не найден. Установите необходимые библиотеки вручную"
    fi

#Конфигурация flask-migrate для работы базы данных
    export FLASK_APP=app.py

    if [[ -d "$PROJECT_DIR/backend/migrations" ]]; then
        echo "Каталог migrations уже существует, пропускаем конфигурацию"
    else
        echo "Создаем каталог migrations для работы базы данных"
        flask db init
    fi

    echo "Обновляем таблицы базы данных..."
    flask db migrate -m "Update from setup.sh"
    flask db upgrade

    deactivate
    cd -
fi



#Вывод ключевой информации о сервере
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
