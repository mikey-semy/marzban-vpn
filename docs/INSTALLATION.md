# Установка Marzban VPN

## Требования

- Docker 20.10+
- Docker Compose v2+
- 1 GB RAM минимум
- Домен с настроенным DNS

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

**Обязательные настройки:**

```env
# Учетные данные администратора
SUDO_USERNAME=admin
SUDO_PASSWORD=ваш_надежный_пароль

# База данных
MYSQL_PASSWORD=пароль_базы_данных
MYSQL_ROOT_PASSWORD=рут_пароль_базы_данных
SQLALCHEMY_DATABASE_URL=mysql+pymysql://marzban:пароль_базы_данных@mysql:3306/marzban-db

# Ваш домен
DOMAIN=vpn.yourdomain.com
XRAY_SUBSCRIPTION_URL_PREFIX=https://vpn.yourdomain.com
```

### 3. Генерация Reality ключей (рекомендуется)

```bash
# Генерация уникальных ключей для VLESS Reality
docker run --rm gozargah/marzban:latest xray x25519
```

Добавьте полученные ключи в `.env`:
```env
REALITY_PRIVATE_KEY=ваш_приватный_ключ
REALITY_PUBLIC_KEY=ваш_публичный_ключ
```

### 4. Создание Docker сети

```bash
docker network create dokploy-network
```

### 5. Запуск сервисов

```bash
# Запуск WARP прокси
docker-compose -f docker-compose.warp.yml up -d

# Запуск Marzban
docker-compose -f docker-compose.marzban.yml up -d
```

### 6. Проверка статуса

```bash
# Проверка запущенных контейнеров
docker ps

# Логи Marzban
docker logs marzban -f

# Логи WARP
docker logs warp-proxy -f
```

## Доступ к панели

После успешного запуска:

- URL: `https://vpn.yourdomain.com/dashboard/`
- Логин: значение `SUDO_USERNAME`
- Пароль: значение `SUDO_PASSWORD`

## Следующие шаги

- [Настройка SSL](SSL.md) - настройка HTTPS
- [Настройка Dokploy](DOKPLOY.md) - развертывание в Dokploy
- [Настройка Cloudflare](CLOUDFLARE.md) - защита и ускорение
