#!/bin/bash

# Настройки
CONFIG_FILE="$HOME/docent-vpn/envy.conf"
SLEEP_INTERVAL=300 # 5 минут

TYPES=("login_info" "request_info" "admin_info" "keys_info")
THRESHOLD=500


# === Чтение имени базы ===
if [ ! -f "$CONFIG_FILE" ]; then
    exit 1
fi

DB_NAME=$(awk '/^db_name/ {print $2}' "$CONFIG_FILE")
if [ -z "$DB_NAME" ]; then
    exit 1
fi


# Основной цикл
while true; do
    for type in "${TYPES[@]}"; do
        count=$(psql -d "$DB_NAME" -tA -c "SELECT COUNT(*) FROM logs WHERE type = '$type';")

        if [ -z "$count" ]; then
            continue
        fi

        if [ "$count" -gt "$THRESHOLD" ]; then
            excess=$((count - THRESHOLD))

            psql -d "$DB_NAME" -tA \
                -c "DELETE FROM logs WHERE id IN (
                      SELECT id FROM logs
                      WHERE type = '$type'
                      ORDER BY date ASC
                      LIMIT $excess
                    );"
        fi
    done

    sleep "$SLEEP_INTERVAL"
done
