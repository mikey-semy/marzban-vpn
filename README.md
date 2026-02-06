# Marzban VPN Panel с WARP

Полноценная VPN панель на базе Marzban с поддержкой WARP для обхода блокировок, оптимизированная для развертывания в Docker и Dokploy.

## Возможности

- **Marzban Panel** - веб-интерфейс для управления VPN пользователями
- **WARP Integration** - роутинг через Cloudflare WARP для заблокированных сервисов
- **Множественные протоколы**: VMess, VLESS, Trojan, Shadowsocks
- **Reality Protocol** - защита от DPI
- **MySQL Database** - надежное хранение данных
- **Telegram Bot** - уведомления и управление
- **Docker Swarm** - поддержка кластерного развертывания

## Протоколы и порты

| Протокол | TCP | WebSocket | Описание |
|----------|-----|-----------|----------|
| VMess | 2053 | 2083 | Классический V2Ray |
| VLESS | 2054 | 2084 | Легковесный протокол |
| VLESS Reality | 2443 | - | Защита от DPI |
| Trojan | 2055 | 2085 | Имитация HTTPS |
| Shadowsocks | 1080 | - | SOCKS5 прокси |

## WARP роутинг

Автоматически направляет трафик через WARP:
- OpenAI (ChatGPT), Google, YouTube
- Netflix, Spotify, TikTok
- Instagram, Facebook, Twitter/X
- Discord, Telegram

## Быстрый старт

```bash
# Клонирование
git clone https://github.com/mikey-semy/marzban-vpn.git
cd marzban-vpn

# Настройка
cp .env.example .env
nano .env  # Измените пароли и домен

# Создание сети
docker network create dokploy-network

# Запуск
docker-compose -f docker-compose.warp.yml up -d
docker-compose -f docker-compose.marzban.yml up -d
```

Панель доступна: `https://yourdomain.com/dashboard/`

## Документация

- [Установка](docs/INSTALLATION.md) - полная инструкция по установке
- [Конфигурация](docs/CONFIGURATION.md) - все переменные окружения
- [SSL](docs/SSL.md) - настройка HTTPS сертификатов
- [Dokploy](docs/DOKPLOY.md) - развертывание в Dokploy
- [Docker Swarm](docs/SWARM.md) - кластерное развертывание
- [Cloudflare](docs/CLOUDFLARE.md) - интеграция с Cloudflare
- [Решение проблем](docs/TROUBLESHOOTING.md) - диагностика и исправление ошибок

## Структура проекта

```
marzban-vpn/
├── Dockerfile                    # Сборка образа
├── docker-entrypoint.sh         # Инициализация
├── docker-compose.marzban.yml   # Основные сервисы
├── docker-compose.warp.yml      # WARP прокси
├── docker-compose.swarm.yml     # Docker Swarm
├── config.json                  # Шаблон Xray
├── .env.example                 # Пример настроек
└── docs/                        # Документация
```

## Архитектура

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Traefik   │────│   Marzban    │────│   MySQL     │
│   (Proxy)   │    │   (Panel)    │    │   (DB)      │
└─────────────┘    └──────────────┘    └─────────────┘
                          │
                   ┌──────────────┐
                   │    WARP      │
                   │   (Proxy)    │
                   └──────────────┘
```

## Безопасность

- Сгенерируйте уникальные Reality ключи:
  ```bash
  docker run --rm gozargah/marzban:latest xray x25519
  ```
- Используйте надежные пароли
- Настройте firewall для VPN портов
- Используйте Cloudflare для скрытия IP

## Лицензия

MIT License - свободное использование для личных и коммерческих целей.
