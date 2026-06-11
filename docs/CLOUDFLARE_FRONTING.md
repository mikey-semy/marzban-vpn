# Cloudflare Fronting — обход whitelist через CF edge

Дополнительный VLESS+XHTTP инбаунд, доступный **через Cloudflare** вместо прямого подключения к серверу. Существует **рядом** с обычным Reality-инбаундом на 2444, не заменяя его.

## Зачем

В whitelist-режиме ТСПУ режет соединения к dst-IP вне белого списка после ~16-20 KB данных. Это убивает любой бараchный exit на немецком IP. Но **Cloudflare-овские IP в белом списке** (заблочить CF целиком = положить пол-рунета), поэтому если клиент коннектится к домену через CF orange-cloud, dst-IP для ТСПУ становится cloudflare-овским — соединение проходит.

Также этот канал часто работает там, где XHTTP+Reality на 2444 не работает (агрессивный JA4/поведенческий DPI у конкретного оператора), потому что снаружи выглядит как обычный браузер ходит к CDN-сайту.

## Архитектура

```
Клиент → cf.sethub.org:8443 (orange) → CF edge → 45.152.22.222:8443 → Marzban (Xray)
              dst-IP = Cloudflare                       TLS Origin Cert
              (whitelisted в РФ)                        (15 лет, валидный для CF)
```

| Параметр | Существующий 2444 | Новый CF (8443) |
|---|---|---|
| Транспорт | VLESS+XHTTP | VLESS+XHTTP |
| Security | Reality (steal SNI=microsoft) | TLS (валидный Origin Cert) |
| Mode | `stream-up` | `packet-up` (для CDN) |
| Куда коннектится клиент | напрямую IP сервера | `cf.sethub.org` через CF edge |
| dst-IP для ТСПУ | datacenter Hetzner/HOSTKEY | Cloudflare (whitelisted) |
| Path | `/api/v1/data` | `/api/v2/cf` |

## Что нужно сделать

### 1. Подтвердить, что `cf.sethub.org` создан в Cloudflare
- DNS → Records:
  - `cf` → A → `45.152.22.222` → **Proxied (оранжевое облако)**.

### 2. Создать Origin Certificate в Cloudflare
Cloudflare → выбранная зона → **SSL/TLS → Origin Server → Create Certificate**:
- **Hostnames:** `cf.sethub.org` (или `*.sethub.org` если хочешь покрыть все поддомены сразу).
- **Private key type:** RSA (2048) или ECDSA — без разницы.
- **Validity:** **15 лет** (максимум).
- **Create** → откроется страница с **Certificate** (PEM) и **Private Key** (PEM) — **скопируй оба сразу**, показывается один раз.

⚠️ **Сохрани оба в защищённое место (passwords manager)** — если потеряешь, придётся перевыпускать и переподключать всех клиентов.

### 3. Положить сертификат на сервер
В томе Marzban нужно создать файлы:
- `/var/lib/marzban/certs/cf-origin.crt` — Certificate (PEM)
- `/var/lib/marzban/certs/cf-origin.key` — Private Key (PEM)

#### Через SSH
```bash
# Создаём временные файлы
nano /tmp/cf-origin.crt   # вставь Certificate PEM целиком (---BEGIN CERTIFICATE--- ... ---END CERTIFICATE---)
nano /tmp/cf-origin.key   # вставь Private Key PEM целиком

# Загружаем в контейнер
docker cp /tmp/cf-origin.crt marzban:/var/lib/marzban/certs/
docker cp /tmp/cf-origin.key marzban:/var/lib/marzban/certs/

# Удаляем временные файлы
shred -u /tmp/cf-origin.crt /tmp/cf-origin.key
```

#### Через Dokploy File Manager
Если есть встроенный файловый менеджер в Dokploy — открой volume `marzban_data`, создай папку `certs`, загрузи оба файла.

### 4. Включить Cloudflare SSL/TLS mode → Full (strict)
Cloudflare → зона `sethub.org` → **SSL/TLS → Overview** → **Full (strict)**.
Это значит, что CF будет проверять наш Origin Certificate. Без этого CF может разрешить self-signed, но мы хотим чтобы он строго проверял.

### 5. Bypass Cache для CF-fronting URL
Чтобы Cloudflare не пытался кэшировать наш VPN-трафик:
- Cloudflare → **Caching → Cache Rules → Create rule**.
- **Rule name:** Bypass cache for VPN
- **When incoming requests match:** Hostname equals `cf.sethub.org`
- **Then:** Cache eligibility → **Bypass cache**.
- Save.

### 6. Открыть 8443/tcp на сервере
В фаерволе HOSTKEY (панель управления или ufw):
```bash
sudo ufw allow 8443/tcp
```

### 7. Передеплоить Marzban
- Через Dokploy: Redeploy.
- Через SSH: `docker compose -f docker-compose.marzban.yml up -d --build`.

В логах entrypoint должна появиться строка:
```
[MARZBAN-VPN] CF-fronting сертификат найден: /var/lib/marzban/certs/cf-origin.crt
```

Если вместо неё:
```
[MARZBAN-VPN] CF-fronting сертификат не найден ... Убираю инбаунд 'VLESS XHTTP CF'
```
→ сертификат не доехал до правильного места. Проверь, что файлы лежат точно по путям выше и читаемы пользователем `marzban`.

### 8. Включить инбаунд в Marzban-панели для пользователей
- В панели Marzban → каждому пользователю в **Inbounds** должен появиться `VLESS XHTTP CF` — поставь галку.
- Subscription URL юзера автоматически начнёт отдавать дополнительную ссылку:
  ```
  vless://<UUID>@cf.sethub.org:8443?security=tls&type=xhttp&path=%2Fapi%2Fv2%2Fcf&mode=packet-up&sni=cf.sethub.org#CF-fronting
  ```

### 9. Тест с клиента
- Импортни новую ссылку в **Hiddify** / NekoBox / Streisand.
- Подключайся на той сети, где обычный 2444 не работал (мобильный МТС / whitelist-режим).
- Проверь: открываются ли заблокированные сайты? IP при подключении к https://ipinfo.io должен быть **не российским** (обычно Cloudflare-овский, потому что для не-RU доменов трафик идёт через тоннель → твой сервер → интернет).

## Проверочные команды

### Сертификат лежит правильно?
```bash
docker exec marzban ls -la /var/lib/marzban/certs/
```
Должно быть два файла: `cf-origin.crt` и `cf-origin.key`, владелец `marzban:marzban`.

### Сертификат валидный?
```bash
docker exec marzban openssl x509 -in /var/lib/marzban/certs/cf-origin.crt -noout -dates -subject
```
Должен показать срок действия и `subject` с `CN=cf.sethub.org` (или wildcard).

### Inbound поднялся в Xray?
```bash
docker exec marzban grep -A 5 '"VLESS XHTTP CF"' /var/lib/marzban/xray_config.json
```

### CF доходит до origin?
С локальной машины (НЕ через VPN):
```bash
curl -k -v https://cf.sethub.org:8443/api/v2/cf
```
Ожидаемое: ответ 400 Bad Request от Xray (XHTTP не принимает кривые запросы) — это **означает, что TLS-handshake прошёл, инбаунд жив**.

## Решение проблем

| Симптом | Причина | Лечение |
|---|---|---|
| В логах `CF-fronting сертификат не найден` | Файлы не в `/var/lib/marzban/certs/` | Переложить туда; проверить имена `cf-origin.crt` и `cf-origin.key` |
| `Permission denied` при чтении ключа | Права на файле | `docker exec marzban chmod 600 /var/lib/marzban/certs/cf-origin.key` |
| Xray падает с `tls handshake error` | Cloudflare SSL mode не Full (strict) | Включить в CF → SSL/TLS → Full (strict) |
| 521/525 Bad Gateway при заходе через `https://cf.sethub.org:8443` | CF не может достучаться до origin | Проверить, что 8443/tcp открыт на сервере, A-запись на правильный IP |
| `cf.sethub.org` показывает Welcome page Cloudflare | Не настроена Page Rule / нет VLESS-инбаунда | Передеплоить Marzban, убедиться что инбаунд активен |

## Безопасность

- **Origin Certificate** валиден ТОЛЬКО для связки CF↔origin, не для публичных клиентов. Это не Let's Encrypt-сертификат, обычные браузеры на него ругнутся при прямом заходе на `https://45.152.22.222:8443/`. Это нормально и так задумано.
- **Сам сертификат и приватный ключ** — секретные. Никому не показывай, не коммить в git (мы их добавили в .gitignore).
- **Cloudflare видит трафик в открытом виде** между собой и origin (он же терминирует TLS на edge). Это by design для CF-fronting — мы намеренно отдаём CF возможность видеть наш трафик в обмен на whitelisted IP. Если это неприемлемо — нужен не fronting, а Reality (прямое подключение, без CF в цепочке).

## Что НЕ работает с CF-fronting
- ❌ **UDP-трафик** (Hysteria2) — CF не проксирует UDP на Free плане.
- ❌ **WebSocket в "стриминговом" режиме** долгих соединений — CF может рвать после 100 сек idle. Поэтому используем `mode: packet-up` (короткие POST/GET, обходит таймаут).
- ❌ **HTTP/3** напрямую от клиента к CF — иногда не работает, fallback на HTTP/2 включается автоматически.
