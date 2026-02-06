# Настройка Cloudflare

## Преимущества

- Скрытие реального IP сервера
- Защита от DDoS атак
- Бесплатные SSL сертификаты
- CDN ускорение
- Детальная аналитика

## Настройка

### 1. Регистрация

1. Зарегистрируйтесь на [cloudflare.com](https://cloudflare.com)
2. Нажмите **Add a Site**
3. Введите ваш домен

### 2. Смена DNS серверов

Cloudflare предоставит два nameserver'а:
```
eva.ns.cloudflare.com
walt.ns.cloudflare.com
```

1. Перейдите к регистратору домена
2. Смените NS серверы на предоставленные
3. Дождитесь активации (обычно 1-24 часа)

### 3. DNS записи

В **DNS → Records** создайте:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | vpn | IP_СЕРВЕРА | Proxied (оранжевое облако) |

### 4. SSL/TLS настройки

**SSL/TLS → Overview:**
- Выберите **Full (strict)**

**SSL/TLS → Edge Certificates:**
- Always Use HTTPS: **ON**
- Minimum TLS Version: **1.2**

### 5. Настройка проекта

В `.env`:
```env
DISABLE_INTERNAL_SSL=true
DOMAIN=vpn.yourdomain.com
XRAY_SUBSCRIPTION_URL_PREFIX=https://vpn.yourdomain.com
```

## Оптимизация для VPN

### Отключение оптимизаций

**Speed → Optimization:**
- Auto Minify: **OFF**
- Rocket Loader: **OFF**
- Mirage: **OFF**

Эти опции могут нарушить работу VPN конфигураций.

### Исключения для API

**Caching → Configuration:**
- Cache Level: Standard

**Rules → Page Rules:**
```
URL: vpn.yourdomain.com/api/*
Setting: Cache Level = Bypass
```

### WAF правила

**Security → WAF → Custom Rules:**

**Защита админки:**
```
Field: URI Path
Operator: equals
Value: /dashboard
Action: Managed Challenge
```

**Разрешить API:**
```
Field: URI Path
Operator: contains
Value: /api/
Action: Allow
```

## Проверка

### DNS

```bash
dig vpn.yourdomain.com
# Должен показать IP Cloudflare, не ваш сервер
```

### SSL

Откройте `https://vpn.yourdomain.com/dashboard/` - должен открыться без ошибок.

### Защита

В **Security → Analytics** можно видеть заблокированные атаки.

## Архитектура

```
Пользователь
     │
     ▼
┌─────────────────┐
│   Cloudflare    │
│   (CDN, SSL,    │
│   DDoS защита)  │
└─────────────────┘
     │
     ▼
┌─────────────────┐
│   Ваш сервер    │
│   (HTTP)        │
└─────────────────┘
```

## Миграция с Let's Encrypt

Если уже настроен SSL через Traefik/Dokploy:

1. В Dokploy отключите SSL для домена
2. Настройте Cloudflare
3. Установите `DISABLE_INTERNAL_SSL=true`
4. Перезапустите проект
