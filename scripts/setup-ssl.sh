#!/usr/bin/env bash
#
# Настройка HTTPS с Let's Encrypt через Certbot.
# Запускается ЛОКАЛЬНО — подключается к серверу по SSH.
#
# Требования: контейнеры уже запущены (deploy.sh выполнен).
#
# Использование:
#   ./scripts/setup-ssl.sh <IP> <SSH_KEY> <DOMAIN> [USERNAME]
#
# Аргументы:
#   IP        — адрес сервера
#   SSH_KEY   — путь к приватному SSH-ключу
#   DOMAIN    — домен (например, freshbox.example.com)
#   USERNAME  — имя пользователя (по умолчанию: deploy)
#
# Пример:
#   ./scripts/setup-ssl.sh 203.0.113.10 ~/.ssh/id_ed25519 freshbox.ru deploy

set -euo pipefail

# ─── Аргументы ───────────────────────────────────────────────

SERVER_IP="${1:-}"
SSH_KEY_PATH="${2:-}"
DOMAIN="${3:-}"
USERNAME="${4:-deploy}"
REMOTE_DIR="/home/$USERNAME/landing"

if [[ -z "$SERVER_IP" || -z "$SSH_KEY_PATH" || -z "$DOMAIN" ]]; then
  echo "Ошибка: не указаны обязательные аргументы."
  echo "Использование: $0 <IP> <SSH_KEY> <DOMAIN> [USERNAME]"
  exit 1
fi

if [[ ! -f "$SSH_KEY_PATH" ]]; then
  echo "Ошибка: файл SSH-ключа не найден: $SSH_KEY_PATH"
  exit 1
fi

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -i "$SSH_KEY_PATH")

echo "═══════════════════════════════════════════════"
echo " Настройка SSL для $DOMAIN"
echo " Сервер: $SERVER_IP"
echo "═══════════════════════════════════════════════"
echo

# ─── 1. Проверка что контейнеры запущены ─────────

echo "▸ [1/4] Проверяю контейнеры..."

NGINX_UP=$(ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" \
  "cd $REMOTE_DIR && docker compose ps -q nginx" 2>/dev/null)

if [[ -z "$NGINX_UP" ]]; then
  echo "  ✗ Nginx не запущен. Сначала выполните deploy.sh"
  exit 1
fi

echo "  ✓ Контейнеры работают."
echo

# ─── 2. Получение сертификата ────────────────────

echo "▸ [2/4] Получаю сертификат Let's Encrypt..."

ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" \
  "cd $REMOTE_DIR && docker compose run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    --email admin@$DOMAIN \
    --agree-tos --no-eff-email \
    -d $DOMAIN" \
  && echo "  ✓ Сертификат получен." \
  || { echo "  ✗ Ошибка при получении сертификата."; exit 1; }

echo

# ─── 3. Установка SSL-конфига nginx ──────────────

echo "▸ [3/4] Настраиваю Nginx для HTTPS..."

ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" \
  "cd $REMOTE_DIR && sed 's/\${DOMAIN}/$DOMAIN/g' nginx/ssl.conf.template > nginx/default.conf"

ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" \
  "cd $REMOTE_DIR && docker compose restart nginx" \
  && echo "  ✓ Nginx перезапущен с SSL." \
  || { echo "  ✗ Ошибка при перезапуске Nginx."; exit 1; }

echo

# ─── 4. Автообновление сертификата ───────────────

echo "▸ [4/4] Настраиваю автообновление..."

CRON_CMD="0 3 * * 0 cd $REMOTE_DIR && docker compose run --rm certbot renew && docker compose restart nginx"

ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" \
  "(crontab -l 2>/dev/null | grep -v 'certbot renew'; echo '$CRON_CMD') | crontab -" \
  && echo "  ✓ Cron: обновление каждое воскресенье в 03:00." \
  || { echo "  ✗ Ошибка при настройке cron."; exit 1; }

echo
echo "═══════════════════════════════════════════════"
echo " SSL настроен!"
echo " https://$DOMAIN"
echo "═══════════════════════════════════════════════"
