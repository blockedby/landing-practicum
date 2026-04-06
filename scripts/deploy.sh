#!/usr/bin/env bash
#
# Деплой проекта на сервер.
# Запускается ЛОКАЛЬНО — копирует файлы и запускает Docker на сервере.
#
# Использование:
#   ./scripts/deploy.sh <IP> <SSH_KEY> [USERNAME]
#
# Аргументы:
#   IP        — адрес сервера
#   SSH_KEY   — путь к приватному SSH-ключу (~/.ssh/id_ed25519)
#   USERNAME  — имя пользователя (по умолчанию: deploy)
#
# Пример:
#   ./scripts/deploy.sh 203.0.113.10 ~/.ssh/id_ed25519 deploy

set -euo pipefail

# ─── Аргументы ───────────────────────────────────────────────

SERVER_IP="${1:-}"
SSH_KEY_PATH="${2:-}"
USERNAME="${3:-deploy}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
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
echo " Деплой на $SERVER_IP"
echo " Пользователь: $USERNAME"
echo " Проект:       $PROJECT_DIR"
echo "═══════════════════════════════════════════════"
echo

# ─── 1. Копирование файлов ──────────────────────────────────

echo "▸ [1/3] Копирование файлов на сервер..."

rsync -az --delete \
  --exclude node_modules \
  --exclude .git \
  --exclude dist \
  -e "ssh ${SSH_OPTS[*]}" \
  "$PROJECT_DIR/" "$USERNAME@$SERVER_IP:$REMOTE_DIR/" \
  && echo "  ✓ Файлы скопированы в $REMOTE_DIR" \
  || { echo "  ✗ Ошибка при копировании файлов."; exit 1; }

echo

# ─── 2. Сборка и запуск контейнеров ─────────────────────────

echo "▸ [2/3] Запуск docker compose на сервере..."

ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" \
  "cd $REMOTE_DIR && docker compose up -d --build" \
  && echo "  ✓ Контейнеры запущены." \
  || { echo "  ✗ Ошибка при запуске контейнеров."; exit 1; }

echo

# ─── 3. Готово ───────────────────────────────────────────────

echo "═══════════════════════════════════════════════"
echo " Деплой завершён!"
echo " Сайт: http://$SERVER_IP"
echo "═══════════════════════════════════════════════"
