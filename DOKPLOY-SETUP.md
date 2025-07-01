# Быстрая настройка Marzban VPN в Dokploy

## 🚀 Пошаговая инструкция

### 1. Подготовка репозитория

Убедитесь что у вас есть:
- [x] `Dockerfile` 
- [x] `docker-entrypoint.sh`
- [x] `docker-compose.marzban.yml`
- [x] `config.json`
- [x] `.env` файл (создать из `.env.example`)

### 2. Создание проекта в Dokploy

1. **Войдите в панель Dokploy**
2. **Создайте новый проект**:
   - Тип: `Compose`
   - Название: `marzban-vpn`
   - Repository: `https://github.com/mikey-semy/marzban-vpn.git`
   - Compose файл: `docker-compose.marzban.yml`

### 3. Настройка базы данных (отдельно)

Создайте отдельный проект для MySQL:
1. **Новый проект**: `marzban-mysql`
2. **Тип**: `Application`  
3. **Docker Image**: `mysql:8.0`
4. **Environment Variables**:
   ```env
   MYSQL_DATABASE=marzban
   MYSQL_USER=marzban
   MYSQL_PASSWORD=your_secure_password
   MYSQL_ROOT_PASSWORD=your_root_password
   ```
5. **Volumes**: 
   - `/var/lib/mysql` → `mysql_data`
6. **Networks**: `dokploy-network`

### 4. Настройка переменных окружения

В проекте Marzban добавьте переменные:

```env
# Админ панель
SUDO_USERNAME=admin
SUDO_PASSWORD=your_secure_password

# База данных (укажите внутренний IP MySQL контейнера)
SQLALCHEMY_DATABASE_URL=mysql+pymysql://marzban:your_secure_password@marzban-mysql:3306/marzban

# Сеть
UVICORN_HOST=0.0.0.0
UVICORN_PORT=8003
DOMAIN=vpn.yourdomain.com

# WARP
WARP_ENABLED=true
WARP_HOST=warp-proxy
WARP_PORT=1080

# Telegram (опционально)
TELEGRAM_API_TOKEN=your_bot_token
TELEGRAM_ADMIN_ID=your_telegram_id

# Прочее
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440
DOCS=false
DEBUG=false
XRAY_JSON=/var/lib/marzban/xray_config.json
XRAY_SUBSCRIPTION_URL_PREFIX=https://vpn.yourdomain.com
```

### 5. Настройка домена

1. **В настройках проекта Marzban**:
   - Добавьте домен: `vpn.yourdomain.com`
   - Включите SSL: `Let's Encrypt`
   - Dokploy автоматически настроит Traefik

2. **DNS настройки**:
   - Добавьте A-запись: `vpn.yourdomain.com` → `IP_вашего_сервера`

### 6. Запуск WARP прокси

На сервере выполните:
```bash
cd /path/to/marzban-vpn
docker-compose -f docker-compose.warp.yml up -d
```

### 7. Развертывание

1. **В Dokploy нажмите "Deploy"**
2. **Дождитесь завершения сборки**
3. **Проверьте логи** на наличие ошибок

### 8. Первый вход

1. Откройте: `https://vpn.yourdomain.com/dashboard/`
2. Логин: `admin` (или ваш `SUDO_USERNAME`)
3. Пароль: из `SUDO_PASSWORD`

## 🔧 Устранение неполадок

### Ошибка "unable to find user marzban"
✅ **Исправлено** в новом Dockerfile

### Панель доступна только по порту :8003
✅ **Исправлено** - настроены Traefik labels

### Конфигурация удаляется при перезапуске
✅ **Исправлено** - персистентные volumes

### Проблемы с базой данных
1. Проверьте что MySQL контейнер запущен
2. Проверьте правильность `SQLALCHEMY_DATABASE_URL`
3. Убедитесь что оба контейнера в сети `dokploy-network`

### WARP не работает
1. Проверьте что WARP контейнер запущен:
   ```bash
   docker ps | grep warp
   ```
2. Проверьте подключение:
   ```bash
   docker exec warp-proxy curl -s ipinfo.io
   ```

## 📊 Мониторинг

### Логи в Dokploy
- **Marzban**: Projects → marzban-vpn → Logs
- **MySQL**: Projects → marzban-mysql → Logs

### Команды проверки
```bash
# Статус контейнеров
docker ps

# Логи Marzban
docker logs marzban-vpn-marzban-1 -f

# Логи WARP
docker logs warp-proxy -f

# Проверка портов
netstat -tlnp | grep -E ':(2053|2054|2055|2083|2084|2085|2443|1080)'
```

## 🔄 Обновления

1. **Изменения в коде**: Push в GitHub → Redeploy в Dokploy
2. **Обновление образа**: Rebuild в Dokploy
3. **Изменения конфигурации**: Редактировать переменные окружения

## 📞 Поддержка

При проблемах проверьте:
1. ✅ Все переменные окружения настроены
2. ✅ DNS указывает на сервер
3. ✅ MySQL контейнер работает
4. ✅ WARP контейнер запущен
5. ✅ Порты открыты в firewall

**Структура проекта**:
```
Dokploy Projects:
├── marzban-mysql (отдельный проект)
├── marzban-vpn (основной проект)
└── WARP (отдельный docker-compose)
```
