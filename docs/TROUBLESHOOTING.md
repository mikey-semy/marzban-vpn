# Решение проблем

## Диагностика

### Проверка статуса контейнеров

```bash
docker ps -a
docker logs marzban -f
docker logs warp-proxy -f
docker logs mysql -f
```

### Проверка сети

```bash
# Проверка DNS
dig vpn.yourdomain.com

# Проверка портов
netstat -tlnp | grep -E ':(2053|2054|2055|2083|2084|2085|2443|1080|8003)'

# Проверка подключения к MySQL
docker exec mysql mysqladmin ping -h localhost
```

## Частые проблемы

### Marzban не запускается

**Симптомы:** Контейнер перезапускается или не отвечает

**Решение:**
1. Проверьте логи:
   ```bash
   docker logs marzban
   ```

2. Проверьте подключение к БД:
   ```bash
   docker exec mysql mysql -u marzban -p -e "SELECT 1"
   ```

3. Проверьте переменные окружения:
   ```bash
   docker exec marzban env | grep -E '(UVICORN|MYSQL|SQL)'
   ```

### Ошибка подключения к базе данных

**Симптомы:** `Connection refused` или `Access denied`

**Решение:**
1. Убедитесь что MySQL запущен и здоров:
   ```bash
   docker ps | grep mysql
   ```

2. Проверьте пароли в `.env` и `SQLALCHEMY_DATABASE_URL`

3. Проверьте что контейнеры в одной сети:
   ```bash
   docker network inspect dokploy-network
   ```

### WARP не работает

**Симптомы:** Сервисы (ChatGPT, YouTube) не доступны через VPN

**Решение:**
1. Проверьте что WARP запущен:
   ```bash
   docker ps | grep warp
   ```

2. Проверьте подключение WARP:
   ```bash
   docker exec warp-proxy curl -s ipinfo.io
   docker exec warp-proxy curl -x socks5://127.0.0.1:1080 -s ipinfo.io
   ```

3. Проверьте что WARP и Marzban в одной сети:
   ```bash
   docker network inspect dokploy-network | grep -A5 warp
   docker network inspect dokploy-network | grep -A5 marzban
   ```

4. Перезапустите WARP:
   ```bash
   docker restart warp-proxy
   ```

### SSL ошибки

**Симптомы:** Браузер показывает ошибку сертификата

**Решение:**
1. Проверьте DNS запись:
   ```bash
   dig vpn.yourdomain.com
   ```

2. Проверьте настройки SSL в `.env`:
   ```env
   # Для Traefik/Cloudflare
   DISABLE_INTERNAL_SSL=true

   # Для самоподписанных
   DISABLE_INTERNAL_SSL=false
   ```

3. Проверьте логи Traefik (если используется)

### Порты не доступны

**Симптомы:** Не удается подключиться к VPN

**Решение:**
1. Проверьте что порты опубликованы:
   ```bash
   docker port marzban
   ```

2. Проверьте firewall:
   ```bash
   # UFW
   ufw status

   # iptables
   iptables -L -n | grep -E '(2053|2054|2055|2083|2084|2085|2443|1080)'
   ```

3. Откройте необходимые порты:
   ```bash
   ufw allow 2053:2055/tcp
   ufw allow 2083:2085/tcp
   ufw allow 2443/tcp
   ufw allow 1080/tcp
   ```

### Конфигурация Xray сбрасывается

**Симптомы:** Настройки теряются после перезапуска

**Решение:**
1. Проверьте что том `marzban_configs` существует:
   ```bash
   docker volume ls | grep marzban
   ```

2. Проверьте что конфигурация сохраняется:
   ```bash
   docker exec marzban cat /var/lib/marzban/xray_config.json
   ```

### Ошибка "user marzban not found"

**Симптомы:** Контейнер не запускается с ошибкой пользователя

**Решение:**
Эта проблема исправлена в текущей версии Dockerfile. Обновите образ:
```bash
docker-compose -f docker-compose.marzban.yml build --no-cache
docker-compose -f docker-compose.marzban.yml up -d
```

## Сброс и восстановление

### Полный сброс

```bash
# Остановка контейнеров
docker-compose -f docker-compose.marzban.yml down
docker-compose -f docker-compose.warp.yml down

# Удаление томов (ВНИМАНИЕ: удалит все данные!)
docker volume rm marzban_data marzban_configs marzban_logs mysql_data

# Перезапуск
docker-compose -f docker-compose.warp.yml up -d
docker-compose -f docker-compose.marzban.yml up -d
```

### Восстановление конфигурации Xray

```bash
# Конфигурация автоматически восстановится из шаблона
docker exec marzban rm /var/lib/marzban/xray_config.json
docker restart marzban
```

## Логи

### Расположение логов

- Marzban: `docker logs marzban`
- MySQL: `docker logs mysql`
- WARP: `docker logs warp-proxy`
- Xray: внутри контейнера `/var/log/xray/`

### Просмотр логов Xray

```bash
docker exec marzban cat /var/log/xray/access.log
docker exec marzban cat /var/log/xray/error.log
```

### Уровень логирования

В `config.json`:
```json
{
  "log": {
    "loglevel": "warning"  // debug, info, warning, error, none
  }
}
```
