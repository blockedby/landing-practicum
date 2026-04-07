# FreshBox Landing

Лендинг сервиса доставки здоровой еды. Fullstack-приложение в Docker с Telegram-ботом для управления заявками.

## Стек

- **Frontend**: React 19, TanStack Router, TypeScript, Vite
- **Backend**: Express 5, Node.js 22
- **БД**: PostgreSQL 17, Prisma 7
- **Инфраструктура**: Docker Compose, Nginx, bash-скрипты деплоя

## Локальный запуск

```bash
# 1. Склонировать и настроить переменные
git clone <repo-url> && cd landing
cp .env.example .env        # заполнить пароли, токены

# 2. Поднять контейнеры
docker compose up -d --build

# 3. Применить миграции
docker compose exec app npx prisma migrate deploy

# 4. Открыть сайт
open http://localhost        # или порт из NGINX_PORT
```

Для локальной разработки без Docker:

```bash
npm install
npx prisma generate
npx prisma migrate dev       # нужна локальная PostgreSQL
npm run dev                  # сервер с hot-reload на :3000
```

## Миграции и seed

```bash
# Создать новую миграцию после изменений в schema.prisma
npx prisma migrate dev --name <описание>

# Применить миграции (production)
npx prisma migrate deploy

# Применить миграции на удалённом сервере
./scripts/migrate.sh <IP> <SSH_KEY> [USERNAME]

# Посмотреть данные в БД
npx prisma studio
```

## Демо-проверка

Запустить `./scripts/demo.sh` — скрипт за 2 минуты проверяет все ключевые фичи: health, создание заявки, дубликаты, трекинг событий, webhook с секретом и без.

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
