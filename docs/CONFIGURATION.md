# Конфигурация

## Переменные окружения

### Администратор

| Переменная | Описание | Пример |
|------------|----------|--------|
| `SUDO_USERNAME` | Логин администратора | `admin` |
| `SUDO_PASSWORD` | Пароль администратора | `secure_password` |

### База данных

По умолчанию используется **SQLite** — отдельный контейнер БД не нужен.

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `SQLALCHEMY_DATABASE_URL` | URL подключения к внешней БД (опционально) | не задано → SQLite |

**SQLite (рекомендуется для одной ноды):**
- НЕ задавайте `SQLALCHEMY_DATABASE_URL` — Marzban сам создаст файл БД.
- Файл БД: `/var/lib/marzban/db.sqlite3` (в томе `marzban_data`).
- Бэкап = копия одного файла, минимум RAM, без отдельного контейнера.

**Внешняя БД (опционально):**
- Поддерживается ТОЛЬКО MySQL/MariaDB (через PyMySQL). PostgreSQL не поддерживается — драйвера нет в зависимостях Marzban v0.8.4.
- Заранее создайте базу `marzban-db` и пользователя, хост должен быть доступен из `dokploy-network`:
  ```env
  SQLALCHEMY_DATABASE_URL=mysql+pymysql://marzban:your_db_password@<db-host>:3306/marzban-db
  ```
- Встроенный контейнер MySQL из `docker-compose.marzban.yml` удалён. Многонодовый вариант с MySQL см. в [SWARM.md](SWARM.md).

### Сеть

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `UVICORN_HOST` | Адрес прослушивания | `0.0.0.0` |
| `UVICORN_PORT` | Порт панели | `8003` |
| `DOMAIN` | Домен сервера | - |

### SSL

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `DISABLE_INTERNAL_SSL` | Отключить внутренний SSL | `false` |
| `USE_LETSENCRYPT_CERTS` | Использовать Let's Encrypt | `false` |
| `LETSENCRYPT_CERT_PATH` | Путь к сертификату | - |
| `LETSENCRYPT_KEY_PATH` | Путь к ключу | - |
| `SSL_CERT_DAYS` | Срок самоподписанного сертификата | `365` |

> ⚠️ **Для Dokploy / контейнерного Traefik оставляйте `DISABLE_INTERNAL_SSL=false`.**
> Marzban v0.8.4 без SSL-сертификата биндится ТОЛЬКО на `127.0.0.1` и недоступен извне
> (в т.ч. для Traefik в отдельном контейнере). С `DISABLE_INTERNAL_SSL=false` он
> слушает `https://0.0.0.0:8003` (self-signed). Подробнее: [SSL.md](SSL.md).

### VLESS Reality

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `REALITY_PRIVATE_KEY` | Приватный ключ Reality | автогенерация |
| `REALITY_PUBLIC_KEY` | Публичный ключ Reality | автогенерация |
| `REALITY_DEST` | Целевой сервер (зависит от роли ноды) | `www.microsoft.com:443` |
| `REALITY_SERVER_NAMES` | SNI имена (зависит от роли ноды) | `www.microsoft.com` |

**Reality-ключи генерируются автоматически.**
Если оставить `REALITY_PRIVATE_KEY`/`REALITY_PUBLIC_KEY` пустыми, `docker-entrypoint.sh`
при первом старте сам сгенерирует пару, выведет её в логи (`docker logs marzban`) и
сохранит в `/var/lib/marzban/reality_keys.env`. Скопируйте ключи оттуда в `.env`,
чтобы они пережили пересоздание тома.

> ⚠️ НЕ используйте кнопку генерации ключей в панели Marzban v0.8.4 — она ждёт старый
> формат вывода `x25519`, а Xray v26 выдаёт новый. Берите ключи только из логов или `.env`.

**SNI зависит от роли ноды** (IP↔SNI mismatch — DPI флагует Yandex-SNI на не-РФ IP):
- **EXIT за границей** (наш случай): глобальный сервис, чьи IP правдоподобны где угодно.
  ```env
  REALITY_DEST=www.microsoft.com:443
  REALITY_SERVER_NAMES=www.microsoft.com
  ```
  Допустимо `github.com`, `www.twitch.tv`. НЕ `apple.com` (собственный ASN), НЕ `ya.ru` за границей.
- **BRIDGE в РФ**: `ya.ru` уместен.
  ```env
  REALITY_DEST=ya.ru:443
  REALITY_SERVER_NAMES=ya.ru,www.ya.ru
  ```

### WARP

По умолчанию WARP **отключён** — трафик идёт напрямую с exit-IP, в `config.json`
нет warp-outbound и warp-роутинга.

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `WARP_ENABLED` | Включить WARP роутинг | `false` |
| `WARP_HOST` | Хост WARP прокси | `warp-proxy` |
| `WARP_PORT` | Порт WARP прокси | `1080` |

WARP нужен, только если конкретный сервис блокирует datacenter-IP (напр. OpenAI). Тогда:
задеплойте `docker-compose.warp.yml`, верните warp-outbound + routing в `config.json` и
выставьте `WARP_ENABLED=true`. Серверный WARP предпочтительнее клиентского.

### Telegram

| Переменная | Описание |
|------------|----------|
| `TELEGRAM_API_TOKEN` | Токен бота (@BotFather) |
| `TELEGRAM_ADMIN_ID` | ID администратора (@userinfobot) |

### Уведомления

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `NOTIFY_REACHED_USAGE_PERCENT` | Процент для предупреждения | `80` |
| `NOTIFY_DAYS_LEFT` | Дней до окончания | `3` |

### Автоудаление

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `USERS_AUTODELETE_DAYS` | Дней после истечения (-1 = отключено) | `-1` |
| `USER_AUTODELETE_INCLUDE_LIMITED_ACCOUNTS` | Включать ограниченные аккаунты | `false` |

### Таймауты

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `DB_WAIT_RETRIES` | Попытки подключения к БД | `30` |

## Xray конфигурация

Файл `config.json` — шаблон конфигурации Xray и **источник истины**. При каждом старте
`docker-entrypoint.sh` пересоздаёт `xray_config.json` из этого шаблона, поэтому правки
вносите в `config.json` в репозитории, а не в работающем файле внутри контейнера.

Xray-core запинен на **v26.3.27** в `Dockerfile` (`ARG XRAY_VERSION`) — это гарантирует
поддержку транспорта `xhttp`.

### Инбаунды и порты

| Инбаунд | Порт | Транспорт | Описание |
|---------|------|-----------|----------|
| VLESS Reality | 2443 | TCP + Reality | Запасной/совместимый канал |
| VLESS XHTTP Reality | 2444 | XHTTP (mode `stream-up`) + Reality | Основной канал против ТСПУ |

Легаси-инбаунды (VMess, VLESS plain, Trojan, Shadowsocks) удалены.

## Docker тома

| Том | Назначение |
|-----|------------|
| `marzban_data` | Данные Marzban + файл SQLite (`db.sqlite3`) + `reality_keys.env` |
| `marzban_configs` | Конфигурации (`/app/configs`) |
| `marzban_logs` | Логи Xray |

## Файловая структура

```
marzban-vpn/
├── Dockerfile                    # Сборка образа (Xray запинен на v26.3.27)
├── docker-entrypoint.sh         # Инициализация (автогенерация ключей, reseed config)
├── docker-compose.marzban.yml   # Основной сервис (SQLite, без БД-контейнера)
├── docker-compose.warp.yml      # WARP прокси (опционально)
├── docker-compose.swarm.yml     # Docker Swarm (HA/мультинода, использует MySQL)
├── config.json                  # Шаблон Xray (2 инбаунда: Reality + XHTTP Reality)
├── .env.example                 # Пример настроек
└── docs/                        # Документация
```
