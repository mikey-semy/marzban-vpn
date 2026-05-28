# Hysteria2 — второй независимый канал (UDP/QUIC)

Hysteria2 поднимается **отдельным контейнером** рядом с Marzban на том же немецком сервере. Это:
- другое семейство транспорта (UDP/QUIC) — живёт, если ТСПУ убьёт TCP/Reality;
- агрессивный congestion control (brutal) — иногда выжимает из зажатого мобильного канала больше, чем TCP;
- Salamander-обфускация прячет QUIC-хендшейк.

> Hysteria2 — НЕ обход whitelist-режима (идёт напрямую на IP сервера). Для whitelist используется Cloudflare-fronting (см. docs/CLOUDFLARE.md). Hysteria2 — про скорость и резерв.

## 1. DNS (Cloudflare)
1. Переведи зону `equiply.ru` на Cloudflare (NS у регистратора → cloudflare).
2. Создай запись: `hy.equiply.ru` → **A** → `45.152.22.222`, **DNS only (серое облако)**.
   CF не проксирует UDP/QUIC, поэтому Hysteria2 ходит напрямую — облако обязательно серое.

## 2. Cloudflare API Token (для ACME DNS-01)
Cloudflare → My Profile → API Tokens → Create Token → шаблон **Edit zone DNS** →
Zone Resources: `equiply.ru`. Скопируй токен.

## 3. Конфиг
```bash
cp hysteria/server.yaml.example hysteria/server.yaml
# сгенерь два пароля:
openssl rand -base64 24    # → OBFS пароль
openssl rand -base64 24    # → AUTH пароль
nano hysteria/server.yaml  # вставь cloudflare_api_token + оба пароля
```

## 4. Порт
Убедись, что **443/udp свободен** (не занят Amnezia). Если занят — поменяй порт в
`docker-compose.hysteria.yml` и `listen:` в server.yaml на свободный (напр. 8443).
Открой UDP-порт в фаерволе HOSTKEY.

## 5. Запуск
```bash
docker compose -f docker-compose.hysteria.yml up -d
docker logs hysteria2 --tail 50   # должен выпустить Let's Encrypt сертификат через CF DNS-01
```

## 6. Клиент (Hiddify / NekoBox)
Ссылка для импорта:
```
hysteria2://AUTH_ПАРОЛЬ@hy.equiply.ru:443/?obfs=salamander&obfs-password=OBFS_ПАРОЛЬ&sni=hy.equiply.ru#Hysteria2-DE
```
(подставь свои пароли). С реальным Let's Encrypt-сертификатом `insecure` не нужен.

## 7. Тест
На **мобиле** (Amnezia/другой VPN выключен): подключись, проверь IP (должен быть 45.152.22.222)
и скорость — сравни с XHTTP (2444). Если Hysteria2 заметно быстрее — это твой основной канал на мобиле.

---

## Быстрый старт без Cloudflare (вариант B, самоподписанный)
Если зона ещё не на Cloudflare:
```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout hysteria/cert.key -out hysteria/cert.crt -subj "/CN=hy.equiply.ru"
```
В `server.yaml`: закомментируй `acme:`, раскомментируй блок `tls:`. В compose добавь монтирование
`./hysteria/cert.crt` и `./hysteria/cert.key` в `/etc/hysteria/`. На клиенте включи `insecure`.
Минус: при зондировании сертификат самоподписанный (хуже маскировка) — позже перейди на ACME.

## Порт-хоппинг (апгрейд живучести)
Когда одиночный порт начнут резать: `listen: :20000-50000` в server.yaml + iptables NAT
правило, перенаправляющее диапазон на рабочий порт. Распишем отдельно при необходимости.
