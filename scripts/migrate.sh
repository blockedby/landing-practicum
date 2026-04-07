#!/usr/bin/env bash
#
# Применение миграций Prisma на удалённом сервере.
# Запускается ЛОКАЛЬНО — подключается по SSH и выполняет
# prisma migrate deploy внутри Docker-контейнера app.
#
# Использование:
#   ./scripts/migrate.sh <IP> <SSH_KEY> [USERNAME]
#
# Аргументы:
#   IP        — адрес сервера
#   SSH_KEY   — путь к приватному SSH-ключу (~/.ssh/id_ed25519)
#   USERNAME  — имя пользователя (по умолчанию: deploy)
#
# Пример:
#   ./scripts/migrate.sh 203.0.113.10 ~/.ssh/id_ed25519 deploy

set -euo pipefail

# ─── Аргументы ───────────────────────────────────────────────

SERVER_IP="${1:-}"
SSH_KEY_PATH="${2:-}"
USERNAME="${3:-deploy}"
REMOTE_DIR="/home/$USERNAME/landing"

if [[ -z "$SERVER_IP" || -z "$SSH_KEY_PATH" ]]; then
  echo "Ошибка: не указаны обязательные аргументы."
  echo "Использование: $0 <IP> <SSH_KEY> [USERNAME]"
  exit 1
fi

if [[ ! -f "$SSH_KEY_PATH" ]]; then
  echo "Ошибка: файл SSH-ключа не найден: $SSH_KEY_PATH"
  exit 1
fi

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -i "$SSH_KEY_PATH")

echo "═══════════════════════════════════════════════"
echo " Миграция БД на $SERVER_IP"
echo "═══════════════════════════════════════════════"
echo

# ─── 1. Проверка контейнера ──────────────────────────────────

echo "▸ [1/2] Проверяю, что контейнер app запущен..."

APP_CONTAINER=$(ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" \
  "cd $REMOTE_DIR && docker compose ps -q app" 2>/dev/null)

if [[ -z "$APP_CONTAINER" ]]; then
  echo "  ✗ Контейнер app не найден. Сначала запустите: docker compose up -d"
  exit 1
fi

echo "  ✓ Контейнер: ${APP_CONTAINER:0:12}"
echo

# ─── 2. Применение миграций ──────────────────────────────────

echo "▸ [2/2] Применяю миграции..."

ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" \
  "cd $REMOTE_DIR && docker compose exec app npx prisma migrate deploy" \
  && echo "  ✓ Миграции применены." \
  || { echo "  ✗ Ошибка при применении миграций."; exit 1; }

echo
echo "═══════════════════════════════════════════════"
echo " Готово! База данных обновлена."
echo "═══════════════════════════════════════════════"
