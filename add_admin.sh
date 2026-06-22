if [ $# -lt 6 ]; then
    echo "Требуется минимум 6 параметров"
    exit 1
fi

PASSWORD_HASH="$(echo "$6" | python3 ~/docent-vpn/backend/password_to_hash.py)"
#$1 - имя пользователя
#$2 - имя бд
#$3 - имя таблицы пользователей
#$4 - логин админа
#$5 - почта админа
#$6 - пароль админа

psql -U "$1" -d "$2" -c "INSERT INTO users VALUES (0, '$4', '$5', '$PASSWORD_HASH', true, true);"
