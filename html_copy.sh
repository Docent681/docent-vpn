#!/usr/bin/bash

# Проверка, что скрипт запущен через sudo от обычного пользователя
if [[ -z "${SUDO_USER:-}" ]]; then
    echo "Ошибка: скрипт должен быть запущен через sudo, а не от root напрямую."
    exit 1
fi

USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
PROJECTDIR="$USER_HOME/docent-vpn"

cp $PROJECTDIR/backend/templates/* /var/www/html/
echo "Страницы сайтов были успешно скопированы"

exit 0

