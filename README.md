# FreshBox Landing

**https://baza.peacedata.company**

Лендинг сервиса доставки здоровой еды. Fullstack-приложение в Docker с Telegram-ботом для управления заявками.

## Стек

- **Frontend**: React 19, TanStack Router, TypeScript, Vite
- **Backend**: Express 5, Node.js 22
- **БД**: PostgreSQL 17, Prisma 7
- **Инфраструктура**: Docker Compose, Nginx, bash-скрипты деплоя

---

## Как запустить локально

### Вариант 1: Docker (рекомендуемый)

```bash
git clone https://github.com/blockedby/landing-practicum.git
cd landing-practicum

# Настроить переменные окружения
cp .env.example .env
# Отредактировать .env — заполнить пароли, токены бота и т.д.

# Поднять все 3 сервиса (nginx + app + postgres)
docker compose up -d --build

# Применить миграции базы данных
docker compose exec app npx prisma migrate deploy

# Готово — открываем
open http://localhost
```

### Вариант 2: без Docker (для разработки)

Нужна локальная PostgreSQL. Прописать `DATABASE_URL` в `.env` с `localhost`.

```bash
npm install
npx prisma generate
npx prisma migrate dev    # создаст таблицы в локальной БД
npm run dev               # Express + Vite, hot-reload на :3000
```

---

## Как прогнать миграции

```bash
# Локально — создать новую миграцию после изменений в schema.prisma
npx prisma migrate dev --name add_user_email

# Локально — применить существующие миграции (без создания новых)
npx prisma migrate deploy

# На удалённом сервере — через SSH в Docker-контейнер
./scripts/migrate.sh <IP> <SSH_KEY> [USERNAME]

# Посмотреть данные в браузере
npx prisma studio
```

Текущие миграции:
- `20260406233653_init_tables` — Visitor, Lead, EventLog
- `20260407220657_add_lead_status` — enum LeadStatus (new/contacted/rejected)

---

## Демо-скрипт: проверить всё за 2 минуты

```bash
./scripts/demo.sh http://localhost
```

Скрипт автоматически проверяет 12 тестов:

```
═══════════════════════════════════════════════
 Демо-проверка: http://localhost
═══════════════════════════════════════════════

▸ [1/6] Health check...
  ✓ БД подключена

▸ [2/6] Лендинг отдаёт HTML...
  ✓ HTML содержит root
  ✓ Подключены стили

▸ [3/6] Создание заявки...
  ✓ Заявка создана (201)
  ✓ Ответ содержит id

▸ [4/6] Проверка дубликата...
  ✓ Дубликат отклонён (409)

▸ [5/6] Трекинг событий...
  ✓ landing_view записан
  ✓ cta_click записан
  ✓ Неизвестное событие отклонено (400)

▸ [6/6] Webhook...
  ✓ Без секрета — 401
  ✓ С секретом — 201
  ✓ Дубль — duplicate

═══════════════════════════════════════════════
 Все проверки пройдены: 12/12
═══════════════════════════════════════════════
```

---

## Структура

```
src/
  client/                   # React SPA
    sections/               # Hero, Proof, Benefits, FAQ, CTA
    pages/Home.tsx
    tracking.ts             # отправка событий аналитики
  server/
    index.ts                # Express API + Telegram bot polling
prisma/
  schema.prisma             # Visitor, Lead, EventLog
  migrations/
nginx/
  default.conf
scripts/
  setup-vps.sh              # настройка свежего Ubuntu-сервера
  deploy.sh                 # деплой через rsync + docker compose
  migrate.sh                # применение миграций на сервере
  db-export.sh              # экспорт таблиц в CSV
```

## Лендинг

5 секций: Hero (CTA-кнопка), Proof (партнёры + "10 000+ доставок"), Benefits (4 карточки), FAQ (аккордеон), CTA (форма заявки).

Форма с валидацией: имя (буквы, 2-100 символов), телефон (автоформат +7), обязательное согласие на обработку данных. Ошибки валидации — и клиентские, и серверные.

## API

| Метод | Эндпоинт | Описание |
|-------|----------|----------|
| GET | `/api/health` | Проверка соединения с БД |
| POST | `/api/leads` | Создание заявки |
| POST | `/api/events` | Трекинг событий (landing_view, cta_click) |
| POST | `/api/webhook` | Приём внешних событий (заголовок X-Webhook-Secret) |

## База данных

- **Visitor** — fingerprint, IP, user agent, дата первого визита
- **Lead** — имя, контакт (unique), согласие, статус (new / contacted / rejected)
- **EventLog** — тип, источник (internal / external), idempotency key, JSON-данные, связи с visitor и lead

## Аналитика

Клиент отправляет события через `sendBeacon`:
- `landing_view` — загрузка страницы (URL, referrer)
- `cta_click` — клик на кнопку Hero или скролл до формы

## Telegram-бот

При создании заявки бот отправляет уведомление с inline-кнопками для смены статуса ("Связался" / "Не актуален").

Команды:
- `/leads` — последние 5 заявок со статусами
- `/leads week` — заявки за последнюю неделю
- `/stats` — воронка за 7 дней: посещения, клики, заявки

## Webhook

`POST /api/webhook` принимает внешние события. Требует заголовок `X-Webhook-Secret`. Дедупликация по `idempotencyKey`.

## Скрипты

```bash
# Настройка сервера (от root, создаёт пользователя, UFW, Docker, SSH)
./scripts/setup-vps.sh <IP> <SSH_PUB_KEY> [USERNAME]

# Деплой (rsync + docker compose up --build)
./scripts/deploy.sh <IP> <SSH_KEY> [USERNAME]

# Миграции на сервере
./scripts/migrate.sh <IP> <SSH_KEY> [USERNAME]

# Экспорт БД в CSV (сохраняет в data/)
./scripts/db-export.sh <IP> <SSH_KEY> [USERNAME]
```

## Переменные окружения

| Переменная | Описание |
|------------|----------|
| `POSTGRES_USER` | Пользователь PostgreSQL |
| `POSTGRES_PASSWORD` | Пароль PostgreSQL |
| `POSTGRES_DB` | Имя базы данных |
| `DATABASE_URL` | Строка подключения к БД |
| `WEBHOOK_SECRET` | Секрет для входящих вебхуков |
| `TG_BOT_TOKEN` | Токен Telegram-бота |
| `TG_CHAT_ID` | ID чата для уведомлений |
