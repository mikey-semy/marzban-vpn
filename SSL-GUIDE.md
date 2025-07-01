# 🔒 Руководство по SSL сертификатам для Marzban VPN

## 🆓 Бесплатные варианты (рекомендуемые)

### 1. **Let's Encrypt через Dokploy** ⭐ Самый простой

**Преимущества:**
- ✅ Абсолютно бесплатно
- ✅ Автоматическое получение и обновление
- ✅ Настраивается в 2 клика
- ✅ Поддерживается всеми браузерами

**Настройка:**
1. В Dokploy → Projects → Ваш проект → Domains
2. Добавьте домен: `vpn.yourdomain.com`
3. Включите "Generate SSL Certificate"
4. Выберите "Let's Encrypt"
5. ✅ Готово!

**Переменные окружения:**
```env
DISABLE_INTERNAL_SSL=true
```

### 2. **Cloudflare SSL** ⭐ + защита от DDoS

**Преимущества:**
- ✅ Бесплатно
- ✅ Защита от DDoS атак
- ✅ CDN ускорение
- ✅ Скрытие реального IP сервера

**Настройка:**
1. Регистрируйтесь на [Cloudflare](https://cloudflare.com)
2. Добавьте свой домен
3. Измените NS серверы у регистратора
4. В DNS создайте A-запись: `vpn` → `IP_сервера`
5. Включите "Proxy" (оранжевое облако ☁️)
6. SSL/TLS → "Full (strict)"

**Переменные окружения:**
```env
DISABLE_INTERNAL_SSL=true
```

### 3. **Let's Encrypt внутри контейнера**

**Когда использовать:**
- Нет Traefik/Cloudflare
- Прямое подключение к серверу
- Нужен полный контроль

**Настройка:**
```bash
# Установка certbot
apt update && apt install certbot

# Получение сертификата
certbot certonly --standalone \
  --preferred-challenges http \
  --email your@email.com \
  --agree-tos \
  --no-eff-email \
  -d vpn.yourdomain.com

# Автообновление
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
```

**Переменные окружения:**
```env
DISABLE_INTERNAL_SSL=false
USE_LETSENCRYPT_CERTS=true
LETSENCRYPT_CERT_PATH=/etc/letsencrypt/live/vpn.yourdomain.com/fullchain.pem
LETSENCRYPT_KEY_PATH=/etc/letsencrypt/live/vpn.yourdomain.com/privkey.pem
DOMAIN=vpn.yourdomain.com
```

**docker-compose дополнения:**
```yaml
volumes:
  - /etc/letsencrypt:/etc/letsencrypt:ro
```

## 💰 Платные варианты (если нужны особые требования)

### 1. **Sectigo PositiveSSL** - ~$8/год
- ✅ Годовой срок (не 90 дней)
- ✅ Техподдержка
- ✅ Wildcard сертификаты
- 🛒 [Купить](https://sectigo.com)

### 2. **Namecheap SSL** - ~$6/год
- ✅ Простая установка
- ✅ Unlimited reissues
- 🛒 [Купить](https://namecheap.com/ssl)

### 3. **GoGetSSL** - ~$3/год
- ✅ Самые дешевые цены
- ✅ Быстрая активация
- 🛒 [Купить](https://gogetssl.com)

## 🔧 Режимы работы SSL в проекте

### Режим 1: Traefik/Cloudflare (рекомендуется)
```env
DISABLE_INTERNAL_SSL=true
```
- Marzban работает по HTTP
- SSL обрабатывается на уровне прокси

### Режим 2: Let's Encrypt внутри контейнера
```env
USE_LETSENCRYPT_CERTS=true
LETSENCRYPT_CERT_PATH=/path/to/fullchain.pem
LETSENCRYPT_KEY_PATH=/path/to/privkey.pem
```
- Marzban работает по HTTPS
- Сертификаты монтируются в контейнер

### Режим 3: Самоподписанные (только для тестов)
```env
DISABLE_INTERNAL_SSL=false
```
- Автоматическая генерация самоподписанных сертификатов
- ⚠️ Браузеры будут показывать предупреждения

## 🏆 Рекомендации

### Для продакшена в Dokploy:
1. **Let's Encrypt через Dokploy** - самый простой
2. **Cloudflare** - если нужна дополнительная защита

### Для VPS без панели управления:
1. **Cloudflare** - скрывает IP сервера
2. **Let's Encrypt + Certbot** - если IP не критичен

### Для корпоративного использования:
1. **Платные SSL** - для соответствия требованиям
2. **Wildcard сертификаты** - для поддоменов

## 🚀 Быстрый старт

**Самый простой способ (5 минут):**

1. Регистрируетесь на [Cloudflare](https://cloudflare.com)
2. Добавляете домен и меняете NS
3. Создаете A-запись с прокси ☁️
4. В .env ставите `DISABLE_INTERNAL_SSL=true`
5. ✅ Готово! SSL работает + защита от DDoS

**Результат:**
- 🔒 Валидный SSL сертификат
- 🛡️ Защита от атак
- 🚀 Ускорение через CDN
- 🎭 Скрытый реальный IP сервера
