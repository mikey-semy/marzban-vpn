# Решение проблем

## Диагностика

### Проверка статуса контейнеров

```bash
docker ps -a
docker logs marzban -f
```

### Проверка сети

```bash
# Проверка DNS
dig vpn.yourdomain.com

# Проверка портов (публикуются только эти три)
netstat -tlnp | grep -E ':(2443|2444|8003)'

# Проверка панели (внутренний self-signed SSL → флаг -k)
curl -fsSk https://localhost:8003/ -o /dev/null && echo OK
```

## Частые проблемы

### Панель недоступна извне (Marzban слушает только 127.0.0.1)

**Симптомы:** Панель открывается с самого сервера, но недоступна по внешнему IP
или через Traefik в отдельном контейнере.

**Причина:** Marzban v0.8.4 без SSL-сертификата отказывается отдавать голый HTTP на
`0.0.0.0` и биндится ТОЛЬКО на `127.0.0.1`.

**Решение:** Оставьте внутренний self-signed SSL включённым:
```env
DISABLE_INTERNAL_SSL=false
```
Тогда Marzban слушает `https://0.0.0.0:8003`. Панель: `https://<server-ip>:8003/dashboard/`
(примите предупреждение о сертификате). `DISABLE_INTERNAL_SSL=true` оправдан только если
reverse-proxy в том же network namespace (host networking) и сам терминирует TLS — для
Dokploy это НЕ так.

### Ошибка "readonly database" / "attempt to write a readonly database"

**Симптомы:** Marzban падает при записи в SQLite, БД доступна только на чтение или
данные теряются после перезапуска.

**Причина:** Файл SQLite оказался не в персистентном томе (например в `/code`), либо у
процесса нет прав на запись в каталог.

**Решение:** Файл БД должен лежать в томе `marzban_data` по пути
`/var/lib/marzban/db.sqlite3` (это поведение по умолчанию — НЕ задавайте
`SQLALCHEMY_DATABASE_URL`). Проверьте:
```bash
docker exec marzban ls -l /var/lib/marzban/db.sqlite3
docker volume ls | grep marzban_data
```

### Конфигурация Xray не обновляется

**Симптомы:** Правки в работающем `xray_config.json` внутри контейнера не применяются
или теряются после рестарта.

**Причина:** `docker-entrypoint.sh` при КАЖДОМ старте пересоздаёт
`/var/lib/marzban/xray_config.json` из шаблона `config.json` (git-репозиторий = источник истины).

**Решение:** Вносите изменения в `config.json` в репозитории, затем пересоберите/передеплойте:
```bash
docker compose -f docker-compose.marzban.yml up -d --build
```
Правки прямо в работающем файле будут затёрты при следующем старте.

### Reality-ключи

**Симптомы:** Клиенты не подключаются после пересоздания тома; ключи "слетели".

**Причина:** Если `REALITY_PRIVATE_KEY`/`REALITY_PUBLIC_KEY` не заданы в `.env`,
`docker-entrypoint.sh` генерирует новую пару при первом старте на пустом томе.

**Решение:** После первого старта возьмите ключи из логов или из
`/var/lib/marzban/reality_keys.env` и пропишите их в `.env`:
```bash
docker logs marzban | grep -i reality
docker exec marzban cat /var/lib/marzban/reality_keys.env
```
НЕ используйте кнопку генерации ключей в панели v0.8.4 — она ждёт старый формат `x25519`,
несовместимый с Xray v26.

### Healthcheck / эндпоинт здоровья возвращает 404

**Симптомы:** Запрос к `/api/health` отдаёт 404; healthcheck "unhealthy".

**Причина:** В Marzban v0.8.4 эндпоинта `/api/health` НЕТ.

**Решение:** Используйте `GET /` — отдаёт home-страницу (200, без авторизации). С учётом
внутреннего self-signed SSL проверяйте по HTTPS с флагом `-k`:
```bash
curl -fsSk https://localhost:8003/ -o /dev/null && echo OK
```

### Клиент не подключается через XHTTP

**Симптомы:** VLESS Reality (TCP, 2443) работает, а XHTTP (2444) — нет.

**Причина:** Клиент не поддерживает транспорт XHTTP.

**Решение:** XHTTP понимают только свежие клиенты: **Hiddify**, **NekoBox**,
**v2rayNG** (актуальные версии). **Amnezia XHTTP не поддерживает** — для Amnezia
используйте инбаунд VLESS Reality (TCP, порт 2443).

### Порты не доступны

**Симптомы:** Не удается подключиться к VPN.

**Решение:**
1. Проверьте что порты опубликованы:
   ```bash
   docker port marzban
   ```
2. Проверьте firewall и откройте нужные порты (публикуются только 8003/2443/2444):
   ```bash
   ufw status
   ufw allow 8003/tcp
   ufw allow 2443/tcp
   ufw allow 2444/tcp
   ```

## Сброс и восстановление

### Полный сброс

```bash
# Остановка контейнера
docker compose -f docker-compose.marzban.yml down

# Удаление томов (ВНИМАНИЕ: удалит все данные, включая SQLite и Reality-ключи!)
docker volume rm marzban_data marzban_configs marzban_logs

# Перезапуск
docker compose -f docker-compose.marzban.yml up -d --build
```

### Восстановление конфигурации Xray

```bash
# Конфигурация автоматически пересоздаётся из шаблона config.json при старте
docker restart marzban
```

### Бэкап SQLite

```bash
# БД — один файл, бэкап = его копия
docker cp marzban:/var/lib/marzban/db.sqlite3 ./db.sqlite3.bak
```

## Логи

### Расположение логов

- Marzban: `docker logs marzban`
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
