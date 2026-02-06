# Конфигурация

## Переменные окружения

### Администратор

| Переменная | Описание | Пример |
|------------|----------|--------|
| `SUDO_USERNAME` | Логин администратора | `admin` |
| `SUDO_PASSWORD` | Пароль администратора | `secure_password` |

### База данных

| Переменная | Описание | Пример |
|------------|----------|--------|
| `SQLALCHEMY_DATABASE_URL` | URL подключения к MySQL | `mysql+pymysql://user:pass@host:3306/db` |
| `MYSQL_PASSWORD` | Пароль пользователя MySQL | `db_password` |
| `MYSQL_ROOT_PASSWORD` | Пароль root MySQL | `root_password` |

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

### VLESS Reality

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `REALITY_PRIVATE_KEY` | Приватный ключ Reality | из шаблона |
| `REALITY_PUBLIC_KEY` | Публичный ключ Reality | из шаблона |
| `REALITY_DEST` | Целевой сервер | `ya.ru:443` |
| `REALITY_SERVER_NAMES` | SNI имена | `ya.ru,www.ya.ru` |

**Генерация ключей:**
```bash
docker run --rm gozargah/marzban:latest xray x25519
```

### WARP

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `WARP_ENABLED` | Включить WARP роутинг | `true` |
| `WARP_HOST` | Хост WARP прокси | `warp-proxy` |
| `WARP_PORT` | Порт WARP прокси | `1080` |

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

Файл `config.json` - шаблон конфигурации Xray.

### Протоколы и порты

| Протокол | Порт | Описание |
|----------|------|----------|
| VMess TCP | 2053 | Классический VMess |
| VMess WS | 2083 | VMess через WebSocket |
| VLESS TCP | 2054 | Легковесный VLESS |
| VLESS WS | 2084 | VLESS через WebSocket |
| VLESS Reality | 2443 | VLESS с Reality |
| Trojan TCP | 2055 | Trojan протокол |
| Trojan WS | 2085 | Trojan через WebSocket |
| Shadowsocks | 1080 | SOCKS5 прокси |

### WARP роутинг

Трафик к следующим сервисам направляется через WARP:
- OpenAI (ChatGPT)
- Google, YouTube
- Netflix, Spotify, TikTok
- Instagram, Facebook, Twitter
- Discord, Telegram

Настраивается в `config.json` в секции `routing.rules`.

## Docker тома

| Том | Назначение |
|-----|------------|
| `marzban_data` | Данные Marzban |
| `marzban_configs` | Конфигурации Xray |
| `marzban_logs` | Логи Xray |
| `mysql_data` | Данные MySQL |

## Файловая структура

```
marzban-vpn/
├── Dockerfile                    # Сборка образа
├── docker-entrypoint.sh         # Инициализация
├── docker-compose.marzban.yml   # Основные сервисы
├── docker-compose.warp.yml      # WARP прокси
├── docker-compose.swarm.yml     # Docker Swarm
├── config.json                  # Шаблон Xray
├── init-mysql.sql               # Инициализация БД
├── .env.example                 # Пример настроек
└── docs/                        # Документация
```
