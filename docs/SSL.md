# Настройка SSL сертификатов

> ⚠️ **Важный нюанс Marzban v0.8.4:** без SSL-сертификата Marzban отказывается
> отдавать голый HTTP на `0.0.0.0` и биндится ТОЛЬКО на `127.0.0.1` → недоступен извне,
> в т.ч. для Traefik в отдельном контейнере. Поэтому `DISABLE_INTERNAL_SSL=true` имеет
> смысл ТОЛЬКО если reverse-proxy в том же network namespace (host networking) и сам
> терминирует TLS. Для **Dokploy / контейнерного Traefik** держите внутренний SSL
> включённым (`DISABLE_INTERNAL_SSL=false`).

## Варианты SSL

### 1. Traefik/Dokploy (рекомендуется)

Внутренний self-signed SSL оставляем включённым, внешний валидный сертификат
терминирует Traefik.

```env
DISABLE_INTERNAL_SSL=false
```

Marzban слушает `https://0.0.0.0:8003` (self-signed), а в Dokploy для домена укажите
внутренний порт приложения **8003** и протокол **HTTPS**.

**Преимущества:**
- Автоматическое получение Let's Encrypt сертификатов на стороне Traefik
- Автоматическое обновление
- Marzban доступен извне (биндится на 0.0.0.0)

### 2. Cloudflare

SSL обрабатывается Cloudflare, но внутренний SSL Marzban остаётся включённым
(иначе он слушает только localhost). На стороне Cloudflare используйте режим
**Full (strict)**.

```env
DISABLE_INTERNAL_SSL=false
```

**Преимущества:**
- Бесплатные сертификаты
- DDoS защита
- Скрытие IP сервера

### 3. Let's Encrypt внутри контейнера

```env
DISABLE_INTERNAL_SSL=false
USE_LETSENCRYPT_CERTS=true
LETSENCRYPT_CERT_PATH=/etc/letsencrypt/live/vpn.yourdomain.com/fullchain.pem
LETSENCRYPT_KEY_PATH=/etc/letsencrypt/live/vpn.yourdomain.com/privkey.pem
```

**Подготовка:**
```bash
# Установка certbot
apt update && apt install certbot

# Получение сертификата
certbot certonly --standalone \
  -d vpn.yourdomain.com \
  --email your@email.com \
  --agree-tos

# Автообновление
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
```

**docker-compose.marzban.yml:**
```yaml
volumes:
  - /etc/letsencrypt:/etc/letsencrypt:ro
```

### 4. Самоподписанные сертификаты (только для тестирования)

```env
DISABLE_INTERNAL_SSL=false
UVICORN_SSL_CERTFILE=/var/lib/marzban/cert.crt
UVICORN_SSL_KEYFILE=/var/lib/marzban/cert.key
SSL_CERT_DAYS=365
```

Сертификаты генерируются автоматически при запуске.

## Сравнение вариантов

| Вариант | Сложность | Стоимость | Безопасность | Рекомендация |
|---------|-----------|-----------|--------------|--------------|
| Traefik/Dokploy (внутр. SSL + Traefik снаружи) | Низкая | Бесплатно | Высокая | Для Dokploy |
| Cloudflare (внутр. SSL + Full strict) | Низкая | Бесплатно | Очень высокая | Для защиты |
| Let's Encrypt внутри контейнера | Средняя | Бесплатно | Высокая | Для VPS без внешнего прокси |
| Самоподписанные (внутр. SSL) | Низкая | Бесплатно | Средняя | Дефолт; для доступа по IP |

> Примечание: внутренний self-signed SSL (`DISABLE_INTERNAL_SSL=false`) — это значение
> по умолчанию и базовое условие доступности панели извне. Для валидного сертификата в
> subscription-ссылках клиентов терминируйте TLS на Traefik/Cloudflare или используйте
> Let's Encrypt внутри контейнера.

## Проверка SSL

```bash
# Проверка сертификата
openssl s_client -connect vpn.yourdomain.com:443 -servername vpn.yourdomain.com

# Проверка срока действия
openssl s_client -connect vpn.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
```
