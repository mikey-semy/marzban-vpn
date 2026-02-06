# Настройка SSL сертификатов

## Варианты SSL

### 1. Traefik/Dokploy (рекомендуется)

SSL обрабатывается внешним прокси-сервером.

```env
DISABLE_INTERNAL_SSL=true
```

**Преимущества:**
- Автоматическое получение Let's Encrypt сертификатов
- Автоматическое обновление
- Простота настройки

### 2. Cloudflare

SSL обрабатывается Cloudflare.

```env
DISABLE_INTERNAL_SSL=true
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
| Traefik/Dokploy | Низкая | Бесплатно | Высокая | Для Dokploy |
| Cloudflare | Низкая | Бесплатно | Очень высокая | Для защиты |
| Let's Encrypt | Средняя | Бесплатно | Высокая | Для VPS |
| Самоподписанные | Низкая | Бесплатно | Низкая | Только тесты |

## Проверка SSL

```bash
# Проверка сертификата
openssl s_client -connect vpn.yourdomain.com:443 -servername vpn.yourdomain.com

# Проверка срока действия
openssl s_client -connect vpn.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
```
