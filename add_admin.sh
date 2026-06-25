if [ $# -lt 6 ]; then
    echo "Требуется минимум 6 параметров"
    exit 1
fi

PASSWORD_HASH="$(echo "$5" | python3 ~/docent-vpn/backend/password_to_hash.py)"
#$1 - имя пользователя
#$2 - имя бд
#$3 - логин админа
#$4 - почта админа
#$5 - пароль админа

psql -U "$1" -d "$2" -c "INSERT INTO users VALUES (0, '$3', '$4', '$PASSWORD_HASH', true, true);"
