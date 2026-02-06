# Развертывание в Dokploy

## Подготовка

1. Установленный Dokploy на сервере
2. Домен с DNS записью, указывающей на сервер
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

# База данных
SQLALCHEMY_DATABASE_URL=mysql+pymysql://marzban:db_password@mysql:3306/marzban-db
MYSQL_PASSWORD=db_password
MYSQL_ROOT_PASSWORD=root_password

# Сеть
UVICORN_HOST=0.0.0.0
UVICORN_PORT=8003
DOMAIN=vpn.yourdomain.com

# SSL через Traefik
DISABLE_INTERNAL_SSL=true

# WARP
WARP_ENABLED=true
WARP_HOST=warp-proxy
WARP_PORT=1080

# Подписки
XRAY_SUBSCRIPTION_URL_PREFIX=https://vpn.yourdomain.com
```

### 3. Настройка домена

1. Перейдите в **Domains**
2. Добавьте домен: `vpn.yourdomain.com`
3. Включите **Generate SSL Certificate**
4. Выберите **Let's Encrypt**

### 4. Запуск WARP

WARP нужно запустить отдельно на сервере:

```bash
cd /path/to/marzban-vpn
docker-compose -f docker-compose.warp.yml up -d
```

### 5. Развертывание

Нажмите **Deploy** в панели Dokploy.

## Мониторинг

### Логи в Dokploy

- **Marzban**: Projects → marzban-vpn → Logs
- **MySQL**: Projects → marzban-vpn → Logs (выберите сервис mysql)

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
docker logs marzban-vpn-marzban-1

# Проверка базы данных
docker exec marzban-vpn-mysql-1 mysqladmin ping -h localhost
```

### Ошибки SSL

1. Проверьте DNS запись
2. Убедитесь что порты 80/443 открыты
3. Перегенерируйте сертификат в Dokploy

### WARP недоступен

1. Проверьте что WARP контейнер запущен
2. Убедитесь что оба контейнера в сети `dokploy-network`

## Архитектура в Dokploy

```
┌─────────────────────────────────────────────┐
│                  Dokploy                    │
│  ┌─────────────────────────────────────┐   │
│  │              Traefik                │   │
│  │           (SSL, Routing)            │   │
│  └─────────────────────────────────────┘   │
│                    │                        │
│  ┌─────────────────┼─────────────────┐     │
│  │                 │                 │     │
│  │  ┌──────────┐   │   ┌──────────┐  │     │
│  │  │ Marzban  │◄──┼──►│  MySQL   │  │     │
│  │  │ (Panel)  │   │   │  (DB)    │  │     │
│  │  └──────────┘   │   └──────────┘  │     │
│  │        │        │                 │     │
│  │        ▼        │                 │     │
│  │  ┌──────────┐   │                 │     │
│  │  │   WARP   │   │                 │     │
│  │  │ (Proxy)  │   │                 │     │
│  │  └──────────┘   │                 │     │
│  │                 │                 │     │
│  │     dokploy-network               │     │
│  └───────────────────────────────────┘     │
└─────────────────────────────────────────────┘
```
