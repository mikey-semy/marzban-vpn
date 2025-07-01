# Marzban VPN Panel с WARP для Dokploy

Полноценная VPN панель на базе Marzban с поддержкой WARP для обхода блокировок популярных сервисов, оптимизированная для развертывания в Dokploy с Traefik.

## 🚀 Возможности

- **Marzban Panel** - веб-интерфейс для управления VPN пользователями
- **WARP Integration** - автоматический роутинг через Cloudflare WARP для заблокированных сервисов
- **Множественные протоколы**: VMess, VLESS, Trojan, Shadowsocks
- **Reality Protocol** - современная защита от DPI
- **MySQL Database** - надежное хранение данных
- **Telegram Bot** - уведомления и управление
- **Dokploy/Traefik** - автоматическое управление SSL сертификатами
- **Персистентная конфигурация** - сохранение настроек при перезапуске

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

## 🛠 Установка в Dokploy

### 1. Клонирование репозитория

```bash
git clone https://github.com/mikey-semy/marzban-vpn.git
cd marzban-vpn
```

### 2. Настройка переменных окружения

Создайте `.env` файл на основе примера:

```bash
cp .env.example .env
nano .env
```

Обязательно измените:
- `SUDO_USERNAME` и `SUDO_PASSWORD` - для входа в панель
- `MYSQL_PASSWORD` и `MYSQL_ROOT_PASSWORD` - пароли для MySQL
- `TELEGRAM_API_TOKEN` и `TELEGRAM_ADMIN_ID` - для уведомлений
- `XRAY_SUBSCRIPTION_URL_PREFIX` - ваш домен

### 3. Создание проекта в Dokploy

1. Войдите в панель Dokploy
2. Создайте новый проект типа "Compose"
3. Укажите репозиторий: `https://github.com/mikey-semy/marzban-vpn.git`
4. Установите файл compose: `docker-compose.marzban.yml`

### 4. Настройка домена в Dokploy

1. В настройках проекта добавьте домен (например: `vpn.yourdomain.com`)
2. Включите SSL через Let's Encrypt
3. Dokploy автоматически настроит Traefik labels

### 5. Запуск WARP прокси

Отдельно запустите WARP прокси:

```bash
docker-compose -f docker-compose.warp.yml up -d
```

### 6. Развертывание в Dokploy

1. Нажмите "Deploy" в панели Dokploy
2. Дождитесь завершения сборки и запуска контейнеров

## ⚙️ Конфигурация

### Основные файлы

- `Dockerfile` - кастомный образ с персистентной конфигурацией
- `docker-entrypoint.sh` - скрипт инициализации
- `config.json` - шаблон конфигурации Xray с роутингом
- `docker-compose.marzban.yml` - основные сервисы (Marzban + MySQL)
- `docker-compose.warp.yml` - WARP прокси
- `.env` - переменные окружения

### Персистентные тома

- `marzban_data` - данные Marzban (база данных, логи)
- `marzban_configs` - конфигурации Xray
- `marzban_logs` - логи Xray
- `mysql_data` - данные MySQL

### Интеграция с WARP

Переменные окружения для WARP:
```env
WARP_ENABLED=true
WARP_HOST=warp-proxy
WARP_PORT=1080
```

## 🔧 Управление через Dokploy

### Веб-панель
- URL: `https://yourdomain.com/dashboard/`
- Логин: из `SUDO_USERNAME`
- Пароль: из `SUDO_PASSWORD`

### Команды через Dokploy терминал

```bash
# Просмотр логов
docker logs marzban -f
docker logs warp-proxy -f

# Перезапуск сервисов (через Dokploy UI)
# Projects -> Your Project -> Redeploy

# Проверка статуса WARP
docker exec warp-proxy curl -s https://www.cloudflare.com/cdn-cgi/trace
```

### Обновление

1. В Dokploy перейдите к проекту
2. Нажмите "Redeploy"
3. Система автоматически подтянет изменения из репозитория

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
docker exec warp-proxy curl -s ipinfo.io
```

### Dokploy мониторинг

В панели Dokploy доступны:
- Метрики использования ресурсов
- Логи в реальном времени
- Статус сервисов
- История развертываний

## 🔒 Безопасность

### Рекомендации

- Используйте сильные пароли в `.env`
- Настройте файрвол через Dokploy
- Регулярно обновляйте образы через Redeploy
- Используйте SSL сертификаты Let's Encrypt (автоматически в Dokploy)

### Firewall настройки

В Dokploy или на сервере:

```bash
# Разрешить только нужные порты
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (Traefik)
ufw allow 443/tcp   # HTTPS (Traefik)
ufw allow 1080/tcp  # Shadowsocks
ufw allow 2053:2055/tcp  # VMess, VLESS, Trojan
ufw allow 2083:2085/tcp  # WebSocket
ufw allow 2443/tcp  # Reality
ufw enable
```

## 🐛 Решение проблем

### Marzban не запускается

```bash
# Проверить логи в Dokploy
# Projects -> Your Project -> Logs

# Или через терминал
docker logs marzban

# Проверить базу данных
docker exec mysql mysql -u root -p -e "SHOW DATABASES;"
```

### WARP не работает

```bash
# Перезапуск WARP
docker restart warp-proxy

# Проверка подключения
docker exec warp-proxy curl -s ipinfo.io
```

### Проблемы с конфигурацией

Конфигурация Xray автоматически сохраняется в персистентном томе:
- При первом запуске создается из шаблона `config.json`
- При повторных запусках используется сохраненная конфигурация
- При ошибках автоматически восстанавливается из шаблона

### Traefik/SSL проблемы

1. Проверьте настройки домена в Dokploy
2. Убедитесь что DNS указывает на ваш сервер
3. Проверьте логи Traefik в Dokploy

## 📝 Логи

Логи доступны в Dokploy или через команды:
- Marzban: `docker logs marzban`
- MySQL: `docker logs mysql`
- WARP: `docker logs warp-proxy`
- Xray: в томе `/var/log/xray/`

## 🔄 Архитектура

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   Traefik       │────│   Marzban    │────│   MySQL     │
│   (SSL/Proxy)   │    │   (Panel)    │    │   (DB)      │
└─────────────────┘    └──────────────┘    └─────────────┘
                              │
                       ┌──────────────┐
                       │   WARP       │
                       │   (Proxy)    │
                       └──────────────┘
```

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи в Dokploy
2. Убедитесь что все порты открыты
3. Проверьте настройки DNS
4. Проверьте конфигурацию `.env`
5. Используйте функцию Redeploy в Dokploy

## 📄 Лицензия

MIT License - используйте свободно для личных и коммерческих целей.

## 🏗 Структура проекта

```
marzban-vpn/
├── Dockerfile                    # Кастомный образ с персистентной конфигурацией
├── docker-entrypoint.sh         # Скрипт инициализации
├── docker-compose.marzban.yml   # Основные сервисы
├── docker-compose.warp.yml      # WARP прокси
├── config.json                  # Шаблон конфигурации Xray
├── .env.example                 # Пример переменных окружения
└── README.md                    # Документация
```
