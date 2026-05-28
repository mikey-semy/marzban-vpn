# Установка Marzban VPN

## Требования

- Docker 20.10+
- Docker Compose v2+
- 1 GB RAM минимум
- Домен с настроенным DNS (опционально — панель доступна и по IP)

## Быстрая установка

### 1. Клонирование репозитория

```bash
git clone https://github.com/mikey-semy/marzban-vpn.git
cd marzban-vpn
```

### 2. Настройка конфигурации

```bash
# Копирование примера конфигурации
cp .env.example .env

# Редактирование настроек
nano .env
```

**Минимальные настройки** (роль — exit за границей, БД — SQLite):

```env
# Учетные данные администратора
SUDO_USERNAME=admin
SUDO_PASSWORD=ваш_надежный_пароль

# Сеть
UVICORN_PORT=8003
DOMAIN=vpn.yourdomain.com
XRAY_SUBSCRIPTION_URL_PREFIX=https://vpn.yourdomain.com

# SSL — обязательно оставить внутренний self-signed SSL включённым.
# Marzban v0.8.4 без SSL слушает только 127.0.0.1 и недоступен извне.
DISABLE_INTERNAL_SSL=false

# База данных — SQLite (по умолчанию).
# SQLALCHEMY_DATABASE_URL НЕ задаём → SQLite в /var/lib/marzban/db.sqlite3

# Reality SNI — для exit за границей (глобальный сервис).
# НЕ используйте ya.ru на не-РФ IP (IP↔SNI mismatch, DPI флагует).
REALITY_DEST=www.microsoft.com:443
REALITY_SERVER_NAMES=www.microsoft.com
```

### 3. Reality ключи (опционально)

Reality-ключи генерируются **автоматически** при первом старте контейнера. Если оставить
`REALITY_PRIVATE_KEY`/`REALITY_PUBLIC_KEY` пустыми, `docker-entrypoint.sh` создаст пару,
выведет в логи и сохранит в `/var/lib/marzban/reality_keys.env`.

После первого старта скопируйте ключи в `.env`, чтобы они пережили пересоздание тома:

```bash
docker logs marzban | grep -i reality
# или
docker exec marzban cat /var/lib/marzban/reality_keys.env
```

```env
REALITY_PRIVATE_KEY=ваш_приватный_ключ
REALITY_PUBLIC_KEY=ваш_публичный_ключ
```

> ⚠️ НЕ используйте кнопку генерации ключей в панели v0.8.4 — она ждёт старый формат
> `x25519`, несовместимый с Xray v26. Берите ключи только из логов или `.env`.

### 4. Создание Docker сети

```bash
docker network create dokploy-network
```

### 5. Запуск сервиса

```bash
docker compose -f docker-compose.marzban.yml up -d --build
```

> WARP по умолчанию отключён и для базовой установки не требуется. Если он нужен —
> см. [CONFIGURATION.md](CONFIGURATION.md) (раздел WARP).

### 6. Проверка статуса

```bash
# Проверка запущенных контейнеров
docker ps

# Логи Marzban
docker logs marzban -f

# Проверка панели (self-signed SSL → флаг -k)
curl -fsSk https://localhost:8003/ -o /dev/null && echo OK
```

## Доступ к панели

После успешного запуска:

- URL напрямую по IP: `https://<server-ip>:8003/dashboard/` (примите предупреждение о self-signed сертификате)
- URL через домен: `https://vpn.yourdomain.com/dashboard/`
- Логин: значение `SUDO_USERNAME`
- Пароль: значение `SUDO_PASSWORD`

## Следующие шаги

- [Конфигурация](CONFIGURATION.md) — переменные окружения и инбаунды
- [Настройка SSL](SSL.md) - настройка HTTPS
- [Настройка Dokploy](DOKPLOY.md) - развертывание в Dokploy
- [Настройка Cloudflare](CLOUDFLARE.md) - защита и ускорение
