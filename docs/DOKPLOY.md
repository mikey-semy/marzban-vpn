# Развертывание в Dokploy

## Подготовка

1. Установленный Dokploy на сервере
2. Домен с DNS записью, указывающей на сервер (опционально — панель доступна и по IP)
3. Форк или клон репозитория

## Создание проекта

### 1. Создание Compose проекта

1. Войдите в панель Dokploy
2. Создайте новый проект → Тип: **Compose**
3. Укажите:
   - **Repository**: `https://github.com/mikey-semy/marzban-vpn.git`
   - **Compose file**: `docker-compose.marzban.yml`

### 2. Настройка переменных окружения

В разделе **Environment** добавьте:

```env
# Администратор
SUDO_USERNAME=admin
SUDO_PASSWORD=ваш_надежный_пароль

# База данных — SQLite (по умолчанию)
# SQLALCHEMY_DATABASE_URL НЕ задаём → SQLite в /var/lib/marzban/db.sqlite3

# Сеть
UVICORN_HOST=0.0.0.0
UVICORN_PORT=8003
DOMAIN=vpn.yourdomain.com

# SSL — ОБЯЗАТЕЛЬНО оставить внутренний self-signed SSL включённым.
# Без него Marzban v0.8.4 слушает только 127.0.0.1 и недоступен извне/для Traefik.
DISABLE_INTERNAL_SSL=false

# Reality SNI — для exit за границей (глобальный сервис)
REALITY_DEST=www.microsoft.com:443
REALITY_SERVER_NAMES=www.microsoft.com

# WARP отключён по умолчанию
WARP_ENABLED=false

# Подписки
XRAY_SUBSCRIPTION_URL_PREFIX=https://vpn.yourdomain.com
```

> Reality-ключи можно не задавать — `docker-entrypoint.sh` сгенерирует их при первом
> старте и выведет в логи. После первого деплоя скопируйте `REALITY_PRIVATE_KEY` и
> `REALITY_PUBLIC_KEY` из логов в Environment, чтобы они пережили пересоздание тома.

### 3. Публикуемые порты

`docker-compose.marzban.yml` публикует только:

| Порт | Назначение |
|------|------------|
| 8003 | Панель управления (HTTPS, self-signed) |
| 2443 | VLESS Reality (TCP) |
| 2444 | VLESS XHTTP Reality |

### 4. Настройка домена (опционально)

1. Перейдите в **Domains**
2. Добавьте домен: `vpn.yourdomain.com`
3. В качестве внутреннего порта приложения укажите **8003**, протокол — **HTTPS**
   (Marzban отдаёт self-signed HTTPS; Traefik терминирует валидный сертификат снаружи).
4. Включите **Generate SSL Certificate** → **Let's Encrypt**

### 5. Развертывание

Нажмите **Deploy** в панели Dokploy.

## Доступ к панели

- Напрямую по IP: `https://<server-ip>:8003/dashboard/` (примите предупреждение о self-signed сертификате)
- Через домен/Traefik: `https://vpn.yourdomain.com/dashboard/`

## Мониторинг

### Логи в Dokploy

- **Marzban**: Projects → marzban-vpn → Logs

### Метрики

В Dokploy доступны:
- Использование CPU/RAM
- Сетевой трафик
- История развертываний

## Обновление

### Обновление кода

1. Push изменения в GitHub
2. В Dokploy нажмите **Redeploy**

### Обновление образа

1. В Dokploy нажмите **Rebuild**
2. Дождитесь пересборки

## Решение проблем

### Marzban не запускается

```bash
# Проверка логов
docker logs marzban
```

### Панель недоступна извне

Убедитесь, что `DISABLE_INTERNAL_SSL=false` — без внутреннего SSL Marzban v0.8.4
биндится только на `127.0.0.1`. Подробнее: [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### Ошибки SSL

1. Проверьте DNS запись
2. Убедитесь что порты 80/443 открыты
3. Перегенерируйте сертификат в Dokploy

## Архитектура в Dokploy

```
┌─────────────────────────────────────────────┐
│                  Dokploy                     │
│  ┌─────────────────────────────────────┐    │
│  │              Traefik                 │    │
│  │           (SSL, Routing)             │    │
│  └─────────────────────────────────────┘    │
│                    │                         │
│                    ▼                         │
│  ┌──────────────────────────────────────┐   │
│  │              Marzban                  │   │
│  │   (Panel + Xray, SQLite, self-SSL)   │   │
│  │   порты 8003 / 2443 / 2444           │   │
│  └──────────────────────────────────────┘   │
│                                              │
│              dokploy-network                 │
└──────────────────────────────────────────────┘
```
