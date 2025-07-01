# ☁️ Настройка Cloudflare для Marzban VPN

## 🎯 Преимущества Cloudflare для VPN

- 🛡️ **Скрытие реального IP** - пользователи не видят IP вашего сервера
- 🚀 **Ускорение** - CDN кеширует статические файлы
- 🔒 **DDoS защита** - автоматическая фильтрация атак
- 🆓 **Бесплатный SSL** - валидные сертификаты
- 📊 **Аналитика** - статистика трафика и атак

## 🚀 Пошаговая настройка

### Шаг 1: Регистрация в Cloudflare

1. Идите на [cloudflare.com](https://cloudflare.com)
2. Создайте аккаунт
3. Нажмите "Add a Site"
4. Введите ваш домен: `equiply.ru`

### Шаг 2: Смена DNS серверов

Cloudflare покажет 2 nameserver'а, например:
```
eva.ns.cloudflare.com
walt.ns.cloudflare.com
```

1. Идите к вашему регистратору домена
2. Смените NS серверы на предоставленные Cloudflare
3. Дождитесь активации (до 24 часов, обычно 1-2 часа)

### Шаг 3: Настройка DNS записей

В панели Cloudflare → DNS → Records:

```
Type: A
Name: vpn
Content: IP_ВАШЕГО_СЕРВЕРА
Proxy: ☁️ Proxied (ВАЖНО!)
TTL: Auto
```

### Шаг 4: Настройка SSL

В панели Cloudflare → SSL/TLS:

1. **Overview**: выберите "Full (strict)"
2. **Edge Certificates**: 
   - ✅ Always Use HTTPS: ON
   - ✅ HTTP Strict Transport Security: ON
   - ✅ Minimum TLS Version: 1.2
3. **Origin Server**: создайте Origin Certificate (для усиления безопасности)

### Шаг 5: Настройка безопасности

**Security → WAF**:
- ✅ Web Application Firewall: ON
- Создайте правила для VPN портов

**Security → DDoS**:
- ✅ HTTP DDoS Attack Protection: ON
- ✅ Network-layer DDoS Attack Protection: ON

### Шаг 6: Оптимизация для VPN

**Speed → Optimization**:
- ✅ Auto Minify: OFF (может ломать VPN конфиги)
- ✅ Rocket Loader: OFF
- ✅ Mirage: OFF

**Network**:
- ✅ HTTP/2: ON
- ✅ HTTP/3 (with QUIC): ON
- ✅ 0-RTT Connection Resumption: ON

## ⚙️ Настройка проекта для Cloudflare

### Обновите .env файл:

```env
# Основные настройки
DOMAIN=vpn.equiply.ru
XRAY_SUBSCRIPTION_URL_PREFIX=https://vpn.equiply.ru

# SSL через Cloudflare
DISABLE_INTERNAL_SSL=true

# Отключаем лишние SSL проверки
UVICORN_SSL_CERTFILE=""
UVICORN_SSL_KEYFILE=""
UVICORN_SSL_CA_TYPE=""
```

### Обновите docker-compose.yml:

```yaml
environment:
  - WARP_ENABLED=true
  - WARP_HOST=warp-proxy
  - WARP_PORT=1080
  - DISABLE_INTERNAL_SSL=true
  - DOMAIN=vpn.equiply.ru
```

### Уберите Traefik labels в Dokploy

Поскольку Cloudflare обрабатывает SSL, можно упростить:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=dokploy-network"
  - "traefik.http.services.marzban-web.loadbalancer.server.port=8003"
  # Убираем SSL настройки - Cloudflare их обрабатывает
```

## 🔧 Специальные правила для VPN портов

В Cloudflare → Security → WAF → Custom Rules создайте:

**Правило 1: Разрешить VPN порты**
```
Field: URI Path
Operator: contains
Value: /api/
Action: Allow
```

**Правило 2: Защита админки**
```
Field: URI Path  
Operator: equals
Value: /dashboard
Action: Managed Challenge
```

## 📊 Мониторинг

**Security → Analytics**:
- Просматривайте атаки и их блокировку
- Анализируйте источники трафика

**Analytics → Traffic**:
- Статистика запросов
- Время ответа сервера

## ⚠️ Важные настройки для VPN

### 1. Cloudflare не должен кешировать API

В **Caching → Configuration**:
```
Cache Level: Standard
Browser Cache TTL: 4 hours
```

В **Page Rules** создайте:
```
URL: vpn.equiply.ru/api/*
Settings: Cache Level = Bypass
```

### 2. Исключения для WebSocket

Если используете WebSocket соединения:
```
URL: vpn.equiply.ru/ws/*
Settings: Disable Cloudflare Apps
```

## 🎯 Итоговая архитектура

```
Пользователь → Cloudflare (SSL, DDoS защита) → Ваш сервер (HTTP)
```

**Преимущества:**
- 🔒 Реальный IP сервера скрыт
- 🛡️ Защита от DDoS атак  
- 🚀 Ускорение через CDN
- 📈 Детальная аналитика
- 🆓 Бесплатные SSL сертификаты

## 🚨 Финальная проверка

После настройки проверьте:

1. **SSL**: `https://vpn.equiply.ru/dashboard/` - должен открываться без ошибок
2. **Скрытие IP**: `dig vpn.equiply.ru` - должен показывать IP Cloudflare
3. **Защита**: попробуйте DDoS тест (только для проверки!)

## 🔄 Миграция с Dokploy SSL

Если у вас уже настроен Let's Encrypt в Dokploy:

1. В Dokploy отключите SSL для домена
2. Настройте Cloudflare
3. Обновите переменные окружения
4. Перезапустите проект

---

**🎉 Готово!** Ваш VPN теперь защищен Cloudflare и работает быстрее.
