#!/usr/bin/env bash
#
# Экспорт всех таблиц из серверной БД в CSV.
# Запускается ЛОКАЛЬНО — подключается по SSH, делает
# pg_dump в CSV внутри контейнера db, копирует файлы сюда.
#
# Использование:
#   ./scripts/db-export.sh <IP> <SSH_KEY> [USERNAME]
#
# Аргументы:
#   IP        — адрес сервера
#   SSH_KEY   — путь к приватному SSH-ключу
#   USERNAME  — имя пользователя (по умолчанию: deploy)
#
# Параметры БД берутся из .env файла проекта.
#
# Пример:
#   ./scripts/db-export.sh 203.0.113.10 ~/.ssh/id_ed25519 deploy

set -euo pipefail

# ─── Аргументы ───────────────────────────────────────────────

SERVER_IP="${1:-}"
SSH_KEY_PATH="${2:-}"
USERNAME="${3:-deploy}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_DIR="/home/$USERNAME/landing"
LOCAL_DATA="$PROJECT_DIR/data"

if [[ -z "$SERVER_IP" || -z "$SSH_KEY_PATH" ]]; then
  echo "Ошибка: не указаны обязательные аргументы."
  echo "Использование: $0 <IP> <SSH_KEY> [USERNAME]"
  exit 1
fi

if [[ ! -f "$SSH_KEY_PATH" ]]; then
  echo "Ошибка: файл SSH-ключа не найден: $SSH_KEY_PATH"
  exit 1
fi

# ─── Загрузка переменных из .env ─────────────────────────────

ENV_FILE="$PROJECT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Ошибка: файл .env не найден: $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

DB_USER="${POSTGRES_USER:?POSTGRES_USER не задан в .env}"
DB_NAME="${POSTGRES_DB:?POSTGRES_DB не задан в .env}"

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -i "$SSH_KEY_PATH")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EXPORT_DIR="$LOCAL_DATA/$TIMESTAMP"

echo "═══════════════════════════════════════════════"
echo " Экспорт БД с $SERVER_IP"
echo " База: $DB_NAME"
echo " Сохранение: $EXPORT_DIR"
echo "═══════════════════════════════════════════════"
echo

# ─── 1. Получение списка таблиц ─────────────────────────────

echo "▸ [1/3] Получаю список таблиц..."

TABLES=$(ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" \
  "cd $REMOTE_DIR && docker compose exec -T db psql -U $DB_USER -d $DB_NAME -t -A -c \
    \"SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT LIKE '_prisma%';\"")

if [[ -z "$TABLES" ]]; then
  echo "  ✗ Таблицы не найдены."
  exit 1
fi

TABLE_COUNT=$(echo "$TABLES" | wc -l)
echo "  ✓ Найдено таблиц: $TABLE_COUNT"
echo

# ─── 2. Экспорт в CSV ───────────────────────────────────────

echo "▸ [2/3] Экспортирую таблицы в CSV..."

REMOTE_TMP="/tmp/db-export-$TIMESTAMP"
ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" "mkdir -p $REMOTE_TMP"

while IFS= read -r TABLE; do
  [[ -z "$TABLE" ]] && continue

  ssh -n "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" \
    "cd $REMOTE_DIR && docker compose exec -T db psql -U $DB_USER -d $DB_NAME \
      -c \"COPY \\\"$TABLE\\\" TO STDOUT WITH CSV HEADER\" > '$REMOTE_TMP/$TABLE.csv'" \
    || { echo "  ✗ Ошибка при экспорте $TABLE"; continue; }

  echo "  ✓ $TABLE"
done <<< "$TABLES"

echo

# ─── 3. Копирование на локальную машину ──────────────────────

echo "▸ [3/3] Копирую файлы..."

mkdir -p "$EXPORT_DIR"

scp "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP:$REMOTE_TMP/*.csv" "$EXPORT_DIR/" \
  && echo "  ✓ Файлы сохранены в $EXPORT_DIR" \
  || { echo "  ✗ Ошибка при копировании."; exit 1; }

# Очистка на сервере
ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" "rm -rf $REMOTE_TMP"

echo
echo "═══════════════════════════════════════════════"
echo " Экспорт завершён! Файлы:"
for f in "$EXPORT_DIR"/*.csv; do
  ROWS=$(($(wc -l < "$f") - 1))
  echo "   $(basename "$f") — $ROWS записей"
done
echo "═══════════════════════════════════════════════"
