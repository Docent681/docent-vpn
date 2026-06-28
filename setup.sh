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
touch "$PROJECT_DIR/installation.log"
LOGFILE="$PROJECT_DIR/installation.log"
chown "$SUDO_USER":"$SUDO_USER" "$LOGFILE" "$PROJECT_DIR"

# Сброс лог-файла перед установкой
# true > "$LOGFILE"
chown "$SUDO_USER":"$SUDO_USER" "$LOGFILE"

if [[ -f /opt/outline/access.txt ]]; then
    echo "Outline VPN уже установлен в системе"
else
    echo "Устанавливаем сервер Outline VPN (лог: $LOGFILE)..."

    echo "ЛОГ УСТАНОВКИ OUTLINE VPN" &>> "$LOGFILE"
    yes | bash -c "$(wget -qO- https://raw.githubusercontent.com/OutlineFoundation/outline-apps/master/server_manager/install_scripts/install_server.sh)" &>> "$LOGFILE"

    sleep 3

    if [[ -f /opt/outline/access.txt ]]; then
        echo "Outline VPN успешно установлен."
    else
        echo "Ошибка: установка Outline не завершилась успешно. Смотрите лог $LOGFILE"
    fi
fi

# Настройка ufw, если он присутствует
if command -v ufw &>/dev/null; then
    echo "В системе обнаружен UFW. Необходимо открыть порты для Outline и веб-интерфейса."
    read -r -p "Настроить порты автоматически? [Y/n]: " AUTO_FIREWALL_CONF

    while [[ ! "$AUTO_FIREWALL_CONF" =~ ^([yYnN]?)$ ]]; do
        read -r -p "Пожалуйста, введите Y или N (или просто Enter для 'да'): " AUTO_FIREWALL_CONF
    done

    if [[ -z "$AUTO_FIREWALL_CONF" || "$AUTO_FIREWALL_CONF" =~ ^[yY]$ ]]; then
        echo "Настраиваю UFW..."
        grep 'ufw allow' "$LOGFILE" | sed -e 's/^[[:space:]]*sudo //' -e 's/[[:space:]]*$//' | while read -r cmd; do
            if [[ -n "$cmd" ]]; then
                echo "Выполняю: $cmd"
                $cmd &>> "$LOGFILE" || echo "Предупреждение: команда '$cmd' завершилась с ошибкой"
            fi
        done
        echo "Порты UFW для Outline настроены."
    # Другие необходимые порты ufw
    ufw allow 22 &>> "$LOGFILE"
    ufw allow 80 &>> "$LOGFILE"
    ufw allow 443 &>> "$LOGFILE"

    if [[ -f /opt/outline/access.txt ]]; then
        API_URL_FULL_UFW=$(sed -n '2p' /opt/outline/access.txt | sed 's/^apiUrl:[[:space:]]*//')

        HOST_PORT_UFW=$(echo "$API_URL_FULL_UFW" | awk -F/ '{print $3}')
        PORT_UFW=$(echo "$HOST_PORT_UFW" | cut -d: -f2)
        API_BASE_UFW="https://127.0.0.1:${PORT_UFW}"
        SECRET_PATH_UFW=$(echo "$API_URL_FULL_UFW" | sed -E 's|https?://[^/]+/||')

        KEYPORT=$( curl -k -X GET "$API_BASE_UFW/$SECRET_PATH_UFW/server"   -H "Content-Type: application/json" | jq ".portForNewAccessKeys")

        if [[ -z "$KEYPORT" ]]; then
            echo "Не удалось открыть порт для ключей"
        else
            ufw allow "$KEYPORT" &>> "$LOGFILE"
        fi
    else
        echo "Outline не установлен, не получается открыть порт для ключей Outline, сделайте это самостоятельно"
    fi

    echo "Включаем Фаерволл"
    ufw enable
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
	    { apt update -y && apt install -y nginx; } &>> "$LOGFILE"
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
        echo "успешно передали nginx.conf в /etc/nginx"
    else
        echo "nginx не установлен. Пропускаем конфигурацию"
    fi
else
    echo "Не найден файл конфигурации nginx.conf. Настройте nginx вручную"
fi

echo "передаем конфиг docent-vpn в nginx..."
if [[ -f "$PROJECT_DIR/docent-vpn_nginx.txt" ]]; then
    if [[ -d /etc/nginx ]]; then
        if [[ -f /etc/nginx/sites-enabled/default ]]; then
           rm /etc/nginx/sites-enabled/default
           echo "Удалили страницу nginx по умолчанию"
        fi

        cp "$PROJECT_DIR/docent-vpn_nginx.txt" /etc/nginx/sites-available/docent-vpn
        ln -s /etc/nginx/sites-available/docent-vpn /etc/nginx/sites-enabled/

        if nginx -t &>> "$LOGFILE"; then
            echo "Успешно перенесли конфиг docent-vpn в nginx"
        else
            echo "В ходе передачи конфига docent-vpn в nginx. Подробности в $LOGFILE "
        fi
    else
        echo "nginx не установлен. Пропускаем конфигурацию"
    fi
else
    echo "Не найден файл конфигурации docent-vpn_nginx.txt. Пропускаем конфигурацию"
fi

#Перезагрузка nginx
if systemctl is-active --quiet nginx; then
systemctl reload nginx || systemctl restart nginx
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
	        { apt update -y && apt install -y postgresql postgresql-contrib; } &>> "$LOGFILE"
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
        read -r -p "Введите имя базы данных (по умолчанию: '<текущий пользователь>_db'): " SQL_DB_NAME
        if [[ -z "$SQL_DB_NAME" ]]; then
            SQL_DB_NAME="$SUDO_USER"_db
        fi
        read -r -s -p "Введите пароль пользователя базы данных: " SQL_USER_PASSWORD
	echo ""
        if [[ -z "$SQL_USER_PASSWORD" ]]; then
            echo "Вы не ввели пароль, не забудьте добавить недостающие данные вручную в envy.conf"
        fi
        read -r -p "Введите почту (опционально, если вам не нужна двухэтапная аутентификация): " EMAIL
        if [[ -z "$EMAIL" ]]; then
            echo "Вы не ввели почту, не забудьте добавить недостающие данные вручную в envy.conf"
        fi
        if [[ -n "$EMAIL" ]]; then
            read -r -p "Введите специальный пароль приложения для используемой почты (необходимо сгенерировать вручную в google аккаунте): " EMAIL_PASSWORD

            if [[ -z "$EMAIL_PASSWORD" ]]; then
                echo "Вы не ввели специальный пароль для почты, не забудьте добавить недостающие данные вручную в envy.conf"
            fi
        fi

        echo "Веб-интерфейс предусматривает использование сервиса Sendgrid для отправки писем."
        read -r -p "Введите что угодно, если хотите его использовать, или просто нажмите enter, чтобы пропустить: " IS_SENDGRID_COOKED
        if [[ -n "$IS_SENDGRID_COOKED" ]]; then
            export IS_SENDGRID_COOKED="0"
            echo "Вы решили использовать sendgrid"
            read -r -p "Введите ваш sendgrid API: " SENDGRID_API
            if [[ -z "$SENDGRID_API" ]]; then
                echo "Вы не ввели ваш sendgrid API. Позже можно будет добавить ваш API в envy.conf"
            else
                echo "Ваш sendgrid API был записан в envy.conf"
            fi
        else
            export IS_SENDGRID_API="1"
            SENDGRID_API=""
            echo "Вы решили не использовать sendgrid"
        fi

        SECRET_KEY="$(python3 $PROJECT_DIR/backend/secret_key_gen.py)"
        echo "Для доступа к базе данных был сгенерирован ключ $SECRET_KEY. Ключ записан в envy.conf"

        #Открываем порты для почты
        ufw allow out 587/tcp &>> "$LOGFILE"
        ufw allow out 465/tcp &>> "$LOGFILE"

        echo "Проверяем доступность SMTP-портов..."
        if timeout 3 bash -c "echo >/dev/tcp/smtp.gmail.com/587" 2>/dev/null; then
            IS_MAIL_COOKED="0"
            echo "Порт 587 доступен. Двухэтапная аутентификация будет работать."
            echo "Если вы не хотите использовать почту, поменяйте значение is_mail_cooked в envy.conf на 1"
        elif timeout 3 bash -c "echo >/dev/tcp/smtp.gmail.com/465" 2>/dev/null; then
            IS_MAIL_COOKED="0"
            echo "Порт 465 доступен. Будет использоваться SSL (порт 465)."
            echo "Если вы не хотите использовать почту, поменяйте значение is_mail_cooked в envy.conf на 1"
        else
            IS_MAIL_COOKED="1"
            echo "SMTP-порты недоступны (вероятна блокировка провайдера). Двухэтапная аутентификация отключена."
        fi

        > "$PROJECT_DIR/envy.conf"
        chown "$SUDO_USER":"$SUDO_USER" "$PROJECT_DIR/envy.conf"
        chmod 600 "$PROJECT_DIR/envy.conf"

        echo "db_name $SQL_DB_NAME" >> "$PROJECT_DIR/envy.conf"
        echo "db_username $SQL_USER" >> "$PROJECT_DIR/envy.conf"
        echo "email $EMAIL" >> "$PROJECT_DIR/envy.conf"
        echo "email_password $EMAIL_PASSWORD" >> "$PROJECT_DIR/envy.conf"
        echo "db_username_password $SQL_USER_PASSWORD" >> "$PROJECT_DIR/envy.conf"
        echo "secret_key $SECRET_KEY" >> "$PROJECT_DIR/envy.conf"
        echo "is_mail_cooked $IS_MAIL_COOKED" >> "$PROJECT_DIR/envy.conf"

        # Добавляем api_url и outline_secret_path из /opt/outline/access.txt
        if [[ -f /opt/outline/access.txt ]]; then
            API_URL_FULL=$(sed -n '2p' /opt/outline/access.txt | sed 's/^apiUrl:[[:space:]]*//')

            HOST_PORT=$(echo "$API_URL_FULL" | awk -F/ '{print $3}')
            PORT=$(echo "$HOST_PORT" | cut -d: -f2)
            API_BASE="https://127.0.0.1:${PORT}"
            SECRET_PATH=$(echo "$API_URL_FULL" | sed -E 's|https?://[^/]+/||')

            echo "api_url $API_BASE" >> "$PROJECT_DIR/envy.conf"
            echo "outline_secret_path $SECRET_PATH" >> "$PROJECT_DIR/envy.conf"
        else
            echo "/opt/outline/access.txt не найден, api_url и outline_secret_path не записаны. Не забудьте добавить данные вручную в envy.conf"
        fi

        echo "is_sendgrid_cooked $IS_SENDGRID_COOKED" >> "$PROJECT_DIR/envy.conf"
        echo "sendgrid_api $SENDGRID_API" >> "$PROJECT_DIR/envy.conf"

        echo "Создаем новую роль и базу данных в PostgreSQL..."
        sudo -u postgres psql -c "CREATE ROLE $SQL_USER WITH LOGIN PASSWORD '$SQL_USER_PASSWORD';" &>> "$LOGFILE"
        sudo -u postgres psql -c "CREATE DATABASE $SQL_DB_NAME;" &>> "$LOGFILE"
	    sudo -u postgres psql -c "ALTER DATABASE \"$SQL_DB_NAME\" OWNER TO \"$SQL_USER\";" &>> "$LOGFILE"
	    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$SQL_DB_NAME\" TO \"$SQL_USER\";" &>> "$LOGFILE"
	    sudo -u postgres psql -d "$SQL_DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$SQL_USER\";" &>> "$LOGFILE"

        read -r -p "Введите логин администратора веб-интерфейса (по умолчанию пользователь БД): " WEB_ADMIN
        if [[ -z "$WEB_ADMIN" ]]; then
            WEB_ADMIN="$SQL_USER"
        fi
        read -r -p "Введите почту администратора веб-интерфейса (по умолчанию <пользователь>@gmail.com ): " WEB_ADMIN_EMAIL
        if [[ -z "$WEB_ADMIN_EMAIl" ]]; then
            WEB_ADMIN_EMAIL="$WEB_ADMIN@gmail.com"
        fi
        read -r -p "Введите пароль администратора веб-интерфейса (по умолчанию пароль пользователя БД): " WEB_ADMIN_PASSWORD
        if [[ -z "$WEB_ADMIN_PASSWORD" ]]; then
            WEB_ADMIN_PASSWORD="$SQL_USER_PASSWORD"
        fi


        # Непосредственное добавление перенесено в блок после установки .venv окружения,
        # так как используется .py скрипт
        echo "Аккаунт администратора будет создан после настройки .venv окружения"
        echo "Логин: $WEB_ADMIN"
        echo "Почта: $WEB_ADMIN_EMAIL"
        echo "Пароль: $WEB_ADMIN_PASSWORD"

        echo "Конфигурация PostgreSQL была завершена"
    fi
else
    echo "PostgreSQL не установлен. Пропускаем конфигурацию"
fi

# Установка системных зависимостей для Python
echo "Проверяем и устанавливаем python3-venv и python3-pip..."
if ! command -v python3 &>/dev/null; then
    echo "Python3 не найден. Установите python3 вручную."
    exit 1
fi

if command -v apt &>/dev/null; then
    # Устанавливаем пакеты, если они ещё не установлены
    if ! dpkg -l python3-venv &>/dev/null; then
        echo "Устанавливаем python3-venv..."
        apt update -y &>> "$LOGFILE" && apt install -y python3-venv &>> "$LOGFILE"
    fi
    if ! dpkg -l python3-pip &>/dev/null; then
        echo "Устанавливаем python3-pip..."
        apt install -y python3-pip &>> "$LOGFILE"
    fi
else
    echo "Пакетный менеджер apt не обнаружен. Установите python3-venv и python3-pip вручную."
    exit 1
fi

#Конфигурация python окружения
echo "Конфигурируем и устанавливаем библиотеки Python-окружения..."

# Проверяем, существует ли уже venv
if [[ -d "$PROJECT_DIR/backend/.venv" ]]; then
    echo "Каталог python окружения .venv уже существует, пропускаем создание."
else
    echo "Создаём виртуальное окружение от имени пользователя $SUDO_USER..."
    sudo -u "$SUDO_USER" python3 -m venv "$PROJECT_DIR/backend/.venv"
    if [[ $? -ne 0 ]]; then
        echo "Ошибка создания виртуального окружения."
        exit 1
    fi
fi

# Устанавливаем зависимости (pip из venv)
if [[ -f "$PROJECT_DIR/backend/requirements.txt" ]]; then
    echo "Устанавливаем библиотеки (может занять время)..."
    sudo -u "$SUDO_USER" "$PROJECT_DIR/backend/.venv/bin/pip" install -r "$PROJECT_DIR/backend/requirements.txt" &>> "$LOGFILE"
    if [[ $? -ne 0 ]]; then
        echo "Ошибка установки Python-библиотек. Смотрите лог."
        exit 1
    fi
    echo "Библиотеки успешно установлены."
else
    echo "Файл requirements.txt не найден. Пропускаем установку."
fi

# Инициализация и выполнение миграций Flask
echo "Настраиваем базу данных (Flask-Migrate)..."
if [[ -d "$PROJECT_DIR/backend/migrations" ]]; then
    echo "Каталог migrations уже существует, пропускаем инициализацию."
else
    echo "Инициализируем миграции..."
    sudo -u "$SUDO_USER" bash -c "
        cd \"$PROJECT_DIR/backend\"
        export FLASK_APP=app.py
        .venv/bin/flask db init
    " &>> "$LOGFILE"
    if [[ $? -ne 0 ]]; then
        echo "Ошибка инициализации миграций. Смотрите лог."
        exit 1
    fi
fi

echo "Обновляем таблицы базы данных..."
sudo -u "$SUDO_USER" bash -c "
    cd \"$PROJECT_DIR/backend\"
    export FLASK_APP=app.py
    .venv/bin/flask db migrate -m 'Update from setup.sh'
    .venv/bin/flask db upgrade
" &>> "$LOGFILE"
if [[ $? -ne 0 ]]; then
    echo "Ошибка применения миграций. Смотрите лог."
    exit 1
fi

# Создание первого администратора веб-интерфейса
if [[ -n "$WEB_ADMIN" && -n "$WEB_ADMIN_EMAIL" && -n "$WEB_ADMIN_PASSWORD" ]]; then
    echo "Создаём учётную запись администратора $WEB_ADMIN ..."
    PASSWORD_HASH=$(echo "$WEB_ADMIN_PASSWORD" | sudo -u "$SUDO_USER" "$PROJECT_DIR/backend/.venv/bin/python" "$PROJECT_DIR/backend/password_to_hash.py")

    sudo -u "$SUDO_USER" PGPASSWORD="$SQL_USER_PASSWORD" psql \
        -U "$SQL_USER" \
        -d "$SQL_DB_NAME" \
        -c "INSERT INTO users VALUES (0, '$WEB_ADMIN', '$WEB_ADMIN_EMAIL', '$PASSWORD_HASH', true, true);"

    if [[ $? -eq 0 ]]; then
        echo "Администратор $WEB_ADMIN успешно зарегистрирован."
    else
        echo "Ошибка при создании администратора (возможно, таблица users не найдена)."
    fi
else
    echo "Не все данные администратора введены, пропускаем создание учётной записи."
fi


echo "Конфигурация Python-окружения завершена."

#Создание службы в systemd
echo "Организуем автозапуск сервера через systemd..."
if [[ -f "$PROJECT_DIR/docent-vpn.service"  ]]; then
    awk -v user="$SUDO_USER" \
    -v group="$SUDO_USER" \
    -v wd="$PROJECT_DIR/backend" \
    -v env_path="$PROJECT_DIR/backend/.venv/bin" \
    -v exec_cmd="$PROJECT_DIR/backend/.venv/bin/gunicorn -w 4 -b 127.0.0.1:8000 app:app" '
    /^User=/             { printf "User=%s\n", user; next }
    /^Group=/            { printf "Group=%s\n", group; next }
    /^WorkingDirectory=/ { printf "WorkingDirectory=%s\n", wd; next }
    /^Environment="PATH=/{ printf "Environment=\"PATH=%s\"\n", env_path; next }
    /^ExecStart=/        { printf "ExecStart=%s\n", exec_cmd; next }
    { print }
' "$PROJECT_DIR/docent-vpn.service" > "$PROJECT_DIR/docent-vpn.service.tmp" && mv "$PROJECT_DIR/docent-vpn.service.tmp" "$PROJECT_DIR/docent-vpn.service"
    cp "$PROJECT_DIR/docent-vpn.service" /etc/systemd/system/docent-vpn.service

    systemctl daemon-reload &>> "$LOGFILE"
    systemctl enable --now docent-vpn &>> "$LOGFILE"

    echo "автозапуск сервера был успешно настроен"
else
    echo "В проекте не найден файл docent-vpn.service. Пропускаем конфигурацию автозапуска"
fi


#Вывод итоговой информации
echo "=============================="
echo "Установка завершена."
echo "При необходимости не забудьте добавить недостающие данные в envy.conf"
echo "Информация о сервере"

if [[ -f /opt/outline/access.txt ]]; then
    API_URL=$(sed -n '2p' /opt/outline/access.txt)

    if [[ -n "$API_URL" ]]; then
        echo "API URL: $API_URL"

        API_HOST_PORT=$(echo "$API_URL" | awk -F/ '{print $3}')
        API_HOST=$(echo "$API_HOST_PORT" | cut -d: -f1)
        API_PORT=$(echo "$API_HOST_PORT" | cut -sd: -f2)

        echo "IP-адрес сервера: $API_HOST"
        if [[ -n "$API_PORT" ]]; then
            echo "Служебный порт (API): $API_PORT"
            echo "Порт для ключей Outline: $KEYPORT"
        fi
    fi
else
	echo "Не получилось обратиться к access.txt"
fi
echo "=============================="


exit 0
