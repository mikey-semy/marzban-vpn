# Marzban VPN Panel с WARP

Полноценная VPN панель на базе Marzban с поддержкой WARP для обхода блокировок популярных сервисов.

## 🚀 Возможности

- **Marzban Panel** - веб-интерфейс для управления VPN пользователями
- **WARP Integration** - автоматический роутинг через Cloudflare WARP для заблокированных сервисов
- **Множественные протоколы**: VMess, VLESS, Trojan, Shadowsocks
- **Reality Protocol** - современная защита от DPI
- **MySQL Database** - надежное хранение данных
- **Telegram Bot** - уведомления и управление
- **SSL/TLS** - безопасное подключение

## 📋 Поддерживаемые протоколы

| Протокол | TCP порт | WS порт | Описание |
|----------|----------|---------|----------|
| VMess | 2053 | 2083 | Популярный протокол V2Ray |
| VLESS | 2054 | 2084 | Легковесная версия VMess |
| VLESS Reality | 2443 | - | Современная защита от DPI |
| Trojan | 2055 | 2085 | Имитация HTTPS трафика |
| Shadowsocks | 1080 | - | Классический SOCKS5 прокси |

## 🌐 WARP роутинг

Автоматически направляет трафик через WARP для:
- OpenAI (ChatGPT)
- Google сервисы
- YouTube
- Netflix
- Instagram
- Facebook
- Twitter/X
- Discord
- Telegram
- Spotify
- TikTok

## 🛠 Установка

### 1. Клонирование репозитория

```bash
git clone <your-repo-url>
cd marzban-vpn-panel
```

### 2. Настройка окружения

```bash
cp .env.example .env
nano .env
```

Измени пароли и настройки в `.env` файле.

### 3. Запуск сервисов

```bash
# Запуск WARP прокси
docker-compose -f docker-compose.warp.yml up -d

# Запуск Marzban панели
docker-compose -f docker-compose.marzban.yml up -d
```

### 4. Проверка статуса

```bash
docker ps
docker logs marzban
docker logs warp-proxy
```

## ⚙️ Конфигурация

### Основные файлы

- `config.json` - конфигурация Xray с роутингом
- `docker-compose.marzban.yml` - Marzban + MySQL
- `docker-compose.warp.yml` - WARP прокси
- `.env` - переменные окружения

### Настройка доменов

В `.env` измени:
```env
XRAY_SUBSCRIPTION_URL_PREFIX=https://your-domain.com
```

### Telegram бот

1. Создай бота через @BotFather
2. Получи токен и добавь в `.env`:
```env
TELEGRAM_API_TOKEN=your_bot_token
TELEGRAM_ADMIN_ID=your_telegram_id
```

## 🔧 Управление

### Веб-панель
- URL: `https://your-domain.com/dashboard/`
- Логин: из `SUDO_USERNAME`
- Пароль: из `SUDO_PASSWORD`

### Команды Docker

```bash
# Перезапуск сервисов
docker-compose -f docker-compose.marzban.yml restart

# Просмотр логов
docker logs marzban -f
docker logs warp-proxy -f

# Обновление
docker-compose -f docker-compose.marzban.yml pull
docker-compose -f docker-compose.marzban.yml up -d
```

### Бэкап базы данных

```bash
docker exec mysql mysqldump -u root -p marzban > backup.sql
```

### Восстановление

```bash
docker exec -i mysql mysql -u root -p marzban < backup.sql
```

## 🔒 Безопасность

- Используй сильные пароли в `.env`
- Регулярно обновляй образы Docker
- Настрой файрвол для портов
- Используй SSL сертификаты

### Рекомендуемые настройки файрвола

```bash
# Разрешить только нужные порты
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 1080/tcp  # Shadowsocks
ufw allow 2053:2055/tcp  # VMess, VLESS, Trojan
ufw allow 2083:2085/tcp  # WebSocket
ufw allow 2443/tcp  # Reality
ufw enable
```

## 📊 Мониторинг

### Проверка подключений

```bash
# Активные подключения
netstat -an | grep :2053
netstat -an | grep :2054

# Статистика трафика
docker exec marzban cat /var/log/xray/access.log
```

### WARP статус

```bash
docker exec warp-proxy curl -s https://www.cloudflare.com/cdn-cgi/trace
```

## 🐛 Решение проблем

### Marzban не запускается

```bash
# Проверь логи
docker logs marzban

# Проверь базу данных
docker exec mysql mysql -u root -p -e "SHOW DATABASES;"
```

### WARP не работает

```bash
# Перезапуск WARP
docker restart warp-proxy

# Проверка подключения
docker exec warp-proxy curl -s ipinfo.io
```

### Проблемы с SSL

```bash
# Проверь сертификаты
docker exec marzban ls -la /tmp/cert.*

# Пересоздай сертификаты
docker restart marzban
```

## 📝 Логи

Основные логи находятся в:
- Marzban: `docker logs marzban`
- MySQL: `docker logs mysql`
- WARP: `docker logs warp-proxy`
- Xray: внутри контейнера `/var/log/xray/`

## 🔄 Обновления

```bash
# Остановка сервисов
docker-compose -f docker-compose.marzban.yml down
docker-compose -f docker-compose.warp.yml down

# Обновление образов
docker pull gozargah/marzban:latest
docker pull mysql:8.0
docker pull caomingjun/warp

# Запуск обновленных сервисов
docker-compose -f docker-compose.warp.yml up -d
docker-compose -f docker-compose.marzban.yml up -d
```

## 📞 Поддержка

При возникновении проблем:

1. Проверь логи контейнеров
2. Убедись что все порты открыты
3. Проверь настройки DNS
4. Проверь конфигурацию `.env`

## 📄 Лицензия

MIT License - используй свободно для личных и коммерческих целей.
