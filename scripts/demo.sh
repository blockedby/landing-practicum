#!/usr/bin/env bash
#
# Демо-проверка всех ключевых фич лендинга.
# Запускать при работающих контейнерах.
#
# Использование:
#   ./scripts/demo.sh [BASE_URL]
#
# По умолчанию: http://localhost
# Пример:
#   ./scripts/demo.sh http://localhost:81

set -euo pipefail

BASE="${1:-http://localhost}"
PASS=0
FAIL=0

check() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if echo "$actual" | grep -q "$expected"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    ожидалось: $expected"
    echo "    получено:  $actual"
    FAIL=$((FAIL + 1))
  fi
}

echo "═══════════════════════════════════════════════"
echo " Демо-проверка: $BASE"
echo "═══════════════════════════════════════════════"
echo

# ─── 1. Health ───────────────────────────────────

echo "▸ [1/6] Health check..."
RESP=$(curl -s "$BASE/api/health")
check "БД подключена" '"db":"connected"' "$RESP"
echo

# ─── 2. Лендинг ─────────────────────────────────

echo "▸ [2/6] Лендинг отдаёт HTML..."
HTML=$(curl -s "$BASE/")
check "HTML содержит root" 'id="root"' "$HTML"
check "Подключены стили" '.css' "$HTML"
echo

# ─── 3. Создание заявки ─────────────────────────

echo "▸ [3/6] Создание заявки..."
UNIQUE="demo-$(date +%s)"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/leads" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Демо Тест\",\"contact\":\"+7 (900) 000-${UNIQUE: -2}-${UNIQUE: -4:2}\",\"consent\":true,\"fingerprint\":\"demo-fp-$UNIQUE\"}")
CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check "Заявка создана (201)" "201" "$CODE"
check "Ответ содержит id" '"ok":true' "$BODY"
echo

# ─── 4. Дубликат ────────────────────────────────

echo "▸ [4/6] Проверка дубликата..."
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/leads" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Демо Тест\",\"contact\":\"+7 (900) 000-${UNIQUE: -2}-${UNIQUE: -4:2}\",\"consent\":true,\"fingerprint\":\"demo-fp-$UNIQUE\"}")
CODE=$(echo "$RESP" | tail -1)
check "Дубликат отклонён (409)" "409" "$CODE"
echo

# ─── 5. Трекинг событий ─────────────────────────

echo "▸ [5/6] Трекинг событий..."
RESP=$(curl -s "$BASE/api/events" -X POST \
  -H "Content-Type: application/json" \
  -d '{"type":"landing_view","fingerprint":"demo-fp","data":{"url":"demo","referrer":null}}')
check "landing_view записан" '"ok":true' "$RESP"

RESP=$(curl -s "$BASE/api/events" -X POST \
  -H "Content-Type: application/json" \
  -d '{"type":"cta_click","fingerprint":"demo-fp","data":{"action":"demo_test"}}')
check "cta_click записан" '"ok":true' "$RESP"

RESP=$(curl -s -w "\n%{http_code}" "$BASE/api/events" -X POST \
  -H "Content-Type: application/json" \
  -d '{"type":"fake_event","fingerprint":"demo-fp","data":{}}')
CODE=$(echo "$RESP" | tail -1)
check "Неизвестное событие отклонено (400)" "400" "$CODE"
echo

# ─── 6. Webhook ─────────────────────────────────

echo "▸ [6/6] Webhook..."
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/webhook" \
  -H "Content-Type: application/json" \
  -d '{"type":"test","data":{},"idempotencyKey":"demo-key"}')
CODE=$(echo "$RESP" | tail -1)
check "Без секрета — 401" "401" "$CODE"

# Попробуем с секретом из .env (если доступен)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
if [[ -f "$ENV_FILE" ]]; then
  SECRET=$(grep '^WEBHOOK_SECRET=' "$ENV_FILE" | cut -d= -f2-)
  if [[ -n "$SECRET" ]]; then
    RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/api/webhook" \
      -H "Content-Type: application/json" \
      -H "X-Webhook-Secret: $SECRET" \
      -d "{\"type\":\"test\",\"data\":{},\"idempotencyKey\":\"demo-$UNIQUE\"}")
    CODE=$(echo "$RESP" | tail -1)
    BODY=$(echo "$RESP" | head -1)
    check "С секретом — 201" "201" "$CODE"

    RESP=$(curl -s "$BASE/api/webhook" -X POST \
      -H "Content-Type: application/json" \
      -H "X-Webhook-Secret: $SECRET" \
      -d "{\"type\":\"test\",\"data\":{},\"idempotencyKey\":\"demo-$UNIQUE\"}")
    check "Дубль — duplicate" '"duplicate":true' "$RESP"
  fi
fi
echo

# ─── Итог ────────────────────────────────────────

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════"
if [[ $FAIL -eq 0 ]]; then
  echo " Все проверки пройдены: $PASS/$TOTAL"
else
  echo " Пройдено: $PASS/$TOTAL, ошибок: $FAIL"
fi
echo "═══════════════════════════════════════════════"

exit $FAIL
